import Foundation
import UIKit
import HelpBotSDK

final class HelpBotDemoViewModel: NSObject, ObservableObject {
    @Published var channelId: String = "demo_channel"
    @Published var domain: String = "https://api.example.com"
    @Published var token: String = ""

    @Published var statusText: String = "未初始化"
    @Published var logs: [String] = []

    private let logger = HelpBotDemoLogger()

    override init() {
        super.init()
        HelpBot.initLogger(logger)
        HelpBot.setEventsListener(self)
    }

    func install() {
        appendLog("install 开始")
        statusText = "installing..."
        let configMap: [String: Any] = [
            "fullPrivacyMode": false,
            "showTitleBar": true
        ]
        HelpBot.install(channelId: channelId, domain: domain, configMap: configMap, callback: self)
    }

    func login() {
        appendLog("login 开始")
        statusText = "loggingIn..."
        HelpBot.login(token) { [weak self] result in
            guard let self else { return }
            if result.isSuccess {
                self.statusText = "login success"
                self.appendLog("login success")
            } else {
                self.statusText = "login failed: \(result.errorMessage ?? "")"
                self.appendLog("login failed: \(result.errorCode?.rawValue ?? -1) \(result.errorMessage ?? "")")
            }
        }
    }

    func showConversation() {
        guard let top = UIApplication.shared.hbTopViewController() else {
            appendLog("showConversation 失败：找不到 topViewController")
            return
        }
        let r = HelpBot.showConversation(from: top)
        appendLog("showConversation: \(r.isSuccess ? "success" : "fail") \(r.errorMessage ?? "")")
    }

    func hideConversation() {
        _ = HelpBot.hideConversation()
        appendLog("hideConversation")
    }

    func logout() {
        HelpBot.logout { [weak self] result in
            self?.appendLog("logout: \(result.isSuccess ? "success" : "fail")")
            self?.statusText = "logout"
        }
    }

    private func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.logs.insert("[\(Self.formatNow())] \(text)", at: 0)
            if self.logs.count > 80 { self.logs.removeLast(self.logs.count - 80) }
        }
    }

    private static func formatNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
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
        DispatchQueue.main.async {
            self.statusText = "install success"
        }
        appendLog("onInitSuccess")
    }

    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
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


