import Foundation

/**
 HelpBot Web SDK 命令封装（生成 evaluateJavaScript 可执行的 JS 字符串）。

 安全性：
 - 所有字符串入参使用 JSON 编码生成安全字符串字面量，避免注入与语法错误。
 */
enum HelpBotJsCommand {
    static func buildInitConfig(_ config: [String: Any]) -> String {
        let json = HelpBotJsonUtils.toJsonString(config) ?? "{}"
        return "window.HelpBotConfig = \(json);"
    }

    static func buildLoadScript(_ jsUrl: String) -> String {
        let safeUrl = quoteJsString(jsUrl)
        return "var newScript=document.createElement(\"script\");newScript.src=\(safeUrl);document.body.appendChild(newScript);"
    }

    static func buildSetTokenAndConnect(_ token: String) -> String {
        return "HelpBot('setTokenAndConnect', \(quoteJsString(token)));"
    }

    static func buildOpen() -> String { "HelpBot('open');" }
    static func buildClose() -> String { "HelpBot('close');" }
    static func buildToggle() -> String { "HelpBot('toggle');" }
    static func buildDestroy() -> String { "HelpBot('destroy');" }

    static func buildUpdateUserSdkMeta(_ meta: [String: Any]) -> String {
        let json = HelpBotJsonUtils.toJsonString(meta) ?? "{}"
        return "HelpBot('updateUserSdkMeta', \(json));"
    }

    static func buildUpdateUserMeta(_ meta: [String: Any]) -> String {
        let json = HelpBotJsonUtils.toJsonString(meta) ?? "{}"
        return "HelpBot('updateUserMeta', \(json));"
    }

    static func buildAddIssueTags(_ tags: [String]) -> String {
        let json = HelpBotJsonUtils.toJsonString(tags) ?? "[]"
        return "HelpBot('addIssueTags', \(json));"
    }

    static func buildRemoveIssueTags(_ tags: [String]) -> String {
        let json = HelpBotJsonUtils.toJsonString(tags) ?? "[]"
        return "HelpBot('removeIssueTags', \(json));"
    }

    static func buildShowFAQs(_ config: [String: Any]) -> String {
        let json = HelpBotJsonUtils.toJsonString(config) ?? "{}"
        return "HelpBot('showFAQs', \(json));"
    }

    static func buildGetStatus(callbackFnName: String?) -> String {
        guard let callbackFnName, !callbackFnName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "HelpBot('getStatus');"
        }
        let cb = callbackFnName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "try{var s=HelpBot('getStatus');if(window['\(cb)']){window['\(cb)'](s);}}catch(e){}"
    }

    /// 生成 JS 字符串字面量（带引号）
    private static func quoteJsString(_ raw: String) -> String {
        // 利用 JSON 序列化保证转义正确：["xxx"] -> "xxx"
        guard let json = HelpBotJsonUtils.toJsonString([raw]) else { return "\"\"" }
        if json.count >= 4, json.hasPrefix("[\""), json.hasSuffix("\"]") {
            return String(json.dropFirst(1).dropLast(1))
        }
        return "\"\""
    }
}


