import Foundation

/**
 HelpBot SDK 通用结果封装（iOS）。
 */
public struct HelpBotResult<T> {
    public let data: T?
    public let errorCode: HelpBotErrorCode?
    public let errorMessage: String?

    public var isSuccess: Bool { errorCode == nil }

    public static func success(_ data: T? = nil) -> HelpBotResult<T> {
        return HelpBotResult<T>(data: data, errorCode: nil, errorMessage: nil)
    }

    public static func failure(_ code: HelpBotErrorCode, _ message: String? = nil) -> HelpBotResult<T> {
        return HelpBotResult<T>(data: nil, errorCode: code, errorMessage: message ?? code.message)
    }
}

/**
 HelpBot SDK 异步回调。
 */
public protocol HelpBotCallback: AnyObject {
    associatedtype T
    func onSuccess(_ result: T?)
    func onFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String)
}


