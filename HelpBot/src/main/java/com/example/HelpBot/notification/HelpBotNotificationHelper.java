package com.example.HelpBot.notification;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.Manifest;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

import com.example.HelpBot.activity.HelpBotActivity;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.storage.HBPersistentStorage;
import com.example.HelpBot.utils.ApplicationUtils;
import com.example.HelpBot.utils.Utils;

/**
 * HelpBot 系统通知工具类
 * 说明：
 * - 用于处理 WebSDK -> Native 的 SSE “消息摘要”回调（onSSEMessage），在 Native 侧展示系统通知。
 * - Android 8+ 自动创建 NotificationChannel。
 * - 默认使用宿主 App 的 icon 作为 smallIcon（可通过 SDK API 配置覆盖）。
 */
public final class HelpBotNotificationHelper {
    private static final String TAG = "HBNotify";

    private static final String DEFAULT_CHANNEL_ID = "helpbot_message_channel";
    private static final String DEFAULT_CHANNEL_NAME = "HelpBot 消息";
    private static final String DEFAULT_CHANNEL_DESC = "HelpBot 客服消息通知";

    private HelpBotNotificationHelper() {
    }

    public static void notifyNewMessage(@NonNull final Context context, @NonNull final String messageSummary) {
        try {
            if (Utils.isEmpty(messageSummary)) {
                return;
            }

            // Android 13+ 需要运行时通知权限；SDK 侧做兜底避免异常
            if (Build.VERSION.SDK_INT >= 33) {
                try {
                    if (!ApplicationUtils.isPermissionGranted(context, Manifest.permission.POST_NOTIFICATIONS)) {
                        HBlogger.w(TAG, "notifyNewMessage: POST_NOTIFICATIONS 未授权，跳过展示");
                        return;
                    }
                } catch (final Exception ignored) {
                }
            }

            final HelpBotContext hbContext = HelpBotContext.getInstance();
            final HBPersistentStorage storage = (hbContext == null) ? null : hbContext.getPersistentStorage();

            final String channelId = ensureChannel(context, storage);
            final int smallIconResId = resolveSmallIcon(context, storage);

            final PendingIntent contentIntent = buildContentIntent(context);

            final Notification notification = new NotificationCompat.Builder(context, channelId)
                    .setSmallIcon(smallIconResId)
                    .setContentTitle(resolveAppName(context))
                    .setContentText(messageSummary)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(messageSummary))
                    .setAutoCancel(true)
                    .setContentIntent(contentIntent)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    // 锁屏默认不展示敏感内容（由宿主自行决定是否放开）
                    .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                    .build();

            ApplicationUtils.showNotification(context, notification, HelpBotActivity.class);
        } catch (final Exception e) {
            HBlogger.e(TAG, "notifyNewMessage 异常", e);
        }
    }

    @NonNull
    private static String ensureChannel(@NonNull final Context context, final HBPersistentStorage storage) {
        String channelId = (storage == null) ? "" : storage.getNotificationChannelId();
        if (Utils.isEmpty(channelId)) {
            channelId = DEFAULT_CHANNEL_ID;
            try {
                if (storage != null) {
                    storage.setNotificationChannelId(channelId);
                }
            } catch (final Exception ignored) {
            }
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return channelId;
        }

        try {
            final NotificationManager nm = ApplicationUtils.getNotificationManager(context);
            if (nm == null) {
                return channelId;
            }

            final NotificationChannel existing = nm.getNotificationChannel(channelId);
            if (existing != null) {
                return channelId;
            }

            final NotificationChannel channel = new NotificationChannel(
                    channelId,
                    DEFAULT_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription(DEFAULT_CHANNEL_DESC);
            nm.createNotificationChannel(channel);
        } catch (final Exception e) {
            HBlogger.e(TAG, "ensureChannel 异常", e);
        }
        return channelId;
    }

    private static int resolveSmallIcon(@NonNull final Context context, final HBPersistentStorage storage) {
        try {
            if (storage != null) {
                final int configured = storage.getNotificationIcon();
                if (configured != 0) {
                    return configured;
                }
            }
        } catch (final Exception ignored) {
        }
        return ApplicationUtils.getLogoResourceValue(context);
    }

    @NonNull
    private static PendingIntent buildContentIntent(@NonNull final Context context) {
        Intent intent = null;
        try {
            intent = ApplicationUtils.getLaunchIntent(context, context.getPackageName());
        } catch (final Exception ignored) {
        }
        if (intent == null) {
            intent = new Intent(context, HelpBotActivity.class);
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);

        final int flags = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                : PendingIntent.FLAG_UPDATE_CURRENT;

        return PendingIntent.getActivity(context, 0, intent, flags);
    }

    @NonNull
    private static String resolveAppName(@NonNull final Context context) {
        try {
            final CharSequence label = context.getPackageManager().getApplicationLabel(context.getApplicationInfo());
            return (label == null) ? "HelpBot" : String.valueOf(label);
        } catch (final Exception ignored) {
            return "HelpBot";
        }
    }
}
