import Foundation
import UIKit
import UserNotifications

/**
 应用程序工具类（iOS）。
 
 提供系统通知、资源获取、权限检查等功能。
 */
public final class ApplicationUtils {
    
    private static let tag = "AppUtil"
    
    /**
     判断应用是否处于调试模式。
     
     - Returns: 是否为调试模式
     */
    public static func isApplicationInDebugMode() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /**
     获取应用版本号
     
     - Returns: 版本号字符串
     */
    public static func getAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    /**
     获取应用 Build 号
     
     - Returns: Build 号字符串
     */
    public static func getAppBuildNumber() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
    
    /**
     获取应用 Bundle ID
     
     - Returns: Bundle ID 字符串
     */
    public static func getBundleIdentifier() -> String? {
        return Bundle.main.bundleIdentifier
    }
    
    /**
     获取应用名称
     
     - Returns: 应用名称
     */
    public static func getAppName() -> String? {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String
    }
    
    /**
     获取设备语言代码
     
     - Returns: 语言代码（例如 "zh-Hans", "en"）
     */
    public static func getDeviceLanguage() -> String {
        return Locale.preferredLanguages.first ?? Locale.current.languageCode ?? "en"
    }
    
    /**
     获取设备区域代码
     
     - Returns: 区域代码（例如 "CN", "US"）
     */
    public static func getDeviceRegion() -> String? {
        return Locale.current.regionCode
    }
    
    /**
     检查是否已授予指定权限
     
     - Parameter permission: 权限类型（例如通知权限）
     - Returns: 是否已授予权限
     */
    public static func isNotificationPermissionGranted(completion: @escaping (Bool) -> Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                completion(settings.authorizationStatus == .authorized)
            }
        } else {
            let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
            completion(isRegistered)
        }
    }
    
    /**
     请求通知权限
     
     - Parameter completion: 完成回调，返回是否授权成功
     */
    public static func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    HBlogger.d(tag, "请求通知权限失败: \(error.localizedDescription)")
                }
                completion(granted)
            }
        } else {
            let settings = UIUserNotificationSettings(types: [.alert, .sound, .badge], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
            completion(true)
        }
    }
    
    /**
     获取主窗口
     
     - Returns: 主窗口
     */
    public static func getKeyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
    /**
     获取顶层 ViewController
     
     - Returns: 顶层 ViewController
     */
    public static func getTopViewController() -> UIViewController? {
        guard let rootViewController = getKeyWindow()?.rootViewController else {
            return nil
        }
        return getTopViewController(from: rootViewController)
    }
    
    private static func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let navigationController = viewController as? UINavigationController {
            if let visible = navigationController.visibleViewController {
                return getTopViewController(from: visible)
            }
        }
        if let tabBarController = viewController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                return getTopViewController(from: selected)
            }
        }
        return viewController
    }
    
    /**
     在主线程执行
     
     - Parameter block: 要执行的代码块
     */
    public static func runOnMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    /**
     在后台线程执行
     
     - Parameter block: 要执行的代码块
     */
    public static func runOnBackgroundThread(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async {
            block()
        }
    }
    
    private init() {
        fatalError("ApplicationUtils 不能被实例化")
    }
}
