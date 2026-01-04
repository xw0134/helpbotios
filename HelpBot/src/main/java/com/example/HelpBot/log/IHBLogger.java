package com.example.HelpBot.log;

public interface IHBLogger
{
    void d(final String tag, final String message);

    void w(final String tag, final String message);

    void e(final String tag, final String message);

    void d(final String tag, final String message, final Throwable tr);

    void w(final String tag, final String message, final Throwable tr);

    void e(final String tag, final String message, final Throwable tr);

    public enum LEVEL
    {
        DEBUG,
        WARN,
        ERROR;
    }
}