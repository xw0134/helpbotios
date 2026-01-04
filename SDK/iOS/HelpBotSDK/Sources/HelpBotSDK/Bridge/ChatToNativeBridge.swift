import Foundation
import WebKit

/**
 Web -> Native JSBridge（iOS），对齐 Android `ChatToNativeBridge`：
 - 入口：`window.HelpBotNativeIOS.sendEvent(payloadStr)`
 - payloadStr: JSON 字符串，结构 `{ "EVENT_NAME": { ...eventData... } }`
 */
final class ChatToNativeBridge: NSObject {
    private static let tag = "ChatToNativeBridge"

    // 单次 payload 必须严格限制，避免 DoS/卡顿
    private static let maxPayloadChars = 128 * 1024
    // SSE 通知消息摘要：严格限制，避免 UI/通知线程被大 payload 拖死
    private static let maxSseMessageChars = 10 * 1024
    private static let maxEventNameLength = 64
    private static let maxEventsPerPayload = 50

    private let eventProxy: EventProxy
    private weak var webViewSession: HelpBotWebViewSession?

    init(eventProxy: EventProxy, webViewSession: HelpBotWebViewSession) {
        self.eventProxy = eventProxy
        self.webViewSession = webViewSession
    }

    /**
     校验 message 来源：仅允许 HTTPS 安全域消息（拒绝 file/http 等），降低被恶意页面/iframe 注入的风险。

     说明：Android 侧 JSBridge 默认运行在 WebView 的同一进程空间，且子 frame 也可能调用；
     这里做“协议级最小门禁”，既不破坏跨域 iframe 的兼容性，又能阻断低安全协议来源。
     */
    private func isAllowedOrigin(_ message: WKScriptMessage) -> Bool {
        do {
            let proto = message.frameInfo.securityOrigin.`protocol`.lowercased()
            return proto == "https"
        } catch {
            return false
        }
    }

    private func isValidEventName(_ event: String) -> Bool {
        let e = event.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty || e.count > Self.maxEventNameLength { return false }
        // 仅允许 A-Z / 0-9 / _
        for scalar in e.unicodeScalars {
            let v = scalar.value
            let ok = (v >= 65 && v <= 90) || (v >= 48 && v <= 57) || v == 95
            if !ok { return false }
        }
        return true
    }

    private func parseAndDispatchEvents(_ payload: String) {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let costMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if costMs > 200 {
                HBlogger.w(Self.tag, "sendEvent 解析耗时=\(costMs)ms", nil)
            }
        }

        guard let json = HelpBotJsonUtils.parseJsonObject(payload) else {
            HBlogger.e(Self.tag, "sendEvent: JSON 解析失败", nil)
            return
        }

        var count = 0
        for (k, v) in json {
            if count >= Self.maxEventsPerPayload {
                HBlogger.w(Self.tag, "sendEvent: 事件过多(\(count))，已截断", nil)
                break
            }
            if !isValidEventName(k) {
                HBlogger.w(Self.tag, "sendEvent: 事件名称无效，已跳过", nil)
                continue
            }

            let data = HelpBotJsonUtils.normalizeEventData(v)
            eventProxy.sendEvent(k, data)

            // 关键事件：用于解锁 install/login 的等待
            if k == "SDK_READY" {
                webViewSession?.notifyWebSdkSdkReady(eventData: data)
                HelpBot.markLoginConfirmedFromWeb()
            } else if k == "SDK_ERROR" {
                webViewSession?.notifyWebSdkLoginFailed(reason: "websdk_error", detail: data)
            } else if k == "USER_AUTHENTICATION_FAILED" {
                webViewSession?.notifyWebSdkLoginFailed(reason: "user_authentication_failed", detail: data)
                // 单独抛给宿主
                let reasonRaw = (data?["reason"] as? String) ?? (data?["CODE"] as? String) ?? ""
                eventProxy.notifyAuthFailure(HelpBotAuthenticationFailureReason.from(reasonRaw))
            }

            count += 1
        }
    }
}

extension ChatToNativeBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // 所有处理都要 try-catch 风格收口，避免影响宿主稳定性
        do {
            // 0) 来源校验（防注入）：非白名单来源一律忽略
            if !isAllowedOrigin(message) {
                return
            }

            // 1) WebBridge：事件透传/认证失败（helpbot-bridge.js）
            if message.name == HelpBotWebViewHelper.nativeBridgeName {
                // {method:'sendEvent', data:'...'} 或 {method:'sendUserAuthFailureEvent', data:'...'}
                if let dict = message.body as? [String: Any] {
                    let method = (dict["method"] as? String) ?? ""
                    let data = (dict["data"] as? String) ?? ""

                    if method == "sendUserAuthFailureEvent" {
                        eventProxy.notifyAuthFailure(HelpBotAuthenticationFailureReason.from(data))
                        return
                    }

                    if method != "sendEvent" { return }

                    let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { return }
                    if trimmed.count > Self.maxPayloadChars { return }

                    // JSON 解析放后台，避免阻塞 WebKit 回调线程
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        self?.parseAndDispatchEvents(trimmed)
                    }
                    return
                }

                // 兜底：若直接传字符串
                if let data = message.body as? String {
                    let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { return }
                    if trimmed.count > Self.maxPayloadChars { return }
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        self?.parseAndDispatchEvents(trimmed)
                    }
                }
                return
            }

            // 2) SSE 通知：helpbot-sdk.js 使用 window.webkit.messageHandlers['onSSEMessage'] 直接回调
            if message.name == HelpBotWebViewHelper.sseMessageHandlerName {
                let raw: String
                if let s = message.body as? String {
                    raw = s
                } else {
                    raw = String(describing: message.body)
                }

                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return }
                if trimmed.count > Self.maxSseMessageChars { return }

                // 事件透传给宿主（与 Android 对齐事件名）
                eventProxy.sendEvent("SSE_MESSAGE", ["message": trimmed])

                // 系统通知（默认启用，可由宿主开关控制）
                HelpBotNotificationHelper.notifyNewMessage(trimmed)
                return
            }

            // 3) Web 控制台日志（仅 DEBUG，默认忽略）
            if message.name == HelpBotWebViewHelper.consoleLogHandlerName {
                #if DEBUG
                WebViewConsoleLogger.logFromScriptMessage(message)
                #endif
                return
            }

            // 其它 messageHandlers：忽略
            return
        } catch {
            HBlogger.e(Self.tag, "didReceive message 异常: \(error.localizedDescription)", error)
        }
    }
}


