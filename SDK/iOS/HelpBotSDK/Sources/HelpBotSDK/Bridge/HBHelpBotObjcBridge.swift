import Foundation
import UIKit

/**
 Objective-C 兼容桥接层（iOS）。
 
 目的：
 - 让 Unity / Unreal / Cocos2d 等非 Swift 宿主能直接调用 `SDK/iOS/HelpBotSDK` 的能力
 - 避免各引擎平台重复实现一套 iOS 逻辑（SDK 标准化）
 
 设计说明：
 - 仅暴露 ObjC 友好的 API（String/Int/Bool/NSDictionary/NSArray + block 回调）
 - 所有对外入口均 try-catch（Swift: do/catch）并保证回调一定执行（可选）
 - UI 相关操作统一使用 `ApplicationUtils.getTopViewController()`，避免宿主显式传 VC
 */
@objcMembers
public final class HBHelpBotObjcBridge: NSObject {
    private static let tag = "HBHelpBotObjcBridge"
    private static let queue = DispatchQueue(label: "com.helpbot.sdk.objcbridge.lock")
    private static var eventsListener: _HBObjcEventsListener?

    // MARK: - Helpers

    private static func topViewController() -> UIViewController? {
        return ApplicationUtils.getTopViewController()
    }

    private static func parseJsonDict(_ json: String?) -> [String: Any] {
        guard let json, !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        return HelpBotJsonUtils.toDictionary(json) ?? [:]
    }

    private static func parseJsonArray(_ json: String?) -> [Any] {
        guard let json, !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return HelpBotJsonUtils.toArray(json) ?? []
    }

    private static func okCallback(_ callback: ((Bool, Int, String?) -> Void)?) {
        callback?(true, 0, nil)
    }

    private static func failCallback(_ callback: ((Bool, Int, String?) -> Void)?, _ code: HelpBotErrorCode, _ msg: String?) {
        callback?(false, code.rawValue, (msg == nil || msg!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? code.message : msg)
    }

    private static func mapResultVoid(_ result: HelpBotResult<Void>) -> (Bool, Int, String?) {
        if result.isSuccess {
            return (true, 0, nil)
        }
        return (false, result.errorCode?.rawValue ?? HelpBotErrorCode.internalError.rawValue, result.errorMessage)
    }

    // MARK: - Public APIs (ObjC)

    /// install（configJson: {"channelId":"...","domain":"https://...","fullPrivacyMode":true,...}）
    @objc(installWithConfigJson:callback:)
    public static func install(configJson: String, callback: ((Bool, Int, String?) -> Void)?) {
        let cfg = parseJsonDict(configJson)
        let channelId = (cfg["channelId"] as? String) ?? ""
        let domain = (cfg["domain"] as? String) ?? ""
        if channelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failCallback(callback, .invalidChannelId, "channelId 不能为空")
            return
        }
        if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failCallback(callback, .invalidDomain, "domain 不能为空")
            return
        }

