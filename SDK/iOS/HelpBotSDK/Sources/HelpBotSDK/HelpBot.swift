import Foundation
import UIKit
import WebKit

/**
 HelpBot SDK 主入口类（iOS）。
 
 设计要点：
 1. 仅提供异步 API（避免宿主在主线程调用阻塞导致卡顿/死锁）。
 2. 统一错误码与回调机制。
 3. 线程安全与资源生命周期管理。
 */
public final class HelpBot {
    private static let tag = "HelpBot"
    private static let tokenStorageKeyJwt = "jwt_token"
    /// iOS SDK 版本号
    private static let sdkVersion = "0.1.13"

    /// FAQ 基础 URL（实现：当前为占位示例，后续可替换为真实帮助中心域名）
    private static let faqBaseUrl = "https://www.baidu.com/"

    private static let defaultWebSdkInitWaitTimeoutMs: Int = 35_000
    private static let defaultWebSdkLoginWaitTimeoutMs: Int = 30_000
    private static let defaultWebSdkBootstrapWaitTimeoutMs: Int = 20_000

    private static let operationLock = NSLock()

    private enum InstallState {
        case notInstalled
        case installing
        case installed
        case failed
    }

    private enum LoginState {
        case notLoggedIn
        case loginPending
        case loggingIn
        case loggedIn
        case failed
    }

    private static var installState: InstallState = .notInstalled
    private static var loginState: LoginState = .notLoggedIn
    private static var loginConfirmed: Bool = false

    private static var config: HelpBotConfig?
    private static var eventProxy: EventProxy = EventProxy(listener: nil)
    private static var keychain: HBKeychainStorage = HBKeychainStorage(service: "com.helpbot.sdk")

    private static weak var currentConversationController: UIViewController?
    
    // 生命周期监听在窗口可用后自动执行
    private static var hasRegisteredAppLifecycleObserver: Bool = false
    private static var appLifecycleObserverToken: NSObjectProtocol?

    private struct PendingLoginRequest {
        let token: String
        let createdAtMs: Int64
        let completion: ((HelpBotResult<Void>) -> Void)?
    }

    private struct PendingShowConversationRequest {
        weak var from: UIViewController?
        let createdAtMs: Int64
    }

    private static let pendingRequestTtlMs: Int64 = 2 * 60 * 1000
    private static var pendingLoginRequest: PendingLoginRequest?
    private static var pendingShowConversationRequest: PendingShowConversationRequest?

    // setEventsListener 需要排队：仅在 install 完成后才绑定（）
    private static weak var pendingEventsListener: HelpBotEventsListener?
    private static var pendingEventsListenerCreatedAtMs: Int64 = 0
    private static var hasPendingEventsListenerUpdate: Bool = false

    private init() {
        assertionFailure("HelpBot 不能被实例化")
    }
    
    
    
