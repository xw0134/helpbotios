import Foundation

/**
 SDK 全局上下文管理器（iOS）。
 

 负责 SDK 全局状态管理、组件初始化协调、事件代理管理。
 */
public final class HelpBotContext {
    
    private static let tag = "HelpBotContext"
    private static let lock = NSLock()
    
    /// 共享实例
    private static var instance: HelpBotContext?
    
    /// 事件代理
    private var eventProxy: EventProxy
    
    /// 是否已安装
    private var installed: Bool = false
    
    /// 安装进行中标志
    private var installInProgress: Bool = false
    
    /// SDK 配置
    private var config: HelpBotConfig?
    
    private init() {
        self.eventProxy = EventProxy(listener: nil)
    }
    
    /**
     获取共享实例
     
     - Returns: HelpBotContext 实例
     */
    public static func getInstance() -> HelpBotContext? {
        lock.lock()
        defer { lock.unlock() }
        return instance
    }
    
    /**
     初始化实例
     
     - Parameter config: SDK 配置
     */
    public static func initInstance(config: HelpBotConfig) {
        lock.lock()
        defer { lock.unlock() }
        
        if instance == nil {
            instance = HelpBotContext()
        }
        instance?.config = config
    }
    
    /**
     销毁实例
     */
    public static func destroy() {
        lock.lock()
        defer { lock.unlock() }
        
        instance?.installed = false
        instance?.installInProgress = false
        instance?.config = nil
        instance = nil
    }
    
    /**
     检查是否已安装
     
     - Returns: 是否已安装
     */
    public static func isInstalled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return instance?.installed ?? false
    }
    
    /**
     设置安装状态
     
     - Parameter installed: 是否已安装
     */
    public static func setInstalled(_ installed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        instance?.installed = installed
    }
    
    /**
     检查安装是否进行中
     
     - Returns: 是否进行中
     */
    public static func isInstallInProgress() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return instance?.installInProgress ?? false
    }
    
    /**
     设置安装进行中标志
     
     - Parameter inProgress: 是否进行中
     */
    public static func setInstallInProgress(_ inProgress: Bool) {
        lock.lock()
        defer { lock.unlock() }
        instance?.installInProgress = inProgress
    }
    
    /**
     获取事件代理
     
     - Returns: 事件代理
     */
    public func getEventProxy() -> EventProxy {
        return eventProxy
    }
    
    /**
     设置事件监听器
     
     - Parameter listener: 事件监听器
     */
    public func setEventsListener(_ listener: HelpBotEventsListener?) {
        eventProxy.updateListener(listener)
    }
    
    /**
     获取 SDK 配置
     
     - Returns: SDK 配置
     */
    public func getConfig() -> HelpBotConfig? {
        return config
    }
    
    /**
     初始化组件
     */
    public func initialiseComponents() {
        HBlogger.d(Self.tag, "初始化 SDK 组件")
        // 这里可以初始化其他组件
    }
}