        HelpBot.install(channelId: channelId, domain: domain, configMap: cfg, callback: _HBInitCallbackProxy { ok, code, msg in
            callback?(ok, code, msg)
        })
    }

    /// login（loginConfigJson 可选：{"xxx":...}）
    @objc(loginWithToken:loginConfigJson:callback:)
    public static func login(token: String, loginConfigJson: String?, callback: ((Bool, Int, String?) -> Void)?) {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            failCallback(callback, .invalidToken, "Token 不能为空")
            return
        }

        // iOS SDK 当前 login 不支持额外 loginConfig（对齐 Android 可扩展），这里先做兼容：
        // - 若宿主传入 loginConfigJson，仅作为扩展字段保留（不影响登录核心流程）
        // - 后续如需对齐，可在 HelpBot.login 内部消费该字段
        _ = parseJsonDict(loginConfigJson)

        HelpBot.login(t) { result in
            let mapped = mapResultVoid(result)
            callback?(mapped.0, mapped.1, mapped.2)
        }
    }

    /// showConversation：自动取 topVC
    @objc(showConversation)
    public static func showConversation() -> Bool {
        guard let vc = topViewController() else { return false }
        let r = HelpBot.showConversation(from: vc)
        return r.isSuccess
    }

    @objc(hideConversation)
    public static func hideConversation() -> Bool {
        return HelpBot.hideConversation().isSuccess
    }

    @objc(logoutWithCallback:)
    public static func logout(callback: ((Bool, Int, String?) -> Void)?) {
        HelpBot.logout { result in
            let mapped = mapResultVoid(result)
            callback?(mapped.0, mapped.1, mapped.2)
        }
    }

    @objc(destroyWithCallback:)
    public static func destroy(callback: ((Bool, Int, String?) -> Void)?) {
        HelpBot.destroy { result in
            let mapped = mapResultVoid(result)
            callback?(mapped.0, mapped.1, mapped.2)
        }
    }

    @objc(closeSession)
    public static func closeSession() -> Bool {
        return HelpBot.closeSession().isSuccess
    }

    // MARK: - FAQ

    @objc(showFAQsWithConfigJson:)
    public static func showFAQs(configJson: String?) -> Bool {
        guard let vc = topViewController() else { return false }
        let cfg = parseJsonDict(configJson)
        return HelpBot.showFAQs(from: vc, config: cfg).isSuccess
    }

    @objc(showFAQSection:configJson:)
    public static func showFAQSection(sectionPublishId: String, configJson: String?) -> Bool {
        guard let vc = topViewController() else { return false }
        let cfg = parseJsonDict(configJson)
        return HelpBot.showFAQSection(from: vc, sectionPublishId: sectionPublishId, config: cfg).isSuccess
    }

    @objc(showSingleFAQ:configJson:)
    public static func showSingleFAQ(questionPublishId: String, configJson: String?) -> Bool {
        guard let vc = topViewController() else { return false }
        let cfg = parseJsonDict(configJson)
        return HelpBot.showSingleFAQ(from: vc, questionPublishId: questionPublishId, config: cfg).isSuccess
    }

    // MARK: - Meta / Tags

    @objc(updateSDKMetaWithJson:)
    public static func updateSDKMeta(metaJson: String?) -> Bool {
        let meta = parseJsonDict(metaJson)
        return HelpBot.updateSDKMeta(meta).isSuccess
    }

    @objc(updateCustomMetaWithJson:)
    public static func updateCustomMeta(metaJson: String?) -> Bool {
        let meta = parseJsonDict(metaJson)
        return HelpBot.updateCustomMeta(meta).isSuccess
    }

    @objc(addIssueTagsWithJson:)
    public static func addIssueTags(tagsJson: String?) -> Bool {
        let arr = parseJsonArray(tagsJson).compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return HelpBot.addIssueTags(arr).isSuccess
    }

    @objc(removeIssueTagsWithJson:)
    public static func removeIssueTags(tagsJson: String?) -> Bool {
        let arr = parseJsonArray(tagsJson).compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return HelpBot.removeIssueTags(arr).isSuccess
    }

    // MARK: - Messages

    @objc(sendMessage:callback:)
    public static func sendMessage(message: String, callback: ((Bool, Int, String?, String?) -> Void)?) {
        HelpBot.sendMessageAsync(message) { result in
            switch result {
            case .success(let data):
                let json = HelpBotJsonUtils.toJsonString(data) ?? "{}"
                callback?(true, 0, nil, json)
            case .failure(let code, let msg):
                callback?(false, code.rawValue, msg, nil)
            }
        }
    }

    @objc(getHistoryMessagesWithCallback:)
    public static func getHistoryMessages(callback: ((Bool, Int, String?, String?) -> Void)?) {
        HelpBot.getHistoryMessagesAsync { result in
            switch result {
            case .success(let data):
                let json = HelpBotJsonUtils.toJsonString(data) ?? "{}"
                callback?(true, 0, nil, json)
            case .failure(let code, let msg):
                callback?(false, code.rawValue, msg, nil)
            }
        }
    }

    @objc(loadMoreMessagesWithLimit:offset:callback:)
    public static func loadMoreMessages(limit: Int, offset: Int, callback: ((Bool, Int, String?, String?) -> Void)?) {
        HelpBot.loadMoreMessagesAsync(limit: limit, offset: offset) { result in
            switch result {
            case .success(let data):
                let json = HelpBotJsonUtils.toJsonString(data) ?? "{}"
                callback?(true, 0, nil, json)
            case .failure(let code, let msg):
                callback?(false, code.rawValue, msg, nil)
            }
        }
    }

    // MARK: - SSE / State / Diagnostics

    @objc(enableSseNotification:)
    public static func enableSseNotification(enable: Bool) {
        HelpBot.enableSseNotification(enable)
    }

    @objc(isSseNotificationEnabled)
    public static func isSseNotificationEnabled() -> Bool {
        return HelpBot.isSseNotificationEnabled()
    }

    @objc(isDebugMode)
    public static func isDebugMode() -> Bool {
        return ApplicationUtils.isApplicationInDebugMode()
    }

    @objc(isInitialized)
    public static func isInitialized() -> Bool {
        return HelpBot.isInitialized()
    }

    @objc(isConversationVisible)
    public static func isConversationVisible() -> Bool {
        return HelpBot.isConversationVisible()
    }

    @objc(getSdkVersion)
    public static func getSdkVersion() -> String {
        return HelpBot.getSDKVersion()
    }

    @objc(getWebSdkHealthSnapshotJson)
    public static func getWebSdkHealthSnapshotJson() -> String {
        let data = HelpBot.getWebSdkHealthSnapshot()
        return HelpBotJsonUtils.toJsonString(data) ?? "{}"
    }

    @objc(reportSystemInfoToServer)
    public static func reportSystemInfoToServer() -> Bool {
        return HelpBot.reportSystemInfoToServer().isSuccess
    }

    // MARK: - Events Listener

    @objc(setEventsListenerWithEventCallback:authFailureCallback:)
    public static func setEventsListener(
        eventCallback: @escaping (String, String) -> Void,
        authFailureCallback: @escaping (String) -> Void
    ) {
        queue.sync {
            let listener = _HBObjcEventsListener(
                onEvent: { name, data in
                    let json = (data == nil) ? "{}" : (HelpBotJsonUtils.toJsonString(data!) ?? "{}")
                    DispatchQueue.main.async {
                        eventCallback(name, json)
                    }
                },
                onAuthFailure: { reason in
                    DispatchQueue.main.async {
                        authFailureCallback(reason.rawValue)
                    }
                }
            )
            eventsListener = listener
            HelpBot.setEventsListener(listener)
        }
    }

    @objc(clearEventsListener)
    public static func clearEventsListener() {
        queue.sync {
            eventsListener = nil
            HelpBot.setEventsListener(nil)
        }
    }
}

