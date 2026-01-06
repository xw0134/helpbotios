import Foundation
import WebKit
import UIKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/**
 HelpBot WebView 会话管理器（SDK 内部单例）。
 - install 阶段：无 UI 预创建 WKWebView + 加载 WebSDK loader 并完成 HelpBot('init') 初始化
 - showConversation 阶段：UIViewController 接管同一个 WKWebView，保证复用与稳定
 */
final class HelpBotWebViewSession: NSObject {
    private static let tag = "HBWebViewSession"
    static let shared = HelpBotWebViewSession()

    // 轮询间隔
    private static let pollingStepIntervalMs: Int = 200
    private static let statusBlockingTimeoutMs: Int = 1200
    private static let bootstrapBlockingTimeoutMs: Int = 1200

    // 监控轮询间隔（对齐 Android 策略：前 30 秒高频，之后低频）
    private static let monitorHighFreqDurationMs: Int64 = 30_000
    private static let monitorHighFreqIntervalMs: Int64 = 1_000
    private static let monitorLowFreqIntervalMs: Int64 = 5_000
    private static let bootstrapRefreshIntervalMs: Int64 = 10_000

    private let mainQueue = DispatchQueue.main
    private let stateLock = NSLock()

    private var isPreloading: Bool = false
    private var isInitialized: Bool = false
    private var hasInitFailed: Bool = false

    private var webSdkInitLatch: HBCountDownLatch = HBCountDownLatch(1)
    private var webSdkInitFailedReason: String?

    private let loginWaitLock = NSLock()
    private var currentLoginWaiter: LoginWaiter?

    private var pendingOpenConversation: Bool = false

    private var config: HelpBotConfig?
    private var eventProxy: EventProxy?
    private var bridge: ChatToNativeBridge?

    private(set) var webView: WKWebView?
    private weak var attachedViewController: UIViewController?
    private weak var attachedContainerView: UIView?
    private var documentPickerCoordinator: DocumentPickerCoordinator?

    // status snapshot
    private var lastStatusSnapshot: [String: Any]?
    private var lastStatusUpdatedAtMs: Int64 = 0

    // bootstrap snapshot（通道就绪判定）
    private var lastBootstrapSnapshot: [String: Any]?
    private var lastBootstrapUpdatedAtMs: Int64 = 0

    // 健康监管（install 完成后持续运行，直到 destroy）
    private var isMonitoring: Bool = false
    private var lastHealthLevel: String?
    private var lastStatusJson: String?
    private var firstAuthenticatedAtMs: Int64 = 0
    private var lastRealtimeConnectedAtMs: Int64 = 0
    private var lastIssueSeenAtMs: Int64 = 0
    private var monitorEventProxy: EventProxy?

    // 页面加载兜底重试次数（弱网/偶发 DNS 抖动）
    private var pageLoadRetryCount: Int = 0
    private var initRetryCount: Int = 0
    private var initTimeoutTimer: DispatchSourceTimer?

    // 最近一次 WebView 错误快照（用于 install 超时诊断/提示）
    private var lastLoadErrorSnapshot: WebViewLoadErrorSnapshot?

    private override init() {
        super.init()
    }

