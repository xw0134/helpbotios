package com.example.HelpBot.chat;

import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.core.HelpBotAuthenticationFailureReason;

import android.os.Handler;
import android.os.Looper;

import java.util.HashMap;
import java.util.Map;

public class EventProxy {
    private static final String TAG = "EventProxy";
    private HelpBotEventsListener eventsListener;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public void setHelpshiftEventsListener(final HelpBotEventsListener listener) {
        this.eventsListener = listener;
    }

    public void sendEvent(final String eventName, final Map<String, Object> data) {
        HBlogger.d(TAG, "事件发生: " + eventName);
        if (this.eventsListener == null) {
            HBlogger.d(TAG, "未找到事件监听器，忽略事件: " + eventName);
            return;
        }

        final Map<String, Object> dataCopy = new HashMap<String, Object>();
        if (data != null) {
            dataCopy.putAll(data);
        }
        // 统一在主线程回调宿主，避免宿主在后台线程更新 UI 造成崩溃
        mainHandler.post(() -> {
            try {
                if (eventsListener != null) {
                    eventsListener.onEventOccurred(eventName, dataCopy);
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "onEventOccurred 回调异常", e);
            }
        });

    }

    public void sendAuthFailureEvent(final String reason) {
        HBlogger.d(TAG, "身份认证失败，原因: " + reason);

        if (this.eventsListener == null) {
            return;
        }

        HelpBotAuthenticationFailureReason failureReason = HelpBotAuthenticationFailureReason.UNKNOWN;
        if ("missing user auth token".equals(reason)) {
            failureReason = HelpBotAuthenticationFailureReason.REASON_AUTH_TOKEN_NOT_PROVIDED;
        } else if ("invalid user auth token".equals(reason)) {
            failureReason = HelpBotAuthenticationFailureReason.REASON_INVALID_AUTH_TOKEN;
        }

        // 统一在主线程回调宿主，避免线程不一致导致崩溃
        final HelpBotAuthenticationFailureReason finalReason = failureReason;
        mainHandler.post(() -> {
            try {
                if (eventsListener != null) {
                    eventsListener.onUserAuthenticationFailure(finalReason);
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "onUserAuthenticationFailure 回调异常", e);
            }
        });
    }
}
