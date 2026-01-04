package com.example.HelpBot.utils;

import com.example.HelpBot.log.HBlogger;

import java.io.Closeable;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * SDK 内通用工具类。
 */
public final class Utils {
    private static final String TAG = "Utils";

    public static <K, V> V getOrDefault(final Map<K, V> map, final K key, final V defaultValue) {
        if (isEmpty(map)) {
            return defaultValue;
        }
        final V value = map.get(key);
        return (value == null) ? defaultValue : value;
    }

    public static boolean isNotEmpty(final String data) {
        return !isEmpty(data);
    }

    public static boolean isEmpty(final String data) {
        return data == null || data.trim().isEmpty();
    }

    public static boolean isNotEmpty(final Map<?, ?> map) {
        return !isEmpty(map);
    }

    public static boolean isEmpty(final Map<?, ?> map) {
        return map == null || map.isEmpty();
    }

    public static <T> boolean isEmpty(final List<T> list) {
        return list == null || list.isEmpty();
    }

    public static <T> boolean isEmpty(final Set<T> list) {
        return list == null || list.isEmpty();
    }

    public static <T> boolean isNotEmpty(final List<T> list) {
        return list != null && !list.isEmpty();
    }

    public static void closeQuietly(final Closeable stream) {
        try {
            if (stream != null) {
                stream.close();
            }
        } catch (final Exception ex) {
            HBlogger.d(TAG, "closeQuietly: 关闭流时发生异常", ex);
        }
    }

    public static String join(final CharSequence delimiter, final Iterable<String> tokens) {
        if (tokens == null) {
            return null;
        }
        final StringBuilder sb = new StringBuilder();
        boolean firstTime = true;
        for (final String token : tokens) {
            if (firstTime) {
                firstTime = false;
            } else {
                sb.append(delimiter);
            }
            sb.append(token);
        }
        return sb.toString();
    }

    /**
     * 反转义 WebView.evaluateJavascript 的返回值。
     *
     * 说明：evaluateJavascript 回调参数是 JSON 字符串（可能带引号与转义），这里统一还原，避免多处重复实现。
     *
     * @param value evaluateJavascript 回调 value
     * @return 还原后的字符串；null/"null" 会返回空串
     */
    public static String unquoteJsString(final String value) {
        if (value == null) {
            return "";
        }
        String v = value.trim();
        if (v.length() >= 2 && v.startsWith("\"") && v.endsWith("\"")) {
            v = v.substring(1, v.length() - 1);
            v = v.replace("\\\\", "\\")
                    .replace("\\\"", "\"")
                    .replace("\\n", "\n")
                    .replace("\\r", "\r")
                    .replace("\\t", "\t");
        }
        if ("null".equalsIgnoreCase(v)) {
            return "";
        }
        return v;
    }

    private Utils() {
    }
}