// MARK: - Internal proxies

private final class _HBInitCallbackProxy: HelpBotInitCallback {
    private let completion: (Bool, Int, String?) -> Void

    init(_ completion: @escaping (Bool, Int, String?) -> Void) {
        self.completion = completion
    }

    func onInitStart() {
        // Unity/UE 侧不需要逐步进度时可忽略；保留以对齐 SDK 语义
    }

    func onInitProgress(_ progress: Int, _ message: String) {
        // 透传进度给宿主需要额外协议；这里先不做（避免改变现有桥接协议）
    }

    func onInitSuccess() {
        completion(true, 0, nil)
    }

    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
        completion(false, errorCode.rawValue, errorMessage)
    }
}

private final class _HBObjcEventsListener: HelpBotEventsListener {
    private let onEvent: (String, [String: Any]?) -> Void
    private let onAuthFailure: (HelpBotAuthenticationFailureReason) -> Void

    init(
        onEvent: @escaping (String, [String: Any]?) -> Void,
        onAuthFailure: @escaping (HelpBotAuthenticationFailureReason) -> Void
    ) {
        self.onEvent = onEvent
        self.onAuthFailure = onAuthFailure
    }

    func onEventOccurred(_ eventName: String, _ data: [String : Any]?) {
        onEvent(eventName, data)
    }

    func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason) {
        onAuthFailure(reason)
    }
}


