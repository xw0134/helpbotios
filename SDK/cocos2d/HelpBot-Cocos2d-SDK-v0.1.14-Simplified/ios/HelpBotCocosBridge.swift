import Foundation
import UIKit

import HelpBotSDK

/**
 HelpBotCocosBridge - Cocos2d Creator iOS 桥接层（Swift）
 
 设计目标：
 - 让 Creator 通过 `jsb.reflection.callStaticMethod("HelpBotCocosBridge", ...)` 调用 HelpBot iOS SDK
 - API 尽量与 Android Bridge 对齐（install/login/showConversation/meta/tags/destroy）
 
 重要说明：
 - iOS 侧如何“回调事件到 JS”，取决于你的 Creator iOS 工程是否暴露了 JS 执行入口。
   不同 Creator 版本差异较大，因此这里默认仅做 **API 封装**，事件回传你可按项目实际补齐 `emitToJs(...)`。
 */
@objcMembers
public final class HelpBotCocosBridge: NSObject {
    private static let tag = "HelpBotCocosBridge(iOS)"
    private static var lastDispatchMode: String = "NONE" // EVAL_STRING / JSB_BRIDGE / NONE

    public static func `init`() {
        // 可选：在这里设置事件监听（需要你实现 emitToJs）
        // HBHelpBot.setEventsDelegate(...)
    }

    /**
     install(configJson)
     JSON 格式（对齐 Creator TS）：{ requestId, channelId, domain, configMap: { ... } }
     */
    public static func install(_ configJson: String) {
        let payload = parseJsonObject(configJson)
        let requestId = payload["requestId"] as? String ?? ""
        let channelId = payload["channelId"] as? String ?? ""
        let domain = payload["domain"] as? String ?? ""
        let configMap = payload["configMap"] as? [String: Any]

        // 直接复用 SDK 的 install（内部含完整状态机/安全校验）
        HelpBot.install(channelId: channelId, domain: domain, configMap: configMap, callback: InstallCallback(requestId: requestId))
    }

    /**
     login(token)
     */
    public static func login(_ token: String) {
        // TS 侧会把 requestId 放到 loginConfigJson；iOS 目前签名简化，直接走 token。
        HelpBot.login(token) { r in
            if r.isSuccess {
                emitToJs(eventName: "LOGIN_SUCCESS", payload: ["success": true])
            } else {
                emitToJs(eventName: "LOGIN_FAILURE", payload: ["success": false, "errorMessage": r.errorMessage ?? "login_failed"])
            }
        }
    }

    public static func showConversation() {
        _ = HelpBot.showConversation()
    }

    public static func hideConversation() {
        _ = HelpBot.hideConversation()
    }

    public static func updateSdkMeta(_ json: String) {
        let meta = parseJsonObject(json)
        let r = HelpBot.updateSDKMeta(meta)
        emitToJs(eventName: "META_RESULT", payload: resultToPayload(r))
    }

    public static func updateCustomMeta(_ json: String) {
        let meta = parseJsonObject(json)
        let r = HelpBot.updateCustomMeta(meta)
        emitToJs(eventName: "META_RESULT", payload: resultToPayload(r))
    }

    public static func addIssueTags(_ jsonArray: String) {
        let tags = parseJsonStringArray(jsonArray)
        let r = HelpBot.addIssueTags(tags)
        emitToJs(eventName: "TAGS_RESULT", payload: resultToPayload(r))
    }

    public static func removeIssueTags(_ jsonArray: String) {
        let tags = parseJsonStringArray(jsonArray)
        let r = HelpBot.removeIssueTags(tags)
        emitToJs(eventName: "TAGS_RESULT", payload: resultToPayload(r))
    }

    public static func destroy() {
        HelpBot.destroy { r in
            emitToJs(eventName: "DESTROY_RESULT", payload: resultToPayload(r))
        }
    }

    /**
     Bridge 自检（给 Creator TS/宿主读取）
     */
    public static func diagnose() -> String {
        var o: [String: Any] = [:]
        o["lastDispatchMode"] = lastDispatchMode
        o["hasJsbBridgeWrapper"] = (NSClassFromString("JsbBridgeWrapper") != nil) || (NSClassFromString("cocos.JsbBridgeWrapper") != nil)
        o["hasCocos2dxJavascriptJavaBridge"] = (NSClassFromString("Cocos2dxJavascriptJavaBridge") != nil)
        return jsonString(o) ?? "{}"
    }

    public static func getLastDispatchMode() -> String {
        return lastDispatchMode
    }

    // MARK: - Install callback adapter

    private final class InstallCallback: HelpBotInitCallback {
        private let requestId: String

        init(requestId: String) {
            self.requestId = requestId
        }

        func onInitStart() {
            emitToJs(eventName: "INSTALL_START", payload: ["requestId": requestId, "success": true])
        }

        func onInitProgress(_ progress: Int, _ message: String) {
            emitToJs(eventName: "INSTALL_PROGRESS", payload: ["requestId": requestId, "success": true, "progress": progress, "message": message])
        }

        func onInitSuccess() {
            emitToJs(eventName: "INSTALL_SUCCESS", payload: ["requestId": requestId, "success": true])
        }

