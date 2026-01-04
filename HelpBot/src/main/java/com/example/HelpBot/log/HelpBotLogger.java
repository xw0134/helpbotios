package com.example.HelpBot.log;

import android.util.Log;

public class HelpBotLogger implements IHBLogger {
    private static final String TAG = "HelpBot";
    private final boolean shouldEnableLogging;

    public HelpBotLogger(final boolean enableLogging) {
        super();
        this.shouldEnableLogging = enableLogging;
    }

    @Override
    public void d(String tag, String message) {
        this.d(tag, message, null);
    }

    @Override
    public void w(String tag, String message) {
        this.w(tag, message, null);
    }

    @Override
    public void e(String tag, String message) {
        this.e(tag, message, null);
    }

    @Override
    public void d(String tag, String message, Throwable tr) {
        this.logMessage(IHBLogger.LEVEL.DEBUG, tag, message, tr);
    }

    @Override
    public void w(String tag, String message, Throwable tr) {
        this.logMessage(IHBLogger.LEVEL.WARN, tag, message, tr);
    }

    @Override
    public void e(String tag, String message, Throwable tr) {
        this.logMessage(IHBLogger.LEVEL.ERROR, tag, message, tr);
    }

    private void logMessage(final IHBLogger.LEVEL level, final String tag, String message, final Throwable tr) {
        message = tag + ": " + message;
        if (!this.shouldEnableLogging) {
            return;
        }
        switch (level) {
            case ERROR: {
                Log.e(TAG, message, tr);
                break;
            }
            case WARN: {
                Log.w(TAG, message, tr);
                break;
            }
            case DEBUG: {
                Log.d(TAG, message, tr);
                break;
            }
        }
    }
}
