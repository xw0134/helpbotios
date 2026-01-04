package com.helpbot.ue;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.core.HelpBotAuthenticationFailureReason;
import com.example.HelpBot.core.HelpBotCallback;
import com.example.HelpBot.core.HelpBotErrorCode;
import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.core.HelpBotInitCallback;
import com.example.HelpBot.log.HBlogger;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * HelpBot Unreal Engine Java 桥。
 *
 * 设计目标：
 * 1) UE(C++) 侧仅处理字符串与 JNI，复杂对象统一用 JSON 透传。
 * 2) 通过 HelpBotEventsListener 将 Android SDK 事件回调到 UE。
 * 3) 统一 try-catch，避免桥接层异常导致宿主（UE Activity）崩溃。
 *
 * 事件名约定（透传到 UE 的 OnHelpBotEvent）：
 * - HB_INSTALL_START / HB_INSTALL_PROGRESS / HB_INSTALL_SUCCESS / HB_INSTALL_FAILURE
 * - HB_LOGIN_SUCCESS / HB_LOGIN_FAILURE
 * - HB_LOGOUT_SUCCESS / HB_LOGOUT_FAILURE
 * - HB_SEND_MESSAGE_SUCCESS / HB_SEND_MESSAGE_FAILURE
 * - HB_SDK_EVENT（通用 SDK 事件：onEventOccurred）
 * - HB_AUTH_FAILURE（鉴权失败）
 */
public final class HelpBotUEBridge {
    private static final String TAG = "HelpBotUEBridge";

    private static volatile boolean listenerBound = false;
    @Nullable
    private static volatile Context appContext;

    private HelpBotUEBridge() {
    }

    // =========================
    // Native 回调（由 UE 实现）
    // =========================
    private static native void nativeOnEvent(@NonNull final String eventName, @NonNull final String payloadJson);

    private static void emit(@NonNull final String eventName, @Nullable final String payloadJson) {
        try {
            nativeOnEvent(eventName, payloadJson == null ? "" : payloadJson);
        } catch (final Throwable t) {
            // Native 不可用时（极早期/被裁剪）避免崩溃
            HBlogger.e(TAG, "emit nativeOnEvent 异常", t);
        }
    }