        func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
            emitToJs(eventName: "INSTALL_FAILURE", payload: ["requestId": requestId, "success": false, "errorCode": errorCode.rawValue, "errorMessage": errorMessage])
        }
    }

    // MARK: - JSON helpers

    private static func parseJsonObject(_ json: String) -> [String: Any] {
        do {
            let data = json.data(using: .utf8) ?? Data()
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            return obj as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }

    private static func parseJsonStringArray(_ json: String) -> [String] {
        do {
            let data = json.data(using: .utf8) ?? Data()
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            let arr = obj as? [Any] ?? []
            return arr.compactMap { String(describing: $0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private static func resultToPayload(_ r: HelpBotResult<Void>) -> [String: Any] {
        if r.isSuccess {
            return ["success": true]
        }
        return ["success": false, "errorCode": r.errorCode?.rawValue ?? HelpBotErrorCode.unknownError.rawValue, "errorMessage": r.errorMessage ?? ""]
    }

    // MARK: - JS event dispatch (TODO)

    /**
     将事件回传给 JS（需要你在 Creator iOS 工程里提供 JS 执行入口）
     
     推荐做法：
     - 在 iOS 侧找到 Cocos 的 JS eval API（不同版本不同类/符号）
     - 执行：globalThis.__helpBotCocosOnNativeEvent(eventName, JSON.stringify(payload))
     */
    private static func emitToJs(eventName: String, payload: [String: Any]) {
        // 兼容策略（尽量覆盖 Creator 2.x/3.x）：
        // 1) 优先走 Creator 3.x 常见通道：JsbBridgeWrapper.dispatchEventToScript(...)
        //    约定事件名：HelpBotNativeEvent，payload 为 {"eventName":"XXX","data":{...}}
        // 2) 回退走 Creator 2.x（Cocos2d-x）通道：Cocos2dxJavascriptJavaBridge.evalString(...)
        //
        // 注意：不同 Creator 版本/自定义引擎可能类名/方法签名略有差异，因此这里采用“多 selector 探测”。

        let bridgeEventName = "HelpBotNativeEvent"
        let wrapped: [String: Any] = ["eventName": eventName, "data": payload]
        let payloadStr = jsonString(wrapped) ?? "{}"

        // 1) Creator 3.x：JsbBridgeWrapper
        if dispatchViaJsbBridgeWrapper(eventName: bridgeEventName, payload: payloadStr) {
            lastDispatchMode = "JSB_BRIDGE"
            return
        }

        // 2) Creator 2.x：evalString 执行 JS
        let js = buildJsDispatch(eventName: eventName, payloadJson: payloadStr)
        if evalViaCocos2dxJavascriptJavaBridge(js: js) {
            lastDispatchMode = "EVAL_STRING"
        } else {
            lastDispatchMode = "NONE"
        }
    }

    // MARK: - Creator 2.x / 3.x dispatch helpers

    private static func dispatchViaJsbBridgeWrapper(eventName: String, payload: String) -> Bool {
        // 常见类名：JsbBridgeWrapper（Creator 3.x）
        guard let cls = NSClassFromString("JsbBridgeWrapper") as? NSObject.Type else {
            // 有些引擎可能放在命名空间/模块里，尝试备用类名
            guard let cls2 = NSClassFromString("cocos.JsbBridgeWrapper") as? NSObject.Type else {
                return false
            }
            return invokeDispatchEventToScript(cls: cls2, eventName: eventName, payload: payload)
        }
        return invokeDispatchEventToScript(cls: cls, eventName: eventName, payload: payload)
    }

    private static func invokeDispatchEventToScript(cls: NSObject.Type, eventName: String, payload: String) -> Bool {
        // 探测多种可能 selector（不同引擎版本可能命名不同）
        let selectors: [Selector] = [
            Selector(("dispatchEventToScript:arg:")),
            Selector(("dispatchEventToScript:payload:")),
            Selector(("dispatchEventToScript:data:")),
            Selector(("dispatchEventToScript::")), // 极端兜底（两个参数）
        ]

        for sel in selectors {
            if cls.responds(to: sel) {
                // class method
                _ = (cls as AnyObject).perform(sel, with: eventName, with: payload)
                return true
            }
        }

        // 有些实现可能是单例实例方法：getInstance + dispatchEventToScript
        let getInstanceSel = Selector(("getInstance"))
        if cls.responds(to: getInstanceSel) {
            if let inst = (cls as AnyObject).perform(getInstanceSel)?.takeUnretainedValue() as AnyObject? {
                for sel in selectors {
                    if inst.responds(to: sel) {
                        _ = inst.perform(sel, with: eventName, with: payload)
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func evalViaCocos2dxJavascriptJavaBridge(js: String) -> Bool {
        guard !js.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        guard let cls = NSClassFromString("Cocos2dxJavascriptJavaBridge") as? NSObject.Type else {
            // 备用：某些工程可能是 "org.cocos2dx.lib.Cocos2dxJavascriptJavaBridge"（通常为 Android 命名，但这里兜底）
            return false
        }
        let sel = Selector(("evalString:"))
        if cls.responds(to: sel) {
            _ = (cls as AnyObject).perform(sel, with: js)
            return true
        }
        return false
    }

    private static func buildJsDispatch(eventName: String, payloadJson: String) -> String {
        // JS 侧约定：globalThis.__helpBotCocosOnNativeEvent(eventName, dataJson)
        // dataJson 这里直接使用 payloadJson（其中 data 内已包裹 eventName/data）
        let en = jsonString(eventName) ?? "\"\""
        let pj = jsonString(payloadJson) ?? "\"{}\""
        return "try{var fn=globalThis&&globalThis.__helpBotCocosOnNativeEvent;if(fn){fn(\(en),\(pj));}}catch(e){}"
    }

    private static func jsonString(_ obj: Any) -> String? {
        if let s = obj as? String {
            // 需要做 JSON quote
            if let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
               let txt = String(data: data, encoding: .utf8),
               txt.count >= 2 {
                // ["xxx"] -> "xxx"
                let start = txt.index(after: txt.startIndex)
                let end = txt.index(before: txt.endIndex)
                return String(txt[start..<end])
            }
            return nil
        }
        if JSONSerialization.isValidJSONObject(obj) {
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let s = String(data: data, encoding: .utf8) {
                return s
            }
        }
        return nil
    }
}

