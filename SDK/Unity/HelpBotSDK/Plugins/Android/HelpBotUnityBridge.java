package com.example.HelpBot.unity;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.core.HelpBotAuthenticationFailureReason;
import com.example.HelpBot.core.HelpBotCallback;
import com.example.HelpBot.core.HelpBotConfig;
import com.example.HelpBot.core.HelpBotErrorCode;
import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.core.HelpBotInitCallback;
import com.example.HelpBot.log.HBlogger;

import com.unity3d.player.UnityPlayer;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * HelpBot Unity Bridge for Android
 * 
 * 负责 Unity 与 Android HelpBot SDK 之间的通信
 * 
 * 设计要点：
 * 1. 使用 UnitySendMessage 将回调发送到 Unity
 * 2. JSON 序列化/反序列化参数
 * 3. 线程安全处理
 * 4. 完整的错误处理和日志记录
 */
public class HelpBotUnityBridge {
    private static final String TAG = "HelpBotUnityBridge";

    private final Context context;
    private String eventsGameObjectName;
    private String eventsMethodName;
    private String authFailureMethodName;

    /**
     * 构造函数
     * 
     * @param context Android Context
     */
    public HelpBotUnityBridge(@NonNull final Context context) {
        this.context = context;
        HBlogger.d(TAG, "HelpBotUnityBridge 已创建");
    }

    /**
     * 初始化 HelpBot SDK
     * 
     * @param configJson      配置 JSON 字符串
     * @param gameObjectName  Unity GameObject 名称
     * @param callbackMethod  回调方法名称
     */
    public void install(@NonNull final String configJson,
                       @NonNull final String gameObjectName,
                       @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "install: configJson=" + configJson);

