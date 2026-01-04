import Foundation

/**
 HelpBot 统一日志协议（由宿主注入）。

 - 注意：SDK 作为依赖库，不应强行接管宿主日志系统。
 - 安全：HBlogger 会对敏感字段做脱敏处理，且默认仅在 DEBUG 构建允许输出。
 */
public protocol IHBLogger: AnyObject {
    func d(_ tag: String, _ message: String, _ error: Error?)
    func w(_ tag: String, _ message: String, _ error: Error?)
    func e(_ tag: String, _ message: String, _ error: Error?)
}