    private static void ensureListenerBound() {
        if (listenerBound) {
            return;
        }
        try {
            HelpBot.setHelpBotEventsListener(new HelpBotEventsListener() {
                @Override
                public void onEventOccurred(@NonNull final String eventName, final Map<String, Object> data) {
                    try {
                        final JSONObject json = mapToJson(data);
                        emit("HB_SDK_EVENT", buildPayload(eventName, json));
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "onEventOccurred 异常", e);
                    }
                }

                @Override
                public void onUserAuthenticationFailure(final HelpBotAuthenticationFailureReason reason) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("reason", String.valueOf(reason));
                        emit("HB_AUTH_FAILURE", payload.toString());
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "onUserAuthenticationFailure 异常", e);
                    }
                }
            });
            listenerBound = true;
        } catch (final Exception e) {
            HBlogger.e(TAG, "ensureListenerBound 异常", e);
        }
    }

    @NonNull
    private static String buildPayload(@NonNull final String eventName, @Nullable final JSONObject data) {
        try {
            final JSONObject payload = new JSONObject();
            payload.put("eventName", eventName);
            if (data != null) {
                payload.put("data", data);
            }
            return payload.toString();
        } catch (final Exception ignored) {
            return "{\"eventName\":\"" + eventName + "\"}";
        }
    }

    // =========================
    // UE 调用入口（C++ -> Java）
    // =========================

    public static void install(@NonNull final Activity activity,
                               @NonNull final String channelId,
                               @NonNull final String domain,
                               @Nullable final String configJson) {
        try {
            appContext = activity.getApplicationContext();
            ensureListenerBound();

            final Map<String, Object> cfg = jsonToMapSafe(configJson);
            HelpBot.install(appContext, channelId, domain, cfg, new HelpBotInitCallback() {
                @Override
                public void onStart() {
                    emit("HB_INSTALL_START", "{}");
                }

                @Override
                public void onProgress(final int progress, @NonNull final String message) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("progress", progress);
                        payload.put("message", message);
                        emit("HB_INSTALL_PROGRESS", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }

                @Override
                public void onSuccess() {
                    emit("HB_INSTALL_SUCCESS", "{}");
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_INSTALL_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "install 异常", e);
            try {
                final JSONObject payload = new JSONObject();
                payload.put("code", "INTERNAL_ERROR");
                payload.put("message", String.valueOf(e.getMessage()));
                emit("HB_INSTALL_FAILURE", payload.toString());
            } catch (final Exception ignored) {
                emit("HB_INSTALL_FAILURE", "{\"code\":\"INTERNAL_ERROR\"}");
            }
        }
    }

    public static void login(@NonNull final String token, @Nullable final String loginConfigJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> cfg = jsonToMapSafe(loginConfigJson);
            HelpBot.login(token, cfg, new HelpBotCallback<Void>() {
                @Override
                public void onSuccess(final Void result) {
                    emit("HB_LOGIN_SUCCESS", "{}");
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_LOGIN_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "login 异常", e);
            emit("HB_LOGIN_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void showConversation(@NonNull final Activity activity) {
        try {
            ensureListenerBound();
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.showConversation(activity);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_SHOW_CONVERSATION_FAILURE", payload.toString());
                return;
            }
            emit("HB_SHOW_CONVERSATION_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "showConversation 异常", e);
            emit("HB_SHOW_CONVERSATION_FAILURE",
                    "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void hideConversation() {
        try {
            ensureListenerBound();
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.hideConversation();
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_HIDE_CONVERSATION_FAILURE", payload.toString());
                return;
            }
            emit("HB_HIDE_CONVERSATION_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "hideConversation 异常", e);
            emit("HB_HIDE_CONVERSATION_FAILURE",
                    "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void logout() {
        try {
            ensureListenerBound();
            HelpBot.logoutAsync(new HelpBotCallback<Void>() {
                @Override
                public void onSuccess(final Void result) {
                    emit("HB_LOGOUT_SUCCESS", "{}");
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_LOGOUT_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "logout 异常", e);
            emit("HB_LOGOUT_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void sendMessage(@NonNull final String message) {
        try {
            ensureListenerBound();
            HelpBot.sendMessageAsync(message, new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(final Map<String, Object> result) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("data", mapToJson(result));
                        emit("HB_SEND_MESSAGE_SUCCESS", payload.toString());
                    } catch (final Exception ignored) {
                        emit("HB_SEND_MESSAGE_SUCCESS", "{}");
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_SEND_MESSAGE_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "sendMessage 异常", e);
            emit("HB_SEND_MESSAGE_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void enableSseNotification(final boolean enable) {
        try {
            HelpBot.enableSseNotification(enable);
        } catch (final Exception e) {
            HBlogger.e(TAG, "enableSseNotification 异常", e);
        }
    }

    @NonNull
    public static String getSdkVersion() {
        try {
            return HelpBot.getSDKVersion();
        } catch (final Exception e) {
            return "";
        }
    }

    // ==================== P0: 历史消息功能 ====================

    public static void getHistoryMessages() {
        try {
            ensureListenerBound();
            HelpBot.getHistoryMessagesAsync(new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(final Map<String, Object> result) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("data", mapToJson(result));
                        emit("HB_GET_HISTORY_MESSAGES_SUCCESS", payload.toString());
                    } catch (final Exception ignored) {
                        emit("HB_GET_HISTORY_MESSAGES_SUCCESS", "{}");
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_GET_HISTORY_MESSAGES_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "getHistoryMessages 异常", e);
            emit("HB_GET_HISTORY_MESSAGES_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void loadMoreMessages(final int limit, final int offset) {
        try {
            ensureListenerBound();
            HelpBot.loadMoreMessagesAsync(limit, offset, new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(final Map<String, Object> result) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("data", mapToJson(result));
                        emit("HB_LOAD_MORE_MESSAGES_SUCCESS", payload.toString());
                    } catch (final Exception ignored) {
                        emit("HB_LOAD_MORE_MESSAGES_SUCCESS", "{}");
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        final JSONObject payload = new JSONObject();
                        payload.put("code", String.valueOf(errorCode));
                        payload.put("message", errorMessage);
                        emit("HB_LOAD_MORE_MESSAGES_FAILURE", payload.toString());
                    } catch (final Exception ignored) {
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "loadMoreMessages 异常", e);
            emit("HB_LOAD_MORE_MESSAGES_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    // ==================== P0: FAQ 功能 ====================

    public static void showFAQs(@NonNull final Activity activity, @Nullable final String configJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> cfg = jsonToMapSafe(configJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.showFAQs(activity, cfg);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_SHOW_FAQS_FAILURE", payload.toString());
                return;
            }
            emit("HB_SHOW_FAQS_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQs 异常", e);
            emit("HB_SHOW_FAQS_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void showFAQsSimple(@NonNull final Activity activity) {
        showFAQs(activity, "{}");
    }

    public static void showFAQSection(@NonNull final Activity activity, @NonNull final String sectionPublishId, @Nullable final String configJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> cfg = jsonToMapSafe(configJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.showFAQSection(activity, sectionPublishId, cfg);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_SHOW_FAQ_SECTION_FAILURE", payload.toString());
                return;
            }
            emit("HB_SHOW_FAQ_SECTION_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQSection 异常", e);
            emit("HB_SHOW_FAQ_SECTION_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void showFAQSectionSimple(@NonNull final Activity activity, @NonNull final String sectionPublishId) {
        showFAQSection(activity, sectionPublishId, "{}");
    }

    public static void showSingleFAQ(@NonNull final Activity activity, @NonNull final String questionPublishId, @Nullable final String configJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> cfg = jsonToMapSafe(configJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.showSingleFAQ(activity, questionPublishId, cfg);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_SHOW_SINGLE_FAQ_FAILURE", payload.toString());
                return;
            }
            emit("HB_SHOW_SINGLE_FAQ_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "showSingleFAQ 异常", e);
            emit("HB_SHOW_SINGLE_FAQ_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void showSingleFAQSimple(@NonNull final Activity activity, @NonNull final String questionPublishId) {
        showSingleFAQ(activity, questionPublishId, "{}");
    }

    // ==================== P0: Meta 数据更新 ====================

    public static void updateSDKMeta(@Nullable final String metaJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> meta = jsonToMapSafe(metaJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.updateSDKMeta(meta);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_UPDATE_SDK_META_FAILURE", payload.toString());
                return;
            }
            emit("HB_UPDATE_SDK_META_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateSDKMeta 异常", e);
            emit("HB_UPDATE_SDK_META_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void updateCustomMeta(@Nullable final String customMetaJson) {
        try {
            ensureListenerBound();
            final Map<String, Object> meta = jsonToMapSafe(customMetaJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.updateCustomMeta(meta);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_UPDATE_CUSTOM_META_FAILURE", payload.toString());
                return;
            }
            emit("HB_UPDATE_CUSTOM_META_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateCustomMeta 异常", e);
            emit("HB_UPDATE_CUSTOM_META_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void reportSystemInfoToServer() {
        try {
            ensureListenerBound();
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.reportSystemInfoToServer();
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_REPORT_SYSTEM_INFO_FAILURE", payload.toString());
                return;
            }
            emit("HB_REPORT_SYSTEM_INFO_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "reportSystemInfoToServer 异常", e);
            emit("HB_REPORT_SYSTEM_INFO_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    // ==================== P0: 会话管理 ====================

    public static void closeSession() {
        try {
            ensureListenerBound();
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.closeSession();
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_CLOSE_SESSION_FAILURE", payload.toString());
                return;
            }
            emit("HB_CLOSE_SESSION_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "closeSession 异常", e);
            emit("HB_CLOSE_SESSION_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void destroy() {
        try {
            HelpBot.destroy();
            emit("HB_DESTROY_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroy 异常", e);
            emit("HB_DESTROY_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    // ==================== P1: Issue 标签管理 ====================

    public static void addIssueTags(@Nullable final String tagsJson) {
        try {
            ensureListenerBound();
            final ArrayList<String> tags = jsonArrayToList(tagsJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.addIssueTags(tags);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_ADD_ISSUE_TAGS_FAILURE", payload.toString());
                return;
            }
            emit("HB_ADD_ISSUE_TAGS_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "addIssueTags 异常", e);
            emit("HB_ADD_ISSUE_TAGS_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    public static void removeIssueTags(@Nullable final String tagsJson) {
        try {
            ensureListenerBound();
            final ArrayList<String> tags = jsonArrayToList(tagsJson);
            final com.example.HelpBot.core.HelpBotResult<Void> result = HelpBot.removeIssueTags(tags);
            if (result != null && result.isFailure()) {
                final JSONObject payload = new JSONObject();
                payload.put("code", String.valueOf(result.getErrorCode()));
                payload.put("message", String.valueOf(result.getErrorMessage()));
                emit("HB_REMOVE_ISSUE_TAGS_FAILURE", payload.toString());
                return;
            }
            emit("HB_REMOVE_ISSUE_TAGS_SUCCESS", "{}");
        } catch (final Exception e) {
            HBlogger.e(TAG, "removeIssueTags 异常", e);
            emit("HB_REMOVE_ISSUE_TAGS_FAILURE", "{\"code\":\"INTERNAL_ERROR\",\"message\":\"" + safeString(e.getMessage()) + "\"}");
        }
    }

    // ==================== P1: SDK 信息查询 ====================

    public static boolean isInitialized() {
        try {
            return HelpBot.isInitialized();
        } catch (final Exception e) {
            return false;
        }
    }

    public static boolean isConversationVisible() {
        try {
            return HelpBot.isConversationVisible();
        } catch (final Exception e) {
            return false;
        }
    }

    public static boolean isSseNotificationEnabled() {
        try {
            return HelpBot.isSseNotificationEnabled();
        } catch (final Exception e) {
            return false;
        }
    }

    @NonNull
    public static String getWebSdkHealthSnapshot() {
        try {
            final Map<String, Object> snapshot = HelpBot.getWebSdkHealthSnapshot();
            return mapToJson(snapshot).toString();
        } catch (final Exception e) {
            return "{}";
        }
    }

    // =========================
    // JSON / Map 工具（安全）
    // =========================

    @NonNull
    private static Map<String, Object> jsonToMapSafe(@Nullable final String json) {
        try {
            if (json == null || json.trim().isEmpty()) {
                return new HashMap<>();
            }
            final JSONObject obj = new JSONObject(json);
            return jsonObjectToMap(obj);
        } catch (final Exception ignored) {
            return new HashMap<>();
        }
    }

    @NonNull
    private static Map<String, Object> jsonObjectToMap(@NonNull final JSONObject obj) {
        final Map<String, Object> map = new HashMap<>();
        try {
            final Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                final String key = keys.next();
                final Object value = obj.opt(key);
                map.put(key, jsonValueToJava(value));
            }
        } catch (final Exception ignored) {
        }
        return map;
    }

    @Nullable
    private static Object jsonValueToJava(@Nullable final Object value) {
        try {
            if (value == null || value == JSONObject.NULL) {
                return null;
            }
            if (value instanceof JSONObject) {
                return jsonObjectToMap((JSONObject) value);
            }
            if (value instanceof JSONArray) {
                final JSONArray arr = (JSONArray) value;
                final int len = arr.length();
                final List<Object> list = new ArrayList<>(Math.max(len, 0));
                for (int i = 0; i < len; i++) {
                    list.add(jsonValueToJava(arr.opt(i)));
                }
                return list;
            }
            // String / Boolean / Number 等直接返回
            return value;
        } catch (final Exception ignored) {
            return null;
        }
    }

    @NonNull
    private static JSONObject mapToJson(@Nullable final Map<String, Object> map) {
        final JSONObject obj = new JSONObject();
        try {
            if (map == null || map.isEmpty()) {
                return obj;
            }
            for (final Map.Entry<String, Object> e : map.entrySet()) {
                if (e == null) {
                    continue;
                }
                obj.put(e.getKey(), javaValueToJson(e.getValue()));
            }
        } catch (final Exception ignored) {
        }
        return obj;
    }

    @Nullable
    private static Object javaValueToJson(@Nullable final Object value) {
        try {
            if (value == null) {
                return JSONObject.NULL;
            }
            if (value instanceof Map) {
                //noinspection unchecked
                return mapToJson((Map<String, Object>) value);
            }
            if (value instanceof Iterable) {
                final JSONArray jsonArr = new JSONArray();
                for (final Object v : (Iterable<?>) value) {
                    jsonArr.put(javaValueToJson(v));
                }
                return jsonArr;
            }
            return value;
        } catch (final Exception ignored) {
            return JSONObject.NULL;
        }
    }

    @NonNull
    private static ArrayList<String> jsonArrayToList(@Nullable final String json) {
        final ArrayList<String> list = new ArrayList<>();
        try {
            if (json == null || json.trim().isEmpty()) {
                return list;
            }
            final JSONArray arr = new JSONArray(json);
            for (int i = 0; i < arr.length(); i++) {
                final String item = arr.optString(i);
                if (item != null && !item.trim().isEmpty()) {
                    list.add(item);
                }
            }
        } catch (final Exception ignored) {
        }
        return list;
    }

    @NonNull
    private static String safeString(@Nullable final String s) {
        return s == null ? "" : s.replace("\"", "\\\"");
    }
}


