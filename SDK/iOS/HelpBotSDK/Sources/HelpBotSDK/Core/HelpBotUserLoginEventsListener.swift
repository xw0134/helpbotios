import Foundation

/**
 HelpBot 用户登录事件监听器（iOS）。
 

 用于监听用户登录相关的事件。
 */
public protocol HelpBotUserLoginEventsListener: AnyObject {
    
    /**
     用户登录成功回调
     */
    func onUserLoginSuccess()
    
    /**
     用户登录失败回调
     
     - Parameters:
        - reason: 失败原因
     */
    func onUserLoginFailure(_ reason: HelpBotAuthenticationFailureReason)
    
    /**
     用户登出回调
     */
    func onUserLogout()
}
