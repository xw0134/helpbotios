package com.example.HelpBot.log;

import com.example.HelpBot.BuildConfig;

import java.util.regex.Pattern;

/**
 * HelpBot 统一日志类
 *
 * - 自动脱敏敏感信息（Token、密码等）
 * - 支持外部日志实现
 * - ProGuard会自动移除Debug日志
 */
public final class HBlogger {
    private static IHBLogger logger;

    /**
     * 发布版本禁止日志输出：
     * - 只要 SDK 以 release 变体构建（BuildConfig.DEBUG=false），无论宿主是否注入 logger，SDK
     * 都不输出任何日志。
     * - 该策略可避免线上泄露敏感信息/影响宿主日志策略。
     */
    private static final boolean SDK_LOGGING_ALLOWED = BuildConfig.DEBUG;

    // 敏感信息正则模式
    private static final Pattern TOKEN_PATTERN = Pattern.compile(
            "(token|jwt|bearer|authorization)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern PASSWORD_PATTERN = Pattern
            .compile("(password|passwd|pwd)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern KEY_PATTERN = Pattern.compile(
            "(api[_-]?key|secret|private[_-]?key)[\"']?\\s*[:=]\\s*[\"']?([^\"',\\s}]+)", Pattern.CASE_INSENSITIVE);

    private HBlogger() {
    }

    public static void initLogger(final IHBLogger externalLogger) {
        HBlogger.logger = externalLogger;
    }

    /**
     * 判断是否已初始化 Logger（SDK 不应强行覆盖宿主 Logger）。
     */
    public static boolean isInitialized() {
        return HBlogger.logger != null;
    }

    /**
     * 仅在未初始化时设置 Logger，避免 SDK 覆盖宿主日志系统。
     */
    public static synchronized void initLoggerIfAbsent(final IHBLogger externalLogger) {
        if (HBlogger.logger != null) {
            return;
        }
        HBlogger.logger = externalLogger;
    }

    public static void d(final String tag, final String message) {
        d(tag, message, null);
    }

    public static void w(final String tag, final String message) {
        w(tag, message, null);
    }

    public static void e(final String tag, final String message) {
        e(tag, message, null);
    }

    public static void d(final String tag, final String message, final Throwable tr) {
        if (!SDK_LOGGING_ALLOWED) {
            return;
        }
        if (HBlogger.logger == null) {
            return;
        }
        // Debug日志进行脱敏
        HBlogger.logger.d(tag, sanitize(message), tr);
    }

    public static void w(final String tag, final String message, final Throwable tr) {
        if (!SDK_LOGGING_ALLOWED) {
            return;
        }
        if (HBlogger.logger == null) {
            return;
        }
        // Warning日志进行脱敏
        HBlogger.logger.w(tag, sanitize(message), tr);
    }

    public static void e(final String tag, final String message, final Throwable tr) {
        if (!SDK_LOGGING_ALLOWED) {
            return;
        }
        if (HBlogger.logger == null) {
            return;
        }
        // Error日志进行脱敏
        HBlogger.logger.e(tag, sanitize(message), tr);
    }

    /**
     * 日志脱敏处理
     * 
     * 自动移除或遮蔽敏感信息：
     * - Token/JWT
     * - 密码
     * - API Key/Secret
     * 
     * @param message 原始日志消息
     * @return 脱敏后的日志消息
     */
    private static String sanitize(final String message) {
        if (message == null || message.isEmpty()) {
            return message;
        }

        try {
            String sanitized = message;

            // 脱敏 Token（保留前4位和后4位）
            sanitized = TOKEN_PATTERN.matcher(sanitized).replaceAll("$1=***已脱敏***");

            // 脱敏密码
            sanitized = PASSWORD_PATTERN.matcher(sanitized).replaceAll("$1=***已脱敏***");

            // 脱敏 API Key/Secret
            sanitized = KEY_PATTERN.matcher(sanitized).replaceAll("$1=***已脱敏***");

            return sanitized;
        } catch (final Exception e) {
            // 脱敏失败，返回原始消息（避免日志系统崩溃）
            return message;
        }
    }

    /**
     * 脱敏单个值（用于显式脱敏）
     * 
     * @param value 原始值
     * @return 脱敏后的值（保留前4位和后4位）
     */
    public static String sanitizeValue(final String value) {
        if (value == null || value.length() <= 8) {
            return "***";
        }

        try {
            final String prefix = value.substring(0, 4);
            final String suffix = value.substring(value.length() - 4);
            return prefix + "***" + suffix;
        } catch (final Exception e) {
            return "***";
        }
    }
}
