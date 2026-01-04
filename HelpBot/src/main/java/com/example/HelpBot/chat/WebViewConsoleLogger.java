package com.example.HelpBot.chat;

import com.example.HelpBot.log.HBlogger;

import android.webkit.ConsoleMessage;

/**
 * WebView 控制台日志桥接（统一走 {@link HBlogger}）。
 */
public final class WebViewConsoleLogger {
    private WebViewConsoleLogger() {
        super();
    }

    public static void log(@androidx.annotation.Nullable final ConsoleMessage.MessageLevel messageLevel,
            final String tag,
            final String message) {
        if (messageLevel == null) {
            HBlogger.d(tag, message);
            return;
        }
        switch (messageLevel) {
            case ERROR:
                HBlogger.e(tag, message);
                break;
            case WARNING:
                HBlogger.w(tag, message);
                break;
            default:
                HBlogger.d(tag, message);
                break;
        }
    }
}
