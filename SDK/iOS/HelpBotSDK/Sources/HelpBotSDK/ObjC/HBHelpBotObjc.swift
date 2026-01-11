import Foundation
import UIKit

/**
 HelpBotSDK 的 Objective-C 友好封装（大厂 SDK 交付标准）。
 
 设计目标：
 - **宿主是 Objective-C 也能直接接入**（不需要写 Swift）。
 - 对外接口稳定：尽量使用 `NSString/NSDictionary/NSNumber/UIViewController` 等 ObjC 兼容类型。
 - 保持与 Swift API 一致：内部调用 `HelpBot` 的 Swift API。
 
 注意：
 - 该类属于 SDK 的对外公开 API，会出现在 `HelpBotSDK-Swift.h` 中。
 */
@objcMembers
public final class HBHelpBot: NSObject {
    private static let tag = "HBHelpBot"

    private override init() {
        super.init()
    }

    // MARK: - Types

    /**
     Objective-C 初始化回调（可选实现）。
     */
    @objc(HBHelpBotInitDelegate)
    public protocol InitDelegate: NSObjectProtocol {
        @objc optional func onInitStart()
        @objc optional func onInitProgress(_ progress: Int, message: String)
        @objc optional func onInitSuccess()
        @objc optional func onInitFailure(_ errorCode: Int, message: String)
    }

    /**
     Objective-C 事件监听（可选实现）。
     */
    @objc(HBHelpBotEventsDelegate)
    public protocol EventsDelegate: NSObjectProtocol {
        /// Web -> Native 事件透传
        @objc optional func onEventOccurred(_ eventName: String, data: NSDictionary?)
        /// 认证失败原因（原始字符串枚举值，例如 "TOKEN_EXPIRED"）
        @objc optional func onUserAuthenticationFailure(_ reason: String)
    }

    /**
     Objective-C 结果对象（避免泛型，便于 ObjC 使用）。
     */
    @objc(HBHelpBotResult)
    public final class Result: NSObject {
        @objc public let success: Bool
        @objc public let errorCode: Int
        @objc public let errorMessage: String?

        @objc public init(success: Bool, errorCode: Int, errorMessage: String?) {
            self.success = success
            self.errorCode = errorCode
            self.errorMessage = errorMessage
            super.init()
        }
    }

    // MARK: - Internal adapters

    private final class InitCallbackAdapter: HelpBotInitCallback {
        weak var delegate: InitDelegate?

        init(delegate: InitDelegate?) {
            self.delegate = delegate
        }

        func onInitStart() {
            delegate?.onInitStart?()
        }

        func onInitProgress(_ progress: Int, _ message: String) {
            delegate?.onInitProgress?(progress, message: message)
        }

        func onInitSuccess() {
            delegate?.onInitSuccess?()
        }

        func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
            delegate?.onInitFailure?(errorCode.rawValue, message: errorMessage)
        }
    }

    private final class EventsListenerAdapter: HelpBotEventsListener {
        weak var delegate: EventsDelegate?

        init(delegate: EventsDelegate?) {
            self.delegate = delegate
        }

        func onEventOccurred(_ eventName: String, _ data: [String: Any]?) {
            delegate?.onEventOccurred?(eventName, data: data as NSDictionary?)
        }

        func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason) {
            delegate?.onUserAuthenticationFailure?(reason.rawValue)
        }
    }

    // MARK: - Public APIs (ObjC)

    /**
     获取 SDK 版本号。
     */
    @objc public static func sdkVersion() -> String {
        return HelpBot.getSDKVersion()
    }

    /**
     设置事件监听（ObjC）。
     
     - 说明：底层仍为 Swift `HelpBotEventsListener`，这里做适配。
     - 参数传 nil 表示移除监听。
     */
    @objc public static func setEventsDelegate(_ delegate: EventsDelegate?) {
        if let d = delegate {
            HelpBot.setEventsListener(EventsListenerAdapter(delegate: d))
        } else {
            HelpBot.setEventsListener(nil)
        }
    }

    /**
     初始化 SDK（ObjC 友好版本）。
     - Parameters:
       - channelId: 渠道标识
       - domain: API 域名（建议 https）
       - configMap: 配置字典（可传 nil）
       - delegate: 初始化回调（可传 nil）
     */
    @objc public static func install(
        channelId: String,
        domain: String,
        configMap: NSDictionary?,
        delegate: InitDelegate?
    ) {
        do {
            let swiftMap = configMap as? [String: Any]
            let cb = InitCallbackAdapter(delegate: delegate)
            HelpBot.install(channelId: channelId, domain: domain, configMap: swiftMap, callback: cb)
        } catch {
            // Swift 的 install 本身已做 try-catch，这里再兜底一次，保证 ObjC 不崩溃。
            HBlogger.e(tag, "install 异常: \(error.localizedDescription)", nil)
            delegate?.onInitFailure?(HelpBotErrorCode.internalError.rawValue, message: "install 异常: \(error.localizedDescription)")
        }
    }

    /**
     登录（ObjC 友好版本）。
     - Parameters:
       - token: JWT token
       - completion: 完成回调（可传 nil）
     */
    @objc public static func login(_ token: String, completion: ((Result) -> Void)?) {
        HelpBot.login(token) { r in
            if r.isSuccess {
                completion?(Result(success: true, errorCode: 0, errorMessage: nil))
            } else {
                completion?(Result(success: false, errorCode: r.errorCode?.rawValue ?? HelpBotErrorCode.unknownError.rawValue, errorMessage: r.errorMessage))
            }
        }
    }

    /**
     打开会话窗口（ObjC 友好版本）。
     */
    @objc public static func showConversation(from viewController: UIViewController) {
        HelpBot.showConversation(from: viewController)
    }

    /**
     隐藏会话窗口（ObjC 友好版本）。
     */
    @objc public static func hideConversation() {
        HelpBot.hideConversation()
    }

    /**
     退出登录（ObjC 友好版本）。
     */
    @objc public static func logout(_ completion: ((Result) -> Void)?) {
        HelpBot.logout { r in
            if r.isSuccess {
                completion?(Result(success: true, errorCode: 0, errorMessage: nil))
            } else {
                completion?(Result(success: false, errorCode: r.errorCode?.rawValue ?? HelpBotErrorCode.unknownError.rawValue, errorMessage: r.errorMessage))
            }
        }
    }

    /**
     销毁 SDK（ObjC 友好版本）。
     */
    @objc public static func destroy(_ completion: ((Result) -> Void)?) {
        HelpBot.destroy { r in
            if r.isSuccess {
                completion?(Result(success: true, errorCode: 0, errorMessage: nil))
            } else {
                completion?(Result(success: false, errorCode: r.errorCode?.rawValue ?? HelpBotErrorCode.unknownError.rawValue, errorMessage: r.errorMessage))
            }
        }
    }

    /**
     上报系统信息到服务器（ObjC 友好版本）。
     */
    @objc public static func reportSystemInfoToServer() -> Result {
        let r = HelpBot.reportSystemInfoToServer()
        if r.isSuccess {
            return Result(success: true, errorCode: 0, errorMessage: nil)
        }
        return Result(success: false, errorCode: r.errorCode?.rawValue ?? HelpBotErrorCode.unknownError.rawValue, errorMessage: r.errorMessage)
    }
}

