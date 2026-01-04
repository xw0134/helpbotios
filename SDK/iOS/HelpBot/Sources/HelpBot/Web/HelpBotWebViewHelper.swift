import Foundation
import WebKit

/// WebView 配置与管理类
///
/// 设计要点:
/// 1. 与 Android SDK 的 HelpBotWebViewHelper 保持一致
/// 2. 配置 WebView 安全设置
/// 3. 加载 WebSDK loader
public class HelpBotWebViewHelper {
    
    private static let TAG = "HelpBotWebViewHelper"
    
    // MARK: - WebView 创建与配置
    
    /// 创建并配置 WKWebView
    /// - Parameters:
    ///   - eventProxy: 事件代理
    ///   - fullscreen: 是否全屏模式
    /// - Returns: 配置好的 WKWebView
    public static func createWebView(eventProxy: EventProxy, fullscreen: Bool = true) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // JavaScript 配置（WebSDK 必需）
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        if #available(iOS 13.0, *) {
            // 启用欺诈网站警告（安全基线）
            configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        }
        
        // 允许内联播放媒体
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 添加 JavaScript Bridge
        let userContentController = WKUserContentController()
        let bridge = ChatToNativeBridge(eventProxy: eventProxy)
        userContentController.add(bridge, name: "sendEvent")
        userContentController.add(bridge, name: "sendUserAuthFailureEvent")
        configuration.userContentController = userContentController
        
        // 注入 Native Bridge 对象
        let bridgeScript = """
        window.HelpBotNativeIOS = {
            sendEvent: function(payload) {
                window.webkit.messageHandlers.sendEvent.postMessage(payload);
            },
            sendUserAuthFailureEvent: function(reason) {
                window.webkit.messageHandlers.sendUserAuthFailureEvent.postMessage(reason);
            }
        };
        """
        let userScript = WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(userScript)
        
        // 创建 WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) {
            // 仅在 Debug 场景由宿主控制是否开启 Web Inspector；SDK 默认关闭
            webView.isInspectable = false
        }
        
        // 设置代理
        // navigationDelegate 和 uiDelegate 需要在外部设置
        
        HBLogger.d(TAG, "WebView 已创建并配置")
        
        return webView
    }
    
    // MARK: - 加载 WebSDK
    
    /// 加载 WebSDK Loader
    /// - Parameters:
    ///   - webView: WKWebView 实例
    ///   - config: SDK 配置
    ///   - completion: 完成回调
    public static func loadWebSDK(
        webView: WKWebView,
        config: HelpBotConfig,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let loaderUrl = SDKUrls.WEBCHAT_LOADER_URL
        HBLogger.d(TAG, "开始加载 WebSDK Loader: \(loaderUrl)")

        // 构建 HTML 页面（注意：是否“真正初始化成功”由上层通过 getStatus/bootstrap 轮询确认）
        let html = buildLoaderHTML(config: config)

        // 加载 HTML
        webView.loadHTMLString(html, baseURL: URL(string: config.domain))

        // 这里不做“固定延时成功”，避免弱网/首次DNS导致误判。
        // 上层会继续等待 WebSDK 通过 getStatus/bootstrap 确认就绪后才算 install 成功。
        completion(true, nil)
    }
    
    /// 构建 Loader HTML
    private static func buildLoaderHTML(config: HelpBotConfig) -> String {
        let loaderUrl = SDKUrls.WEBCHAT_LOADER_URL
        
        // 构建配置对象
        var webConfig: [String: Any] = [:]
        webConfig["channelId"] = config.channelId
        webConfig["domain"] = config.domain
        webConfig["fullPrivacyMode"] = config.fullPrivacyMode
        webConfig["hideBubble"] = true  // Native 场景隐藏气泡
        webConfig["fullscreen"] = true
        
        if let preGeneratedToken = config.preGeneratedToken {
            webConfig["preGeneratedToken"] = preGeneratedToken
        }
        
        if config.useDevApi {
            webConfig["useDevAPI"] = true
            if let companyId = config.companyId {
                webConfig["companyId"] = companyId
            }
            if let userId = config.userId {
                webConfig["userId"] = userId
            }
        }
        
        let configJson = JsonUtils.toJsonString(webConfig)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>HelpBot</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; }
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
            </style>
        </head>
        <body>
            <script src="\(loaderUrl)"></script>
            <script>
                // 初始化 WebSDK
                var config = \(configJson);
                HelpBot('init', config);
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - JavaScript 执行
    
    /// 执行 JavaScript 代码
    /// - Parameters:
    ///   - webView: WKWebView 实例
    ///   - javascript: JavaScript 代码
    ///   - completion: 完成回调
    public static func evaluateJavaScript(
        webView: WKWebView,
        javascript: String,
        completion: ((String?) -> Void)? = nil
    ) {
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                HBLogger.e(TAG, "JavaScript 执行失败: \(javascript)", error: error)
                completion?(nil)
                return
            }
            
            let resultString: String?
            if let result = result {
                if let str = result as? String {
                    resultString = str
                } else {
                    resultString = "\(result)"
                }
            } else {
                resultString = nil
            }
            
            completion?(resultString)
        }
    }
    
    // MARK: - URL 白名单验证
    
    /// 验证 URL 是否在白名单中
    /// - Parameters:
    ///   - url: 待验证的 URL
    ///   - domain: 业务域名
    /// - Returns: 是否允许导航
    public static func shouldAllowNavigation(url: URL, domain: String) -> Bool {
        guard let host = url.host else {
            HBLogger.w(TAG, "URL 缺少 host: \(url.absoluteString)")
            return false
        }
        
        // 允许的域名列表
        let allowedHosts = [
            "webchat.helpbot.com",  // WebChat 域名
            URL(string: domain)?.host ?? ""  // 业务域名
        ].compactMap { $0 }
        
        let isAllowed = allowedHosts.contains { allowedHost in
            host == allowedHost || host.hasSuffix(".\(allowedHost)")
        }
        
        if !isAllowed {
            HBLogger.w(TAG, "URL 不在白名单中: \(url.absoluteString)")
        }
        
        return isAllowed
    }
}
