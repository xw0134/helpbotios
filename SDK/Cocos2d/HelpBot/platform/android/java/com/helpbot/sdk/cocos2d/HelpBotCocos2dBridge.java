package com.helpbot.sdk.cocos2d;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.helpbot.sdk.HelpBot;
import com.helpbot.sdk.core.HelpBotAuthenticationFailureReason;
import com.helpbot.sdk.core.HelpBotCallback;
import com.helpbot.sdk.core.HelpBotConfig;
import com.helpbot.sdk.core.HelpBotErrorCode;
import com.helpbot.sdk.core.HelpBotEventsListener;
import com.helpbot.sdk.core.HelpBotInitCallback;
import com.helpbot.sdk.core.HelpBotResult;
import com.helpbot.sdk.log.HBlogger;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * HelpBot Cocos2d Android Bridge
 *
 * <p>
 * 目的：为 Cocos2d-x 的 C++ 层提供一个“稳定可控”的 Java 桥接点：
 * - 统一持有 Android SDK 回调（InitCallback/Callback/EventsListener）
 * - 将回调透传回 native（避免在 C++ 侧构造 Java interface 实例）
 * - 兼容 ProGuard/R8（需 keep 本类与 native 方法）
 * </p>
 *
 * <p>
 * 安全/稳定基线：
 * - 所有回调入口 try-catch 包裹，避免异常穿透导致宿主崩溃
 * - 不在日志中输出敏感 token，仅输出必要信息
 * </p>
 */
public final class HelpBotCocos2dBridge {
    private static final String TAG = "HelpBotCocos2dBridge";

    private HelpBotCocos2dBridge() {
        super();
    }

    /**
     * 初始化 native 侧 ClassLoader（强烈建议宿主在 Application/Activity 的 onCreate 调用一次）。
     *
     * <p>
     * 说明：在 native 线程中直接 FindClass 可能失败（ClassLoader 不同），因此这里把 App ClassLoader 传给 native。
     * </p>
     */
    public static void initNativeClassLoader() {
        try {
            nativeInitClassLoader(HelpBotCocos2dBridge.class.getClassLoader());
        } catch (final Throwable t) {
            // 不能抛出到宿主
            HBlogger.e(TAG, "initNativeClassLoader 异常", t);
        }
    }

    public static void install(@NonNull final Context context,
                               @NonNull final HelpBotConfig config,
                               final long callbackPtr) {
        try {
            final HelpBotInitCallback callback = (callbackPtr == 0) ? null : new HelpBotInitCallback() {
                @Override
                public void onInitStart() {
                    try {
                        nativeOnInitStart(callbackPtr);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onInitStart -> native 异常", t);
                    }
                }

                @Override
                public void onInitProgress(final int progress, @NonNull final String message) {
                    try {
                        nativeOnInitProgress(callbackPtr, progress, message);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onInitProgress -> native 异常", t);
                    }
                }

                @Override
                public void onInitSuccess() {
                    try {
                        nativeOnInitSuccess(callbackPtr);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onInitSuccess -> native 异常", t);
                    }
                }

                @Override
                public void onInitFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        nativeOnInitFailure(callbackPtr,
                                errorCode != null ? errorCode.getCode() : HelpBotErrorCode.UNKNOWN_ERROR.getCode(),
                                errorMessage);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onInitFailure -> native 异常", t);
                    }
                }
            };

