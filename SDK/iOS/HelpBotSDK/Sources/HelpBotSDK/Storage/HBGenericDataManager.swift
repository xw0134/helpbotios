import Foundation

/**
 通用数据管理器（iOS）。
 
 与 Android HBGenericDataManager.java 对齐。
 提供统一的数据访问接口，支持持久化存储和加密存储。
 */
public final class HBGenericDataManager {
    
    private static let tag = "HBGenericDataManager"
    
    private let persistentStorage: HBPersistentStorage
    private let encryptedStorage: EncryptedStorage
    
    /**
     初始化数据管理器
     
     - Parameters:
        - persistentStorage: 持久化存储
        - encryptedStorage: 加密存储
     */
    public init(
        persistentStorage: HBPersistentStorage = .shared,
        encryptedStorage: EncryptedStorage = .shared
    ) {
        self.persistentStorage = persistentStorage
        self.encryptedStorage = encryptedStorage
    }
    
    /**
     获取共享实例
     */
    public static let shared = HBGenericDataManager()
    
    // MARK: - Persistent Storage Operations
    
    /**
     存储字符串（持久化）
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func saveString(_ key: String, _ value: String) -> Bool {
        return persistentStorage.putString(key, value)
    }
    
    /**
     获取字符串（持久化）
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 字符串值
     */
    public func loadString(_ key: String, defaultValue: String? = nil) -> String? {
        return persistentStorage.getString(key, defaultValue: defaultValue)
    }
    
    /**
     存储整数（持久化）
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func saveInt(_ key: String, _ value: Int) -> Bool {
        return persistentStorage.putInt(key, value)
    }
    
    /**
     获取整数（持久化）
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 整数值
     */
    public func loadInt(_ key: String, defaultValue: Int = 0) -> Int {
        return persistentStorage.getInt(key, defaultValue: defaultValue)
    }
    
    /**
     存储布尔值（持久化）
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func saveBool(_ key: String, _ value: Bool) -> Bool {
        return persistentStorage.putBool(key, value)
    }
    
    /**
     获取布尔值（持久化）
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 布尔值
     */
    public func loadBool(_ key: String, defaultValue: Bool = false) -> Bool {
        return persistentStorage.getBool(key, defaultValue: defaultValue)
    }
    
    // MARK: - Encrypted Storage Operations
    
    /**
     存储加密字符串
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func saveSecureString(_ key: String, _ value: String) -> Bool {
        return encryptedStorage.putString(key, value)
    }
    
    /**
     获取加密字符串
     
     - Parameter key: 键
     - Returns: 字符串值
     */
    public func loadSecureString(_ key: String) -> String? {
        return encryptedStorage.getString(key)
    }
    
    /**
     存储加密对象
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func saveSecureObject<T: Codable>(_ key: String, _ value: T) -> Bool {
        return encryptedStorage.putObject(key, value)
    }
    
    /**
     获取加密对象
     
     - Parameters:
        - key: 键
        - type: 对象类型
     - Returns: 对象值
     */
    public func loadSecureObject<T: Codable>(_ key: String, type: T.Type) -> T? {
        return encryptedStorage.getObject(key, type: type)
    }
    
    // MARK: - Remove Operations
    
    /**
     移除持久化数据
     
     - Parameter key: 键
     - Returns: 是否成功
     */
    @discardableResult
    public func remove(_ key: String) -> Bool {
        return persistentStorage.remove(key)
    }
    
    /**
     移除加密数据
     
     - Parameter key: 键
     - Returns: 是否成功
     */
    @discardableResult
    public func removeSecure(_ key: String) -> Bool {
        return encryptedStorage.remove(key)
    }
    
    /**
     清空所有持久化数据
     
     - Returns: 是否成功
     */
    @discardableResult
    public func clearAll() -> Bool {
        let result1 = persistentStorage.clear()
        let result2 = encryptedStorage.clear()
        return result1 && result2
    }
    
    // MARK: - Utility Methods
    
    /**
     检查持久化数据是否存在
     
     - Parameter key: 键
     - Returns: 是否存在
     */
    public func contains(_ key: String) -> Bool {
        return persistentStorage.contains(key)
    }
    
    /**
     检查加密数据是否存在
     
     - Parameter key: 键
     - Returns: 是否存在
     */
    public func containsSecure(_ key: String) -> Bool {
        return encryptedStorage.contains(key)
    }
}