    /// install 阶段预加载（主线程创建 WKWebView）
    func preload(config: HelpBotConfig, eventProxy: EventProxy) {
        self.config = config
        self.eventProxy = eventProxy

        // 若上一次初始化失败，允许重试（只有 FAILED 才允许再次 install）
        if hasInitFailed {
            resetForRetry()
        }

        if isInitialized { return }
        if isPreloading { return }
        isPreloading = true

        // 复位重试计数与错误快照
        stateLock.lock()
        pageLoadRetryCount = 0
        initRetryCount = 0
        lastLoadErrorSnapshot = nil
        stateLock.unlock()

        // 初始化超时守护
        let effectiveTimeout = max(config.initTimeoutMs, 35_000)
        startInitTimeoutGuard(timeoutMs: effectiveTimeout)

        mainQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.ensureWebViewCreatedOnMainThread()
                self.loadWebChatIndex()
                self.startPollingWebSdkStatus(initialDelayMs: 0)
            } catch {
                self.hasInitFailed = true
                self.isPreloading = false
                HBlogger.e(Self.tag, "preload 异常: \(error.localizedDescription)", error)
                self.markWebSdkInitFailed("preload_exception")
            }
        }
    }

    func attach(to viewController: UIViewController, containerView: UIView) {
        mainQueue.async { [weak self] in
            guard let self else { return }
            // 若宿主未 preload（或 closeSession 后 WebView 被销毁），此处补一次初始化
            if self.webView == nil, let cfg = self.config, let proxy = self.eventProxy {
                self.preload(config: cfg, eventProxy: proxy)
            }
            guard let webView = self.webView else { return }
            self.attachedViewController = viewController
            self.attachedContainerView = containerView
            webView.removeFromSuperview()
            webView.frame = containerView.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(webView)
            self.tryOpenConversationIfPossible()
        }
    }

    func detach() {
        mainQueue.async { [weak self] in
            guard let self else { return }
            self.attachedViewController = nil
            self.attachedContainerView = nil
        }
    }

    /**
     销毁会话（释放 WKWebView 与状态）。建议在宿主明确退出/注销或 SDK destroy 时调用。

     - 释放 WebView 资源
     - 复位 latch/状态机，避免下一次 install 被旧状态污染
     */
    func destroy() {
        mainQueue.async { [weak self] in
            guard let self else { return }
            self.destroyOnMainThread()
        }
    }

    /// showConversation 触发：当 WKWebView attach 后尽快 open
    func openWhenReady() {
        pendingOpenConversation = true
        tryOpenConversationIfPossible()
    }

    /// 等待 WebSDK 初始化完成（loaded=true 且 initialized=true）
    func awaitWebSdkInitialized(timeoutMs: Int) -> Bool {
        if Thread.isMainThread {
            // 禁止主线程等待
            HBlogger.w(Self.tag, "awaitWebSdkInitialized 禁止在主线程调用", nil)
            return false
        }
        if isInitialized { return true }
        return webSdkInitLatch.await(timeoutMs: timeoutMs) && isInitialized
    }

    func getWebSdkInitFailedReason() -> String? {
        return webSdkInitFailedReason
    }

    /**
     最近一次 WebView 加载错误快照（仅诊断/提示用，避免在日志中输出敏感信息）。
     */
    func getLastLoadErrorSnapshot() -> WebViewLoadErrorSnapshot? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastLoadErrorSnapshot
    }

    /**
     WebView 加载错误快照
     */
    struct WebViewLoadErrorSnapshot {
        let type: String
        let url: String?
        let errorCode: Int?
        let description: String?
        let mainFrame: Bool
        let httpStatus: Int?
        let atMs: Int64
    }

    // MARK: - Bootstrap readiness（Bridge/Native 通道就绪）

    /**
     获取 WebSDK/Bridge 基础就绪信息（阻塞，禁止主线程）。

     install 判定“通道就绪”的标准（）：
     - HelpBot 函数存在
     - HelpBotBridge 存在（bridge.js 已加载）
     - Native Bridge 对象存在（window.HelpBotNativeIOS）且具备 sendEvent
     */
    func getWebSdkBootstrapInfoBlocking(timeoutMs: Int) -> [String: Any]? {
        if Thread.isMainThread { return nil }
        guard let webView else { return nil }

        let latch = HBCountDownLatch(1)
        var result: [String: Any]?
        let js = """
        (function(){try{
          var r={};
          r.helpBotExists=(typeof window.HelpBot==='function');
          r.helpBotBridgeExists=!!window.HelpBotBridge;
          r.nativeIOSExists=!!window.HelpBotNativeIOS;
          r.nativeSendEventExists=!!(window.HelpBotNativeIOS&&typeof window.HelpBotNativeIOS.sendEvent==='function');
          return JSON.stringify(r);
        }catch(e){return '';}})();
        """

        mainQueue.async {
            webView.evaluateJavaScript(js) { value, _ in
                defer { latch.countDown() }
                if let s = value as? String, let parsed = HelpBotJsonUtils.parseJsonObject(s) {
                    result = parsed
                } else if let dict = value as? [String: Any] {
                    result = dict
                }
            }
        }

        _ = latch.await(timeoutMs: max(timeoutMs, 0))
        return result
    }

    /**
     install 用：等待 bootstrap “全就绪”。
     */
    func awaitWebSdkBootstrapReady(timeoutMs: Int) -> Bool {
        if Thread.isMainThread { return false }
        let deadline = nowMs() + Int64(max(timeoutMs, 0))
        while nowMs() < deadline {
            if let info = getWebSdkBootstrapInfoBlocking(timeoutMs: Self.bootstrapBlockingTimeoutMs) {
                stateLock.lock()
                lastBootstrapSnapshot = info
                lastBootstrapUpdatedAtMs = nowMs()
                stateLock.unlock()

                let ok = (info["helpBotExists"] as? Bool) == true
                    && (info["helpBotBridgeExists"] as? Bool) == true
                    && (info["nativeIOSExists"] as? Bool) == true
                    && (info["nativeSendEventExists"] as? Bool) == true
                if ok { return true }
            }
            Thread.sleep(forTimeInterval: TimeInterval(Self.pollingStepIntervalMs) / 1000.0)
        }
        return false
    }

    // MARK: - WebSDK monitoring（健康监管）

    func startMonitoring(eventProxy: EventProxy?) {
        stateLock.lock()
        if isMonitoring {
            stateLock.unlock()
            return
        }
        isMonitoring = true
        monitorEventProxy = eventProxy
        stateLock.unlock()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.monitorLoop()
        }
    }

    func stopMonitoring() {
        stateLock.lock()
        isMonitoring = false
        monitorEventProxy = nil
        stateLock.unlock()
    }

    /**
     获取 WebSDK 健康快照（用于宿主查询/埋点/诊断）。
     注意：此方法不触发 JS 执行，仅返回最近一次监控采样结果。
     */
    func getHealthSnapshot() -> [String: Any] {
        stateLock.lock()
        defer { stateLock.unlock() }
        var data: [String: Any] = [:]
        data["websdkInitialized"] = isInitialized
        data["websdkInitFailed"] = hasInitFailed
        data["websdkInitFailedReason"] = webSdkInitFailedReason ?? ""
        data["lastHealthLevel"] = lastHealthLevel ?? "UNKNOWN"
        data["lastStatusUpdatedAtMs"] = lastStatusUpdatedAtMs
        data["lastBootstrapUpdatedAtMs"] = lastBootstrapUpdatedAtMs
        data["firstAuthenticatedAtMs"] = firstAuthenticatedAtMs
        data["lastRealtimeConnectedAtMs"] = lastRealtimeConnectedAtMs
        data["lastIssueSeenAtMs"] = lastIssueSeenAtMs
        if let err = lastLoadErrorSnapshot {
            data["lastWebViewErrorType"] = err.type
            data["lastWebViewErrorMainFrame"] = err.mainFrame
            data["lastWebViewErrorAtMs"] = err.atMs
            if let code = err.errorCode { data["lastWebViewErrorCode"] = code }
            if let status = err.httpStatus { data["lastWebViewHttpStatus"] = status }
        }
        if let bootstrap = lastBootstrapSnapshot {
            data["bootstrap"] = HelpBotJsonUtils.toJsonString(bootstrap) ?? ""
        }
        if let status = lastStatusSnapshot {
            data["status"] = HelpBotJsonUtils.toJsonString(status) ?? ""
            data["authenticated"] = (status["authenticated"] as? Bool) ?? false
            data["hasIssue"] = (status["hasIssue"] as? Bool) ?? false
            data["issueId"] = (status["issueId"] as? String) ?? ""
            data["realtimeConnected"] = (status["realtimeConnected"] as? Bool) ?? false
        }
        return data
    }

    // MARK: - Login waiter

    final class LoginWaiter {
        private let condition = NSCondition()
        private var finished: Bool = false
        private var success: Bool = false
        private var eventData: [String: Any]?
        private var failReason: String?
        private var failDetail: [String: Any]?

        func awaitStep(_ timeoutMs: Int) {
            let timeout = TimeInterval(max(timeoutMs, 0)) / 1000.0
            let deadline = Date().addingTimeInterval(timeout)
            condition.lock()
            defer { condition.unlock() }
            while !finished {
                if !condition.wait(until: deadline) { break }
            }
        }

        func isFinished() -> Bool { condition.withLock { finished } }
        func isSuccess() -> Bool { condition.withLock { success } }
        func getFailReason() -> String? { condition.withLock { failReason } }
        func getFailDetail() -> [String: Any]? { condition.withLock { failDetail } }
        func getEventData() -> [String: Any]? { condition.withLock { eventData } }

        func cancel(_ reason: String) {
            condition.lock()
            if finished { condition.unlock(); return }
            finished = true
            success = false
            failReason = reason
            condition.broadcast()
            condition.unlock()
        }

        func succeed(_ eventData: [String: Any]?) {
            condition.lock()
            if finished { condition.unlock(); return }
            finished = true
            success = true
            self.eventData = eventData
            condition.broadcast()
            condition.unlock()
        }

        func fail(_ reason: String, _ detail: [String: Any]?) {
            condition.lock()
            if finished { condition.unlock(); return }
            finished = true
            success = false
            failReason = reason
            failDetail = detail
            condition.broadcast()
            condition.unlock()
        }
    }

    func beginLoginWait() -> LoginWaiter {
        loginWaitLock.lock()
        defer { loginWaitLock.unlock() }
        currentLoginWaiter?.cancel("login_replaced")
        let w = LoginWaiter()
        currentLoginWaiter = w
        return w
    }

    func notifyWebSdkSdkReady(eventData: [String: Any]?) {
        loginWaitLock.lock()
        defer { loginWaitLock.unlock() }
        currentLoginWaiter?.succeed(eventData)
        currentLoginWaiter = nil
    }

    func notifyWebSdkLoginFailed(reason: String, detail: [String: Any]?) {
        loginWaitLock.lock()
        defer { loginWaitLock.unlock() }
        currentLoginWaiter?.fail(reason, detail)
        currentLoginWaiter = nil
    }

    // MARK: - Status snapshot

    func isAuthenticatedSnapshot(maxAgeMs: Int) -> Bool {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let age = now - lastStatusUpdatedAtMs
        if age > Int64(max(maxAgeMs, 0)) { return false }
        let authed = (lastStatusSnapshot?["authenticated"] as? Bool) ?? false
        return authed
    }

    /// 获取 WebSDK 状态（阻塞，禁止主线程）
    func getWebSdkStatusBlocking(timeoutMs: Int) -> [String: Any]? {
        if Thread.isMainThread { return nil }
        guard let webView else { return nil }

        let latch = HBCountDownLatch(1)
        var result: [String: Any]?

        mainQueue.async {
            webView.evaluateJavaScript("try{HelpBot('getStatus')}catch(e){null}") { value, _ in
                defer { latch.countDown() }
                if let dict = value as? [String: Any] {
                    result = dict
                } else if let str = value as? String, let parsed = HelpBotJsonUtils.parseJsonObject(str) {
                    result = parsed
                }
            }
        }

        _ = latch.await(timeoutMs: max(timeoutMs, 0))
        return result
    }

    // MARK: - Private helpers

    private func nowMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /**
     初始化超时兜底：到期仍未 initialized 且未失败，则标记 init_timeout
     */
    private func startInitTimeoutGuard(timeoutMs: Int) {
        let timeout = Int64(max(timeoutMs, 0))
        if timeout <= 0 { return }

        stateLock.lock()
        initTimeoutTimer?.cancel()
        initTimeoutTimer = nil
        stateLock.unlock()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + .milliseconds(Int(timeout)))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let shouldFail = !self.isInitialized && !self.hasInitFailed
            self.stateLock.unlock()
            if shouldFail {
                self.markWebSdkInitFailed("init_timeout")
            }
        }
        stateLock.lock()
        initTimeoutTimer = timer
        stateLock.unlock()
        timer.resume()
    }

    private func cancelInitTimeoutGuard() {
        stateLock.lock()
        initTimeoutTimer?.cancel()
        initTimeoutTimer = nil
        stateLock.unlock()
    }

    private func ensureWebViewCreatedOnMainThread() throws {
        if !Thread.isMainThread {
            throw NSError(domain: "HelpBotSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "必须在主线程创建 WKWebView"])
        }
        if webView != nil { return }

        guard let cfg = config else {
            throw NSError(domain: "HelpBotSDK", code: -2, userInfo: [NSLocalizedDescriptionKey: "config 未设置"])
        }
        guard let proxy = eventProxy else {
            throw NSError(domain: "HelpBotSDK", code: -3, userInfo: [NSLocalizedDescriptionKey: "eventProxy 未设置"])
        }

        let bridge = ChatToNativeBridge(eventProxy: proxy, webViewSession: self)
        self.bridge = bridge

        let configuration = HelpBotWebViewHelper.buildConfiguration(
            fullPrivacyMode: cfg.fullPrivacyMode,
            scriptMessageHandler: bridge
        )

        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsLinkPreview = false
        if #available(iOS 16.4, *) {
            wv.isInspectable = false
        }
        self.webView = wv
    }

    private func destroyOnMainThread() {
        // 注意：必须在主线程执行 WebView 释放
        stopMonitoring()
        cancelInitTimeoutGuard()

        pendingOpenConversation = false
        pageLoadRetryCount = 0
        initRetryCount = 0

        attachedViewController = nil
        attachedContainerView = nil

        // 解除 login waiter，避免宿主卡住等待
        loginWaitLock.lock()
        currentLoginWaiter?.cancel("session_destroyed")
        currentLoginWaiter = nil
        loginWaitLock.unlock()

        if let webView {
            // 尽量移除 message handlers，打断潜在引用链
            let uc = webView.configuration.userContentController
            uc.removeScriptMessageHandler(forName: HelpBotWebViewHelper.nativeBridgeName)
            uc.removeScriptMessageHandler(forName: HelpBotWebViewHelper.sseMessageHandlerName)
            #if DEBUG
            uc.removeScriptMessageHandler(forName: HelpBotWebViewHelper.consoleLogHandlerName)
            #endif

            // 停止加载
            webView.stopLoading()

            // 从父视图移除
            webView.removeFromSuperview()

            // 加载空白页（清理渲染/资源）
            if let blank = URL(string: "about:blank") {
                webView.load(URLRequest(url: blank))
            }

            // 解除 delegate，避免回调到已释放对象
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
        }

        // 释放引用
        self.webView = nil
        self.bridge = nil

        // 复位状态（必须保证 latch 可用于下一次 install）
        stateLock.lock()
        isPreloading = false
        isInitialized = false
        hasInitFailed = false
        webSdkInitFailedReason = nil
        webSdkInitLatch = HBCountDownLatch(1)
        lastStatusSnapshot = nil
        lastStatusUpdatedAtMs = 0
        lastBootstrapSnapshot = nil
        lastBootstrapUpdatedAtMs = 0
        lastHealthLevel = nil
        lastStatusJson = nil
        firstAuthenticatedAtMs = 0
        lastRealtimeConnectedAtMs = 0
        lastIssueSeenAtMs = 0
        lastLoadErrorSnapshot = nil
        stateLock.unlock()
    }

    private func resetForRetry() {
        // 仅重置必要状态，避免旧 latch 影响重试
        cancelInitTimeoutGuard()
        stopMonitoring()
        hasInitFailed = false
        isInitialized = false
        isPreloading = false
        webSdkInitFailedReason = nil
        webSdkInitLatch = HBCountDownLatch(1)
        lastStatusSnapshot = nil
        lastStatusUpdatedAtMs = 0
        lastBootstrapSnapshot = nil
        lastBootstrapUpdatedAtMs = 0
        lastHealthLevel = nil
        lastStatusJson = nil
        firstAuthenticatedAtMs = 0
        lastRealtimeConnectedAtMs = 0
        lastIssueSeenAtMs = 0
        pageLoadRetryCount = 0
        initRetryCount = 0
        lastLoadErrorSnapshot = nil
        // 彻底释放旧 WebView，避免残留状态（Cookie/脚本等）
        mainQueue.async { [weak self] in
            guard let self else { return }
            self.webView?.navigationDelegate = nil
            self.webView?.uiDelegate = nil
            self.webView?.removeFromSuperview()
            self.webView = nil
        }
    }

    private func loadWebChatIndex() {
        guard let webView else { return }
        guard let cfg = config else { return }
        guard let url = URL(string: HelpBotSDKUrls.webChatIndex) else {
            markWebSdkInitFailed("invalid_index_url")
            return
        }
        let timeout = TimeInterval(max(cfg.webViewLoadTimeoutMs, 0)) / 1000.0
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: max(timeout, 15)))
    }

    private func markWebSdkInitFailed(_ reason: String) {
        cancelInitTimeoutGuard()
        stateLock.lock()
        if hasInitFailed || isInitialized {
            stateLock.unlock()
            return
        }
        webSdkInitFailedReason = reason
        hasInitFailed = true
        isPreloading = false
        stateLock.unlock()
        webSdkInitLatch.countDown()

        // install 失败事件：透传给宿主（便于诊断）
        eventProxy?.sendEvent("WEBSDK_INIT_FAILED", ["reason": reason, "retryCount": initRetryCount])
    }

    private func markWebSdkInitialized() {
        cancelInitTimeoutGuard()
        stateLock.lock()
        if isInitialized {
            stateLock.unlock()
            return
        }
        isInitialized = true
        hasInitFailed = false
        isPreloading = false
        webSdkInitFailedReason = nil
        stateLock.unlock()
        webSdkInitLatch.countDown()
    }

    private func startPollingWebSdkStatus(initialDelayMs: Int) {
        let delay = TimeInterval(max(initialDelayMs, 0)) / 1000.0
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.pollingStep()
        }
    }

    private func pollingStep() {
        if isInitialized || hasInitFailed { return }
        if Thread.isMainThread {
            DispatchQueue.global(qos: .utility).async { [weak self] in self?.pollingStep() }
            return
        }
        guard let status = getWebSdkStatusBlocking(timeoutMs: Self.statusBlockingTimeoutMs) else {
            scheduleNextPolling()
            return
        }

        // 记录快照
        lastStatusSnapshot = status
        lastStatusUpdatedAtMs = Int64(Date().timeIntervalSince1970 * 1000)

        let loaded = (status["loaded"] as? Bool) ?? false
        let initialized = (status["initialized"] as? Bool) ?? false

        if loaded && initialized {
            HBlogger.d(Self.tag, "WebSDK 初始化完成（loaded && initialized）", nil)
            markWebSdkInitialized()
            tryOpenConversationIfPossible()
            return
        }

        scheduleNextPolling()
    }

    private func scheduleNextPolling() {
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + TimeInterval(Self.pollingStepIntervalMs) / 1000.0
        ) { [weak self] in
            self?.pollingStep()
        }
    }

    private func tryOpenConversationIfPossible() {
        guard pendingOpenConversation else { return }
        // 需要已初始化 + 已 attach
        guard isInitialized else { return }
        guard attachedContainerView != nil else { return }
        guard let webView else { return }
        pendingOpenConversation = false
        mainQueue.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildOpen(), completionHandler: nil)
        }
    }

    private func injectConfigAndLoaderIfNeeded() {
        guard let webView else { return }
        guard let cfg = config else { return }

        // WebSDK 读取 window.HelpBotConfig：仅注入业务参数，不提供可被宿主篡改的入口 URL
        var configObj: [String: Any] = [:]
        configObj["baseURL"] = cfg.domain
        configObj["channelId"] = cfg.channelId
        configObj["fullPrivacyMode"] = cfg.fullPrivacyMode
        configObj["full_privacy_enabled"] = cfg.fullPrivacyMode
        configObj["useDevAPI"] = cfg.useDevApi
        if cfg.useDevApi {
            if let companyId = cfg.companyId { configObj["companyId"] = companyId }
            if let userId = cfg.userId { configObj["userId"] = userId }
        } else {
            if let token = cfg.preGeneratedToken { configObj["preGeneratedToken"] = token }
        }
        configObj["autoInit"] = false
        configObj["hideBubble"] = true
        configObj["fullscreen"] = true

        let initJs = HelpBotJsCommand.buildInitConfig(configObj)
        let loaderJs = HelpBotJsCommand.buildLoadScript(HelpBotSDKUrls.webChatLoaderJs)

        webView.evaluateJavaScript(initJs, completionHandler: nil)
        webView.evaluateJavaScript(loaderJs, completionHandler: nil)
    }

    /**
     WebView 页面/网络错误兜底（弱网/偶发抖动）：有限次数重试 reload，并派发事件给宿主。
     */
    private func onWebViewLoadError(
        _ errorType: String,
        url: String?,
        errorCode: Int?,
        description: String?,
        isMainFrame: Bool,
        httpStatus: Int?
    ) {
        // 记录最近一次错误快照（用于 install 超时诊断/提示）
        stateLock.lock()
        lastLoadErrorSnapshot = WebViewLoadErrorSnapshot(
            type: errorType,
            url: url,
            errorCode: errorCode,
            description: description,
            mainFrame: isMainFrame,
            httpStatus: httpStatus,
            atMs: nowMs()
        )
        stateLock.unlock()

        // 透传给宿主
        var data: [String: Any] = ["type": errorType, "retryCount": pageLoadRetryCount]
        if let url { data["url"] = url }
        eventProxy?.sendEvent("WEBVIEW_LOAD_ERROR", data)

        // install 阶段加速失败判定：主框架确定性 HTTP 错误无需继续重试
        if isMainFrame {
            if let status = httpStatus, !isInitialized {
                if status == 401 || status == 403 || status == 404 || status == 410 {
                    markWebSdkInitFailed("http_error_\(status)")
                    return
                }
            }
        }

        // 兜底：最多重试 2 次，避免死循环
        stateLock.lock()
        let canRetry = pageLoadRetryCount < 2
        if canRetry { pageLoadRetryCount += 1 }
        let retryCount = pageLoadRetryCount
        stateLock.unlock()

        if !canRetry {
            // 重试用尽：若仍未初始化完成，直接判定失败，避免 install 长时间卡住
            if isMainFrame && !isInitialized {
                markWebSdkInitFailed("webview_load_failed")
            }
            return
        }
        guard let webView else { return }

        let delayMs: Int64 = (retryCount == 1) ? 1_000 : 3_000
        mainQueue.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs))) {
            webView.reload()
        }
    }

    private func monitorLoop() {
        let start = nowMs()
        while true {
            stateLock.lock()
            let running = isMonitoring
            stateLock.unlock()
            if !running { break }

            let elapsed = nowMs() - start
            let interval: Int64 = (elapsed < Self.monitorHighFreqDurationMs)
                ? Self.monitorHighFreqIntervalMs
                : Self.monitorLowFreqIntervalMs

            // 1) 低频刷新 bootstrap（桥接通道是否就绪）
            let age = nowMs() - lastBootstrapUpdatedAtMs
            if lastBootstrapUpdatedAtMs == 0 || age > Self.bootstrapRefreshIntervalMs {
                if let bootstrap = getWebSdkBootstrapInfoBlocking(timeoutMs: Self.bootstrapBlockingTimeoutMs) {
                    stateLock.lock()
                    lastBootstrapSnapshot = bootstrap
                    lastBootstrapUpdatedAtMs = nowMs()
                    stateLock.unlock()
                }
            }

            // 2) 获取 status 并计算健康度
            if let status = getWebSdkStatusBlocking(timeoutMs: Self.statusBlockingTimeoutMs) {
                stateLock.lock()
                lastStatusSnapshot = status
                lastStatusUpdatedAtMs = nowMs()
                stateLock.unlock()

                emitIfStatusChanged(status)

                // 记录关键时间点（用于健康判定）
                let authenticated = (status["authenticated"] as? Bool) ?? false
                let hasIssue = (status["hasIssue"] as? Bool) ?? false
                let realtimeConnected = (status["realtimeConnected"] as? Bool) ?? false
                stateLock.lock()
                if authenticated && firstAuthenticatedAtMs == 0 { firstAuthenticatedAtMs = lastStatusUpdatedAtMs }
                if hasIssue { lastIssueSeenAtMs = lastStatusUpdatedAtMs }
                if realtimeConnected { lastRealtimeConnectedAtMs = lastStatusUpdatedAtMs }
                stateLock.unlock()

                let health = computeHealthLevel(status)
                if let health {
                    stateLock.lock()
                    let changed = (lastHealthLevel == nil) || (lastHealthLevel?.lowercased() != health.lowercased())
                    if changed { lastHealthLevel = health }
                    let proxy = monitorEventProxy
                    stateLock.unlock()

                    if changed, let proxy {
                        proxy.sendEvent("WEBSDK_HEALTH_CHANGED", [
                            "level": health,
                            "authenticated": authenticated,
                            "hasIssue": hasIssue,
                            "issueId": (status["issueId"] as? String) ?? "",
                            "realtimeConnected": realtimeConnected
                        ])
                    }
                }
            } else {
                // status 为空：可能是页面还没 ready 或 JS 执行异常
                stateLock.lock()
                let changed = lastHealthLevel?.uppercased() != "UNKNOWN"
                lastHealthLevel = "UNKNOWN"
                let proxy = monitorEventProxy
                stateLock.unlock()
                if changed, let proxy {
                    proxy.sendEvent("WEBSDK_HEALTH_CHANGED", ["level": "UNKNOWN"])
                }
            }

            Thread.sleep(forTimeInterval: TimeInterval(interval) / 1000.0)
        }
    }

    private func emitIfStatusChanged(_ status: [String: Any]) {
        guard let json = HelpBotJsonUtils.toJsonString(status) else { return }
        stateLock.lock()
        let prev = lastStatusJson
        if prev == json {
            stateLock.unlock()
            return
        }
        lastStatusJson = json
        let proxy = monitorEventProxy
        stateLock.unlock()

        proxy?.sendEvent("WEBSDK_STATUS", ["json": json])
    }

    private func computeHealthLevel(_ status: [String: Any]) -> String? {
        let authenticated = (status["authenticated"] as? Bool) ?? false
        let hasIssue = (status["hasIssue"] as? Bool) ?? false
        let realtimeConnected = (status["realtimeConnected"] as? Bool) ?? false

        if !authenticated {
            return "OK" // 未登录不算异常，属于正常状态
        }
        if hasIssue && !realtimeConnected {
            return "DEGRADED"
        }
        return "OK"
    }
}

