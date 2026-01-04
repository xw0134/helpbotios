import Foundation
import WebKit

/**
 WKWebView 初始化与安全加固工具类（iOS）。

 目标：
 - 统一 SDK 内 WKWebView 的配置
 - 限制跳转域名、减少不必要能力开启、所有回调 try-catch
 */
enum HelpBotWebViewHelper {
    static let nativeBridgeName = "HelpBotNativeIOS"
    /// WebSDK SSE 通知回调（Web -> Native）方法名：helpbot-sdk.js 直接调用 window.webkit.messageHandlers['onSSEMessage']
    static let sseMessageHandlerName = "onSSEMessage"
    /// Web 控制台日志回调（仅 DEBUG）：由注入脚本转发
    static let consoleLogHandlerName = "consoleLog"

    // 预解析，避免每次导航都重复解析 URL
    private static let indexUrl = URL(string: HelpBotSDKUrls.webChatIndex)
    private static let loaderUrl = URL(string: HelpBotSDKUrls.webChatLoaderJs)

    private static let indexHost = indexUrl?.host?.lowercased()
    private static let loaderHost = loaderUrl?.host?.lowercased()
    private static let indexPort = indexUrl?.port ?? 443
    private static let loaderPort = loaderUrl?.port ?? 443

    static func buildConfiguration(
        fullPrivacyMode: Bool,
        scriptMessageHandler: WKScriptMessageHandler
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // 隐私模式：使用非持久化存储（不落盘 Cookie/LocalStorage）
        if fullPrivacyMode {
            config.websiteDataStore = .nonPersistent()
        }

        let controller = WKUserContentController()
        // 1) WebBridge：事件透传/认证失败（helpbot-bridge.js 通过 window.HelpBotNativeIOS.sendEvent(...) 调用）
        controller.add(scriptMessageHandler, name: nativeBridgeName)

        // 2) SSE 通知：helpbot-sdk.js 通过 window.webkit.messageHandlers['onSSEMessage'].postMessage(...) 调用
        // 说明：该通道与上面的 nativeBridgeName 不是同一个协议，因此需要单独注册。
        controller.add(scriptMessageHandler, name: sseMessageHandlerName)

        // 3) Web 控制台日志（仅 DEBUG）：用于开发排查 WebSDK 问题；Release 不注入，避免泄露与性能开销
        #if DEBUG
        controller.add(scriptMessageHandler, name: consoleLogHandlerName)
        controller.addUserScript(WKUserScript(
            source: WebViewConsoleLogger.createConsoleInterceptScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        #endif

        // 注入 iOS Native Bridge：对齐 WebSDK 的判定逻辑（window.HelpBotNativeIOS）
        controller.addUserScript(WKUserScript(
            source: buildNativeBridgeInjectionJs(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        config.userContentController = controller

        // JS 必须开启（Web SDK 核心依赖）
        config.preferences.javaScriptEnabled = true
        // 安全基线：禁止 JS 自动打开新窗口（对齐 Android：setJavaScriptCanOpenWindowsAutomatically(false)）
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        if #available(iOS 14.0, *) {
            let pagePref = WKWebpagePreferences()
            pagePref.allowsContentJavaScript = true
            config.defaultWebpagePreferences = pagePref
        }

        return config
    }

    /// 主框架域名白名单：仅允许 index/loader 所在域名（两者可能一致或不同）
    static func isMainFrameUrlAllowed(_ url: URL?) -> Bool {
        guard let url else { return false }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme != "https" && scheme != "about" { return false }
        if scheme == "about" {
            // 对齐 Android：仅允许 about:blank（用于销毁/清理阶段）
            return url.absoluteString.lowercased() == "about:blank"
        }

        let host = url.host?.lowercased()
        if host == nil || host?.isEmpty == true { return false }

        let port = url.port ?? 443
        if port != 443 && port != indexPort && port != loaderPort { return false }

        if let indexHost, host == indexHost { return true }
        if let loaderHost, host == loaderHost { return true }

        return false
    }

    /**
     子资源/子框架放行策略（对齐 Android 思路）：
     - 主框架导航仍必须走严格白名单，防止顶层跳转被劫持
     - 子资源/子框架仅做最小协议白名单：允许 https + blob/data + about:blank

     说明：WKWebView 的资源加载/子资源拦截能力与 Android 不同；这里主要用于 iframe/子 frame 的导航兜底。
     */
    static func isSubresourceUrlAllowed(_ url: URL?) -> Bool {
        guard let url else { return true }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme.isEmpty { return true }
        if scheme == "about" {
            return url.absoluteString.lowercased() == "about:blank"
        }
        if scheme == "blob" || scheme == "data" {
            return true
        }
        return scheme == "https"
    }

    /// 兼容旧调用：默认按“主框架”策略判断
    static func isUrlAllowed(_ url: URL?) -> Bool {
        return isMainFrameUrlAllowed(url)
    }

    private static func buildNativeBridgeInjectionJs() -> String {
        // 说明：WebSDK 仅判断 window.HelpBotNativeIOS 是否存在并调用其 sendEvent / sendUserAuthFailureEvent
        // 这里统一转发到 WK messageHandlers: HelpBotNativeIOS
        return """
        (function(){
          try{
            if(window.HelpBotNativeIOS){return;}
            window.HelpBotNativeIOS = {
              sendEvent: function(payloadStr){
                try{
                  window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(nativeBridgeName)
                    && window.webkit.messageHandlers.\(nativeBridgeName).postMessage({method:'sendEvent', data: String(payloadStr||'')});
                }catch(e){}
              },
              sendUserAuthFailureEvent: function(reason){
                try{
                  window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(nativeBridgeName)
                    && window.webkit.messageHandlers.\(nativeBridgeName).postMessage({method:'sendUserAuthFailureEvent', data: String(reason||'')});
                }catch(e){}
              }
            };
          }catch(e){}
        })();
        """
    }
}


