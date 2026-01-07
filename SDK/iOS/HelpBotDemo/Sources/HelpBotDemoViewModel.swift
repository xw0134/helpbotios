import Foundation
import UIKit
import HelpBotSDK
import Network
import UserNotifications

final class HelpBotDemoViewModel: NSObject, ObservableObject {
    // ===== 配置输入=====
    @Published var channelId: String = "appc-20251126114209416-ptvea1y414vey36"
    @Published var domain: String = "dev-bot-server.yuedongcs.com"

    /// Token 生成接口
    @Published var tokenUrl: String = "https://dev-bot-server.yuedongcs.com:8123/generate_token"
    @Published var identityIdentifier: String = "uid"
    @Published var identityValue: String = "123456789"

    /// 预生成 Token（JWT）：可手动粘贴；GenToken 成功后会自动写入
    @Published var tokenInput: String = ""

    /// Token 脱敏展示文本
    @Published var tokenMaskedText: String = "Token：未生成（将以脱敏形式展示）"

    @Published var statusText: String = "状态：已启动（等待操作）"

    /// Android 风格日志面板（可复制/可裁剪，避免 OOM）
    @Published var logText: String = "日志：\n"

    private let logger = HelpBotDemoLogger()

    // ===== State =====
    private var rawToken: String?
    private let logLock = NSLock()
    private var logBuffer: String = "日志：\n"
    private static let logMaxChars: Int = 40_000

    // 网络监听
    @Published var networkMonitorEnabled: Bool = true
    @Published var autoRetryEnabled: Bool = false
    
    // SSE 通知开关
    @Published var sseNotificationEnabled: Bool = true
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.helpbot.demo.netmonitor")
    private var lastInstallFailedDueToNetwork: Bool = false
    private var lastInstallAttemptAtMs: Int64 = 0

    // 压力回归
    @Published private(set) var stressRunning: Bool = false
    @Published private(set) var stressLoopCount: Int = 0
    @Published private(set) var stressSuccessCount: Int = 0
    @Published private(set) var stressFailureCount: Int = 0
    private let stressMaxLoops: Int = 60

    override init() {
        super.init()
        HelpBot.initLogger(logger)
        HelpBot.setEventsListener(self)
        setupNetworkMonitorIfNeeded()
        requestNotificationPermissionIfNeeded()

        clearLog()
        updateStatus("状态：已启动（等待操作）")
        appendLog("App 启动完成")
    }
    
    deinit {
        stopNetworkMonitor()
    }

    func install() {
        appendLog("========== 测试：Install(异步) ==========")
        updateStatus("状态：Install 开始...")
        // initTimeout/webViewLoadTimeout/enableSseNotification
        let configMap: [String: Any] = [
            "fullPrivacyMode": false,
            "showTitleBar": true,
            "enableSseNotification": sseNotificationEnabled,
            "initTimeout": 30_000,
            "webViewLoadTimeout": 15_000
        ]
        lastInstallAttemptAtMs = Self.nowMs()
        HelpBot.install(channelId: channelId, domain: domain, configMap: configMap, callback: self)
    }

    func genToken() {
        appendLog("========== 测试：GenToken ==========")
        updateStatus("状态：正在生成 Token...")

        let urlStr = tokenUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlStr), !urlStr.isEmpty else {
            updateStatus("状态：构造请求失败: tokenUrl 为空或无效")
            appendLog("GenToken: failure=tokenUrl 为空或无效")
            return
        }

        let identifier = identityIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = identityValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if identifier.isEmpty || value.isEmpty {
            updateStatus("状态：构造请求失败: identity 不能为空")
            appendLog("GenToken: failure=identity 不能为空")
            return
        }

