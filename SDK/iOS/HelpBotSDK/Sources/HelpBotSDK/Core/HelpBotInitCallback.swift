import Foundation

/**
 HelpBot SDK 初始化回调接口（iOS）。
 */
public protocol HelpBotInitCallback: AnyObject {
    /// 初始化开始
    func onInitStart()

    /// 初始化进度更新
    /// - Parameters:
    ///   - progress: 进度百分比 (0-100)
    ///   - message: 当前步骤描述
    func onInitProgress(_ progress: Int, _ message: String)

    /// 初始化成功
    func onInitSuccess()

    /// 初始化失败
    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String)
}


