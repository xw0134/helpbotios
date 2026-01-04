package com.example.HelpBot.web;

import android.content.Context;
import android.view.ContextThemeWrapper;

import androidx.annotation.NonNull;

import com.example.HelpBot.log.HBlogger;

/**
 * WebView 创建/离屏运行所需的 Context 工具类（SDK 内部使用）。
 *
 * 部分 Android 版本/厂商 ROM 在 StrictMode 或框架校验下，会拒绝在不是UI的环境
 *（如 {@link android.app.Application} / {@link android.content.MutableContextWrapper} 直接包裹的 applicationContext）
 *上创建 View（WebView 内部会访问 {@code ViewConfiguration} 等需要配置上下文的系统服务），从而抛出
 * {@link java.lang.IllegalAccessException}。
 *
 * 在没有 Activity 的离屏阶段，使用 {@link Context#createConfigurationContext(android.content.res.Configuration)}
 * 创建配置环境，并可以选择套上系统主题，确保 View 创建与资源解析更稳定。
 */
public final class HelpBotWebViewContextUtils {
    private static final String TAG = "HBWebViewCtx";

    private HelpBotWebViewContextUtils() {
    }

    /**
     * 构建可以离屏创建 WebView的安全 环境。
     * - 仅持有 applicationContext，避免泄漏 Activity
     * - 使用 createConfigurationContext 提供配置环境，兼容 StrictMode/厂商校验
     * - 兜底套上系统主题，减少主题缺失导致的崩溃概率
     */
    @NonNull
    public static Context buildPreloadContext(@NonNull final Context appContext) {
        try {
            final Context appCtx = appContext.getApplicationContext();

            Context configured = appCtx;
            try {
                configured = appCtx.createConfigurationContext(appCtx.getResources().getConfiguration());
            } catch (final Exception e) {
                // 有些设备/ROM 对 createConfigurationContext 行为不一致，保持兜底
                HBlogger.d(TAG, "createConfigurationContext 失败，使用 applicationContext 兜底", e);
                configured = appCtx;
            }

            final int themeResId = resolveSafeThemeResId(configured);
            try {
                return new ContextThemeWrapper(configured, themeResId);
            } catch (final Exception e) {
                // 主题包装失败时直接返回 configured
                HBlogger.d(TAG, "ContextThemeWrapper 失败，直接返回 configured context", e);
                return configured;
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "buildPreloadContext 异常，返回原 context 兜底", e);
            return appContext;
        }
    }

    /**
     * 解析一个安全的主题资源 ID。
     * - 优先使用宿主 Application 的 theme
     * - 否则使用系统默认主题稳定并跨版本
     */
    private static int resolveSafeThemeResId(@NonNull final Context context) {
        int themeResId = 0;
        try {
            if (context.getApplicationInfo() != null) {
                themeResId = context.getApplicationInfo().theme;
            }
        } catch (final Exception ignored) {
        }
        if (themeResId == 0) {
            themeResId = android.R.style.Theme_DeviceDefault;
        }
        return themeResId;
    }
}