        let payload: [String: Any] = [
            "identities": [
                [
                    "identifier": identifier,
                    "value": value
                ]
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            updateStatus("状态：构造请求失败: 请求体序列化失败")
            appendLog("GenToken: failure=request body 序列化失败")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 45

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 45
        cfg.timeoutIntervalForResource = 45
        let session = URLSession(configuration: cfg)

        session.dataTask(with: req) { [weak self] data, resp, err in
            guard let self else { return }
            defer { session.invalidateAndCancel() }

            if let err {
                self.appendLog("GenToken: failure=\(err.localizedDescription)")
                self.updateStatus("状态：Token 生成失败: \(err.localizedDescription)")
                return
            }

            if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let msg = "HTTP \(http.statusCode)"
                self.appendLog("GenToken: failure=\(msg)")
                self.updateStatus("状态：Token 生成失败: \(msg)")
                return
            }

            guard let data, !data.isEmpty else {
                self.appendLog("GenToken: failure=empty response")
                self.updateStatus("状态：Token 生成失败: 响应为空")
                return
            }

            do {
                let obj = try JSONSerialization.jsonObject(with: data)
                guard let dict = obj as? [String: Any] else {
                    throw NSError(domain: "HelpBotDemo", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应不是 JSON 对象"])
                }
                let token = (dict["token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if token == nil || token?.isEmpty == true {
                    throw NSError(domain: "HelpBotDemo", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应缺少 token 字段"])
                }

                self.rawToken = token
                DispatchQueue.main.async {
                    self.tokenInput = token ?? ""
                    let masked = HBlogger.sanitizeValue(token)
                    self.tokenMaskedText = "Token（脱敏）：\(masked)"
                    self.statusText = "状态：Token 已生成（脱敏显示）"
                }
                self.appendLog("GenToken: success（已脱敏）")
            } catch {
                self.appendLog("GenToken: failure=parse \(error.localizedDescription)")
                self.updateStatus("状态：Token 获取失败")
            }
        }.resume()
    }

    func login() {
        appendLog("========== 测试：Login(异步) ==========")
        updateStatus("状态：Login 开始...")
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenToUse = token.isEmpty ? (rawToken ?? "") : token
        if tokenToUse.isEmpty {
            updateStatus("状态：Login 失败（Token 为空）")
            appendLog("Login.onFailure: Token 为空")
            return
        }
        rawToken = tokenToUse
        HelpBot.login(tokenToUse) { [weak self] result in
            guard let self else { return }
            if result.isSuccess {
                self.updateStatus("状态：Login 成功")
                self.appendLog("Login.onSuccess")
            } else {
                self.updateStatus("状态：Login 失败: \(result.errorMessage ?? "")")
                self.appendLog("Login.onFailure: \(result.errorCode?.rawValue ?? -1) - \(result.errorMessage ?? "")")
            }
        }
    }

    func showConversation() {
        guard let top = UIApplication.shared.hbTopViewController() else {
            appendLog("OpenConversation: failure=找不到 topViewController")
            updateStatus("状态：OpenConversation 失败: 找不到 topViewController")
            return
        }
        let r = HelpBot.showConversation(from: top)
        if r.isSuccess {
            appendLog("OpenConversation: success（若 install/login 未完成可能为入队等待）")
            updateStatus("状态：OpenConversation 已触发")
        } else {
            appendLog("OpenConversation: failure=\(r.errorMessage ?? "")")
            updateStatus("状态：OpenConversation 失败: \(r.errorMessage ?? "")")
        }
    }

    func hideConversation() {
        _ = HelpBot.hideConversation()
        appendLog("hideConversation")
    }

    func logout() {
        HelpBot.logout { [weak self] result in
            self?.appendLog("logout: \(result.isSuccess ? "success" : "fail")")
            self?.updateStatus("状态：logout")
        }
    }

    func clearWebViewData() {
        appendLog("清理 WebView 缓存/数据...")
        HelpBot.clearWebViewData { [weak self] result in
            guard let self else { return }
            if result.isSuccess {
                self.appendLog("清理 WebView 数据成功")
                self.updateStatus("状态：已清理 WebView 缓存/数据")
            } else {
                self.appendLog("清理 WebView 数据失败: \(result.errorMessage ?? "")")
                self.updateStatus("状态：清理失败: \(result.errorMessage ?? "")")
            }
        }
    }

    // MARK: - 质量保障

    func runSelfCheck() {
        appendLog("========== 一键自检开始 ==========")
        updateStatus("状态：自检中...")

        let dev = IOSDevice.shared
        appendLog("bundleId=\(dev.getBundleId()) appVersion=\(dev.getAppVersion()) build=\(dev.getAppBuildNumber())")
        appendLog("iOS=\(dev.getOSVersion()) deviceModel=\(dev.getDeviceModel()) isSimulator=\(dev.isSimulator())")
        appendLog("HelpBotSDKVersion=\(HelpBot.getSDKVersion())")
        appendLog("HelpBot.isInitialized=\(HelpBot.isInitialized())")
        appendLog("HelpBot.isConversationVisible=\(HelpBot.isConversationVisible())")

        let diagnosis = NetworkUtils.diagnose()
        appendLog("NetworkDiagnosis: connected=\(diagnosis.networkConnected) internet=\(diagnosis.hasInternetCapability) validated=\(diagnosis.validated) transport=\(diagnosis.transport ?? "") hint=\(diagnosis.buildUserHint())")

        updateStatus("状态：自检完成（详见日志）")
        appendLog("========== 一键自检完成 ==========")
    }

    func runSecurityBaselineAudit() {
        appendLog("========== 安全基线扫描开始 ==========")
        updateStatus("状态：安全扫描中...")

        let snap = HelpBot.getWebViewSecurityBaselineSnapshot()
        appendLog("WebViewSecurityBaseline=\(snap)")
        updateStatus("状态：安全扫描完成（详见日志）")
        appendLog("========== 安全基线扫描完成 ==========")
    }

    func runNegativeTests() {
        appendLog("========== 负向用例开始 ==========")
        updateStatus("状态：负向用例执行中...")

        // 1) 未登录/未 install 直接 showConversation
        if let top = UIApplication.shared.hbTopViewController() {
            let r = HelpBot.showConversation(from: top)
            appendLog("Negative.showConversationWithoutLogin: success=\(r.isSuccess) err=\(r.errorMessage ?? "")")
        } else {
            appendLog("Negative.showConversationWithoutLogin: skip（找不到 topViewController）")
        }

        // 2) login 空 token
        HelpBot.login("") { [weak self] result in
            self?.appendLog("Negative.loginEmptyToken: success=\(result.isSuccess) code=\(result.errorCode?.rawValue ?? -1) msg=\(result.errorMessage ?? "")")
        }

        // 3) install 非 https domain（应失败）
        appendLog("Negative.installHttpDomain: start")
        HelpBot.install(channelId: "test_channel", domain: "http://example.com", configMap: nil, callback: NegativeInstallCallback { [weak self] code, msg in
            self?.appendLog("Negative.installHttpDomain: result code=\(code.rawValue) msg=\(msg)")
        })

        // 4) 重复 install（应返回明确错误）
        appendLog("Negative.doubleInstall: trigger twice")
        install()
        install()

        updateStatus("状态：负向用例完成（详见日志）")
        appendLog("========== 负向用例完成 ==========")
    }

    // MARK: - 其它 UI / 数据更新（长按入口）

    func testOtherUIAPIs() {
        appendLog("========== 测试：其他UI接口 ==========")
        guard let top = UIApplication.shared.hbTopViewController() else {
            appendLog("showFAQs/FAQSection/SingleFAQ 失败：找不到 topViewController")
            return
        }
        let r1 = HelpBot.showFAQs(from: top, config: ["tn": "68018901_16_pg"])
        appendLog("showFAQs: \(r1.isSuccess ? "success" : "fail") \(r1.errorMessage ?? "")")
        let r2 = HelpBot.showFAQSection(from: top, sectionPublishId: "test_section_id", config: ["tn": "68018901_16_pg"])
        appendLog("showFAQSection: \(r2.isSuccess ? "success" : "fail") \(r2.errorMessage ?? "")")
        let r3 = HelpBot.showSingleFAQ(from: top, questionPublishId: "test_question_id", config: ["tn": "68018901_16_pg"])
        appendLog("showSingleFAQ: \(r3.isSuccess ? "success" : "fail") \(r3.errorMessage ?? "")")
    }

    func testDataUpdateAPIs() {
        appendLog("========== 测试：数据更新接口 ==========")
        let dev = IOSDevice.shared
        let sdkMeta: [String: Any] = [
            "app_version": dev.getAppVersion(),
            "device_model": dev.getDeviceModel()
        ]
        let r1 = HelpBot.updateSDKMeta(sdkMeta)
        appendLog("updateSDKMeta: \(r1.isSuccess ? "success" : "fail") \(r1.errorMessage ?? "")")

        let customMeta: [String: Any] = [
            "user_level": "VIP",
            "test_key": "test_value"
        ]
        let r2 = HelpBot.updateCustomMeta(customMeta)
        appendLog("updateCustomMeta: \(r2.isSuccess ? "success" : "fail") \(r2.errorMessage ?? "")")

        let tags = ["test_tag_1", "test_tag_2"]
        let r3 = HelpBot.addIssueTags(tags)
        appendLog("addIssueTags: \(r3.isSuccess ? "success" : "fail") \(r3.errorMessage ?? "")")
        let r4 = HelpBot.removeIssueTags(tags)
        appendLog("removeIssueTags: \(r4.isSuccess ? "success" : "fail") \(r4.errorMessage ?? "")")

        let r5 = HelpBot.reportSystemInfoToServer()
        appendLog("reportSystemInfoToServer: \(r5.isSuccess ? "success" : "fail") \(r5.errorMessage ?? "")")
    }

    // MARK: - 网络波动 / 自动重试

    func onNetworkMonitorToggled() {
        setupNetworkMonitorIfNeeded()
    }
    
    func onSseNotificationToggled() {
        let enabled = sseNotificationEnabled
        HelpBot.enableSseNotification(enabled)
        appendLog("SSE 通知开关：\(enabled ? "开启" : "关闭")")
    }

    private func setupNetworkMonitorIfNeeded() {
        if !networkMonitorEnabled {
            stopNetworkMonitor()
            return
        }
        if pathMonitor != nil { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            let transport: String = {
                if path.usesInterfaceType(.wifi) { return "WIFI" }
                if path.usesInterfaceType(.cellular) { return "CELLULAR" }
                if path.usesInterfaceType(.wiredEthernet) { return "ETHERNET" }
                return "UNKNOWN"
            }()
            self.appendLog("Network.changed: connected=\(connected) transport=\(transport) constrained=\(path.isConstrained)")

            // 自动重试 install（失败且网络恢复）
            if connected, self.autoRetryEnabled, self.lastInstallFailedDueToNetwork {
                let now = Self.nowMs()
                if now - self.lastInstallAttemptAtMs > 3_000 {
                    self.appendLog("检测到网络恢复，触发自动重试 Install（有间隔）")
                    DispatchQueue.main.async { self.install() }
                }
            }
        }
        monitor.start(queue: pathMonitorQueue)
        appendLog("网络监听已注册")
    }

    private func stopNetworkMonitor() {
        if let m = pathMonitor {
            m.cancel()
            pathMonitor = nil
        }
        appendLog("网络监听已注销")
    }

    // MARK: - 压力回归（open/hide 循环）

    func startStressTest() {
        if stressRunning {
            appendLog("压力回归已在运行")
            return
        }
        stressRunning = true
        stressLoopCount = 0
        stressSuccessCount = 0
        stressFailureCount = 0
        updateStatus("状态：压力回归运行中...")
        appendLog("========== 压力回归开始（open/hide 循环） ==========")
        scheduleNextStressStep()
    }

    func stopStressTest() {
        if !stressRunning {
            appendLog("压力回归未运行")
            return
        }
        stressRunning = false
        appendLog("========== 压力回归停止 loops=\(stressLoopCount) ok=\(stressSuccessCount) fail=\(stressFailureCount) ==========")
        updateStatus("状态：压力回归已停止 loops=\(stressLoopCount) ok=\(stressSuccessCount) fail=\(stressFailureCount)")
    }

    private func scheduleNextStressStep() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if !self.stressRunning { return }
            self.stressLoopCount += 1
            if let top = UIApplication.shared.hbTopViewController() {
                let open = HelpBot.showConversation(from: top)
                if open.isSuccess {
                    self.stressSuccessCount += 1
                } else {
                    self.stressFailureCount += 1
                    self.appendLog("Stress.open fail: \(open.errorMessage ?? "")")
                }
            } else {
                self.stressFailureCount += 1
                self.appendLog("Stress.open fail: 找不到 topViewController")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                if !self.stressRunning { return }
                let hide = HelpBot.hideConversation()
                if !hide.isSuccess {
                    self.stressFailureCount += 1
                    self.appendLog("Stress.hide fail: \(hide.errorMessage ?? "")")
                }
                if self.stressLoopCount % 10 == 0 {
                    self.appendLog("Stress progress: loops=\(self.stressLoopCount) ok=\(self.stressSuccessCount) fail=\(self.stressFailureCount)")
                    DispatchQueue.main.async {
                        self.statusText = "压力回归 loops=\(self.stressLoopCount) ok=\(self.stressSuccessCount) fail=\(self.stressFailureCount)"
                    }
                }
                if self.stressLoopCount >= self.stressMaxLoops {
                    self.stopStressTest()
                    return
                }
                self.scheduleNextStressStep()
            }
        }
    }

    // MARK: - 健康快照 / 报告 / 剪贴板

    func dumpHealthSnapshot() {
        appendLog("========== WebSDK 健康快照 ==========")
        let snapshot = HelpBot.getWebSdkHealthSnapshot()
        appendLog("healthSnapshot=\(snapshot)")
        updateStatus("状态：已读取健康快照（详见日志）")
    }

    func exportReportToClipboard() {
        let report = buildReport()
        UIPasteboard.general.string = report
        appendLog("报告已复制到剪贴板")
        updateStatus("状态：报告已复制到剪贴板")
    }

    func copyLogToClipboard() {
        UIPasteboard.general.string = logText
        appendLog("日志已复制到剪贴板")
    }

    func copyTokenToClipboard() {
        let token = (rawToken ?? tokenInput).trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty {
            appendLog("Token 为空，无法复制")
            return
        }
        UIPasteboard.general.string = token
        appendLog("Token 已复制到剪贴板（未写入日志内容）")
    }

    func refreshTokenMaskedText() {
        let masked = HBlogger.sanitizeValue(tokenInput)
        DispatchQueue.main.async {
            if self.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.tokenMaskedText = "Token：未生成（将以脱敏形式展示）"
            } else {
                self.tokenMaskedText = "Token（脱敏）：\(masked)"
            }
        }
    }

