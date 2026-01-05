import Foundation
import SystemConfiguration
import Network

/**
 网络诊断工具（iOS）。
 
 
 设计目标：
 - 不抛异常：所有系统调用 try-catch 包裹，避免影响宿主稳定性
 - 兼容 iOS 12+
 - 在"无网/网络受限/被策略拦截导致初始化超时"的场景给出更可行动的提示
 */
public final class NetworkUtils {
    
    /**
     网络诊断结果（只做提示用，非强一致网络判定）。
     */
    public struct NetworkDiagnosis {
        /// 是否有网络权限（iOS 始终为 true）
        public let hasAccessNetworkStatePermission: Bool
        /// 网络是否已连接
        public let networkConnected: Bool
        /// 是否具备互联网能力
        public let hasInternetCapability: Bool
        /// 网络是否已验证（iOS 12-13 恒 false，iOS 14+ 可能可用）
        public let validated: Bool
        /// 传输类型：WIFI / CELLULAR / ETHERNET / VPN / UNKNOWN
        public let transport: String?
        
        /**
         生成面向宿主的提示语（用于 install/login 超时/失败时的错误 message）。
         */
        public func buildUserHint() -> String {
            if !networkConnected {
                return "当前设备无可用网络连接（可能飞行模式/系统网络关闭/宿主禁用网络）。"
            }
            if !hasInternetCapability {
                return "当前网络不具备互联网能力（可能为局域网/受限网络），请切换到可访问互联网的网络环境。"
            }
            if validated {
                return "当前网络已连接且可访问互联网。若仍初始化失败，请检查域名是否被企业防火墙/DNS/代理策略拦截。"
            }
            return "当前网络已连接但互联网可用性未验证（可能需要认证/受限网络/被策略拦截）。若初始化超时，请检查防火墙/DNS/代理/VPN。"
        }
    }
    
    /**
     执行网络诊断
     
     - Returns: 网络诊断结果
     */
    public static func diagnose() -> NetworkDiagnosis {
        // iOS 不需要网络权限，始终为 true
        let hasPermission = true
        
        var networkConnected = false
        var hasInternet = false
        var validated = false
        var transport: String?
        
        // 方法1: 使用 SCNetworkReachability (兼容 iOS 12+)
        if let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") {
            var flags = SCNetworkReachabilityFlags()
            if SCNetworkReachabilityGetFlags(reachability, &flags) {
                networkConnected = flags.contains(.reachable)
                hasInternet = flags.contains(.reachable) && !flags.contains(.connectionRequired)
                
                // 判断网络类型
                if flags.contains(.isWWAN) {
                    transport = "CELLULAR"
                } else if networkConnected {
                    transport = "WIFI"
                }
            }
        }
        
        // 方法2: 使用 Network.framework (iOS 12+)
        if #available(iOS 12.0, *) {
            let monitor = NWPathMonitor()
            let semaphore = DispatchSemaphore(value: 0)
            
            monitor.pathUpdateHandler = { path in
                networkConnected = path.status == .satisfied
                hasInternet = path.status == .satisfied
                
                // iOS 14+ 可以检查是否已验证
                if #available(iOS 14.0, *) {
                    validated = path.status == .satisfied && !path.isConstrained
                }
                
                // 获取传输类型
                if path.usesInterfaceType(.wifi) {
                    transport = "WIFI"
                } else if path.usesInterfaceType(.cellular) {
                    transport = "CELLULAR"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    transport = "ETHERNET"
                } else if path.usesInterfaceType(.other) {
                    // 可能是 VPN
                    transport = "VPN"
                } else {
                    transport = "UNKNOWN"
                }
                
                semaphore.signal()
            }
            
            let queue = DispatchQueue(label: "com.helpbot.network.monitor")
            monitor.start(queue: queue)
            
            // 等待最多 500ms
            _ = semaphore.wait(timeout: .now() + 0.5)
            monitor.cancel()
        }
        
        return NetworkDiagnosis(
            hasAccessNetworkStatePermission: hasPermission,
            networkConnected: networkConnected,
            hasInternetCapability: hasInternet,
            validated: validated,
            transport: transport
        )
    }
    
    /**
     检查网络是否可用
     
     - Returns: 网络是否可用
     */
    public static func isNetworkAvailable() -> Bool {
        let diagnosis = diagnose()
        return diagnosis.networkConnected && diagnosis.hasInternetCapability
    }
    
    private init() {
        fatalError("NetworkUtils 不能被实例化")
    }
}
