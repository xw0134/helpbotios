import Foundation
import UIKit
import WebKit

/**
 HelpBot SDK 主入口类（iOS）。
 
 设计要点（与 Android 一致）：
 1. 仅提供异步 API（避免宿主在主线程调用阻塞导致卡顿/死锁）。
 2. 统一错误码与回调机制。
 3. 线程安全与资源生命周期管理。
 */
public final class HelpBot {
    private static let tag = "HelpBot"
    private static let tokenStorageKeyJwt = "jwt_token"
    /// iOS SDK 版本号（对齐 Android AAR 版本号命名）
    private static let sdkVersion = "0.1.13"

    /// FAQ 基础 URL（对齐 Android 实现：当前为占位示例，后续可替换为真实帮助中心域名）
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

    private init() {
        assertionFailure("HelpBot 不能被实例化")
    }

    // MARK: - Public APIs

    /// 初始化日志（可选）
    public static func initLogger(_ logger: IHBLogger?) {
        HBlogger.initLoggerIfAbsent(logger)
    }

    /// 设置事件监听器（可在任意时机调用，后设置会覆盖旧监听器）
    public static func setEventsListener(_ listener: HelpBotEventsListener?) {
        eventProxy.updateListener(listener)
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
            let builder = HelpBotConfig.Builder()
                .channelId(channelId)
                .domain(domain)
                .fullPrivacyMode(fullPrivacyMode)

            // customConfig：保存所有原始配置，供 SDK 内部（如标题栏）读取
            if let configMap, !configMap.isEmpty {
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
        operationLock.unlock()

        callback?.onInitStart()
        callback?.onInitProgress(15, "预加载 WebView")

        // 预加载 + 等待初始化完成（后台线程）
        DispatchQueue.global(qos: .utility).async {
            do {
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
            } catch {
                operationLock.lock()
                installState = .failed
                operationLock.unlock()
                DispatchQueue.main.async {
                    callback?.onInitFailure(.internalError, "install 异常: \(error.localizedDescription)")
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

        if loginState == .loggingIn {
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

        DispatchQueue.global(qos: .utility).async {
            let result = loginInternal(token)
            onLoginFinished(result.isSuccess)
            DispatchQueue.main.async { completion?(result) }
        }
    }

    /// 显示对话窗口（异步，推荐）
    @discardableResult
    public static func showConversation(from viewController: UIViewController) -> HelpBotResult<Void> {
        operationLock.lock()
        // install 进行中：入队
        if installState == .installing {
            pendingShowConversationRequest = PendingShowConversationRequest(from: viewController, createdAtMs: nowMs())
            operationLock.unlock()
            return .success()
        }
        if installState != .installed || config == nil {
            operationLock.unlock()
            return .failure(.sdkNotInitialized)
        }
        if loginState == .loginPending || loginState == .loggingIn {
            pendingShowConversationRequest = PendingShowConversationRequest(from: viewController, createdAtMs: nowMs())
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

    /// 隐藏对话窗口（不销毁会话）
    @discardableResult
    public static func hideConversation() -> HelpBotResult<Void> {
        DispatchQueue.main.async {
            do {
                if let wv = HelpBotWebViewSession.shared.webView {
                    wv.evaluateJavaScript(HelpBotJsCommand.buildClose(), completionHandler: nil)
                }
            } catch {}
            if let vc = currentConversationController {
                if let nav = vc.navigationController {
                    nav.dismiss(animated: true)
                } else {
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
        operationLock.unlock()

        _ = keychain.remove(tokenStorageKeyJwt)

        DispatchQueue.main.async {
            do {
                if let wv = HelpBotWebViewSession.shared.webView {
                    wv.evaluateJavaScript(HelpBotJsCommand.buildDestroy(), completionHandler: nil)
                }
            } catch {}
            completion?(.success())
        }
    }

    public static func isConversationVisible() -> Bool {
        return currentConversationController != nil
    }
    
    // MARK: - FAQ APIs
    
    /**
     显示 FAQ 主页面（对齐 Android：使用系统浏览器打开 URL，而非在 WebChat 内嵌打开）。
     
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
     显示 FAQ 分组页面（对齐 Android）。
     
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
     显示 FAQ 单页（对齐 Android）。
     
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

    /// 构建 FAQ URL（对齐 Android 的 buildFaqUrl 逻辑）
    private static func buildFaqUrl(tn: String?, extraKey: String?, extraValue: String?) -> String {
        // tn 默认值与 Android 对齐
        let tnValue = (tn ?? "").isEmpty ? "68018901_16_pg" : (tn ?? "68018901_16_pg")
        var comps = URLComponents(string: faqBaseUrl) ?? URLComponents()
        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "tn", value: tnValue))
        if let extraKey, let extraValue, !extraKey.isEmpty, !extraValue.isEmpty {
            items.append(URLQueryItem(name: extraKey, value: extraValue))
        }
        comps.queryItems = items
        return comps.string ?? faqBaseUrl
    }
    
    // MARK: - SDK Management APIs
    
    /// 销毁 SDK 并释放所有资源（与 Android 对齐）
    public static func destroy(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        operationLock.lock()
        installState = .notInstalled
        loginState = .notLoggedIn
        loginConfirmed = false
        pendingLoginRequest = nil
        pendingShowConversationRequest = nil
        let currentConfig = config
        config = nil
        operationLock.unlock()
        
        // 清理存储
        _ = keychain.remove(tokenStorageKeyJwt)
        
        // 销毁 WebView 会话
        DispatchQueue.main.async {
            do {
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
            } catch {
                completion?(.failure(.internalError, "destroy 异常: \(error.localizedDescription)"))
            }
        }
    }
    
    /// 获取 SDK 版本号（与 Android 对齐）
    public static func getSDKVersion() -> String {
        return sdkVersion
    }

    // MARK: - Android 对齐补充 API（别名/兼容）

    /**
     更新 SDK Meta（对齐 Android `updateSDKMeta`）。
     - 说明：iOS 内部复用 `updateUserSdkMeta`。
     */
    public static func updateSDKMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        return updateUserSdkMeta(meta)
    }

    /**
     更新用户自定义 Meta（对齐 Android `updateCustomMeta`）。
     - 说明：iOS 内部复用 `updateUserMeta`。
     */
    public static func updateCustomMeta(_ meta: [String: Any]) -> HelpBotResult<Void> {
        return updateUserMeta(meta)
    }

    /**
     上报系统信息到服务器（对齐 Android `reportSystemInfoToServer`）。
     - 说明：通过 WebSDK `updateUserSdkMeta` 上报；隐私模式下最小化上报字段。
     */
    public static func reportSystemInfoToServer() -> HelpBotResult<Void> {
        operationLock.lock()
        guard installState == .installed, let cfg = config else {
            operationLock.unlock()
            return .failure(.sdkNotInitialized)
        }
        operationLock.unlock()

        do {
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
                meta["country_code"] = dev.getDeviceRegion()
                meta["language"] = dev.getDeviceLanguage()
                meta["app_identifier"] = dev.getBundleId()
                meta["device_id"] = dev.getDeviceId()
                meta["is_online"] = diagnosis.networkConnected && diagnosis.hasInternetCapability
            } else {
                meta["full_privacy_mode"] = true
            }

            return updateUserSdkMeta(meta)
        } catch {
            return .failure(.internalError, "reportSystemInfoToServer 异常: \(error.localizedDescription)")
        }
    }

    /**
     设置通知小图标资源 ID（对齐 Android API）。
     - 说明：iOS 无“通知小图标资源 ID”概念，此方法为跨平台 API 兼容保留，当前 no-op。
     */
    public static func setNotificationSmallIconResId(_ resId: Int) {
        HBlogger.w(tag, "setNotificationSmallIconResId: iOS 平台不适用，已忽略", nil)
    }

    /**
     设置通知渠道 ID（对齐 Android API）。
     - 说明：iOS 无 NotificationChannelId 概念，此方法为跨平台 API 兼容保留，当前 no-op。
     */
    public static func setNotificationChannelId(_ channelId: String) {
        HBlogger.w(tag, "setNotificationChannelId: iOS 平台不适用，已忽略", nil)
    }

    /**
     关闭当前会话（对齐 Android `closeSession()`）：
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
        operationLock.unlock()

        _ = keychain.remove(tokenStorageKeyJwt)

        ApplicationUtils.runOnMainThread {
            do {
                if let wv = HelpBotWebViewSession.shared.webView {
                    wv.evaluateJavaScript(HelpBotJsCommand.buildClose(), completionHandler: nil)
                }
            } catch {
                // ignore
            }
            HelpBotWebViewSession.shared.destroy()
        }
        return .success()
    }
    
    /// 验证 SDK 是否已正确安装（与 Android 对齐）
    public static func verifyInstall() -> Bool {
        operationLock.lock()
        defer { operationLock.unlock() }
        return installState == .installed && config != nil && HelpBotContext.isInstalled()
    }

    /// SDK 是否已初始化完成（与 Android `isInitialized()` 对齐）
    public static func isInitialized() -> Bool {
        return verifyInstall()
    }
    
    /// 获取当前 SDK 配置（与 Android 对齐）
    public static func getConfig() -> HelpBotConfig? {
        operationLock.lock()
        defer { operationLock.unlock() }
        return config
    }

    /// 获取 WebSDK 健康快照（与 Android `getWebSdkHealthSnapshot()` 对齐）
    public static func getWebSdkHealthSnapshot() -> [String: Any] {
        return HelpBotWebViewSession.shared.getHealthSnapshot()
    }
    
    // MARK: - SSE Notification APIs
    
    private static var sseNotificationEnabled: Bool = true
    
    /// 启用 SSE 通知（与 Android 对齐）
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
    
    /// 禁用 SSE 通知（与 Android 对齐）
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

    /// 兼容 Android 入口：enableSseNotification(boolean enable)
    public static func enableSseNotification(_ enable: Bool) {
        if enable {
            enableSseNotification()
        } else {
            disableSseNotification()
        }
    }
    
    // MARK: - User Login Events Listener
    
    private static weak var userLoginEventsListener: HelpBotUserLoginEventsListener?
    
    /// 设置用户登录事件监听器（与 Android 对齐）
    public static func setUserLoginEventsListener(_ listener: HelpBotUserLoginEventsListener?) {
        operationLock.lock()
        userLoginEventsListener = listener
        operationLock.unlock()
    }
    
    // MARK: - Data Management APIs
    
    /// 清除匿名用户数据（与 Android 对齐）
    public static func clearAnonymousUser(completion: ((HelpBotResult<Void>) -> Void)? = nil) {
        HelpBotThreadPool.shared.submit {
            do {
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
            } catch {
                completion?(.failure(.internalError, "清除匿名用户异常: \(error.localizedDescription)"))
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

    // MARK: - Internal hooks for Bridge

    static func markLoginConfirmedFromWeb() {
        operationLock.lock()
        loginConfirmed = true
        loginState = .loggedIn
        operationLock.unlock()
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
           let wv = HelpBotWebViewSession.shared.webView {
            DispatchQueue.main.async {
                wv.evaluateJavaScript(HelpBotJsCommand.buildSetTokenAndConnect(token), completionHandler: nil)
            }
            triggered = true
        }

        // 兜底：若未能触发，返回失败（iOS 侧目前只支持“已初始化后触发”）
        if !triggered {
            return .failure(.webViewDestroyed, "WebView 未初始化")
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

        return .failure(.operationTimeout, "等待 WebSDK 登录确认超时")
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

        if let req = showToRun, let from = req.from {
            DispatchQueue.main.async {
                presentConversationNow(from: from)
            }
        }
    }

    private static func runPendingRequestsIfNeeded() {
        // install 完成后，处理排队 login / showConversation
        var loginReq: PendingLoginRequest?
        operationLock.lock()
        let now = nowMs()
        if let p = pendingLoginRequest, now - p.createdAtMs <= pendingRequestTtlMs {
            loginReq = p
            pendingLoginRequest = nil
            loginState = .loggingIn
        } else {
            pendingLoginRequest = nil
            if loginState == .loginPending {
                loginState = .notLoggedIn
            }
        }
        operationLock.unlock()

        if let req = loginReq {
            login(req.token, completion: req.completion)
        }
    }

    private static func presentConversationNow(from viewController: UIViewController) {
        // 已展示：直接 open
        if currentConversationController != nil {
            HelpBotWebViewSession.shared.openWhenReady()
            return
        }

        let showTitleBar = shouldShowTitleBar()
        let vc = HelpBotViewController(showTitleBar: showTitleBar)
        currentConversationController = vc

        if showTitleBar {
            let nav = UINavigationController(rootViewController: vc)
            viewController.present(nav, animated: true)
        } else {
            viewController.present(vc, animated: true)
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
        guard let map else { return defaultValue }
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
                if let error {
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