        try {
            // 解析配置 JSON
            final HelpBotConfig config = parseConfig(configJson);

            // 创建初始化回调
            final HelpBotInitCallback callback = createInitCallback(gameObjectName, callbackMethod);

            // 调用 Android SDK
            HelpBot.install(context, config, callback);

        } catch (final Exception e) {
            HBlogger.e(TAG, "install 异常", e);
            sendInitFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INVALID_PARAMETER.getCode(),
                    "配置解析失败: " + e.getMessage());
        }
    }

    /**
     * 用户登录
     * 
     * @param token            JWT Token
     * @param loginConfigJson  登录配置 JSON 字符串
     * @param gameObjectName   Unity GameObject 名称
     * @param callbackMethod   回调方法名称
     */
    public void login(@NonNull final String token,
                     @Nullable final String loginConfigJson,
                     @NonNull final String gameObjectName,
                     @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "login: token=" + token.substring(0, Math.min(20, token.length())) + "...");

        try {
            // 解析登录配置
            Map<String, Object> loginConfig = null;
            if (loginConfigJson != null && !loginConfigJson.trim().isEmpty() && !loginConfigJson.equals("{}")) {
                loginConfig = parseJsonToMap(loginConfigJson);
            }

            // 创建回调
            final HelpBotCallback<Void> callback = createCallback(gameObjectName, callbackMethod);

            // 调用 Android SDK
            HelpBot.login(token, loginConfig, callback);

        } catch (final Exception e) {
            HBlogger.e(TAG, "login 异常", e);
            sendFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INVALID_PARAMETER.getCode(),
                    "登录参数解析失败: " + e.getMessage());
        }
    }

    /**
     * 显示对话窗口
     */
    public void showConversation() {
        HBlogger.d(TAG, "showConversation");
        try {
            HelpBot.showConversation(context);
        } catch (final Exception e) {
            HBlogger.e(TAG, "showConversation 异常", e);
        }
    }

    /**
     * 显示 FAQ
     * 
     * @param configJson 配置 JSON 字符串
     */
    public void showFAQs(@Nullable final String configJson) {
        HBlogger.d(TAG, "showFAQs: configJson=" + configJson);
        try {
            Map<String, Object> configMap = null;
            if (configJson != null && !configJson.trim().isEmpty() && !configJson.equals("{}")) {
                configMap = parseJsonToMap(configJson);
            } else {
                configMap = new HashMap<>();
            }
            HelpBot.showFAQs(context, configMap);
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQs 异常", e);
        }
    }

    /**
     * 用户登出
     * 
     * @param gameObjectName Unity GameObject 名称
     * @param callbackMethod 回调方法名称
     */
    public void logout(@NonNull final String gameObjectName,
                      @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "logout");
        try {
            final HelpBotCallback<Void> callback = createCallback(gameObjectName, callbackMethod);
            HelpBot.logoutAsync(callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "logout 异常", e);
            sendFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INTERNAL_ERROR.getCode(),
                    "登出失败: " + e.getMessage());
        }
    }

    /**
     * 销毁 SDK
     */
    public void destroy() {
        HBlogger.d(TAG, "destroy");
        try {
            HelpBot.destroy();
            eventsGameObjectName = null;
            eventsMethodName = null;
            authFailureMethodName = null;
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroy 异常", e);
        }
    }

    /**
     * 设置事件监听器
     * 
     * @param gameObjectName      Unity GameObject 名称
     * @param eventMethod         事件回调方法名称
     * @param authFailureMethod   认证失败回调方法名称
     */
    public void setEventsListener(@NonNull final String gameObjectName,
                                  @NonNull final String eventMethod,
                                  @NonNull final String authFailureMethod) {
        HBlogger.d(TAG, "setEventsListener");
        this.eventsGameObjectName = gameObjectName;
        this.eventsMethodName = eventMethod;
        this.authFailureMethodName = authFailureMethod;

        HelpBot.setEventsListener(new HelpBotEventsListener() {
            @Override
            public void onEventOccurred(@NonNull final String eventName, final Map<String, Object> data) {
                try {
                    // 将事件数据转换为 JSON 字符串
                    String dataJson = "{}";
                    if (data != null && !data.isEmpty()) {
                        dataJson = mapToJson(data);
                    }

                    // 发送到 Unity: "eventName|dataJson"
                    final String message = eventName + "|" + dataJson;
                    UnityPlayer.UnitySendMessage(eventsGameObjectName, eventsMethodName, message);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onEventOccurred 异常", e);
                }
            }

            @Override
            public void onUserAuthenticationFailure(final HelpBotAuthenticationFailureReason reason) {
                try {
                    final String reasonStr = reason != null ? reason.name() : "UNKNOWN";
                    UnityPlayer.UnitySendMessage(eventsGameObjectName, authFailureMethodName, reasonStr);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onUserAuthenticationFailure 异常", e);
                }
            }
        });
    }

    /**
     * 清除事件监听器
     */
    public void clearEventsListener() {
        HBlogger.d(TAG, "clearEventsListener");
        HelpBot.setEventsListener(null);
        eventsGameObjectName = null;
        eventsMethodName = null;
        authFailureMethodName = null;
    }

    /**
     * 更新主属性
     * 
     * @param attributesJson  属性 JSON 字符串
     * @param gameObjectName  Unity GameObject 名称
     * @param callbackMethod  回调方法名称
     */
    public void updateMasterAttributes(@NonNull final String attributesJson,
                                      @NonNull final String gameObjectName,
                                      @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "updateMasterAttributes: " + attributesJson);
        try {
            final Map<String, Object> attributes = parseJsonToMap(attributesJson);
            final HelpBotCallback<Void> callback = createCallback(gameObjectName, callbackMethod);
            HelpBot.updateMasterAttributes(attributes, callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateMasterAttributes 异常", e);
            sendFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INVALID_PARAMETER.getCode(),
                    "属性解析失败: " + e.getMessage());
        }
    }

    /**
     * 更新应用属性
     * 
     * @param attributesJson  属性 JSON 字符串
     * @param gameObjectName  Unity GameObject 名称
     * @param callbackMethod  回调方法名称
     */
    public void updateAppAttributes(@NonNull final String attributesJson,
                                   @NonNull final String gameObjectName,
                                   @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "updateAppAttributes: " + attributesJson);
        try {
            final Map<String, Object> attributes = parseJsonToMap(attributesJson);
            final HelpBotCallback<Void> callback = createCallback(gameObjectName, callbackMethod);
            HelpBot.updateAppAttributes(attributes, callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateAppAttributes 异常", e);
            sendFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INVALID_PARAMETER.getCode(),
                    "属性解析失败: " + e.getMessage());
        }
    }

    /**
     * 发送文本消息
     */
    public void sendMessage(@NonNull final String message,
                           @NonNull final String gameObjectName,
                           @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "sendMessage: " + message);
        try {
            final HelpBotCallback<Map<String, Object>> callback = createMapCallback(gameObjectName, callbackMethod);
            HelpBot.sendMessageAsync(message, callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "sendMessage 异常", e);
            sendMapFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INTERNAL_ERROR.getCode(),
                    "发送消息失败: " + e.getMessage());
        }
    }

    /**
     * 获取历史消息
     */
    public void getHistoryMessages(@NonNull final String gameObjectName,
                                   @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "getHistoryMessages");
        try {
            final HelpBotCallback<Map<String, Object>> callback = createMapCallback(gameObjectName, callbackMethod);
            HelpBot.getHistoryMessagesAsync(callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "getHistoryMessages 异常", e);
            sendMapFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INTERNAL_ERROR.getCode(),
                    "获取历史消息失败: " + e.getMessage());
        }
    }

    /**
     * 分页加载更多历史消息
     */
    public void loadMoreMessages(final int limit, final int offset,
                                @NonNull final String gameObjectName,
                                @NonNull final String callbackMethod) {
        HBlogger.d(TAG, "loadMoreMessages: limit=" + limit + ", offset=" + offset);
        try {
            final HelpBotCallback<Map<String, Object>> callback = createMapCallback(gameObjectName, callbackMethod);
            HelpBot.loadMoreMessagesAsync(limit, offset, callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "loadMoreMessages 异常", e);
            sendMapFailure(gameObjectName, callbackMethod,
                    HelpBotErrorCode.INTERNAL_ERROR.getCode(),
                    "加载更多消息失败: " + e.getMessage());
        }
    }

    /**
     * 显示 FAQ 分组页面
     */
    public void showFAQSection(@NonNull final String sectionPublishId,
                              @Nullable final String configJson) {
        HBlogger.d(TAG, "showFAQSection: " + sectionPublishId);
        try {
            Map<String, Object> configMap = null;
            if (configJson != null && !configJson.trim().isEmpty() && !configJson.equals("{}")) {
                configMap = parseJsonToMap(configJson);
            } else {
                configMap = new HashMap<>();
            }
            HelpBot.showFAQSection(context, sectionPublishId, configMap);
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQSection 异常", e);
        }
    }

    /**
     * 显示单个 FAQ
     */
    public void showSingleFAQ(@NonNull final String questionPublishId,
                             @Nullable final String configJson) {
        HBlogger.d(TAG, "showSingleFAQ: " + questionPublishId);
        try {
            Map<String, Object> configMap = null;
            if (configJson != null && !configJson.trim().isEmpty() && !configJson.equals("{}")) {
                configMap = parseJsonToMap(configJson);
            } else {
                configMap = new HashMap<>();
            }
            HelpBot.showSingleFAQ(context, questionPublishId, configMap);
        } catch (final Exception e) {
            HBlogger.e(TAG, "showSingleFAQ 异常", e);
        }
    }

    /**
     * 隐藏对话窗口
     */
    public void hideConversation() {
        HBlogger.d(TAG, "hideConversation");
        try {
            HelpBot.hideConversation();
        } catch (final Exception e) {
            HBlogger.e(TAG, "hideConversation 异常", e);
        }
    }

    /**
     * 检查对话窗口是否可见
     */
    public boolean isConversationVisible() {
        try {
            return HelpBot.isConversationVisible();
        } catch (final Exception e) {
            HBlogger.e(TAG, "isConversationVisible 异常", e);
            return false;
        }
    }

    /**
     * 关闭当前会话
     */
    public void closeSession() {
        HBlogger.d(TAG, "closeSession");
        try {
            HelpBot.closeSession();
        } catch (final Exception e) {
            HBlogger.e(TAG, "closeSession 异常", e);
        }
    }

    /**
     * 更新 SDK Meta 数据
     */
    public void updateSDKMeta(@NonNull final String metaJson) {
        HBlogger.d(TAG, "updateSDKMeta: " + metaJson);
        try {
            final Map<String, Object> meta = parseJsonToMap(metaJson);
            HelpBot.updateSDKMeta(meta);
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateSDKMeta 异常", e);
        }
    }

    /**
     * 更新自定义 Meta 数据
     */
    public void updateCustomMeta(@NonNull final String metaJson) {
        HBlogger.d(TAG, "updateCustomMeta: " + metaJson);
        try {
            final Map<String, Object> meta = parseJsonToMap(metaJson);
            HelpBot.updateCustomMeta(meta);
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateCustomMeta 异常", e);
        }
    }

    /**
     * 添加 Issue 标签
     */
    public void addIssueTags(@NonNull final String tagsJson) {
        HBlogger.d(TAG, "addIssueTags: " + tagsJson);
        try {
            final ArrayList<String> tags = parseJsonToList(tagsJson);
            HelpBot.addIssueTags(tags);
        } catch (final Exception e) {
            HBlogger.e(TAG, "addIssueTags 异常", e);
        }
    }

    /**
     * 移除 Issue 标签
     */
    public void removeIssueTags(@NonNull final String tagsJson) {
        HBlogger.d(TAG, "removeIssueTags: " + tagsJson);
        try {
            final ArrayList<String> tags = parseJsonToList(tagsJson);
            HelpBot.removeIssueTags(tags);
        } catch (final Exception e) {
            HBlogger.e(TAG, "removeIssueTags 异常", e);
        }
    }

    /**
     * 启用/禁用 SSE 通知
     */
    public void enableSseNotification(final boolean enable) {
        HBlogger.d(TAG, "enableSseNotification: " + enable);
        try {
            HelpBot.enableSseNotification(enable);
        } catch (final Exception e) {
            HBlogger.e(TAG, "enableSseNotification 异常", e);
        }
    }

    /**
     * 检查 SSE 通知状态
     */
    public boolean isSseNotificationEnabled() {
        try {
            return HelpBot.isSseNotificationEnabled();
        } catch (final Exception e) {
            HBlogger.e(TAG, "isSseNotificationEnabled 异常", e);
            return false;
        }
    }

    /**
     * 检查 Debug 模式
     */
    public boolean isDebugMode() {
        try {
            return HelpBot.isDebugMode();
        } catch (final Exception e) {
            HBlogger.e(TAG, "isDebugMode 异常", e);
            return false;
        }
    }

    /**
     * 检查初始化状态
     */
    public boolean isInitialized() {
        try {
            return HelpBot.isInitialized();
        } catch (final Exception e) {
            HBlogger.e(TAG, "isInitialized 异常", e);
            return false;
        }
    }

    /**
     * 获取 WebSDK 健康快照
     */
    public String getWebSdkHealthSnapshot() {
        try {
            final Map<String, Object> snapshot = HelpBot.getWebSdkHealthSnapshot();
            return mapToJson(snapshot);
        } catch (final Exception e) {
            HBlogger.e(TAG, "getWebSdkHealthSnapshot 异常", e);
            return "{}";
        }
    }

    /**
     * 上报系统信息到服务器
     */
    public void reportSystemInfoToServer() {
        HBlogger.d(TAG, "reportSystemInfoToServer");
        try {
            HelpBot.reportSystemInfoToServer();
        } catch (final Exception e) {
            HBlogger.e(TAG, "reportSystemInfoToServer 异常", e);
        }
    }

    /**
     * 设置通知小图标资源 ID (Android Only)
     */
    public void setNotificationSmallIconResId(final int resId) {
        HBlogger.d(TAG, "setNotificationSmallIconResId: " + resId);
        try {
            HelpBot.setNotificationSmallIconResId(resId);
        } catch (final Exception e) {
            HBlogger.e(TAG, "setNotificationSmallIconResId 异常", e);
        }
    }

    /**
     * 设置通知渠道 ID (Android Only)
     */
    public void setNotificationChannelId(@NonNull final String channelId) {
        HBlogger.d(TAG, "setNotificationChannelId: " + channelId);
        try {
            HelpBot.setNotificationChannelId(channelId);
        } catch (final Exception e) {
            HBlogger.e(TAG, "setNotificationChannelId 异常", e);
        }
    }

    // ==================== 私有辅助方法 ====================

    /**
     * 解析配置 JSON
     */
    private HelpBotConfig parseConfig(@NonNull final String configJson) throws JSONException {
        final JSONObject json = new JSONObject(configJson);

        final HelpBotConfig.Builder builder = new HelpBotConfig.Builder()
                .channelId(json.getString("channelId"))
                .domain(json.getString("domain"));

        if (json.has("fullPrivacyMode")) {
            builder.fullPrivacyMode(json.getBoolean("fullPrivacyMode"));
        }
        if (json.has("enableSseNotification")) {
            builder.enableSseNotification(json.getBoolean("enableSseNotification"));
        }
        if (json.has("initTimeoutMs")) {
            builder.initTimeout(json.getInt("initTimeoutMs"));
        }
        if (json.has("webViewLoadTimeoutMs")) {
            builder.webViewLoadTimeout(json.getInt("webViewLoadTimeoutMs"));
        }
        if (json.has("useDevApi")) {
            builder.useDevApi(json.getBoolean("useDevApi"));
        }
        if (json.has("companyId")) {
            builder.companyId(json.getString("companyId"));
        }
        if (json.has("userId")) {
            builder.userId(json.getString("userId"));
        }
        if (json.has("preGeneratedToken")) {
            builder.preGeneratedToken(json.getString("preGeneratedToken"));
        }

        // 添加自定义配置
        final Iterator<String> keys = json.keys();
        while (keys.hasNext()) {
            final String key = keys.next();
            if (!isReservedKey(key)) {
                builder.addCustomConfig(key, json.get(key));
            }
        }

        return builder.build();
    }

    /**
     * 判断是否为保留键
     */
    private boolean isReservedKey(@NonNull final String key) {
        return key.equals("channelId") || key.equals("domain") ||
               key.equals("fullPrivacyMode") || key.equals("enableSseNotification") ||
               key.equals("initTimeoutMs") || key.equals("webViewLoadTimeoutMs") ||
               key.equals("useDevApi") || key.equals("companyId") ||
               key.equals("userId") || key.equals("preGeneratedToken");
    }

    /**
     * 解析 JSON 字符串为 Map
     */
    private Map<String, Object> parseJsonToMap(@NonNull final String jsonStr) throws JSONException {
        final JSONObject json = new JSONObject(jsonStr);
        final Map<String, Object> map = new HashMap<>();

        final Iterator<String> keys = json.keys();
        while (keys.hasNext()) {
            final String key = keys.next();
            map.put(key, json.get(key));
        }

        return map;
    }

    /**
     * 将 Map 转换为 JSON 字符串
     */
    private String mapToJson(@NonNull final Map<String, Object> map) {
        try {
            final JSONObject json = new JSONObject(map);
            return json.toString();
        } catch (final Exception e) {
            HBlogger.e(TAG, "mapToJson 异常", e);
            return "{}";
        }
    }

    /**
     * 创建初始化回调
     */
    private HelpBotInitCallback createInitCallback(@NonNull final String gameObjectName,
                                                   @NonNull final String callbackMethod) {
        if (callbackMethod.equals("null")) {
            return null;
        }

        return new HelpBotInitCallback() {
            @Override
            public void onInitStart() {
                UnityPlayer.UnitySendMessage(gameObjectName, "OnInitStart", callbackMethod);
            }

            @Override
            public void onInitProgress(final int progress, @NonNull final String message) {
                // 格式: "callbackMethod|progress|message"
                final String msg = callbackMethod + "|" + progress + "|" + message;
                UnityPlayer.UnitySendMessage(gameObjectName, "OnInitProgress", msg);
            }

            @Override
            public void onInitSuccess() {
                UnityPlayer.UnitySendMessage(gameObjectName, "OnInitSuccess", callbackMethod);
            }

            @Override
            public void onInitFailure(@NonNull final HelpBotErrorCode errorCode,
                                     @NonNull final String errorMessage) {
                // 格式: "callbackMethod|errorCode|errorMessage"
                final String msg = callbackMethod + "|" + errorCode.getCode() + "|" + errorMessage;
                UnityPlayer.UnitySendMessage(gameObjectName, "OnInitFailure", msg);
            }
        };
    }

    /**
     * 创建通用回调
     */
    private HelpBotCallback<Void> createCallback(@NonNull final String gameObjectName,
                                                 @NonNull final String callbackMethod) {
        if (callbackMethod.equals("null")) {
            return null;
        }

        return new HelpBotCallback<Void>() {
            @Override
            public void onSuccess(@Nullable final Void result) {
                UnityPlayer.UnitySendMessage(gameObjectName, "OnSuccess", callbackMethod);
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode,
                                 @NonNull final String errorMessage) {
                // 格式: "callbackMethod|errorCode|errorMessage"
                final String msg = callbackMethod + "|" + errorCode.getCode() + "|" + errorMessage;
                UnityPlayer.UnitySendMessage(gameObjectName, "OnFailure", msg);
            }
        };
    }

    /**
     * 创建支持 Map 数据返回的回调
     */
    private HelpBotCallback<Map<String, Object>> createMapCallback(@NonNull final String gameObjectName,
                                                                    @NonNull final String callbackMethod) {
        if (callbackMethod.equals("null")) {
            return null;
        }

        return new HelpBotCallback<Map<String, Object>>() {
            @Override
            public void onSuccess(@Nullable final Map<String, Object> result) {
                try {
                    // 将结果转换为 JSON 字符串
                    String resultJson = "{}";
                    if (result != null && !result.isEmpty()) {
                        resultJson = mapToJson(result);
                    }

                    // 发送到 Unity: "callbackMethod|resultJson"
                    final String msg = callbackMethod + "|" + resultJson;
                    UnityPlayer.UnitySendMessage(gameObjectName, "OnSuccessWithData", msg);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "createMapCallback.onSuccess 异常", e);
                }
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode,
                                 @NonNull final String errorMessage) {
                // 格式: "callbackMethod|errorCode|errorMessage"
                final String msg = callbackMethod + "|" + errorCode.getCode() + "|" + errorMessage;
                UnityPlayer.UnitySendMessage(gameObjectName, "OnFailure", msg);
            }
        };
    }

    /**
     * 发送 Map 回调失败消息到 Unity
     */
    private void sendMapFailure(@NonNull final String gameObjectName,
                               @NonNull final String callbackMethod,
                               final int errorCode,
                               @NonNull final String errorMessage) {
        final String msg = callbackMethod + "|" + errorCode + "|" + errorMessage;
        UnityPlayer.UnitySendMessage(gameObjectName, "OnFailure", msg);
    }

    /**
     * 解析 JSON 数组为 ArrayList
     */
    private ArrayList<String> parseJsonToList(@NonNull final String jsonStr) throws JSONException {
        final JSONArray jsonArray = new JSONArray(jsonStr);
        final ArrayList<String> list = new ArrayList<>();

        for (int i = 0; i < jsonArray.length(); i++) {
            list.add(jsonArray.getString(i));
        }

        return list;
    }

    /**
     * 发送初始化失败消息到 Unity
     */
    private void sendInitFailure(@NonNull final String gameObjectName,
                                 @NonNull final String callbackMethod,
                                 final int errorCode,
                                 @NonNull final String errorMessage) {
        final String msg = callbackMethod + "|" + errorCode + "|" + errorMessage;
        UnityPlayer.UnitySendMessage(gameObjectName, "OnInitFailure", msg);
    }

    /**
     * 发送失败消息到 Unity
     */
    private void sendFailure(@NonNull final String gameObjectName,
                            @NonNull final String callbackMethod,
                            final int errorCode,
                            @NonNull final String errorMessage) {
        final String msg = callbackMethod + "|" + errorCode + "|" + errorMessage;
        UnityPlayer.UnitySendMessage(gameObjectName, "OnFailure", msg);
    }
}