            HelpBot.install(context, config, callback);
        } catch (final Throwable t) {
            HBlogger.e(TAG, "install 异常", t);
            if (callbackPtr != 0) {
                try {
                    nativeOnInitFailure(callbackPtr, HelpBotErrorCode.INTERNAL_ERROR.getCode(), "install 异常: " + t.getMessage());
                } catch (final Throwable ignored) {
                }
            }
        }
    }

    public static void login(@NonNull final String token,
                             @Nullable final Map<String, Object> loginConfig,
                             final long callbackPtr) {
        try {
            final HelpBotCallback<Void> callback = (callbackPtr == 0) ? null : new HelpBotCallback<Void>() {
                @Override
                public void onSuccess(@Nullable final Void result) {
                    try {
                        nativeOnVoidCallbackSuccess(callbackPtr);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "login onSuccess -> native 异常", t);
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        nativeOnVoidCallbackFailure(callbackPtr,
                                errorCode != null ? errorCode.getCode() : HelpBotErrorCode.UNKNOWN_ERROR.getCode(),
                                errorMessage);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "login onFailure -> native 异常", t);
                    }
                }
            };

            HelpBot.login(token, loginConfig, callback);
        } catch (final Throwable t) {
            HBlogger.e(TAG, "login 异常", t);
            if (callbackPtr != 0) {
                try {
                    nativeOnVoidCallbackFailure(callbackPtr, HelpBotErrorCode.INTERNAL_ERROR.getCode(), "login 异常: " + t.getMessage());
                } catch (final Throwable ignored) {
                }
            }
        }
    }

    public static void sendMessageAsync(@NonNull final String message, final long callbackPtr) {
        try {
            final HelpBotCallback<Map<String, Object>> callback = (callbackPtr == 0) ? null : new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(@Nullable final Map<String, Object> result) {
                    try {
                        nativeOnJsonCallbackSuccess(callbackPtr, mapToJsonString(result));
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "sendMessageAsync onSuccess -> native 异常", t);
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        nativeOnJsonCallbackFailure(callbackPtr,
                                errorCode != null ? errorCode.getCode() : HelpBotErrorCode.UNKNOWN_ERROR.getCode(),
                                errorMessage);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "sendMessageAsync onFailure -> native 异常", t);
                    }
                }
            };

            HelpBot.sendMessageAsync(message, callback);
        } catch (final Throwable t) {
            HBlogger.e(TAG, "sendMessageAsync 异常", t);
            if (callbackPtr != 0) {
                try {
                    nativeOnJsonCallbackFailure(callbackPtr, HelpBotErrorCode.INTERNAL_ERROR.getCode(), "sendMessageAsync 异常: " + t.getMessage());
                } catch (final Throwable ignored) {
                }
            }
        }
    }

    public static void getHistoryMessagesAsync(final long callbackPtr) {
        try {
            final HelpBotCallback<Map<String, Object>> callback = (callbackPtr == 0) ? null : new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(@Nullable final Map<String, Object> result) {
                    try {
                        nativeOnJsonCallbackSuccess(callbackPtr, mapToJsonString(result));
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "getHistoryMessagesAsync onSuccess -> native 异常", t);
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        nativeOnJsonCallbackFailure(callbackPtr,
                                errorCode != null ? errorCode.getCode() : HelpBotErrorCode.UNKNOWN_ERROR.getCode(),
                                errorMessage);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "getHistoryMessagesAsync onFailure -> native 异常", t);
                    }
                }
            };

            HelpBot.getHistoryMessagesAsync(callback);
        } catch (final Throwable t) {
            HBlogger.e(TAG, "getHistoryMessagesAsync 异常", t);
            if (callbackPtr != 0) {
                try {
                    nativeOnJsonCallbackFailure(callbackPtr, HelpBotErrorCode.INTERNAL_ERROR.getCode(), "getHistoryMessagesAsync 异常: " + t.getMessage());
                } catch (final Throwable ignored) {
                }
            }
        }
    }

    public static void loadMoreMessagesAsync(final int limit, final int offset, final long callbackPtr) {
        try {
            final HelpBotCallback<Map<String, Object>> callback = (callbackPtr == 0) ? null : new HelpBotCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(@Nullable final Map<String, Object> result) {
                    try {
                        nativeOnJsonCallbackSuccess(callbackPtr, mapToJsonString(result));
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "loadMoreMessagesAsync onSuccess -> native 异常", t);
                    }
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    try {
                        nativeOnJsonCallbackFailure(callbackPtr,
                                errorCode != null ? errorCode.getCode() : HelpBotErrorCode.UNKNOWN_ERROR.getCode(),
                                errorMessage);
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "loadMoreMessagesAsync onFailure -> native 异常", t);
                    }
                }
            };

            HelpBot.loadMoreMessagesAsync(limit, offset, callback);
        } catch (final Throwable t) {
            HBlogger.e(TAG, "loadMoreMessagesAsync 异常", t);
            if (callbackPtr != 0) {
                try {
                    nativeOnJsonCallbackFailure(callbackPtr, HelpBotErrorCode.INTERNAL_ERROR.getCode(), "loadMoreMessagesAsync 异常: " + t.getMessage());
                } catch (final Throwable ignored) {
                }
            }
        }
    }

    public static void setEventsListener(final long listenerPtr) {
        try {
            if (listenerPtr == 0) {
                HelpBot.removeHelpBotEventsListener();
                return;
            }

            HelpBot.setHelpBotEventsListener(new HelpBotEventsListener() {
                @Override
                public void onEventOccurred(@NonNull final String eventName, @Nullable final Map<String, Object> data) {
                    try {
                        nativeOnEventOccurred(listenerPtr, eventName, flattenMapToStringMap(data));
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onEventOccurred -> native 异常", t);
                    }
                }

                @Override
                public void onUserAuthenticationFailure(@NonNull final HelpBotAuthenticationFailureReason reason) {
                    try {
                        nativeOnAuthFailure(listenerPtr, reason != null ? reason.name() : "UNKNOWN");
                    } catch (final Throwable t) {
                        HBlogger.e(TAG, "onUserAuthenticationFailure -> native 异常", t);
                    }
                }
            });
        } catch (final Throwable t) {
            HBlogger.e(TAG, "setEventsListener 异常", t);
        }
    }

    /**
     * 获取 WebSDK 健康快照（JSON 字符串）。
     *
     * <p>对齐 Android：HelpBot.getWebSdkHealthSnapshot()</p>
     */
    @NonNull
    public static String getWebSdkHealthSnapshotJson() {
        try {
            return mapToJsonString(HelpBot.getWebSdkHealthSnapshot());
        } catch (final Throwable t) {
            return "{}";
        }
    }

    // ==================== JSON/Map 工具 ====================

    @NonNull
    private static String mapToJsonString(@Nullable final Map<String, Object> map) {
        try {
            if (map == null || map.isEmpty()) {
                return "{}";
            }
            return mapToJsonObject(map).toString();
        } catch (final Throwable t) {
            return "{}";
        }
    }

    @NonNull
    private static JSONObject mapToJsonObject(@NonNull final Map<String, Object> map) {
        final JSONObject obj = new JSONObject();
        for (final Map.Entry<String, Object> entry : map.entrySet()) {
            try {
                final String key = entry.getKey();
                final Object value = entry.getValue();
                obj.put(key, wrapJsonValue(value));
            } catch (final Throwable ignored) {
            }
        }
        return obj;
    }

    private static Object wrapJsonValue(@Nullable final Object value) {
        if (value == null) {
            return JSONObject.NULL;
        }
        if (value instanceof JSONObject || value instanceof JSONArray) {
            return value;
        }
        if (value instanceof Map) {
            //noinspection unchecked
            return mapToJsonObject((Map<String, Object>) value);
        }
        if (value instanceof Iterable) {
            final JSONArray arr = new JSONArray();
            for (final Object item : (Iterable<?>) value) {
                arr.put(wrapJsonValue(item));
            }
            return arr;
        }
        if (value.getClass().isArray()) {
            final JSONArray arr = new JSONArray();
            try {
                final Object[] a = (Object[]) value;
                for (final Object item : a) {
                    arr.put(wrapJsonValue(item));
                }
            } catch (final Throwable ignored) {
            }
            return arr;
        }
        // String/Number/Boolean
        return value;
    }

    @NonNull
    private static Map<String, String> flattenMapToStringMap(@Nullable final Map<String, Object> data) {
        final Map<String, String> result = new HashMap<>();
        if (data == null || data.isEmpty()) {
            return result;
        }
        for (final Map.Entry<String, Object> entry : data.entrySet()) {
            try {
                result.put(entry.getKey(), String.valueOf(entry.getValue()));
            } catch (final Throwable ignored) {
            }
        }
        return result;
    }

    // ==================== native 方法 ====================

    private static native void nativeInitClassLoader(@NonNull ClassLoader classLoader);

    private static native void nativeOnInitStart(long callbackPtr);
    private static native void nativeOnInitProgress(long callbackPtr, int progress, @NonNull String message);
    private static native void nativeOnInitSuccess(long callbackPtr);
    private static native void nativeOnInitFailure(long callbackPtr, int errorCode, @NonNull String errorMessage);

    private static native void nativeOnVoidCallbackSuccess(long callbackPtr);
    private static native void nativeOnVoidCallbackFailure(long callbackPtr, int errorCode, @NonNull String errorMessage);

    private static native void nativeOnJsonCallbackSuccess(long callbackPtr, @NonNull String jsonResult);
    private static native void nativeOnJsonCallbackFailure(long callbackPtr, int errorCode, @NonNull String errorMessage);

    private static native void nativeOnEventOccurred(long listenerPtr, @NonNull String eventName, @NonNull Map<String, String> data);
    private static native void nativeOnAuthFailure(long listenerPtr, @NonNull String reason);
}


