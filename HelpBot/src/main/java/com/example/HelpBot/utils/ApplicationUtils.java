package com.example.HelpBot.utils;

import com.example.HelpBot.activity.HelpBotActivity;
import com.example.HelpBot.log.HBlogger;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.LocaleList;
import android.provider.Settings;

import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.notification.HelpBotNotificationHelper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

/**
 * 应用程序工具类，提供系统通知、资源获取、权限检查等功能。
 */
public final class ApplicationUtils {
    private static final String TAG = "AppUtil";
    private static final int DEFAULT_NOTIFICATION_ID = 121;

    private ApplicationUtils() {
    }

    /**
     * 尝试获取用于 JS Bridge 的 Application Context。
     *
     * @return Application Context，获取失败则返回 null。
     */
    @Nullable
    private static Context tryGetApplicationContextForBridge() {
        try {
            final HelpBotContext hb = HelpBotContext.getInstance();
            if (hb != null && hb.context != null) {
                return hb.context.getApplicationContext();
            }
        } catch (final Exception ignored) {
        }

        try {
            final Class<?> helperClz = Class.forName("org.cocos2dx.lib.Cocos2dxHelper");
            final java.lang.reflect.Method m = helperClz.getMethod("getActivity");
            final Object activity = m.invoke(null);
            if (activity instanceof Context) {
                return ((Context) activity).getApplicationContext();
            }
        } catch (final Throwable ignored) {
        }

        return null;
    }

    /**
     * 判断应用是否处于调试模式。
     */
    public static boolean isApplicationInDebugMode(@NonNull final Context context) {
        return (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    /**
     * 检查是否已授予指定权限。
     */
    public static boolean isPermissionGranted(final Context context, final String permissionName) {
        boolean isPermissionGranted = false;
        try {
            isPermissionGranted = (ContextCompat.checkSelfPermission(context,
                    permissionName) == PackageManager.PERMISSION_GRANTED);
        } catch (final Exception e) {
            HBlogger.d(TAG, "检查权限异常: " + permissionName, e);
        }
        return isPermissionGranted;
    }

    /**
     * 在系统状态栏显示通知。
     */
    public static void showNotification(final Context context, final Notification notification,
            final Class<? extends Activity> clazz) {
        if (notification == null) {
            HBlogger.d(TAG, "通知对象为空，不予展示");
            return;
        }
        final NotificationManager notificationManager = getNotificationManager(context);
        if (notificationManager == null) {
            HBlogger.d(TAG, "通知管理器为空，初始化失败");
            return;
        }
        try {
            final boolean areNotificationAllowed = NotificationManagerCompat.from(context).areNotificationsEnabled();
            HBlogger.d(TAG, "通知权限状态: " + areNotificationAllowed);
            if (areNotificationAllowed) {
                final String notificationTag = generateNotificationTag(clazz);
                HBlogger.d(TAG, "正在展示通知, 标签: " + notificationTag);
                notificationManager.notify(notificationTag, DEFAULT_NOTIFICATION_ID, notification);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "展示系统通知异常", e);
        }
    }

    /**
     * 获取系统通知管理器实例。
     */
    public static NotificationManager getNotificationManager(final Context context) {
        NotificationManager notificationManager = null;
        try {
            notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取通知管理器异常", e);
        }
        return notificationManager;
    }

    /**
     * 获取应用图标或 Logo 资源 ID。
     */
    public static int getLogoResourceValue(final Context context) {
        int resId = context.getApplicationInfo().logo;
        if (resId == 0) {
            resId = context.getApplicationInfo().icon;
        }
        return resId;
    }

    /**
     * 获取 Target SDK 版本号。
     */
    public static int getTargetSDKVersion(final Context c) {
        int targetVersion = 0;
        try {
            final ApplicationInfo applicationInfo = c.getApplicationInfo();
            targetVersion = applicationInfo.targetSdkVersion;
        } catch (final Exception e) {
            HBlogger.d(TAG, "获取 Target SDK 版本异常", e);
        }
        return targetVersion;
    }

    /**
     * 取消显示的通知。
     */
    public static void cancelNotification(final Context context) {
        HBlogger.d(TAG, "取消正在显示的通知");
        final NotificationManager notificationManager = getNotificationManager(context);
        if (notificationManager != null) {
            notificationManager.cancel(generateNotificationTag(HelpBotActivity.class), DEFAULT_NOTIFICATION_ID);
        }
    }

    /**
     * 根据资源名称获取资源 ID。
     */
    public static int getResourceIdFromName(final Context context, final String name, final String resourceType,
            final String packageName) {
        return context.getResources().getIdentifier(name, resourceType, packageName);
    }

    /**
     * 获取指定包名的启动 Intent。
     */
    public static Intent getLaunchIntent(final Context context, final String packageName) {
        Intent launchIntentForPackage = null;
        try {
            final PackageManager packageManager = context.getPackageManager();
            launchIntentForPackage = packageManager.getLaunchIntentForPackage(packageName);
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取启动 Intent 异常: " + packageName, e);
        }
        return launchIntentForPackage;
    }

    /**
     * 生成通知标签。
     */
    private static String generateNotificationTag(final Class<? extends Activity> clazz) {
        return "hsft_notification_tag_" + clazz.getName();
    }

    /**
     * 判断 LocaleList 是否非空（适用于 API 24+）。
     */
    @RequiresApi(api = 24)
    public static boolean isLocaleListNotEmpty(@Nullable final LocaleList localeList) {
        return localeList != null && !localeList.isEmpty();
    }

    /**
     * @deprecated 历史遗留方法，请使用 isLocaleListNotEmpty
     */
    @Deprecated
    @RequiresApi(api = 24)
    public static boolean isLocalListEmpty(@Nullable final LocaleList localeList) {
        return isLocaleListNotEmpty(localeList);
    }
}
