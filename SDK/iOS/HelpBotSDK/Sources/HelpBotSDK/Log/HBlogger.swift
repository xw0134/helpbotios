import Foundation

/**
 HelpBot 统一日志实现（iOS）。
 
 功能：
 - 支持自定义日志接口 (IHBLogger)
 - 线程安全
 - 安全：默认仅在 DEBUG 构建允许输出；Release 一律不输出（避免线上泄露敏感信息/影响宿主日志策略）
 - 安全：自动脱敏敏感字段（Token/JWT/Authorization/密码/APIKey/Secret等）
 */
public final class HBlogger {
    
    private static let lock = NSLock()
    private static var customLogger: IHBLogger?
    
    /// 发布版本禁止日志输出（与 Android 策略对齐）
    private static let sdkLoggingAllowed: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    // MARK: - Sensitive data sanitization

    /// 敏感字段正则
    private static let tokenPattern = try? NSRegularExpression(
        pattern: "(token|jwt|bearer|authorization)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)",
        options: [.caseInsensitive]
    )
    private static let passwordPattern = try? NSRegularExpression(
        pattern: "(password|passwd|pwd)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)",
        options: [.caseInsensitive]
    )
    private static let keyPattern = try? NSRegularExpression(
        pattern: "(api[_-]?key|secret|private[_-]?key)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)",
        options: [.caseInsensitive]
    )
    
    /**
     初始化日志记录器（如果尚未初始化）
     
     - Parameter logger: 自定义日志实现
     */
    public static func initLoggerIfAbsent(_ logger: IHBLogger?) {
        lock.lock()
        defer { lock.unlock() }
        if customLogger == nil {
            customLogger = logger
        }
    }

    /**
     判断是否已初始化 Logger（SDK 不应强行覆盖宿主 Logger）。
     */
    public static func isInitialized() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return customLogger != nil
    }
    
    /**
     记录调试日志
     
     - Parameters:
        - tag: 标签
        - msg: 消息
     */
    public static func d(_ tag: String, _ msg: String, _ error: Error? = nil) {
        log(tag: tag, msg: msg, error: error, level: "DEBUG")
    }
    
    /**
     记录信息日志（iOS 侧为兼容历史 API 保留，实际等价于 DEBUG）。

     说明：Android 侧无 INFO 级别。
     */
    public static func i(_ tag: String, _ msg: String, _ error: Error? = nil) {
        d(tag, msg, error)
    }
    
    /**
     记录警告日志
     
     - Parameters:
        - tag: 标签
        - msg: 消息
     */
    public static func w(_ tag: String, _ msg: String, _ error: Error? = nil) {
        log(tag: tag, msg: msg, error: error, level: "WARN")
    }
    
    /**
     记录错误日志
     
     - Parameters:
        - tag: 标签
        - msg: 消息
     */
    public static func e(_ tag: String, _ msg: String, _ error: Error? = nil) {
        log(tag: tag, msg: msg, error: error, level: "ERROR")
    }
    
    /**
     内部日志实现
     */
    private static func log(tag: String, msg: String, error: Error?, level: String) {
        // 与 Android 策略一致：Release 一律不输出
        if !sdkLoggingAllowed {
            return
        }

        lock.lock()
        let logger = customLogger
        lock.unlock()

        // 与 Android 策略一致：未注入 logger 不输出（SDK 不接管宿主日志系统）
        guard let logger = logger else {
            return
        }

        // 统一做脱敏
        let safeMsg = sanitize(msg)

        // 统一走宿主 logger（SDK 内不 print/NSLog，避免泄露/扰动宿主策略）
        switch level {
        case "DEBUG":
            logger.d(tag, safeMsg, error)
        case "WARN":
            logger.w(tag, safeMsg, error)
        case "ERROR":
            logger.e(tag, safeMsg, error)
        default:
            logger.d(tag, safeMsg, error)
        }
    }

    /**
     日志脱敏处理
     */
    private static func sanitize(_ message: String) -> String {
        if message.isEmpty {
            return message
        }
        var sanitized = message
        let fullRange = NSRange(location: 0, length: (sanitized as NSString).length)

        // token/jwt/bearer/authorization
        if let re = tokenPattern {
            sanitized = re.stringByReplacingMatches(in: sanitized, options: [], range: fullRange, withTemplate: "$1=***已脱敏***")
        }
        // password
        if let re = passwordPattern {
            sanitized = re.stringByReplacingMatches(in: sanitized, options: [], range: NSRange(location: 0, length: (sanitized as NSString).length), withTemplate: "$1=***已脱敏***")
        }
        // api key / secret / private key
        if let re = keyPattern {
            sanitized = re.stringByReplacingMatches(in: sanitized, options: [], range: NSRange(location: 0, length: (sanitized as NSString).length), withTemplate: "$1=***已脱敏***")
        }
        return sanitized
    }

    /**
     显式脱敏单个值（保留前 4 位与后 4 位）。
     */
    public static func sanitizeValue(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "***" }
        if value.count <= 8 { return "***" }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)***\(suffix)"
    }
    
    private init() {
        fatalError("HBlogger 不能被实例化")
    }
}
