import Foundation
import Security

/**
 加密存储（iOS）。
 
 
 使用 Keychain 进行敏感数据加密存储。
 */
public final class EncryptedStorage {
    
    private static let tag = "EncryptedStorage"
    private let service: String
    private let accessGroup: String?
    
    /**
     初始化加密存储
     
     - Parameters:
        - service: Keychain service 名称
        - accessGroup: Keychain access group（可选，用于应用间共享）
     */
    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    /**
     获取共享实例
     */
    public static let shared = EncryptedStorage(service: "com.helpbot.sdk.encrypted")
    
    // MARK: - String Operations
    
    /**
     存储加密字符串
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putString(_ key: String, _ value: String) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putString: key 不能为空")
            return false
        }
        guard let data = value.data(using: .utf8) else {
            HBlogger.e(Self.tag, "putString: 字符串转 Data 失败")
            return false
        }
        return putData(key, data)
    }
    
    /**
     获取加密字符串
     
     - Parameter key: 键
     - Returns: 字符串值
     */
    public func getString(_ key: String) -> String? {
        guard let data = getData(key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Data Operations
    
    /**
     存储加密 Data
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putData(_ key: String, _ value: Data) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putData: key 不能为空")
            return false
        }
        
        // 先删除旧值
        _ = remove(key)
        
        // 构建查询字典
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            // 安全基线：ThisDeviceOnly，避免敏感数据随备份/迁移泄露（与 HBKeychainStorage/Android 对齐）
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            HBlogger.e(Self.tag, "putData 失败: \(status)")
            return false
        }
    }
    
    /**
     获取加密 Data
     
     - Parameter key: 键
     - Returns: Data 值
     */
    public func getData(_ key: String) -> Data? {
        guard !Utils.isEmpty(key) else {
            return nil
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else if status != errSecItemNotFound {
            HBlogger.d(Self.tag, "getData: \(status)")
        }
        return nil
    }
    
    // MARK: - Object Operations
    
    /**
     存储加密对象（需要符合 Codable）
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putObject<T: Codable>(_ key: String, _ value: T) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putObject: key 不能为空")
            return false
        }
        do {
            let data = try JSONEncoder().encode(value)
            return putData(key, data)
        } catch {
            HBlogger.e(Self.tag, "putObject 编码失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /**
     获取加密对象
     
     - Parameters:
        - key: 键
        - type: 对象类型
     - Returns: 对象值
     */
    public func getObject<T: Codable>(_ key: String, type: T.Type) -> T? {
        guard let data = getData(key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            HBlogger.e(Self.tag, "getObject 解码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Remove Operations
    
    /**
     移除键值对
     
     - Parameter key: 键
     - Returns: 是否成功
     */
    @discardableResult
    public func remove(_ key: String) -> Bool {
        guard !Utils.isEmpty(key) else {
            return false
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /**
     检查键是否存在
     
     - Parameter key: 键
     - Returns: 是否存在
     */
    public func contains(_ key: String) -> Bool {
        guard !Utils.isEmpty(key) else {
            return false
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /**
     清空所有数据
     
     - Returns: 是否成功
     */
    @discardableResult
    public func clear() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