    private static func ensureAppLifecycleObserverInstalled() {
        operationLock.lock()
        if hasRegisteredAppLifecycleObserver {
            operationLock.unlock()
            return
        }
        hasRegisteredAppLifecycleObserver = true
        operationLock.unlock()
        
        // 只在 iOS App 场景生效；extension 下 UIApplication.shared 仍可用但通知语义不同
        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            tryRunPendingShowConversationIfPossible(trigger: "didBecomeActive")
        }
        appLifecycleObserverToken = token
    }
    
    private static func tryRunPendingShowConversationIfPossible(trigger: String) {
        // 仅在主线程尝试展示（UIKit 要求）
        if !Thread.isMainThread {
            DispatchQueue.main.async { tryRunPendingShowConversationIfPossible(trigger: trigger) }
            return
        }
        
        // 已显示：直接 open
        if currentConversationController != nil {
            HelpBotWebViewSession.shared.openWhenReady()
            return
        }
        
        // 读取并校验 pending request（TTL）
        var hasPending = false
        operationLock.lock()
        if let pending = pendingShowConversationRequest {
            let now = nowMs()
            if now - pending.createdAtMs <= pendingRequestTtlMs {
                hasPending = true
            } else {
                pendingShowConversationRequest = nil
            }
        }
        operationLock.unlock()
        if !hasPending { return }
        
        // install/login 状态不满足：等待后续 onLoginFinished 或下一次 didBecomeActive
        operationLock.lock()
        let installed = (installState == .installed && config != nil)
        let loginBusy = (loginState == .loginPending || loginState == .loggingIn)
        let confirmed = loginConfirmed
        operationLock.unlock()
        if !installed || loginBusy { return }
        
        // 登录确认：优先 loginConfirmed，其次 status 快照兜底
        var loggedIn = confirmed
        if !loggedIn {
            loggedIn = HelpBotWebViewSession.shared.isAuthenticatedSnapshot(maxAgeMs: 3000)
        }
        if !loggedIn {
            // 未登录不自动弹窗/不强行展示
            return
        }
        
        guard let top = ApplicationUtils.getTopViewControllerForPresentation() else {
            HBlogger.d(tag, "tryRunPendingShowConversationIfPossible(\(trigger)): topViewController is nil, wait", nil)
            return
        }
        
        // 消费 pending（只执行一次）
        operationLock.lock()
        pendingShowConversationRequest = nil
        operationLock.unlock()
        
        presentConversationNow(from: top)
    }

    // MARK: - State Machine Notes（重要：避免竞态/重复调用）
    //
    // install:
    // - 状态：notInstalled/failed -> installing -> installed/failed
    // - installing 期间允许 setEventsListener/login/showConversation 入队（只保留最后一次）
    //
    // login:
    // - 状态：notLoggedIn/failed -> loggingIn -> loggedIn/failed
    // - install=installing 时：login 入队（loginPending），install 完成后由 runPendingRequestsIfNeeded 执行
    // - 关键约束：SDK 内部“执行登录”必须只走 internal flow（loginInternal + onLoginFinished），禁止再回调到 public login()
    //
    // showConversation:
    // - loginPending/loggingIn：入队并返回 success（对齐 Android：宿主无需写 callback 链）
    // - 展示触发：loginFinished / didBecomeActive / installFinished（取到可用 presenter 时执行）

    /// 统一的内部登录执行器（public login 与 pending-login 共用）。
    /// 注意：调用前必须已在锁内将 loginState 置为 .loggingIn，确保不会并发触发多次登录。
    private static func executeLoginInternalAsync(
        token: String,
        completion: ((HelpBotResult<Void>) -> Void)?,
        reason: String
    ) {
        HBlogger.i(tag, "login: start internal (\(reason))", nil)
        DispatchQueue.global(qos: .utility).async {
            let result = loginInternal(token)
            onLoginFinished(result.isSuccess)
            DispatchQueue.main.async { completion?(result) }
        }
    }

    // MARK: - Public APIs

    /// 初始化日志（可选）
    public static func initLogger(_ logger: IHBLogger?) {
        HBlogger.initLoggerIfAbsent(logger)
    }

    /// 设置事件监听器（事件驱动）。
    /// 需求对齐：必须在 install 完成后才真正绑定；install 未完成时入队（只保留最后一次）。
    public static func setEventsListener(_ listener: HelpBotEventsListener?) {
        operationLock.lock()
        if installState == .installed {
            operationLock.unlock()
            eventProxy.updateListener(listener)
            return
        }
        // install 未完成：入队
        hasPendingEventsListenerUpdate = true
        pendingEventsListener = listener
        pendingEventsListenerCreatedAtMs = nowMs()
        operationLock.unlock()
    }

    /// 兼容 Android 需求文档签名：channelId/domain/configMap
    public static func install(
        channelId: String,
        domain: String,
        configMap: [String: Any]?,
        callback: HelpBotInitCallback?
    ) {
        do {
            callback?.onInitStart()
            callback?.onInitProgress(5, "构建配置")

            let fullPrivacyMode = readBool(configMap, key: "fullPrivacyMode", defaultValue: false)
            let enableSseNotification = readBool(configMap, key: "enableSseNotification", defaultValue: true)
            let initTimeoutMs = readInt(configMap, key: "initTimeout", defaultValue: 30_000)
            let webViewLoadTimeoutMs = readInt(configMap, key: "webViewLoadTimeout", defaultValue: 15_000)
            let builder = HelpBotConfig.Builder()
                .channelId(channelId)
                .domain(domain)
                .fullPrivacyMode(fullPrivacyMode)
                .enableSseNotification(enableSseNotification)
                .initTimeoutMs(initTimeoutMs)
                .webViewLoadTimeoutMs(webViewLoadTimeoutMs)

            // customConfig：保存所有原始配置，供 SDK 内部（如标题栏）读取
            if let configMap = configMap, !configMap.isEmpty {
                for (k, v) in configMap {
                    let key = k.trimmingCharacters(in: .whitespacesAndNewlines)
                    if key.isEmpty { continue }
                    builder.addCustomConfig(key, v)
                }
            }

            let cfg = try builder.build()
            install(config: cfg, callback: callback)
        } catch let e as HelpBotConfigError {
            switch e {
            case .invalidChannelId:
                callback?.onInitFailure(.invalidChannelId, HelpBotErrorCode.invalidChannelId.message)
            case .invalidDomain:
                callback?.onInitFailure(.invalidDomain, HelpBotErrorCode.invalidDomain.message)
            case .missingCompanyId, .missingUserId:
                callback?.onInitFailure(.invalidParameter, "useDevApi=true 时 companyId/userId 不能为空")
            }
        } catch {
            callback?.onInitFailure(.internalError, "install 异常: \(error.localizedDescription)")
        }
    }

    /// install（推荐）
    public static func install(config: HelpBotConfig, callback: HelpBotInitCallback?) {
        // 状态机：只允许 NOT_INSTALLED / FAILED 进入 install
        operationLock.lock()
        if installState == .installed || installState == .installing {
            operationLock.unlock()
            callback?.onInitFailure(.sdkAlreadyInitialized, HelpBotErrorCode.sdkAlreadyInitialized.message)
            return
        }
        installState = .installing
        self.config = config
        // install 时允许通过 config 预设 SSE 通知开关
        sseNotificationEnabled = config.enableSseNotification
        operationLock.unlock()

        callback?.onInitStart()
        callback?.onInitProgress(15, "预加载 WebView")

        // 预加载 + 等待初始化完成（后台线程）
        DispatchQueue.global(qos: .utility).async {
            HelpBotWebViewSession.shared.preload(config: config, eventProxy: eventProxy)

            callback?.onInitProgress(50, "等待 WebSDK 初始化")
            let ok = HelpBotWebViewSession.shared.awaitWebSdkInitialized(
                timeoutMs: max(config.initTimeoutMs, defaultWebSdkInitWaitTimeoutMs)
            )

            if ok {
                // 进一步：等待 bridge/native 通道就绪（确保 SDK_READY/SDK_ERROR 能可靠送达宿主）
                callback?.onInitProgress(70, "等待 WebSDK 通道就绪")
                let bootstrapOk = HelpBotWebViewSession.shared.awaitWebSdkBootstrapReady(
                    timeoutMs: defaultWebSdkBootstrapWaitTimeoutMs
                )
                if !bootstrapOk {
                    operationLock.lock()
                    installState = .failed
                    operationLock.unlock()
                    DispatchQueue.main.async {
                        callback?.onInitFailure(.webViewInitFailed, "WebSDK 通道未就绪（Bridge/Native 通信异常）")
                    }
                    return
                }

                // 启动健康监管（install 完成后持续运行，直到 destroy）
                HelpBotWebViewSession.shared.startMonitoring(eventProxy: eventProxy)
                
                // 用于 showConversation() 无 VC 调用场景自动补执行
                DispatchQueue.main.async {
                    ensureAppLifecycleObserverInstalled()
                    tryRunPendingShowConversationIfPossible(trigger: "installFinished")
                }

                operationLock.lock()
                installState = .installed
                operationLock.unlock()

                callback?.onInitProgress(100, "初始化完成")
                DispatchQueue.main.async { callback?.onInitSuccess() }
                runPendingRequestsIfNeeded()
            } else {
                let reason = HelpBotWebViewSession.shared.getWebSdkInitFailedReason() ?? "unknown"
                operationLock.lock()
                installState = .failed
                operationLock.unlock()
                DispatchQueue.main.async {
                    if reason.lowercased() == "init_timeout" {
                        // 超时高概率与网络相关：无网/受限网络/企业防火墙或域名不可达
                        var webViewHint = ""
                        if let err = HelpBotWebViewSession.shared.getLastLoadErrorSnapshot() {
                            var parts: [String] = []
                            parts.append("type=\(err.type)")
                            if let s = err.httpStatus { parts.append("httpStatus=\(s)") }
                            if let c = err.errorCode { parts.append("errorCode=\(c)") }
                            parts.append("mainFrame=\(err.mainFrame)")
                            webViewHint = "（最近一次 WebView 错误：" + parts.joined(separator: " ") + "）"
                        }
                        let diagnosis = NetworkUtils.diagnose()
                        let msg: String
                        if !diagnosis.networkConnected || !diagnosis.hasInternetCapability {
                            msg = "WebSDK 初始化超时：当前网络不可用或被禁用。" + diagnosis.buildUserHint() + webViewHint
                        } else {
                            msg = "WebSDK 初始化超时：网络可能受限/被策略拦截或目标域名不可达。" + diagnosis.buildUserHint() + webViewHint
                        }
                        callback?.onInitFailure(.operationTimeout, msg)
                    } else {
                        callback?.onInitFailure(.webViewInitFailed, "WebSDK 初始化失败: \(reason)")
                    }
                }
            }
        }
    }

    /// 登录（异步）
    public static func login(_ identitiesJwt: String, completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        let token = identitiesJwt.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty {
            completion?(.failure(.invalidToken, "Token 不能为空"))
            return
        }

        operationLock.lock()
        // install 进行中：允许入队
        if installState == .installing {
            if loginState == .loginPending || loginState == .loggingIn {
                operationLock.unlock()
                completion?(.failure(.operationInProgress, "login 正在进行中，请勿重复调用"))
                return
            }
            if loginState == .loggedIn || loginConfirmed {
                operationLock.unlock()
                completion?(.failure(.alreadyLoggedIn, HelpBotErrorCode.alreadyLoggedIn.message))
                return
            }
            pendingLoginRequest = PendingLoginRequest(token: token, createdAtMs: nowMs(), completion: completion)
            loginState = .loginPending
            operationLock.unlock()
            return
        }

        // install 未完成：直接失败
        if installState != .installed || self.config == nil {
            operationLock.unlock()
            completion?(.failure(.sdkNotInitialized, "SDK 未初始化：请先调用 HelpBot.install(...)"))
            return
        }

        // 兼容：install 阶段的 pending 状态在 install 完成前后可能存在窗口期，统一视为“进行中”
        if loginState == .loginPending || loginState == .loggingIn {
            operationLock.unlock()
            completion?(.failure(.operationInProgress, "login 正在进行中，请勿重复调用"))
            return
        }
        if loginState == .loggedIn || loginConfirmed {
            operationLock.unlock()
            completion?(.failure(.alreadyLoggedIn, HelpBotErrorCode.alreadyLoggedIn.message))
            return
        }
        if loginState != .notLoggedIn && loginState != .failed {
            operationLock.unlock()
            completion?(.failure(.operationNotAllowed, HelpBotErrorCode.operationNotAllowed.message))
            return
        }
        loginState = .loggingIn
        operationLock.unlock()
        executeLoginInternalAsync(token: token, completion: completion, reason: "public")
    }

    /// 显示对话窗口（异步，推荐）
    @discardableResult
    public static func showConversation(from viewController: UIViewController) -> HelpBotResult<Void> {
        operationLock.lock()
        // install 进行中：入队
        if installState == .installing {
            //排队阶段不强依赖宿主传入的 VC（未来可能不在 window/正在过渡导致无法 present）
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        if installState != .installed || config == nil {
            operationLock.unlock()
            return .failure(.sdkNotInitialized)
        }
        // login 进行中/排队中：入队等待
        if loginState == .loginPending || loginState == .loggingIn || pendingLoginRequest != nil {
            // 排队阶段不强依赖宿主传入的 VC（未来可能不在 window/正在过渡导致无法 present）
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        operationLock.unlock()

        // 登录确认：优先使用 loginConfirmed，其次用 status 快照兜底
        var loggedIn = false
        operationLock.lock()
        loggedIn = loginConfirmed
        operationLock.unlock()
        if !loggedIn {
            loggedIn = HelpBotWebViewSession.shared.isAuthenticatedSnapshot(maxAgeMs: 3000)
        }
        if !loggedIn {
            return .failure(.notLoggedIn, "请先调用 HelpBot.login(...) 完成登录")
        }

        DispatchQueue.main.async {
            presentConversationNow(from: viewController)
        }
        return .success()
    }
    
    /**
     打开会话窗口（推荐，无需传入 ViewController）。

     - Returns: 结果（成功表示已触发展示/或已入队等待 install/login 完成）
     */
    @discardableResult
    public static func showConversation() -> HelpBotResult<Void> {
        
        // 若当前无法获取 topVC（例如 App 尚未 active / window 未就绪），则入队等待 didBecomeActive 后补执行。
        ensureAppLifecycleObserverInstalled()
        
        // 已展示：直接 open
        if currentConversationController != nil {
            HelpBotWebViewSession.shared.openWhenReady()
            return .success()
        }
        
        // 先按状态机做“入队/拒绝”决策（避免先取 topVC 导致误判）
        operationLock.lock()
        if installState == .installing {
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        if installState != .installed || config == nil {
            operationLock.unlock()
            return .failure(.sdkNotInitialized, "SDK 未初始化：请先调用 HelpBot.install(...)")
        }
        // login 进行中/排队中：入队等待
        if loginState == .loginPending || loginState == .loggingIn || pendingLoginRequest != nil {
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        operationLock.unlock()
        
        // install/login 已满足：尝试直接展示；若取不到 topVC，入队等待
        guard let top = ApplicationUtils.getTopViewControllerForPresentation() else {
            operationLock.lock()
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        return showConversation(from: top)
    }

    /// 隐藏对话窗口（不销毁会话）
    @discardableResult
    public static func hideConversation() -> HelpBotResult<Void> {
        DispatchQueue.main.async {
            if let wv = HelpBotWebViewSession.shared.webView {
                wv.evaluateJavaScript(HelpBotJsCommand.buildClose(), completionHandler: nil)
            }
            if let vc = currentConversationController {
                // 兼容两种展示方式：
                // 1) push：应 pop
                // 2) present：应 dismiss（可能包了一层 UINavigationController）
                if vc.presentingViewController != nil {
                    // vc 自身被 present
                    vc.dismiss(animated: true)
                } else if let nav = vc.navigationController, nav.presentingViewController != nil {
                    // vc 在被 present 的 nav 里
                    nav.dismiss(animated: true)
                } else if let nav = vc.navigationController, nav.viewControllers.contains(vc) {
                    // push 进宿主导航栈
                    nav.popViewController(animated: true)
                } else {
                    // 兜底：尽力 dismiss
                    vc.dismiss(animated: true)
                }
            }
        }
        return .success()
    }

    /// 退出登录（销毁会话）
    public static func logout(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        operationLock.lock()
        if installState != .installed || config == nil {
            operationLock.unlock()
            completion?(.failure(.sdkNotInitialized))
            return
        }
        // logout 明确退出登录态，允许后续重新 login
        loginState = .notLoggedIn
        loginConfirmed = false
        pendingLoginRequest = nil
        pendingShowConversationRequest = nil
        hasPendingEventsListenerUpdate = false
        pendingEventsListener = nil
        pendingEventsListenerCreatedAtMs = 0
        operationLock.unlock()

        _ = keychain.remove(tokenStorageKeyJwt)

        DispatchQueue.main.async {
            if let wv = HelpBotWebViewSession.shared.webView {
                wv.evaluateJavaScript(HelpBotJsCommand.buildDestroy(), completionHandler: nil)
            }
            completion?(.success())
        }
    }

    public static func isConversationVisible() -> Bool {
        return currentConversationController != nil
    }
    
    // MARK: - FAQ APIs
    
    /**
     显示 FAQ 主页
     
     - Parameter config: 可选配置（支持 key：tn）
     - Returns: 结果
     */
    @discardableResult
    public static func showFAQs(config: [String: Any]? = nil) -> HelpBotResult<Void> {
        guard let top = ApplicationUtils.getTopViewController() else {
            return .failure(.contextNull, "无法获取顶层 ViewController")
        }
        return showFAQs(from: top, config: config)
    }
    
    /**
     显示 FAQ 分组页
     
     - Parameters:
       - sectionPublishId: 分组 ID（必填）
       - config: 可选配置（支持 key：tn）
     - Returns: 结果
     */
    @discardableResult
    public static func showFAQSection(
        sectionPublishId: String,
        config: [String: Any]? = nil
    ) -> HelpBotResult<Void> {
        guard let top = ApplicationUtils.getTopViewController() else {
            return .failure(.contextNull, "无法获取顶层 ViewController")
        }
        return showFAQSection(from: top, sectionPublishId: sectionPublishId, config: config)
    }
    
    /**
     显示 FAQ 单页
     
     - Parameters:
       - questionPublishId: 问题 ID（必填）
       - config: 可选配置（支持 key：tn）
     - Returns: 结果
     */
    @discardableResult
    public static func showSingleFAQ(
        questionPublishId: String,
        config: [String: Any]? = nil
    ) -> HelpBotResult<Void> {
        guard let top = ApplicationUtils.getTopViewController() else {
            return .failure(.contextNull, "无法获取顶层 ViewController")
        }
        return showSingleFAQ(from: top, questionPublishId: questionPublishId, config: config)
    }
    
    /**
     显示 FAQ 主页面（使用系统浏览器打开 URL，而非在 WebChat 内嵌打开）。
     
     - Parameters:
       - viewController: 当前页面 VC（仅用于调用方语义一致性；iOS 采用系统 openURL，不强依赖该参数）
       - config: 可选配置（支持 key：tn）
     */
    @discardableResult
    public static func showFAQs(from viewController: UIViewController, config: [String: Any]? = nil) -> HelpBotResult<Void> {
        operationLock.lock()
        if installState != .installed || self.config == nil {
            operationLock.unlock()
            return .failure(.sdkNotInitialized, "SDK 未初始化")
        }
        operationLock.unlock()

        let tn = (config?["tn"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = buildFaqUrl(tn: tn, extraKey: nil, extraValue: nil)
        guard let url = URL(string: urlStr) else {
            return .failure(.invalidParameter, "FAQ URL 无效")
        }

        ApplicationUtils.runOnMainThread {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return .success()
    }

    /**
     显示 FAQ 分组页面
     
     - Parameters:
       - viewController: 当前页面 VC（语义一致）
       - sectionPublishId: 分组 ID（必填）
       - config: 可选配置（支持 key：tn）
     */
    @discardableResult
    public static func showFAQSection(
        from viewController: UIViewController,
        sectionPublishId: String,
        config: [String: Any]? = nil
    ) -> HelpBotResult<Void> {
        let sid = sectionPublishId.trimmingCharacters(in: .whitespacesAndNewlines)
        if sid.isEmpty { return .failure(.invalidParameter, "sectionPublishId 不能为空") }

        operationLock.lock()
        let installed = (installState == .installed && self.config != nil)
        operationLock.unlock()
        if !installed { return .failure(.sdkNotInitialized, "SDK 未初始化") }

        let tn = (config?["tn"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = buildFaqUrl(tn: tn, extraKey: "sectionPublishId", extraValue: sid)
        guard let url = URL(string: urlStr) else { return .failure(.invalidParameter, "FAQ URL 无效") }
        ApplicationUtils.runOnMainThread { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        return .success()
    }

    /**
     显示 FAQ 单页
     
     - Parameters:
       - viewController: 当前页面 VC（语义一致）
       - questionPublishId: 问题 ID（必填）
       - config: 可选配置（支持 key：tn）
     */
    @discardableResult
    public static func showSingleFAQ(
        from viewController: UIViewController,
        questionPublishId: String,
        config: [String: Any]? = nil
    ) -> HelpBotResult<Void> {
        let qid = questionPublishId.trimmingCharacters(in: .whitespacesAndNewlines)
        if qid.isEmpty { return .failure(.invalidParameter, "questionPublishId 不能为空") }

        operationLock.lock()
        let installed = (installState == .installed && self.config != nil)
        operationLock.unlock()
        if !installed { return .failure(.sdkNotInitialized, "SDK 未初始化") }

        let tn = (config?["tn"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = buildFaqUrl(tn: tn, extraKey: "questionPublishId", extraValue: qid)
        guard let url = URL(string: urlStr) else { return .failure(.invalidParameter, "FAQ URL 无效") }
        ApplicationUtils.runOnMainThread { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        return .success()
    }

    /// 构建 FAQ URL
    private static func buildFaqUrl(tn: String?, extraKey: String?, extraValue: String?) -> String {
        // tn 默认值
        let tnValue = (tn ?? "").isEmpty ? "68018901_16_pg" : (tn ?? "68018901_16_pg")
        var comps = URLComponents(string: faqBaseUrl) ?? URLComponents()
        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "tn", value: tnValue))
        if let extraKey = extraKey, let extraValue = extraValue, !extraKey.isEmpty, !extraValue.isEmpty {
            items.append(URLQueryItem(name: extraKey, value: extraValue))
        }
        comps.queryItems = items
        return comps.string ?? faqBaseUrl
    }
    
    // MARK: - SDK Management APIs
    
    /// 销毁 SDK 并释放所有资源（）
    public static func destroy(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        operationLock.lock()
        installState = .notInstalled
        loginState = .notLoggedIn
        loginConfirmed = false
        pendingLoginRequest = nil
        pendingShowConversationRequest = nil
        hasPendingEventsListenerUpdate = false
        pendingEventsListener = nil
        pendingEventsListenerCreatedAtMs = 0
        config = nil
        // 解除生命周期监听（避免宿主长生命周期进程中 observer 堆积）
        if let t = appLifecycleObserverToken {
            NotificationCenter.default.removeObserver(t)
        }
        appLifecycleObserverToken = nil
        hasRegisteredAppLifecycleObserver = false
        operationLock.unlock()
        
        // 清理存储
        _ = keychain.remove(tokenStorageKeyJwt)
        
        // 销毁 WebView 会话
        DispatchQueue.main.async {
            if let wv = HelpBotWebViewSession.shared.webView {
                wv.evaluateJavaScript(HelpBotJsCommand.buildDestroy(), completionHandler: nil)
            }

            // 关闭对话窗口
            if let vc = currentConversationController {
                if let nav = vc.navigationController {
                    nav.dismiss(animated: false)
                } else {
                    vc.dismiss(animated: false)
                }
                currentConversationController = nil
            }

            // 销毁 WebView Session
            HelpBotWebViewSession.shared.destroy()

            // 销毁 Context
            HelpBotContext.destroy()

            completion?(.success())
        }
    }
    
    /// 获取 SDK 版本号（）
    public static func getSDKVersion() -> String {
        return sdkVersion
    }


    /**
     更新 SDK Meta
     - 说明：iOS 内部复用 `updateUserSdkMeta`。
     */
    public static func updateSDKMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        return updateUserSdkMeta(meta)
    }

    /**
     更新用户自定义 Meta
     - 说明：iOS 内部复用 `updateUserMeta`。
     */
    public static func updateCustomMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        return updateUserMeta(meta)
    }

    /**
     上报系统信息到服务器
     - 说明：通过 WebSDK `updateUserSdkMeta` 上报；隐私模式下最小化上报字段。
     */
    public static func reportSystemInfoToServer() -> HelpBotResult<Void> {
        operationLock.lock()
        guard installState == .installed, let cfg = config else {
            operationLock.unlock()
            return .failure(.sdkNotInitialized)
        }
        operationLock.unlock()

        let dev = IOSDevice.shared
        let privacyMode = cfg.fullPrivacyMode
        let diagnosis = NetworkUtils.diagnose()

        var meta: [String: Any] = [:]
        meta["os_type"] = "iOS"
        meta["os_version"] = dev.getOSVersion()
        meta["device_model"] = dev.getDeviceModel()
        meta["app_name"] = ApplicationUtils.getAppName() ?? ""
        meta["app_version"] = ApplicationUtils.getAppVersion() ?? ""
        meta["sdk_version"] = getSDKVersion()

        if !privacyMode {
            meta["battery_level"] = dev.getBatteryLevel()
            meta["battery_status"] = dev.getBatteryState()
            meta["network_type"] = diagnosis.transport ?? ""
            meta["carrier_name"] = dev.getCarrierName()
            meta["country_code"] = dev.getDeviceRegion()
            meta["language"] = dev.getDeviceLanguage()
            meta["app_identifier"] = dev.getBundleId()
            meta["device_id"] = dev.getDeviceId()
            // ：磁盘空间字段
            meta["total_space"] = dev.getTotalDiskSpace()
            meta["free_space"] = dev.getFreeDiskSpace()
            meta["is_online"] = diagnosis.networkConnected && diagnosis.hasInternetCapability
        } else {
            meta["full_privacy_mode"] = true
        }

        return updateUserSdkMeta(meta)
    }

    /**
     设置通知小图标资源 ID
     - 说明：iOS 无“通知小图标资源 ID”概念，此方法为跨平台 API 兼容保留，当前 no-op。
     */
    public static func setNotificationSmallIconResId(_ resId: Int) {
        HBlogger.w(tag, "setNotificationSmallIconResId: iOS 平台不适用，已忽略", nil)
    }

    /**
     设置通知渠道 ID
     - 说明：iOS 无 NotificationChannelId 概念，此方法为跨平台 API 兼容保留，当前 no-op。
     */
    public static func setNotificationChannelId(_ channelId: String) {
        HBlogger.w(tag, "setNotificationChannelId: iOS 平台不适用，已忽略", nil)
    }

    /**
     关闭当前会话
     - 调用 WebSDK close
     - 销毁 WebView 会话（释放 WKWebView），但保留 install（config 仍保留）
     - 清理登录确认与待处理请求
     */
    public static func closeSession() -> HelpBotResult<Void> {
        operationLock.lock()
        if installState != .installed || config == nil {
            operationLock.unlock()
            return .failure(.sdkNotInitialized)
        }
        // 会话销毁会导致 Web 侧登录态丢失
        loginState = .notLoggedIn
        loginConfirmed = false
        pendingLoginRequest = nil
        pendingShowConversationRequest = nil
        hasPendingEventsListenerUpdate = false
        pendingEventsListener = nil
        pendingEventsListenerCreatedAtMs = 0
        operationLock.unlock()

        _ = keychain.remove(tokenStorageKeyJwt)

        ApplicationUtils.runOnMainThread {
            if let wv = HelpBotWebViewSession.shared.webView {
                wv.evaluateJavaScript(HelpBotJsCommand.buildClose(), completionHandler: nil)
            }
            HelpBotWebViewSession.shared.destroy()
        }
        return .success()
    }
    
    /// 验证 SDK 是否已正确安装（）
    public static func verifyInstall() -> Bool {
        operationLock.lock()
        defer { operationLock.unlock() }
        return installState == .installed && config != nil && HelpBotContext.isInstalled()
    }

    /// SDK 是否已初始化完成
    public static func isInitialized() -> Bool {
        return verifyInstall()
    }
    
    /// 获取当前 SDK 配置（）
    public static func getConfig() -> HelpBotConfig? {
        operationLock.lock()
        defer { operationLock.unlock() }
        return config
    }

    /// 获取 WebSDK 健康快照
    public static func getWebSdkHealthSnapshot() -> [String: Any] {
        return HelpBotWebViewSession.shared.getHealthSnapshot()
    }

    /**
     清理 WebView 网站数据（缓存/Cookie/LocalStorage 等）。

     设计目标：
     - 提供宿主可调用的诊断/复位能力
     - 默认仅清理 WebChat index/loader 所在域名的数据（避免误删宿主其它 WebView 数据）
     - 全程不抛异常，completion 必回调
     */
    public static func clearWebViewData(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        DispatchQueue.main.async {
            let hosts = Self.getWebChatHosts()
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

            // 需要同时清理 default 与 nonPersistent（隐私模式下通常为 nonPersistent，但清理操作无副作用）
            let stores: [WKWebsiteDataStore] = {
                let d = WKWebsiteDataStore.default()
                let np = WKWebsiteDataStore.nonPersistent()
                if d === np { return [d] }
                return [d, np]
            }()

            let group = DispatchGroup()

            for store in stores {
                group.enter()
                store.fetchDataRecords(ofTypes: dataTypes) { records in
                    let targets: [WKWebsiteDataRecord]
                    if hosts.isEmpty {
                        targets = records
                    } else {
                        let hostSet = Set(hosts.map { $0.lowercased() })
                        targets = records.filter { hostSet.contains($0.displayName.lowercased()) }
                    }

                    store.removeData(ofTypes: dataTypes, for: targets) {
                        // 清理完成后尽量 reload（与 Android 行为一致）
                        if let wv = HelpBotWebViewSession.shared.webView {
                            wv.reload()
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                completion?(.success())
            }
        }
    }

    /**
     获取 WebView 安全基线快照（仅用于诊断/测试台展示）。

     说明：
     - iOS Demo 无法直接访问 SDK 内部的 WKWebView，因此提供该只读快照接口
     - 不包含敏感数据，不返回 Cookie 内容、不返回 token
     */
    public static func getWebViewSecurityBaselineSnapshot() -> [String: Any] {
        var data: [String: Any] = [:]
        let hosts = getWebChatHosts()
        data["webChatHosts"] = hosts
        data["webChatIndex"] = HelpBotSDKUrls.webChatIndex
        data["webChatLoaderJs"] = HelpBotSDKUrls.webChatLoaderJs
        data["isInitialized"] = isInitialized()
        data["isConversationVisible"] = isConversationVisible()

        guard let wv = HelpBotWebViewSession.shared.webView else {
            data["hasWebView"] = false
            return data
        }
        data["hasWebView"] = true
        data["currentUrl"] = wv.url?.absoluteString ?? ""

        let pref = wv.configuration.preferences
        data["javaScriptEnabled"] = pref.javaScriptEnabled
        data["javaScriptCanOpenWindowsAutomatically"] = pref.javaScriptCanOpenWindowsAutomatically

        // 隐私模式判定：websiteDataStore 是否为 nonPersistent
        data["nonPersistentDataStore"] = (wv.configuration.websiteDataStore === WKWebsiteDataStore.nonPersistent())
        data["allowsLinkPreview"] = wv.allowsLinkPreview
        // 兼容性说明：
        // - `WKWebView.isInspectable` 在较新 SDK（iOS 16.4+ / Xcode 14.3+）才存在
        // - Xcode 13（Swift 5.6 / iOS 15.x SDK）中该符号完全不存在，即使写 @available 也会编译失败
        // 因此这里使用编译器条件编译：旧编译链直接跳过，不引用该符号。
        #if compiler(>=5.8)
        if #available(iOS 16.4, *) {
            data["isInspectable"] = wv.isInspectable
        }
        #endif

        // Bridge 通道约束（不枚举 handler 列表，避免依赖私有 API）
        data["nativeBridgeName"] = HelpBotWebViewHelper.nativeBridgeName
        data["sseMessageHandlerName"] = HelpBotWebViewHelper.sseMessageHandlerName
        #if DEBUG
        data["consoleLogEnabled"] = true
        data["consoleLogHandlerName"] = HelpBotWebViewHelper.consoleLogHandlerName
        #else
        data["consoleLogEnabled"] = false
        #endif

        return data
    }
    
    // MARK: - SSE Notification APIs
    
    private static var sseNotificationEnabled: Bool = true
    
    /// 启用 SSE 通知（）
    public static func enableSseNotification() {
        operationLock.lock()
        sseNotificationEnabled = true
        operationLock.unlock()
        
        HBlogger.d(tag, "SSE 通知已启用")
        
        // 通知 WebSDK
        DispatchQueue.main.async {
            if let webView = HelpBotWebViewSession.shared.webView {
                let js = "try { if (window.HelpBot) { window.HelpBot.enableNotifications(); } } catch(e) {}"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    /// 禁用 SSE 通知（）
    public static func disableSseNotification() {
        operationLock.lock()
        sseNotificationEnabled = false
        operationLock.unlock()
        
        HBlogger.d(tag, "SSE 通知已禁用")
        
        // 通知 WebSDK
        DispatchQueue.main.async {
            if let webView = HelpBotWebViewSession.shared.webView {
                let js = "try { if (window.HelpBot) { window.HelpBot.disableNotifications(); } } catch(e) {}"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    /// 检查 SSE 通知是否已启用
    public static func isSseNotificationEnabled() -> Bool {
        operationLock.lock()
        defer { operationLock.unlock() }
        return sseNotificationEnabled
    }

    /// 兼容 入口：enableSseNotification(boolean enable)
    public static func enableSseNotification(_ enable: Bool) {
        if enable {
            enableSseNotification()
        } else {
            disableSseNotification()
        }
    }
    
    // MARK: - User Login Events Listener
    
    private static weak var userLoginEventsListener: HelpBotUserLoginEventsListener?
    
    /// 设置用户登录事件监听器（）
    public static func setUserLoginEventsListener(_ listener: HelpBotUserLoginEventsListener?) {
        operationLock.lock()
        userLoginEventsListener = listener
        operationLock.unlock()
    }
    
    // MARK: - Data Management APIs
    
    /// 清除匿名用户数据（）
    public static func clearAnonymousUser(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        HelpBotThreadPool.shared.submit {
            // 清除本地存储的匿名用户数据
            _ = HBPersistentStorage.shared.remove("anonymous_user_id")
            _ = HBPersistentStorage.shared.remove("anonymous_user_data")

            // 通知 WebSDK 清除匿名用户
            DispatchQueue.main.async {
                if let webView = HelpBotWebViewSession.shared.webView {
                    let js = "try { if (window.HelpBot) { window.HelpBot.clearAnonymousUser(); } } catch(e) {}"
                    webView.evaluateJavaScript(js) { _, error in
                        if let error = error {
                            completion?(.failure(.internalError, "清除匿名用户失败: \(error.localizedDescription)"))
                        } else {
                            completion?(.success())
                        }
                    }
                } else {
                    completion?(.success())
                }
            }
        }
    }

    // MARK: - WebSDK 对齐接口（evaluateJavaScript）

    /// 发送文本消息（异步）。对齐 WebSDK：HelpBot('sendMessage', text)
    public static func sendMessageAsync(
        _ message: String,
        completion: ((HelpBotResult<[String: Any]>) -> Void)? = nil
    ) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            completion?(.failure(.invalidParameter, "message 不能为空"))
            return
        }
        guard let webView = HelpBotWebViewSession.shared.webView else {
            completion?(.failure(.webViewDestroyed, "WebView 未初始化"))
            return
        }
        let js = "(async function(){try{var r=await HelpBot('sendMessage',\(quoteJsString(text)));return JSON.stringify({ok:true,data:(r||{})});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();"
        evaluateJsonResultOnMain(webView: webView, js: js, apiName: "sendMessageAsync", completion: completion)
    }

    /// 获取历史消息（异步）。对齐 WebSDK：HelpBot('getHistoryMessages')
    public static func getHistoryMessagesAsync(
        completion: ((HelpBotResult<[String: Any]>) -> Void)? = nil
    ) {
        guard let webView = HelpBotWebViewSession.shared.webView else {
            completion?(.failure(.webViewDestroyed, "WebView 未初始化"))
            return
        }
        let js = "(function(){try{var r=HelpBot('getHistoryMessages');return JSON.stringify({ok:true,data:(r||{})});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();"
        evaluateJsonResultOnMain(webView: webView, js: js, apiName: "getHistoryMessagesAsync", completion: completion)
    }

    /// 分页加载更多历史消息（异步）。对齐 WebSDK：HelpBot('loadMoreMessages', limit, offset)
    public static func loadMoreMessagesAsync(
        limit: Int,
        offset: Int,
        completion: ((HelpBotResult<[String: Any]>) -> Void)? = nil
    ) {
        if limit < 0 || offset < 0 {
            completion?(.failure(.invalidParameter, "limit/offset 不能为负数"))
            return
        }
        guard let webView = HelpBotWebViewSession.shared.webView else {
            completion?(.failure(.webViewDestroyed, "WebView 未初始化"))
            return
        }
        let js = "(async function(){try{var r=await HelpBot('loadMoreMessages',\(limit),\(offset));return JSON.stringify({ok:true,data:(r||{})});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();"
        evaluateJsonResultOnMain(webView: webView, js: js, apiName: "loadMoreMessagesAsync", completion: completion)
    }

    /// 更新用户自定义 Meta（同步触发 JS）。对齐 WebSDK：HelpBot('updateUserMeta', metaObj)
    public static func updateUserMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }
        DispatchQueue.main.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildUpdateUserMeta(meta), completionHandler: nil)
        }
        return .success()
    }

    /// 更新 SDK Meta（设备/系统信息等）。对齐 WebSDK：HelpBot('updateUserSdkMeta', metaObj)
    public static func updateUserSdkMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }
        DispatchQueue.main.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildUpdateUserSdkMeta(meta), completionHandler: nil)
        }
        return .success()
    }

    /// 添加 Issue Tags。对齐 WebSDK：HelpBot('addIssueTags', stringArray)
    public static func addIssueTags(_ tags: [String]) -> HelpBotResult<Void> {
        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }
        DispatchQueue.main.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildAddIssueTags(tags), completionHandler: nil)
        }
        return .success()
    }

    /// 移除 Issue Tags。对齐 WebSDK：HelpBot('removeIssueTags', stringArray)
    public static func removeIssueTags(_ tags: [String]) -> HelpBotResult<Void> {
        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }
        DispatchQueue.main.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildRemoveIssueTags(tags), completionHandler: nil)
        }
        return .success()
    }

    /**
     获取 WEB SDK 版本
     */
    public static func getWEBSDKVersion() -> String {
        operationLock.lock()
        let installed = (installState == .installed)
        operationLock.unlock()
        if !installed {
            HBlogger.w(tag, "SDK 未初始化", nil)
            return "unknown"
        }

        guard let webView = HelpBotWebViewSession.shared.webView else {
            return "unknown"
        }

        DispatchQueue.main.async {
            webView.evaluateJavaScript(HelpBotJsCommand.buildWebSdkVersion(), completionHandler: nil)
        }
        return "v0.1.4"
    }

    /**
     绑定新身份到用户
     - 对齐 Android：`HelpBot.addUserIdentity(identifier, value)`
     */
    @discardableResult
    public static func addUserIdentity(_ identifier: String, _ value: String) -> HelpBotResult<Void> {
        operationLock.lock()
        let installed = (installState == .installed)
        operationLock.unlock()
        if !installed {
            return .failure(.sdkNotInitialized)
        }

        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }

        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let val = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let js = HelpBotJsCommand.buildAddUserIdentity(identifier: id, value: val)
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        return .success()
    }

    /**
     设置用户语言
     */
    @discardableResult
    public static func setUserLanguage(_ language: String) -> HelpBotResult<Void> {
        operationLock.lock()
        let installed = (installState == .installed)
        operationLock.unlock()
        if !installed {
            return .failure(.sdkNotInitialized)
        }

        guard let webView = HelpBotWebViewSession.shared.webView else {
            return .failure(.webViewDestroyed, "WebView 未初始化")
        }

        let lang = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let js = HelpBotJsCommand.buildSetUserLanguage(lang)
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        return .success()
    }

    // MARK: - Internal hooks for Bridge

    static func markLoginConfirmedFromWeb() {
        operationLock.lock()
        loginConfirmed = true
        loginState = .loggedIn
        operationLock.unlock()
    }

    /// SDK 内部自愈使用：读取已登录 token（仅供 SDK 内部调用，宿主不可见）
    static func getStoredJwtTokenForRecovery() -> String? {
        return keychain.getString(tokenStorageKeyJwt)
    }

    static func onConversationDismissed() {
        operationLock.lock()
        currentConversationController = nil
        operationLock.unlock()
    }

    // MARK: - Private

    private static func loginInternal(_ token: String) -> HelpBotResult<Void> {
        // 新一轮登录开始，先清理确认标记
        operationLock.lock()
        loginConfirmed = false
        operationLock.unlock()

        // 保存 Token（Keychain）
        _ = keychain.putString(tokenStorageKeyJwt, token)

        // 等待 WebSDK 初始化
        let waiter = HelpBotWebViewSession.shared.beginLoginWait()
        var triggered = false
        if HelpBotWebViewSession.shared.awaitWebSdkInitialized(timeoutMs: defaultWebSdkInitWaitTimeoutMs),
           HelpBotWebViewSession.shared.awaitWebSdkBootstrapReady(timeoutMs: defaultWebSdkBootstrapWaitTimeoutMs),
           let wv = HelpBotWebViewSession.shared.webView {
            let latch = HBCountDownLatch(1)
            DispatchQueue.main.async {
                wv.evaluateJavaScript(HelpBotJsCommand.buildSetTokenAndConnect(token)) { _, error in
                    if let error = error {
                        HBlogger.w(tag, "login: setTokenAndConnect evaluate 失败: \(error.localizedDescription)", error)
                    }
                    latch.countDown()
                }
            }
            // 等待 JS 注入完成（避免极端情况下 evaluate 被延迟，导致后续“已超时但其实没执行过 setToken”）
            _ = latch.await(timeoutMs: 1500)
            triggered = true
        }

        // 兜底：若未能触发，返回失败（iOS 侧目前只支持“已初始化后触发”）
        if !triggered {
            // 更可诊断：区分 init/bootstrap 未就绪 vs webView 已销毁
            let health = HelpBotWebViewSession.shared.getHealthSnapshot()
            let hint = HelpBotJsonUtils.toJsonString(health) ?? ""
            return .failure(.webViewDestroyed, "WebView 未初始化或通道未就绪（health=\(hint)）")
        }

        let deadline = nowMs() + Int64(defaultWebSdkLoginWaitTimeoutMs)
        while nowMs() < deadline {
            let remaining = Int(deadline - nowMs())
            let step = min(250, max(remaining, 0))
            waiter.awaitStep(step)

            if waiter.isFinished() {
                if waiter.isSuccess() {
                    operationLock.lock()
                    loginConfirmed = true
                    loginState = .loggedIn
                    operationLock.unlock()
                    return .success()
                }

                let reason = waiter.getFailReason() ?? "login_failed"
                let detail = waiter.getFailDetail()
                if reason.lowercased() == "user_authentication_failed" {
                    return .failure(.invalidToken, "WebSDK 认证失败")
                }
                if reason.lowercased() == "websdk_error" {
                    // 兼容 WebSDK：errorData 可能带 CODE/MESSAGE
                    let code = (detail?["CODE"] as? String) ?? (detail?["code"] as? String) ?? ""
                    let message = (detail?["MESSAGE"] as? String) ?? (detail?["message"] as? String) ?? ""
                    if code.uppercased() == "MISSING_PRE_GENERATED_TOKEN" {
                        return .failure(.missingPreGeneratedToken, message.isEmpty ? "生产环境必须提供 preGeneratedToken" : message)
                    }
                    if code.uppercased() == "INVALID_PRE_GENERATED_TOKEN" {
                        return .failure(.invalidPreGeneratedToken, message.isEmpty ? "预生成 token 无效" : message)
                    }
                    return .failure(.loginFailed, message.isEmpty ? "WebSDK 登录失败: \(code)" : "WebSDK 登录失败: \(message)")
                }
                return .failure(.loginFailed, "WebSDK 登录失败: \(reason)")
            }

            // 兜底：检查 authenticated=true
            if let status = HelpBotWebViewSession.shared.getWebSdkStatusBlocking(timeoutMs: 800),
               (status["authenticated"] as? Bool) == true {
                operationLock.lock()
                loginConfirmed = true
                loginState = .loggedIn
                operationLock.unlock()
                return .success()
            }
        }

        // 登录超时：输出更多诊断信息（不包含 token）
        let health = HelpBotWebViewSession.shared.getHealthSnapshot()
        let hint = HelpBotJsonUtils.toJsonString(health) ?? ""
        return .failure(.operationTimeout, "等待 WebSDK 登录确认超时（health=\(hint)）")
    }

    private static func onLoginFinished(_ success: Bool) {
        var showToRun: PendingShowConversationRequest?
        operationLock.lock()
        if success {
            loginState = .loggedIn
        } else {
            loginState = .failed
            loginConfirmed = false
        }

        // 清理过期 showConversation 请求
        let now = nowMs()
        if let pending = pendingShowConversationRequest,
           now - pending.createdAtMs > pendingRequestTtlMs {
            pendingShowConversationRequest = nil
        }

        if success, installState == .installed, let pending = pendingShowConversationRequest {
            showToRun = pending
            pendingShowConversationRequest = nil
        }
        operationLock.unlock()

        guard let req = showToRun else { return }
        DispatchQueue.main.async {
            // 说明：排队请求默认不保存宿主 VC（更稳）；但若存在且可用则优先用之
            if let from = req.from, let p = resolvePresenterForPresentation(from: from) {
                presentConversationNow(from: p)
                return
            }
            // 无 VC / VC 不可用：从顶层 presenter 展示
            tryRunPendingShowConversationIfPossible(trigger: "loginFinished")
        }
    }

    private static func runPendingRequestsIfNeeded() {
        // install 完成后，处理排队 setEventsListener / login / showConversation
        var shouldApplyEventsListener = false
        var eventsListenerToApply: HelpBotEventsListener?

        var loginReq: PendingLoginRequest?
        operationLock.lock()
        let now = nowMs()

        // 1) 处理排队的 eventsListener（允许 nil，表示移除）
        if hasPendingEventsListenerUpdate {
            if now - pendingEventsListenerCreatedAtMs <= pendingRequestTtlMs {
                shouldApplyEventsListener = true
                eventsListenerToApply = pendingEventsListener
            }
            hasPendingEventsListenerUpdate = false
            pendingEventsListener = nil
            pendingEventsListenerCreatedAtMs = 0
        }

        // 2) 处理排队的 login
        if let p = pendingLoginRequest, now - p.createdAtMs <= pendingRequestTtlMs {
            loginReq = p
            pendingLoginRequest = nil
            // 关键：必须先切到 loggingIn，避免宿主在这段窗口期调用 showConversation 被误判为“未登录”
            // 对齐 Android：login 进行中时 showConversation 应入队并返回 success。
            loginState = .loggingIn
        } else {
            pendingLoginRequest = nil
            if loginState == .loginPending {
                loginState = .notLoggedIn
            }
        }
        operationLock.unlock()

        if shouldApplyEventsListener {
            eventProxy.updateListener(eventsListenerToApply)
        }

        if let req = loginReq {
            // 关键：这里不能再调用 public login()，否则会被自身的 operationInProgress 检查拦截（SDK 自己卡死）。
            // 对齐 Android：pending-login 进入执行态后应直接走内部登录流程。
            executeLoginInternalAsync(token: req.token, completion: req.completion, reason: "pending")
        }
    }

    private static func presentConversationNow(from viewController: UIViewController) {
        // 已展示：直接 open
        if currentConversationController != nil {
            HelpBotWebViewSession.shared.openWhenReady()
            return
        }
        
        // 选择一个真正可用于 present 的 presenter（避免 UIAlertController / dismiss 过渡 / 不在 window）
        guard let presenter = resolvePresenterForPresentation(from: viewController) else {
            // presenter 不可用：入队等待 app active 后重试
            ensureAppLifecycleObserverInstalled()
            operationLock.lock()
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            HBlogger.w(tag, "showConversation: presenter 不可用，已入队等待重试", nil)
            return
        }
        
        // showConversation 时尝试上报系统信息（失败不影响展示）
        _ = reportSystemInfoToServer()

        let showTitleBar = shouldShowTitleBar()
        let vc = HelpBotViewController(showTitleBar: showTitleBar)

       
        // 说明：viewController 可能本身就是 UINavigationController/UITabBarController；因此必须做一次更稳的解析。
        if let hostNav = ApplicationUtils.getHostNavigationController(from: presenter),
           hostNav.viewIfLoaded?.window != nil,
           !hostNav.isBeingDismissed {
            HBlogger.i(tag, "show", nil)
            hostNav.pushViewController(vc, animated: true)
            markConversationShownIfVisible(conversationController: vc, presenter: hostNav, reason: "push")
            return
        }

        // 无宿主导航栈：fallback 为全屏 present
        HBlogger.i(tag, "showConversation: 无 navigationController，使用 fullScreen present", nil)
        if showTitleBar {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            safePresent(presenter: presenter, controllerToPresent: nav, conversationController: vc, reason: "present_nav")
        } else {
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle = .coverVertical
            safePresent(presenter: presenter, controllerToPresent: vc, conversationController: vc, reason: "present_vc")
        }
    }
    
    /// 解析出可用于 present 的 VC。极端情况下返回 nil（表示应等待 app active/window ready）。
    private static func resolvePresenterForPresentation(from vc: UIViewController) -> UIViewController? {
        // 如果传入的是 alert（或正在 dismiss），优先回退到 presenting
        var cur: UIViewController? = vc
        var depth = 0
        while let c = cur, depth < 12 {
            if c is UIAlertController {
                cur = c.presentingViewController
                depth += 1
                continue
            }
            if c.isBeingDismissed {
                cur = c.presentingViewController
                depth += 1
                continue
            }
            // view 不在 window：回退
            if let v = c.viewIfLoaded, v.window == nil {
                cur = c.presentingViewController
                depth += 1
                continue
            }
            return c
        }
        
        //  回退失败：尝试全局 top presenter
        return ApplicationUtils.getTopViewControllerForPresentation()
    }
    
    /// 只有在“真正展示成功”后才标记 currentConversationController，避免 present/push 失败后永久卡死。
    private static func markConversationShownIfVisible(
        conversationController: UIViewController,
        presenter: UIViewController,
        reason: String
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let isVisible: Bool = {
                if let nav = presenter as? UINavigationController {
                    return nav.viewControllers.contains(where: { $0 === conversationController }) && conversationController.viewIfLoaded?.window != nil
                }
                if conversationController.presentingViewController != nil { return true }
                if let v = conversationController.viewIfLoaded, v.window != nil { return true }
                return false
            }()
            
            if isVisible {
                operationLock.lock()
                currentConversationController = conversationController
                operationLock.unlock()
                return
            }
            
            // 未可见：入队重试（对齐 Android：尽量保证最终可展示）
            operationLock.lock()
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            ensureAppLifecycleObserverInstalled()
            HBlogger.w(tag, "showConversation(\(reason)): 未检测到可见展示，已入队重试", nil)
        }
    }
    
    /// 安全 present：处理“过渡中/正在 dismiss/不在 window”导致的系统拒绝，并自动重试/入队。
    private static func safePresent(
        presenter: UIViewController,
        controllerToPresent: UIViewController,
        conversationController: UIViewController,
        reason: String,
        attempt: Int = 0
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                safePresent(
                    presenter: presenter,
                    controllerToPresent: controllerToPresent,
                    conversationController: conversationController,
                    reason: reason,
                    attempt: attempt
                )
            }
            return
        }
        
        if attempt > 6 {
            operationLock.lock()
            pendingShowConversationRequest = PendingShowConversationRequest(from: nil, createdAtMs: nowMs())
            operationLock.unlock()
            ensureAppLifecycleObserverInstalled()
            HBlogger.w(tag, "safePresent(\(reason)): 超过重试次数，已入队等待重试", nil)
            return
        }
        
        // presenter 不在 window / 正在 dismiss / 正在 present：延迟再试
        if presenter.isBeingDismissed || presenter.isBeingPresented || presenter.transitionCoordinator != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                safePresent(
                    presenter: presenter,
                    controllerToPresent: controllerToPresent,
                    conversationController: conversationController,
                    reason: reason,
                    attempt: attempt + 1
                )
            }
            return
        }
        if let v = presenter.viewIfLoaded, v.window == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let p = ApplicationUtils.getTopViewControllerForPresentation() ?? presenter
                safePresent(
                    presenter: p,
                    controllerToPresent: controllerToPresent,
                    conversationController: conversationController,
                    reason: reason,
                    attempt: attempt + 1
                )
            }
            return
        }
        
        presenter.present(controllerToPresent, animated: true) {
            markConversationShownIfVisible(conversationController: conversationController, presenter: presenter, reason: reason)
        }
    }

    private static func shouldShowTitleBar() -> Bool {
        guard let cfg = config else { return true }
        guard let v = cfg.customConfig["showTitleBar"] else { return true }
        if let b = v as? Bool { return b }
        if let s = v as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return true }
            return !(t.lowercased() == "false" || t == "0" || t.lowercased() == "no")
        }
        return true
    }

    private static func readBool(_ map: [String: Any]?, key: String, defaultValue: Bool) -> Bool {
        guard let map = map else { return defaultValue }
        guard let v = map[key] else { return defaultValue }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.intValue != 0 }
        if let s = v as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return defaultValue }
            return t.lowercased() == "true" || t == "1" || t.lowercased() == "yes"
        }
        return defaultValue
    }

    private static func readInt(_ map: [String: Any]?, key: String, defaultValue: Int) -> Int {
        guard let map = map else { return defaultValue }
        guard let v = map[key] else { return defaultValue }
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return defaultValue }
            return Int(t) ?? defaultValue
        }
        return defaultValue
    }

    private static func getWebChatHosts() -> [String] {
        var hosts: [String] = []
        if let h1 = URL(string: HelpBotSDKUrls.webChatIndex)?.host, !h1.isEmpty { hosts.append(h1) }
        if let h2 = URL(string: HelpBotSDKUrls.webChatLoaderJs)?.host, !h2.isEmpty, !hosts.contains(h2) { hosts.append(h2) }
        return hosts
    }

    private static func nowMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func quoteJsString(_ raw: String) -> String {
        // 与 HelpBotJsCommand.quoteJsString 同策略：["xxx"] -> "xxx"
        guard let json = HelpBotJsonUtils.toJsonString([raw]) else { return "\"\"" }
        if json.count >= 4, json.hasPrefix("[\""), json.hasSuffix("\"]") {
            return String(json.dropFirst(1).dropLast(1))
        }
        return "\"\""
    }

    private static func evaluateJsonResultOnMain(
        webView: WKWebView,
        js: String,
        apiName: String,
        completion: ((HelpBotResult<[String: Any]>) -> Void)?
    ) {
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js) { value, error in
                if let error = error {
                    completion?(.failure(.internalError, "\(apiName) evaluate 异常: \(error.localizedDescription)"))
                    return
                }
                if let str = value as? String, let parsed = HelpBotJsonUtils.parseJsonObject(str) {
                    let ok = (parsed["ok"] as? Bool) ?? false
                    if ok {
                        if let data = parsed["data"] as? [String: Any] {
                            completion?(.success(data))
                        } else {
                            completion?(.success([:]))
                        }
                    } else {
                        let errStr = (parsed["error"] as? String) ?? "unknown"
                        completion?(.failure(.internalError, "\(apiName) 失败: \(errStr)"))
                    }
                    return
                }
                completion?(.failure(.internalError, "\(apiName) 返回值格式错误"))
            }
        }
    }
}


