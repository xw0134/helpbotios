package com.example.HelpBot.chat;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import com.example.HelpBot.HelpBot;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.notification.HelpBotNotificationHelper;
import com.example.HelpBot.utils.JsonUtils;
import com.example.HelpBot.utils.Utils;
import com.example.HelpBot.web.HelpBotWebViewSession;
import com.example.HelpBot.thread.HelpBotThreadPool;

import android.webkit.JavascriptInterface;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Iterator;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class ChatToNativeBridge {
    private static final String TAG = "ChatToNativeBridge";
    // JSBridge 单次 payload 必须严格限制，避免主线程 DoS/ANR
    private static final int MAX_PAYLOAD_CHARS = 128 * 1024; // 约 128K 字符（与 Web 侧约束一致即可）
    private static final int MAX_EVENT_NAME_LENGTH = 64;
    private static final int MAX_EVENTS_PER_PAYLOAD = 50;
    private static final int MAX_WIDGET_TOGGLE_CHARS = 10 * 1024;
    private static final int MAX_WEBCHAT_ERROR_CHARS = 10 * 1024;
    private static final int MAX_ISSUE_EXISTS_CHARS = 1024;
    private static final int MAX_REMOVE_LOCAL_STORAGE_CHARS = 1024;
    private static final int MAX_SET_LOCAL_STORAGE_CHARS = 100 * 1024;
    private static final int MAX_SSE_MESSAGE_CHARS = 10 * 1024;
    private final EventProxy delegate;
    private final Context appContext;
    private boolean isWebSdkConfigLoaded;
    private final ChatEventsHandler eventsHandler;

    public ChatToNativeBridge(final EventProxy delegate, final ChatEventsHandler eventsHandler) {
        this.appContext = null;
        this.delegate = delegate;
        this.eventsHandler = eventsHandler;
    }

    /**
     * 使用 applicationContext，避免持有 Activity 导致内存泄漏。
     */
    public ChatToNativeBridge(final Context context, final EventProxy delegate, final ChatEventsHandler eventsHandler) {
        this.appContext = (context == null) ? null : context.getApplicationContext();
        this.delegate = delegate;
        this.eventsHandler = eventsHandler;
    }

    @JavascriptInterface
    public void sendEvent(final String data) {
        if (this.delegate == null) {
            HBlogger.w(TAG, "sendEvent: delegate 为 null");
            return;
        }

        if (isEmptyPayload("sendEvent", data)) {
            return;
        }

        if (isPayloadTooLarge("sendEvent", data, MAX_PAYLOAD_CHARS)) {
            return;
        }

        // 仅在 debug 打印摘要，避免敏感数据落日志（release 已全禁）
        HBlogger.d(TAG, "从 WebView 接收到事件数据，大小: " + data.length());

        final String payload = data;
        // 将 JSON 解析与 Map 转换移到后台线程，防止 WebView 主线程卡顿/ANR
        HelpBotThreadPool.getInstance().submit(() -> parseAndDispatchEvents(payload));
    }

    private void parseAndDispatchEvents(@NonNull final String data) {
        final long startMs = SystemClock.uptimeMillis();
        try {
            final JSONObject passedData = new JSONObject(data);
            final Iterator<String> events = passedData.keys();
            int eventCount = 0;

            while (events.hasNext() && eventCount < MAX_EVENTS_PER_PAYLOAD) {
                final String event = events.next();
                if (!isValidEventName(event)) {
                    HBlogger.w(TAG, "sendEvent: 事件名称无效，已跳过");
                    continue;
                }

                final String associatedData = passedData.optString(event, "");
                // 透传给宿主
                try {
                    this.delegate.sendEvent(event, JsonUtils.jsonStringToMap(associatedData));
                } catch (final Exception e) {
                    HBlogger.e(TAG, "sendEvent: delegate.sendEvent 异常", e);
                }

                // 关键事件：用于解锁 install/login 的等待
                if ("SDK_READY".equals(event)) {
                    try {
                        HelpBotWebViewSession.getInstance().notifyWebSdkSdkReady(associatedData);
                    } catch (final Exception ignored) {
                    }
                    // Web 侧登录完成并发出 SDK_READY，
                    // SDK 切换为“已登录确认”，保证后续 showConversation 等流程可继续。
                    try {
                        HelpBot.markLoginConfirmedFromWeb();
                    } catch (final Exception ignored) {
                    }
                } else if ("SDK_ERROR".equals(event)) {
                    try {
                        HelpBotWebViewSession.getInstance().notifyWebSdkLoginFailed("websdk_error", associatedData);
                    } catch (final Exception ignored) {
                    }
                } else if ("USER_AUTHENTICATION_FAILED".equals(event)) {
                    try {
                        HelpBotWebViewSession.getInstance().notifyWebSdkLoginFailed("user_authentication_failed",
                                associatedData);
                    } catch (final Exception ignored) {
                    }
                }

                eventCount++;
            }

            if (eventCount >= MAX_EVENTS_PER_PAYLOAD) {
                HBlogger.w(TAG, "sendEvent: 事件过多 (" + eventCount + ")，已截断");
            }
        } catch (final JSONException e) {
            HBlogger.e(TAG, "sendEvent: JSON 解析错误", e);
        } catch (final Exception e) {
            HBlogger.e(TAG, "sendEvent: 未知错误", e);
        } finally {
            final long cost = SystemClock.uptimeMillis() - startMs;
            if (cost > 200L) {
                HBlogger.w(TAG, String.format(Locale.ROOT, "sendEvent 解析耗时=%dms", cost));
            }
        }
    }

    private static boolean isValidEventName(@Nullable final String event) {
        if (event == null) {
            return false;
        }
        final String e = event.trim();
        if (e.isEmpty() || e.length() > MAX_EVENT_NAME_LENGTH) {
            return false;
        }
        // 仅允许 A-Z / 0-9 / _ ，防止宿主被注入奇怪 key（例如 "__proto__" 类）
        for (int i = 0; i < e.length(); i++) {
            final char c = e.charAt(i);
            final boolean ok = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    @JavascriptInterface
    public void widgetToggle(final String data) {
        if (isEmptyPayload("widgetToggle", data)) {
            return;
        }
        if (isPayloadTooLarge("widgetToggle", data, MAX_WIDGET_TOGGLE_CHARS)) {
            return;
        }
        if (!this.isWebSdkConfigLoaded) {
            HBlogger.w(TAG, "widgetToggle: WebSDK 配置尚未加载");
            return;
        }
        HBlogger.d(TAG, "WebChat 组件切换: " + data);
        try {
            final JSONObject passedData = new JSONObject(data);
            final boolean visible = passedData.optBoolean("visible", false);
            if (visible) {
                this.eventsHandler.onWebchatLoaded();
            } else {
                this.eventsHandler.onWebchatClosed();
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "关闭 WebChat 时出错", e);
        }
    }

    @JavascriptInterface
    public void onWebSdkConfigLoad() {
        HBlogger.d(TAG, "接收到 WebSDK 配置加载完成事件");
        if (this.isWebSdkConfigLoaded) {
            return;
        }
        this.isWebSdkConfigLoaded = true;
        this.eventsHandler.onWebchatLoaded();
    }

    @JavascriptInterface
    public void setIssueExistsFlag(final String data) {
        if (isPayloadTooLarge("setIssueExistsFlag", data, MAX_ISSUE_EXISTS_CHARS)) {
            return;
        }
        HBlogger.d(TAG, "收到设置 Issue 存在标志的事件 - " + data);
        this.eventsHandler.setIssueExistsForUser(data);
    }

    @JavascriptInterface
    public void setLocalStorage(final String data) {
        if (isPayloadTooLarge("setLocalStorage", data, MAX_SET_LOCAL_STORAGE_CHARS)) {
            return;
        }
        HBlogger.d(TAG, "从 WebView 收到将数据存入本地存储的事件");
        this.eventsHandler.onSetLocalStorage(data);
    }

    @JavascriptInterface
    public void removeLocalStorage(final String data) {
        if (isPayloadTooLarge("removeLocalStorage", data, MAX_REMOVE_LOCAL_STORAGE_CHARS)) {
            return;
        }
        HBlogger.d(TAG, "从 WebView 收到从本地存储删除数据的事件");
        this.eventsHandler.onRemoveLocalStorage(data);
    }

    @JavascriptInterface
    public void getHelpCenterData() {
        HBlogger.d(TAG, "从 WebView 收到获取帮助中心额外信息的事件");
        this.eventsHandler.getHelpCenterData();
    }

    @JavascriptInterface
    public void onWebchatError(final String data) {
        if (isPayloadTooLarge("onWebchatError", data, MAX_WEBCHAT_ERROR_CHARS)) {
            return;
        }
        HBlogger.e(TAG, "收到来自 WebChat 的错误，错误数据: " + data);
        try {
            final JSONObject errorData = new JSONObject(data);
            final String errorMessage = errorData.optString("errorMessage", "");
            this.eventsHandler.onWebchatError(errorMessage);
        } catch (final JSONException e) {
            HBlogger.e(TAG, "解析错误数据失败", e);
            this.eventsHandler.onWebchatError("");
        }
    }

    @JavascriptInterface
    public void sendPushTokenSyncRequestData(final String data) {
        this.eventsHandler.onReceivePushTokenSyncRequestData(data);
    }

    @JavascriptInterface
    public void onUIConfigChange(final String data) {
        this.eventsHandler.onUiConfigChange(data);
    }

    @JavascriptInterface
    public void sendUserAuthFailureEvent(final String data) {
        if (this.delegate == null || Utils.isEmpty(data)) {
            return;
        }
        String reason = "Authentication Failure";
        try {
            // sendUserAuthFailureEvent(reason) 直接传 reason 字符串
            // 为兼容历史实现，这里同时支持 JSON 与纯字符串两种格式
            final String trimmed = data.trim();
            if (trimmed.startsWith("{")) {
                final JSONObject authDataObject = new JSONObject(trimmed);
                if (authDataObject.has("message")) {
                    final String message = authDataObject.optString("message", "");
                    reason = (Utils.isEmpty(message.trim()) ? reason : message);
                } else if (authDataObject.has("reason")) {
                    final String r = authDataObject.optString("reason", "");
                    reason = (Utils.isEmpty(r.trim()) ? reason : r);
                }
            } else {
                reason = trimmed;
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "读取身份认证失败事件时出错", e);
        }
        this.eventsHandler.onUserAuthenticationFailure();
        this.delegate.sendAuthFailureEvent(reason);

        // 同时释放等待中的 login（避免宿主阻塞等待）
        try {
            HelpBotWebViewSession.getInstance().notifyWebSdkLoginFailed("user_authentication_failed", reason);
        } catch (final Exception ignored) {
        }
    }

    @JavascriptInterface
    public void onRemoveAnonymousUser() {
        this.eventsHandler.onRemoveAnonymousUser();
    }

    @JavascriptInterface
    public void setPollingStatus(final String data) {
        this.eventsHandler.setPollingStatus(data);
    }

    @JavascriptInterface
    public void setGenericSdkData(final String data) {
        this.eventsHandler.setGenericSdkData(data);
    }

    @JavascriptInterface
    public void sdkxMigrationLogSynced(final boolean isSuccess) {
        this.eventsHandler.sdkxMigrationLogSynced(isSuccess);
    }

    @JavascriptInterface
    public void requestConversationMetadata(final String data) {
        this.eventsHandler.requestConversationMetadata(data);
    }

    @JavascriptInterface
    public void webchatJsFileLoaded() {
        this.eventsHandler.webchatJsFileLoaded();
    }

    @JavascriptInterface
    public void wcActionSync(final String data) {
        this.eventsHandler.wcActionSync(data);
    }

    @JavascriptInterface
    public boolean onSSEMessage(String message) {
        try {
            if (Utils.isEmpty(message)) {
                HBlogger.d(TAG, "onSSEMessage: 消息为空");
                return true;
            }
            if (isPayloadTooLarge("onSSEMessage", message, MAX_SSE_MESSAGE_CHARS)) {
                return false;
            }

            HBlogger.d(TAG, "onSSEMessage: " + (message.length() > 100 ? message.substring(0, 100) + "..." : message));

            // 1) 透传给宿主事件监听
            try {
                if (this.delegate != null) {
                    this.delegate.sendEvent("SSE_MESSAGE",
                            JsonUtils.jsonStringToMap("{\"message\":" + org.json.JSONObject.quote(message) + "}"));
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "onSSEMessage: 事件透传失败", e);
            }

            // 2) 系统通知（默认启用）
            try {
                if (this.appContext != null && HelpBot.isSseNotificationEnabled()) {
                    HelpBotNotificationHelper.notifyNewMessage(this.appContext, message);
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "onSSEMessage: 通知展示失败", e);
            }
            return true;
        } catch (final Exception e) {
            HBlogger.e(TAG, "onSSEMessage 异常", e);
            return false;
        }
    }

    private static boolean isEmptyPayload(@NonNull final String method, @Nullable final String data) {
        if (!Utils.isEmpty(data)) {
            return false;
        }
        HBlogger.w(TAG, method + ": 数据为空");
        return true;
    }

    private static boolean isPayloadTooLarge(@NonNull final String method, @Nullable final String data,
            final int maxChars) {
        if (data == null) {
            return false;
        }
        if (data.length() <= Math.max(maxChars, 0)) {
            return false;
        }
        HBlogger.e(TAG, method + ": 数据过大 (" + data.length() + " 字符)，已拒绝");
        return true;
    }

}
