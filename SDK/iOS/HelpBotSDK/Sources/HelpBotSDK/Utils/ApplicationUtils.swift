import Foundation
import UIKit
import UserNotifications

/**
 应用程序工具类（iOS）。
 
 提供系统通知、资源获取、权限检查等功能。
 */
public final class ApplicationUtils {
    
    private static let tag = "AppUtil"
    private static let topViewControllerMaxDepth = 64
    
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
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if scenes.isEmpty { return nil }
            
            // iOS 13+ 多 Scene：优先选取前台激活的 Scene，避免拿到后台/已断开的窗口
            let foregroundActive = scenes.filter { $0.activationState == .foregroundActive }
            let foregroundInactive = scenes.filter { $0.activationState == .foregroundInactive }
            let candidates: [UIWindowScene] = !foregroundActive.isEmpty ? foregroundActive : (!foregroundInactive.isEmpty ? foregroundInactive : scenes)
            
            // 1) 优先 keyWindow
            if let key = candidates.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
                return key
            }
            // 2) 正常层级、可见窗口
            if let normal = candidates
                .flatMap({ $0.windows })
                .first(where: { !$0.isHidden && $0.alpha > 0.0 && $0.windowLevel == .normal }) {
                return normal
            }
            // 3) 任意窗口
            return candidates.flatMap({ $0.windows }).first
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
        return getTopViewController(from: rootViewController, depth: 0, visited: [])
    }
    
    private static func getTopViewController(
        from viewController: UIViewController,
        depth: Int,
        visited: Set<ObjectIdentifier>
    ) -> UIViewController {
        // 防御：避免极端自定义容器导致的环
        if depth > topViewControllerMaxDepth { return viewController }
        
        let oid = ObjectIdentifier(viewController)
        if visited.contains(oid) { return viewController }
        var visited = visited
        visited.insert(oid)
        
        // 1) present 关系：顶层优先（必须优先沿着 presented 往上走）
        // 否则在已有 modal 覆盖时会拿到“被覆盖的 VC”，导致后续 present 被系统拒绝（表现为 showConversation 不弹窗）。
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented, depth: depth + 1, visited: visited)
        }
        
        // 2) 常见容器再展开
        if let nav = viewController as? UINavigationController, let visible = nav.visibleViewController {
            return getTopViewController(from: visible, depth: depth + 1, visited: visited)
        }
        if let tab = viewController as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(from: selected, depth: depth + 1, visited: visited)
        }
        if let split = viewController as? UISplitViewController, let last = split.viewControllers.last {
            return getTopViewController(from: last, depth: depth + 1, visited: visited)
        }
        if #available(iOS 5.0, *), let page = viewController as? UIPageViewController,
           let current = page.viewControllers?.first {
            return getTopViewController(from: current, depth: depth + 1, visited: visited)
        }
        
        // 3) 自定义容器：尽量取最“上层”的 child
        if let child = viewController.children.last {
            return getTopViewController(from: child, depth: depth + 1, visited: visited)
        }
        
        return viewController
    }
    
    /**
     获取宿主导航栈
     
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