    func clearLog() {
        logLock.lock()
        logBuffer = "日志：\n"
        logLock.unlock()
        DispatchQueue.main.async {
            self.logText = "日志：\n"
        }
    }

    func testReinstallation() {
        appendLog("========== 测试：destroy 后重新安装 ==========")
        updateStatus("状态：开始重新安装测试...")
        HelpBot.destroy { [weak self] _ in
            self?.appendLog("✓ HelpBot.destroy 已调用")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.appendLog("步骤：重新 install")
                self?.install()
            }
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
                        self?.appendLog("NotificationPermission granted=\(granted) err=\(error?.localizedDescription ?? "")")
                    }
                }
            }
        } else {
            // iOS 9 及以下：忽略
        }
    }

    private func appendLog(_ text: String) {
        let line = "[\(Self.nowMs())] \(text)"
        logLock.lock()
        logBuffer.append(line)
        logBuffer.append("\n")
        if logBuffer.count > Self.logMaxChars {
            // 保留后半段，避免 OOM
            let keep = Self.logMaxChars / 2
            let startIndex = logBuffer.index(logBuffer.endIndex, offsetBy: -min(keep, logBuffer.count))
            logBuffer = "[trimmed] 日志过长已裁剪\n" + String(logBuffer[startIndex...])
        }
        let snapshot = logBuffer
        logLock.unlock()
        DispatchQueue.main.async {
            self.logText = snapshot
        }
    }

    private static func nowMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func buildReport() -> String {
        let dev = IOSDevice.shared
        let diagnosis = NetworkUtils.diagnose()
        let health = HelpBot.getWebSdkHealthSnapshot()
        let masked = HBlogger.sanitizeValue(rawToken ?? tokenInput)

        var sb: [String] = []
        sb.append("HelpBot SDK iOS Demo 测试报告")
        sb.append("time=\(Self.nowMs())")
        sb.append("bundleId=\(dev.getBundleId())")
        sb.append("appVersion=\(dev.getAppVersion()) (\(dev.getAppBuildNumber()))")
        sb.append("iOS=\(dev.getOSVersion())")
        sb.append("device=\(dev.getDeviceModel())")
        sb.append("helpBotSdkVersion=\(HelpBot.getSDKVersion())")
        sb.append("initialized=\(HelpBot.isInitialized())")
        sb.append("conversationVisible=\(HelpBot.isConversationVisible())")
        sb.append("tokenMasked=\(masked)")
        sb.append("network.connected=\(diagnosis.networkConnected)")
        sb.append("network.hasInternet=\(diagnosis.hasInternetCapability)")
        sb.append("network.validated=\(diagnosis.validated)")
        sb.append("network.transport=\(diagnosis.transport ?? "")")
        sb.append("websdk.healthSnapshot=\(health)")
        sb.append("")
        sb.append("--- logs ---")
        sb.append(logText)
        return sb.joined(separator: "\n")
    }

    private func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusText = text
        }
    }
}

