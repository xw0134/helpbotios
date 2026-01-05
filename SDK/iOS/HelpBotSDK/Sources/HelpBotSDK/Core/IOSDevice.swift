import Foundation
import UIKit

/**
 iOS 设备信息实现。
 

 */
public final class IOSDevice: Device {
    
    private static let tag = "IOSDevice"
    
    /**
     获取共享实例
     */
    public static let shared = IOSDevice()
    
    private init() {}
    
    // MARK: - Device Protocol Implementation
    
    public func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    public func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    public func getDeviceId() -> String {
        // 优先使用 IDFV (Identifier For Vendor)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        
        // 降级：使用持久化的 UUID
        let key = "com.helpbot.sdk.device.id"
        if let savedId = HBPersistentStorage.shared.getString(key) {
            return savedId
        }
        
        // 生成新的 UUID 并保存
        let newId = UUID().uuidString
        _ = HBPersistentStorage.shared.putString(key, newId)
        return newId
    }
    
    public func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    public func getScreenWidth() -> Int {
        let scale = UIScreen.main.scale
        let width = UIScreen.main.bounds.width
        return Int(width * scale)
    }
    
    public func getScreenHeight() -> Int {
        let scale = UIScreen.main.scale
        let height = UIScreen.main.bounds.height
        return Int(height * scale)
    }
    
    public func getScreenDensity() -> Float {
        return Float(UIScreen.main.scale)
    }
    
    public func getDeviceLanguage() -> String {
        return ApplicationUtils.getDeviceLanguage()
    }
    
    public func getDeviceRegion() -> String {
        return ApplicationUtils.getDeviceRegion() ?? "Unknown"
    }
    
    public func getAppVersion() -> String {
        return ApplicationUtils.getAppVersion() ?? "Unknown"
    }
    
    public func getAppBuildNumber() -> String {
        return ApplicationUtils.getAppBuildNumber() ?? "Unknown"
    }
    
    public func getBundleId() -> String {
        return ApplicationUtils.getBundleIdentifier() ?? "Unknown"
    }
    
    public func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Additional iOS-specific Methods
    
    /**
     获取设备类型名称（例如 "iPhone 14 Pro"）
     */
    public func getDeviceTypeName() -> String {
        let model = getDeviceModel()
        return mapToDeviceName(model)
    }
    
    /**
     获取系统名称
     */
    public func getSystemName() -> String {
        return UIDevice.current.systemName
    }
    
    /**
     获取电池电量（0.0 - 1.0）
     */
    public func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    /**
     获取电池状态
     */
    public func getBatteryState() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "Unplugged"
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        @unknown default:
            return "Unknown"
        }
    }
    
    /**
     获取可用内存（字节）
     */
    public func getAvailableMemory() -> UInt64 {
        var pageSize: vm_size_t = 0
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
        host_page_size(hostPort, &pageSize)
        
        var vmStat = vm_statistics_data_t()
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics(hostPort, HOST_VM_INFO, $0, &hostSize)
            }
        }
        
        if result == KERN_SUCCESS {
            let freeMemory = UInt64(vmStat.free_count) * UInt64(pageSize)
            return freeMemory
        }
        return 0
    }
    
    // MARK: - Private Helper Methods
    
    private func mapToDeviceName(_ identifier: String) -> String {
        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,6": return "iPhone SE (3rd generation)"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPad13,1", "iPad13,2": return "iPad Air (4th generation)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11-inch (5th generation)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12.9-inch (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"
        default:
            return identifier
        }
    }
}