extension HelpBotWebViewSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

        // 主框架严格白名单；子 frame 最小协议白名单
        if isMainFrame {
            decisionHandler(HelpBotWebViewHelper.isMainFrameUrlAllowed(url) ? .allow : .cancel)
        } else {
            decisionHandler(HelpBotWebViewHelper.isSubresourceUrlAllowed(url) ? .allow : .cancel)
        }
    }

    /// TLS/认证挑战处理：异常证书必须拒绝继续加载
    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            let ok: Bool
            if #available(iOS 13.0, *) {
                ok = SecTrustEvaluateWithError(trust, nil)
            } else {
                var result = SecTrustResultType.invalid
                let status = SecTrustEvaluate(trust, &result)
                ok = (status == errSecSuccess) && (result == .unspecified || result == .proceed)
            }

            if ok {
                completionHandler(.performDefaultHandling, nil)
            } else {
                HBlogger.e(Self.tag, "TLS 校验失败，拒绝加载: host=\(challenge.protectionSpace.host)", nil)
                onWebViewLoadError(
                    "onReceivedSslError",
                    url: webView.url?.absoluteString,
                    errorCode: nil,
                    description: "ssl_错误",
                    isMainFrame: true,
                    httpStatus: nil
                )
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        // 其它挑战（例如 HTTP Basic）：交由系统默认处理
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame else {
            decisionHandler(.allow)
            return
        }

        if let http = navigationResponse.response as? HTTPURLResponse {
            let status = http.statusCode
            let url = http.url?.absoluteString
            if status >= 400 {
                onWebViewLoadError(
                    "onReceivedHttpError",
                    url: url,
                    errorCode: nil,
                    description: HTTPURLResponse.localizedString(forStatusCode: status),
                    isMainFrame: true,
                    httpStatus: status
                )
            }
            // 对齐 Android：主框架确定性错误直接取消
            if status == 401 || status == 403 || status == 404 || status == 410 {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面加载完成：注入 config 与 loader.js
        injectConfigAndLoaderIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let ns = error as NSError
        onWebViewLoadError(
            "didFail",
            url: webView.url?.absoluteString,
            errorCode: ns.code,
            description: ns.localizedDescription,
            isMainFrame: true,
            httpStatus: nil
        )
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let ns = error as NSError
        onWebViewLoadError(
            "didFailProvisionalNavigation",
            url: webView.url?.absoluteString,
            errorCode: ns.code,
            description: ns.localizedDescription,
            isMainFrame: true,
            httpStatus: nil
        )
    }
}

extension HelpBotWebViewSession: WKUIDelegate {
    /// 禁止多窗口/新 WebView
    /// - 若是 target=_blank（targetFrame==nil），则尝试在当前 WebView 内加载（仅主框架白名单 URL）。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // targetFrame==nil 通常表示新窗口/新 tab
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           HelpBotWebViewHelper.isMainFrameUrlAllowed(url) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    /**
     文件选择：支持 Web 侧 `<input type="file">`（可选）。
     
     - 兼容性：iOS 12+ 可编译；该回调属于 WKUIDelegate 的标准 API（Xcode 16+/WebKit overlay 会对 selector 更严格）。
     - 安全性：仅允许在当前展示的 VC 上弹出选择器，避免后台/无界面触发。
     */
    @available(iOS 10.0, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        guard let presenter = attachedViewController else {
            completionHandler(nil)
            return
        }

        documentPickerCoordinator = DocumentPickerCoordinator(
            presenter: presenter,
            allowsMultiple: parameters.allowsMultipleSelection,
            completion: completionHandler
        )
        documentPickerCoordinator?.present()
    }
}

// MARK: - Document Picker

private final class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private weak var presenter: UIViewController?
    private let allowsMultiple: Bool
    private let completion: ([URL]?) -> Void

    init(presenter: UIViewController, allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void) {
        self.presenter = presenter
        self.allowsMultiple = allowsMultiple
        self.completion = completion
    }

    func present() {
        guard let presenter else {
            completion(nil)
            return
        }

        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        }
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls)
    }
}

private extension NSCondition {
    func withLock<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}


