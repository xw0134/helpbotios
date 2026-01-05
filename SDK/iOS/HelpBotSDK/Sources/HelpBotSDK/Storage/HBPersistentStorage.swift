import Foundation

/**
 持久化存储管理器（iOS）。
 
 使用 UserDefaults 进行数据持久化。
 */
public final class HBPersistentStorage {
    
    private static let tag = "HBPersistentStorage"
    private static let suiteName = "com.helpbot.sdk.storage"
    
    private let userDefaults: UserDefaults
    private let suiteNameUsed: String?
    
    /**
     初始化持久化存储
     
     - Parameter suiteName: UserDefaults suite 名称（可选）
     */
    public init(suiteName: String? = nil) {
        if let suite = suiteName, let defaults = UserDefaults(suiteName: suite) {
            self.userDefaults = defaults
            self.suiteNameUsed = suite
        } else {
            self.userDefaults = UserDefaults.standard
            self.suiteNameUsed = nil
        }
    }
    
    /**
     获取共享实例
     */
    public static let shared = HBPersistentStorage(suiteName: HBPersistentStorage.suiteName)
    
    // MARK: - String Operations
    
    /**
     存储字符串
     
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
        userDefaults.set(value, forKey: key)
        // 与 Android apply() 对齐：不强制同步落盘，避免阻塞主线程
        return true
    }
    
    /**
     获取字符串
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 字符串值
     */
    public func getString(_ key: String, defaultValue: String? = nil) -> String? {
        guard !Utils.isEmpty(key) else {
            return defaultValue
        }
        return userDefaults.string(forKey: key) ?? defaultValue
    }
    
    // MARK: - Int Operations
    
    /**
     存储整数
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putInt(_ key: String, _ value: Int) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putInt: key 不能为空")
            return false
        }
        userDefaults.set(value, forKey: key)
        return true
    }
    
    /**
     获取整数
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 整数值
     */
    public func getInt(_ key: String, defaultValue: Int = 0) -> Int {
        guard !Utils.isEmpty(key) else {
            return defaultValue
        }
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.integer(forKey: key)
    }
    
    // MARK: - Bool Operations
    
    /**
     存储布尔值
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putBool(_ key: String, _ value: Bool) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putBool: key 不能为空")
            return false
        }
        userDefaults.set(value, forKey: key)
        return true
    }
    
    /**
     获取布尔值
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 布尔值
     */
    public func getBool(_ key: String, defaultValue: Bool = false) -> Bool {
        guard !Utils.isEmpty(key) else {
            return defaultValue
        }
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.bool(forKey: key)
    }
    
    // MARK: - Double Operations
    
    /**
     存储浮点数
     
     - Parameters:
        - key: 键
        - value: 值
     - Returns: 是否成功
     */
    @discardableResult
    public func putDouble(_ key: String, _ value: Double) -> Bool {
        guard !Utils.isEmpty(key) else {
            HBlogger.w(Self.tag, "putDouble: key 不能为空")
            return false
        }
        userDefaults.set(value, forKey: key)
        return true
    }
    
    /**
     获取浮点数
     
     - Parameters:
        - key: 键
        - defaultValue: 默认值
     - Returns: 浮点数值
     */
    public func getDouble(_ key: String, defaultValue: Double = 0.0) -> Double {
        guard !Utils.isEmpty(key) else {
            return defaultValue
        }
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.double(forKey: key)
    }
    
    // MARK: - Data Operations
    
    /**
     存储 Data
     
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
        userDefaults.set(value, forKey: key)
        return true
    }
    
    /**
     获取 Data
     
     - Parameter key: 键
     - Returns: Data 值
     */
    public func getData(_ key: String) -> Data? {
        guard !Utils.isEmpty(key) else {
            return nil
        }
        return userDefaults.data(forKey: key)
    }
    
    // MARK: - Object Operations
    
    /**
     存储对象（需要符合 Codable）
     
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
            userDefaults.set(data, forKey: key)
            return true
        } catch {
            HBlogger.e(Self.tag, "putObject 编码失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /**
     获取对象
     
     - Parameters:
        - key: 键
        - type: 对象类型
     - Returns: 对象值
     */
    public func getObject<T: Codable>(_ key: String, type: T.Type) -> T? {
        guard !Utils.isEmpty(key) else {
            return nil
        }
        guard let data = userDefaults.data(forKey: key) else {
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
        userDefaults.removeObject(forKey: key)
        return true
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
        return userDefaults.object(forKey: key) != nil
    }
    
    /**
     清空所有数据
     
     - Returns: 是否成功
     */
    @discardableResult
    public func clear() -> Bool {
        // 安全基线（SDK 规范）：禁止清空宿主 App 的 UserDefaults（避免误删宿主业务数据）。
        // 仅允许清理 SDK 自己的 suiteName 沙箱数据（shared 默认使用 suiteName）。
        if let suite = suiteNameUsed, !suite.isEmpty {
            userDefaults.removePersistentDomain(forName: suite)
            return true
        }
        return false
    }
}
