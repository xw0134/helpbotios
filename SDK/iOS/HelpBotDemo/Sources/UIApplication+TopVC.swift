import UIKit

extension UIApplication {
    func hbTopViewController() -> UIViewController? {
        guard let window = hbKeyWindow() else { return nil }
        return hbTopViewController(from: window.rootViewController)
    }

    private func hbTopViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return hbTopViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return hbTopViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return hbTopViewController(from: presented)
        }
        return root
    }

    private func hbKeyWindow() -> UIWindow? {
        // iOS 13+ 多 Scene 兼容
        if #available(iOS 13.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return keyWindow
        }
    }
}


