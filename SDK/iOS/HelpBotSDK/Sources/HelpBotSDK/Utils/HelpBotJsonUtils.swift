import Foundation

/**
 HelpBot JSON 工具类（iOS）。
 
 与 Android JsonUtils.java 对齐。
 增强功能：
 - 支持更多类型的安全的 JSON 序列化
 - 支持安全的 JSON 反序列化
 - 增加 map/list 的相互转换辅助
 */
public final class HelpBotJsonUtils {
    
    private static let tag = "HelpBotJsonUtils"
    
    /**
     对象转 JSON 字符串
     
     - Parameter object: 要转换的对象（Array 或 Dictionary）
     - Returns: JSON 字符串，失败返回 nil
     */
    public static func toJsonString(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else {
            HBlogger.e(tag, "无效的 JSON 对象")
            return nil
        }
        
        do {
            // iOS 12兼容：不使用 withoutEscapingSlashes，因为它在 iOS 13+ 才可用
            // 为了安全，默认使用最基本的序列化
            let data = try JSONSerialization.data(withJSONObject: object, options: [])
            return String(data: data, encoding: .utf8)
        } catch {
            HBlogger.e(tag, "JSON 序列化失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     JSON 字符串转字典
     
     - Parameter jsonString: JSON 字符串
     - Returns: 字典，失败返回 nil
     */
    public static func toDictionary(_ jsonString: String?) -> [String: Any]? {
        guard let json = jsonString, !json.isEmpty,
              let data = json.data(using: .utf8) else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            HBlogger.e(tag, "JSON 转字典失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     JSON 字符串转数组
     
     - Parameter jsonString: JSON 字符串
     - Returns: 数组，失败返回 nil
     */
    public static func toArray(_ jsonString: String?) -> [Any]? {
        guard let json = jsonString, !json.isEmpty,
              let data = json.data(using: .utf8) else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [Any]
        } catch {
            HBlogger.e(tag, "JSON 转数组失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     字典转模型（Codable）
     
     - Parameters:
        - dictionary: 字典
        - type: 模型类型
     - Returns: 模型对象
     */
    public static func dictionaryToModel<T: Codable>(_ dictionary: [String: Any], type: T.Type) -> T? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return try JSONDecoder().decode(type, from: data)
        } catch {
            HBlogger.e(tag, "字典转模型失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     模型转字典（Codable）
     
     - Parameter model: 模型对象
     - Returns: 字典
     */
    public static func modelToDictionary<T: Codable>(_ model: T) -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(model)
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            HBlogger.e(tag, "模型转字典失败: \(error.localizedDescription)")
            return nil
        }
    }

    /**
     JSON 字符串解析为对象（字典）。

     说明：对齐 Android `parseJsonObject` 语义。
     - Parameter jsonString: JSON 字符串
     - Returns: 字典对象，失败返回 nil
     */
    public static func parseJsonObject(_ jsonString: String?) -> [String: Any]? {
        guard let jsonString, !jsonString.isEmpty else { return nil }
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            HBlogger.e(Self.tag, "parseJsonObject 失败: \(error.localizedDescription)")
            return nil
        }
    }

    /**
     规范化事件数据（Web -> Native）。

     说明：Web 侧事件数据可能是对象/字符串(JSON)/数组/基础类型；此处统一为 `[String: Any]?`，
     以便宿主侧稳定处理（事件 data 以 map 为主）。

     - Parameter raw: 原始事件数据
     - Returns: 规范化后的字典，无法表达时返回 nil
     */
    public static func normalizeEventData(_ raw: Any?) -> [String: Any]? {
        guard let raw else { return nil }

        // 已经是字典：直接返回（显式复制，避免引用类型 value 在并发下被修改）
        if let dict = raw as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: dict.map { ($0.key, $0.value) })
        }

        // 字符串：尝试当作 JSON 对象解析
        if let s = raw as? String {
            if let parsed = parseJsonObject(s) {
                return parsed
            }
            // 非 JSON：以 value 包装，保持信息不丢失
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : ["value": trimmed]
        }

        // 数组：用 list 包装（避免宿主侧对 data 结构分支太多）
        if let arr = raw as? [Any] {
            return ["list": arr]
        }

        // 基础类型：统一用 value 包装
        if raw is NSNumber || raw is Bool {
            return ["value": raw]
        }

        // 兜底：尽量把可描述的对象字符串化（避免返回 nil 造成宿主丢事件）
        let desc = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return desc.isEmpty ? nil : ["value": desc]
    }
    
    private init() {
        fatalError("HelpBotJsonUtils 不能被实例化")
    }
}
