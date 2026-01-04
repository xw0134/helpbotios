package com.example.HelpBot.web;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * HelpBot Web SDK 命令封装（生成 evaluateJavascript 可执行的 JS 字符串）
 * 安全性：
 * - 所有字符串入参使用 JSONObject.quote(...) 做 JS 字符串转义，避免注入与语法错误。
 */
public final class HelpBotJsCommand {

    private HelpBotJsCommand() {
        super();
    }

    @NonNull
    public static String buildInitConfig(@NonNull final JSONObject config) {
        return "window.HelpBotConfig = " + config.toString() + ";";
    }

    @NonNull
    public static String buildLoadScript(@NonNull final String jsUrl) {
        final String safeUrl = JSONObject.quote(jsUrl);
        return "var newScript=document.createElement(\"script\");newScript.src=" + safeUrl + ";document.body.appendChild(newScript);";
    }

    @NonNull
    public static String buildSetTokenAndConnect(@NonNull final String token) {
        return "HelpBot('setTokenAndConnect', " + JSONObject.quote(token) + ");";
    }

    @NonNull
    public static String buildOpen() {
        return "HelpBot('open');";
    }

    @NonNull
    public static String buildClose() {
        return "HelpBot('close');";
    }

    @NonNull
    public static String buildToggle() {
        return "HelpBot('toggle');";
    }

    @NonNull
    public static String buildDestroy() {
        return "HelpBot('destroy');";
    }

    @NonNull
    public static String buildUpdateUserSdkMeta(@NonNull final JSONObject meta) {
        return "HelpBot('updateUserSdkMeta', " + meta.toString() + ");";
    }

    @NonNull
    public static String buildUpdateUserMeta(@NonNull final JSONObject meta) {
        return "HelpBot('updateUserMeta', " + meta.toString() + ");";
    }

    @NonNull
    public static String buildAddIssueTags(@NonNull final JSONArray tags) {
        return "HelpBot('addIssueTags', " + tags.toString() + ");";
    }

    @NonNull
    public static String buildRemoveIssueTags(@NonNull final JSONArray tags) {
        return "HelpBot('removeIssueTags', " + tags.toString() + ");";
    }

    @NonNull
    public static String buildGetStatus(@Nullable final String callbackFnName) {
        // 如果宿主提供回调名，把 status 传回 window[callback](status)
        if (callbackFnName == null || callbackFnName.trim().isEmpty()) {
            return "HelpBot('getStatus');";
        }
        final String safeCb = callbackFnName.trim();
        return "try{var s=HelpBot('getStatus');if(window['" + safeCb + "']){window['" + safeCb + "'](s);}}catch(e){}";
    }
}
