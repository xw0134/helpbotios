import Foundation

/**
 HelpBot 线程池管理器（iOS）。
 
 提供统一的线程池管理和任务调度。
 */
public final class HelpBotThreadPool {
    
    private static let tag = "HelpBotThreadPool"
    
    /// 共享实例
    public static let shared = HelpBotThreadPool()
    
    /// 后台队列（utility 优先级）
    private let backgroundQueue: DispatchQueue
    
    /// 高优先级队列
    private let highPriorityQueue: DispatchQueue
    
    /// 低优先级队列
    private let lowPriorityQueue: DispatchQueue
    
    private init() {
        backgroundQueue = DispatchQueue(
            label: "com.helpbot.sdk.background",
            qos: .utility,
            attributes: .concurrent
        )
        
        highPriorityQueue = DispatchQueue(
            label: "com.helpbot.sdk.high",
            qos: .userInitiated,
            attributes: .concurrent
        )
        
        lowPriorityQueue = DispatchQueue(
            label: "com.helpbot.sdk.low",
            qos: .background,
            attributes: .concurrent
        )
    }
    
    /**
     提交任务到后台队列
     
     - Parameter task: 要执行的任务
     */
    public func submit(_ task: @escaping () -> Void) {
        backgroundQueue.async {
            task()
        }
    }
    
    /**
     提交任务到高优先级队列
     
     - Parameter task: 要执行的任务
     */
    public func submitHighPriority(_ task: @escaping () -> Void) {
        highPriorityQueue.async {
            task()
        }
    }
    
    /**
     提交任务到低优先级队列
     
     - Parameter task: 要执行的任务
     */
    public func submitLowPriority(_ task: @escaping () -> Void) {
        lowPriorityQueue.async {
            task()
        }
    }
    
    /**
     延迟提交任务
     
     - Parameters:
        - delay: 延迟时间（秒）
        - task: 要执行的任务
     */
    public func submitDelayed(delay: TimeInterval, _ task: @escaping () -> Void) {
        backgroundQueue.asyncAfter(deadline: .now() + delay) {
            task()
        }
    }
    
    /**
     在主线程执行任务
     
     - Parameter task: 要执行的任务
     */
    public func runOnMainThread(_ task: @escaping () -> Void) {
        if Thread.isMainThread {
            task()
        } else {
            DispatchQueue.main.async {
                task()
            }
        }
    }
    
    /**
     同步执行任务（阻塞当前线程）
     
     - Parameter task: 要执行的任务
     - Returns: 任务返回值
     */
    public func executeSync<T>(_ task: () -> T) -> T {
        return backgroundQueue.sync {
            return task()
        }
    }
}