// MARK: - HelpBotInitCallback

extension HelpBotDemoViewModel: HelpBotInitCallback {
    func onInitStart() {
        appendLog("onInitStart")
    }

    func onInitProgress(_ progress: Int, _ message: String) {
        DispatchQueue.main.async {
            self.statusText = "install \(progress)% - \(message)"
        }
        appendLog("onInitProgress \(progress)% \(message)")
    }

    func onInitSuccess() {
        lastInstallFailedDueToNetwork = false
        DispatchQueue.main.async {
            self.statusText = "install success"
        }
        appendLog("onInitSuccess")
    }

    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
        // 网络相关失败：标记，便于网络恢复时自动重试
        if errorCode == .networkUnavailable || errorCode == .networkTimeout || errorCode == .operationTimeout {
            lastInstallFailedDueToNetwork = true
        }
        DispatchQueue.main.async {
            self.statusText = "install failed: \(errorMessage)"
        }
        appendLog("onInitFailure \(errorCode.rawValue) \(errorMessage)")
    }
}

// MARK: - HelpBotEventsListener

extension HelpBotDemoViewModel: HelpBotEventsListener {
    func onEventOccurred(_ eventName: String, _ data: [String : Any]?) {
        appendLog("event: \(eventName) data=\(data ?? [:])")
    }

    func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason) {
        appendLog("authFailure: \(reason.rawValue)")
    }
}

// MARK: - Logger

final class HelpBotDemoLogger: IHBLogger {
    func d(_ tag: String, _ message: String, _ error: Error?) { print("[D][\(tag)] \(message) \(error?.localizedDescription ?? "")") }
    func w(_ tag: String, _ message: String, _ error: Error?) { print("[W][\(tag)] \(message) \(error?.localizedDescription ?? "")") }
    func e(_ tag: String, _ message: String, _ error: Error?) { print("[E][\(tag)] \(message) \(error?.localizedDescription ?? "")") }
}

/**
 负向用例专用 install 回调（避免污染主 ViewModel 状态机）。
 */
private final class NegativeInstallCallback: HelpBotInitCallback {
    private let onDone: (HelpBotErrorCode, String) -> Void

    init(onDone: @escaping (HelpBotErrorCode, String) -> Void) {
        self.onDone = onDone
    }

    func onInitStart() {}
    func onInitProgress(_ progress: Int, _ message: String) {}
    func onInitSuccess() {}
    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
        onDone(errorCode, errorMessage)
    }
}


