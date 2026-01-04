import Foundation

/**
 HelpBot 日志包装器（iOS）。
 
 与 Android HelpBotLogger.java 对齐。
 提供额外的日志功能和格式化。
 */
public final class HelpBotLogger {
    
    private static var customLogger: IHBLogger?
    
    /**
     设置自定义日志实现
     
     - Parameter logger: 自定义日志实现
     */
    public static func setLogger(_ logger: IHBLogger?) {
        customLogger = logger
        HBlogger.initLoggerIfAbsent(logger)
    }
    
    /**
     记录调试日志
     
     - Parameters:
        - tag: 标签
        - message: 消息
     */
    public static func debug(_ tag: String, _ message: String) {
        HBlogger.d(tag, message)
    }
    
    /**
     记录信息日志
     
     - Parameters:
        - tag: 标签
        - message: 消息
     */
    public static func info(_ tag: String, _ message: String) {
        HBlogger.i(tag, message)
    }
    
    /**
     记录警告日志
     
     - Parameters:
        - tag: 标签
        - message: 消息
     */
    public static func warning(_ tag: String, _ message: String) {
        HBlogger.w(tag, message)
    }
    
    /**
     记录错误日志
     
     - Parameters:
        - tag: 标签
        - message: 消息
     */
    public static func error(_ tag: String, _ message: String) {
        HBlogger.e(tag, message)
    }
    
    /**
     记录错误日志（带异常）
     
     - Parameters:
        - tag: 标签
        - message: 消息
        - error: 错误对象
     */
    public static func error(_ tag: String, _ message: String, _ error: Error) {
        HBlogger.e(tag, "\(message): \(error.localizedDescription)")
    }
    
    /**
     格式化日志消息
     
     - Parameters:
        - format: 格式字符串
        - args: 参数
     - Returns: 格式化后的字符串
     */
    public static func format(_ format: String, _ args: CVarArg...) -> String {
        return String(format: format, arguments: args)
    }
    
    /**
     记录方法调用
     
     - Parameters:
        - tag: 标签
        - methodName: 方法名
        - parameters: 参数字典
     */
    public static func logMethodCall(_ tag: String, _ methodName: String, parameters: [String: Any]? = nil) {
        var message = "[\(methodName)]"
        if let params = parameters, !params.isEmpty {
            message += " params: \(params)"
        }
        HBlogger.d(tag, message)
    }
    
    /**
     记录方法返回
     
     - Parameters:
        - tag: 标签
        - methodName: 方法名
        - result: 返回值
     */
    public static func logMethodReturn(_ tag: String, _ methodName: String, result: Any? = nil) {
        var message = "[\(methodName)] return"
        if let res = result {
            message += ": \(res)"
        }
        HBlogger.d(tag, message)
    }
    
    private init() {
        fatalError("HelpBotLogger 不能被实例化")
    }
}
