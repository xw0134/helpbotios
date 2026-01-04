import Foundation

/**
 HelpBot 事件监听器（事件驱动）。
 */
public protocol HelpBotEventsListener: AnyObject {
    /// Web -> Native：事件透传（例如 SDK_READY / SDK_ERROR / WIDGET_TOGGLE / MESSAGE_ADD 等）
    func onEventOccurred(_ eventName: String, _ data: [String: Any]?)

    /// Web -> Native：认证失败（单独回调，方便宿主统一处理 token 刷新/重新登录）
    func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason)
}


