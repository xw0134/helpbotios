import Foundation

/**
 通用工具函数（iOS）。
 
 与 Android Utils.java 对齐。
 */
public final class Utils {
    
    /**
     检查字符串是否为空（nil 或空字符串或仅包含空白字符）
     
     - Parameter string: 要检查的字符串
     - Returns: 是否为空
     */
    public static func isEmpty(_ string: String?) -> Bool {
        guard let str = string else { return true }
        return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /**
     检查数组是否为空
     
     - Parameter array: 要检查的数组
     - Returns: 是否为空
     */
    public static func isEmpty<T>(_ array: [T]?) -> Bool {
        guard let arr = array else { return true }
        return arr.isEmpty
    }
    
    /**
     检查字典是否为空
     
     - Parameter dictionary: 要检查的字典
     - Returns: 是否为空
     */
    public static func isEmpty<K, V>(_ dictionary: [K: V]?) -> Bool {
        guard let dict = dictionary else { return true }
        return dict.isEmpty
    }
    
    /**
     安全地从字典中获取字符串值
     
     - Parameters:
        - dictionary: 字典
        - key: 键
        - defaultValue: 默认值
     - Returns: 字符串值
     */
    public static func getString(_ dictionary: [String: Any]?, key: String, defaultValue: String = "") -> String {
        guard let dict = dictionary, let value = dict[key] else {
            return defaultValue
        }
        if let str = value as? String {
            return str
        }
        return String(describing: value)
    }
    
    /**
     安全地从字典中获取整数值
     
     - Parameters:
        - dictionary: 字典
        - key: 键
        - defaultValue: 默认值
     - Returns: 整数值
     */
    public static func getInt(_ dictionary: [String: Any]?, key: String, defaultValue: Int = 0) -> Int {
        guard let dict = dictionary, let value = dict[key] else {
            return defaultValue
        }
        if let intValue = value as? Int {
            return intValue
        }
        if let strValue = value as? String, let intValue = Int(strValue) {
            return intValue
        }
        return defaultValue
    }
    
    /**
     安全地从字典中获取布尔值
     
     - Parameters:
        - dictionary: 字典
        - key: 键
        - defaultValue: 默认值
     - Returns: 布尔值
     */
    public static func getBool(_ dictionary: [String: Any]?, key: String, defaultValue: Bool = false) -> Bool {
        guard let dict = dictionary, let value = dict[key] else {
            return defaultValue
        }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let intValue = value as? Int {
            return intValue != 0
        }
        if let strValue = value as? String {
            let trimmed = strValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed == "true" || trimmed == "1" || trimmed == "yes"
        }
        return defaultValue
    }
    
    /**
     生成 UUID 字符串
     
     - Returns: UUID 字符串
     */
    public static func generateUUID() -> String {
        return UUID().uuidString
    }
    
    /**
     获取当前时间戳（毫秒）
     
     - Returns: 时间戳（毫秒）
     */
    public static func currentTimeMillis() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    /**
     延迟执行
     
     - Parameters:
        - delay: 延迟时间（秒）
        - block: 要执行的代码块
     */
    public static func delay(_ delay: TimeInterval, block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            block()
        }
    }
    
    /**
     URL 编码
     
     - Parameter string: 要编码的字符串
     - Returns: 编码后的字符串
     */
    public static func urlEncode(_ string: String) -> String? {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    /**
     URL 解码
     
     - Parameter string: 要解码的字符串
     - Returns: 解码后的字符串
     */
    public static func urlDecode(_ string: String) -> String? {
        return string.removingPercentEncoding
    }
    
    private init() {
        fatalError("Utils 不能被实例化")
    }
}
