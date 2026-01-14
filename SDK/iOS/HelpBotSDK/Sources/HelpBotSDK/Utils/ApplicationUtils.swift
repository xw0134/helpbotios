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
     获取“宿主导航栈”（对齐 Android：像打开一个页面，而不是弹窗）。
     
     说明：
     - 宿主传入的 VC 可能是：`UINavigationController` / `UITabBarController` / 普通 VC / 多层容器。
     - 仅使用 `viewController.navigationController` 在很多场景会拿不到 nav（例如传入的本身就是 UINavigationController）。
     - 此方法会尽量从容器中解析出可用的 `UINavigationController`，用于 `push` 展示。
     
     - Parameter viewController: 任意 UIViewController（可为 nil）
     - Returns: 可用的 UINavigationController（若无则返回 nil）
     */
    public static func getHostNavigationController(from viewController: UIViewController?) -> UINavigationController? {
        guard let vc = viewController else { return nil }
        var visited = Set<ObjectIdentifier>()
        return resolveNavigationController(from: vc, visited: &visited)
    }
    
    private static func resolveNavigationController(
        from viewController: UIViewController,
        visited: inout Set<ObjectIdentifier>
    ) -> UINavigationController? {
        let oid = ObjectIdentifier(viewController)
        if visited.contains(oid) { return nil }
        visited.insert(oid)
        
        // 1) 自身就是 UINavigationController
        if let nav = viewController as? UINavigationController { return nav }
        
        // 2) 普通 VC 所属的导航栈
        if let nav = viewController.navigationController { return nav }
        
        // 3) Tab 容器：优先选中项
        if let tab = viewController as? UITabBarController, let selected = tab.selectedViewController {
            if let nav = resolveNavigationController(from: selected, visited: &visited) { return nav }
        }
        
        // 4) 已 present 的 VC（顶层优先）
        if let presented = viewController.presentedViewController {
            if let nav = resolveNavigationController(from: presented, visited: &visited) { return nav }
        }
        
        // 5) 子控制器兜底（部分自定义容器）
        // 说明：按 reverse 取最“上层”的 child，尽量贴近用户看到的界面。
        for child in viewController.children.reversed() {
            if let nav = resolveNavigationController(from: child, visited: &visited) { return nav }
        }
        
        return nil
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
