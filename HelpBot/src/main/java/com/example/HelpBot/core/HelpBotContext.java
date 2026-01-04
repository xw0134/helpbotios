package com.example.HelpBot.core;

import com.example.HelpBot.chat.EventProxy;
import com.example.HelpBot.storage.HBPersistentStorage;
import com.example.HelpBot.storage.HBGenericDataManager;
import com.example.HelpBot.BuildConfig;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.storage.SharedPreferencesStore;

import android.content.Context;

import java.util.concurrent.atomic.AtomicBoolean;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * HelpBot SDK 环境上下文。
 * 负责管理 SDK 的生命周期、组件初始化及全局配置。
 */
public class HelpBotContext {
    private static final String TAG = "Context";
    private static HelpBotContext instance;

    /**
     * 未初始化提示限流：避免宿主在 install 进行中频繁调用 API 时刷屏。
     */
    private static final AtomicBoolean hasWarnedNotInstalled = new AtomicBoolean(false);

    /**
     * install 进行中标记：用于避免“初始化过程中”误报未初始化。
     *
     * 设计目标：
     * 1. install 进行中：API 调用应被保护性忽略或失败，但日志不应误导为“install 失败”。
     * 2. install 未调用或已失败：需要明确提示。
     */
    private static final AtomicBoolean installInProgress = new AtomicBoolean(false);

    /**
     * 无日志的“是否已安装成功”判断。
     *
     * 设计约束：
     * 1. install 内部做状态判断时禁止刷错误日志（否则会出现“初始化过程中误报失败”）。
     */
    public static boolean isInstalled() {
        try {
            return HelpBotContext.installCallSuccessful != null && HelpBotContext.installCallSuccessful.get();
        } catch (final Exception ignored) {
            return false;
        }
    }

    public static final String HELP_BOT_SDK_CACHE_NAME = "helpBot_sdk_store";
    private EventProxy eventProxy;
    private Device device;
    private final HBPersistentStorage persistentStorage;
    private final HBGenericDataManager genericDataManager;
    public final Context context;
    public static AtomicBoolean installCallSuccessful;

    public HelpBotContext(@NonNull final Context context) {
        if (context == null) {
            throw new IllegalArgumentException("Context 不能为空");
        }

        final Context appContext = context.getApplicationContext();
        this.context = appContext;

        // 验证 Context 类型
        if (!(appContext instanceof android.app.Application)) {
            HBlogger.w(TAG, "警告: Context 不是 Application 类型，可能存在内存泄漏风险");
            HBlogger.w(TAG, "Context 类型: " + appContext.getClass().getName());
        } else {
            HBlogger.d(TAG, "Context 类型验证通过: ApplicationContext");
        }

        this.persistentStorage = new HBPersistentStorage(
                this.context,
                new SharedPreferencesStore(this.context, HELP_BOT_SDK_CACHE_NAME, 0));
        this.genericDataManager = new HBGenericDataManager(this.persistentStorage);
    }

    public static synchronized void initInstance(@NonNull final Context context) {
        if (context == null) {
            HBlogger.e(TAG, "initInstance: Context 不能为空");
            return;
        }
        final Context appContext = context.getApplicationContext();

        // 验证 Context 类型
        if (!(appContext instanceof android.app.Application)) {
            HBlogger.e(TAG, "严重警告: 传入的 Context 不是 Application 类型!");
            HBlogger.e(TAG, "Context 类型: " + appContext.getClass().getName());
        }

        if (HelpBotContext.instance == null) {
            HelpBotContext.instance = new HelpBotContext(appContext);
            HBlogger.d(TAG, "HelpBotContext 实例已使用 ApplicationContext 创建");
        } else {
            // 验证现有实例的 Context 类型
            if (HelpBotContext.instance.context != appContext) {
                HBlogger.w(TAG, "initInstance: 实例已存在且使用了不同的 Context");
            }
        }
    }

    public static HelpBotContext getInstance() {
        return HelpBotContext.instance;
    }

    /**
     * 初始化各类组件。
     *
     * @param context 上下文
     */
    public void initialiseComponents(@NonNull final Context context) {
        this.device = new AndroidDevice(context, this.persistentStorage);
        this.eventProxy = new EventProxy();
    }

    /**
     * 获取设备信息采集器（SDK 内部使用）。
     */
    public Device getDevice() {
        return this.device;
    }

    /**
     * 获取通用数据管理器（SDK 内部使用）。
     */
    public HBGenericDataManager getGenericDataManager() {
        return this.genericDataManager;
    }

    /**
     * 获取持久化存储（SDK 内部使用）。
     */
    public HBPersistentStorage getPersistentStorage() {
        return this.persistentStorage;
    }

    /**
     * 获取事件代理（SDK 内部使用）。
     */
    public EventProxy getEventProxy() {
        return this.eventProxy;
    }

    /**
     * @deprecated 已移除历史状态字段，保留空实现避免旧代码调用崩溃。将在下一个主版本移除。
     */
    @Deprecated
    public void setSdkIsOpen(final boolean isOpen) {
    }

    /**
     * @deprecated 已移除历史状态字段，保留空实现避免旧代码调用崩溃。将在下一个主版本移除。
     */
    @Deprecated
    public boolean isSdkOpen() {
        return false;
    }

    /**
     * @deprecated 日志开关由 HBlogger/BuildConfig 统一管理。将在下一个主版本移除。
     */
    @Deprecated
    public void setSDKLoggingEnabled(final boolean enableLogging) {
    }

    /**
     * @deprecated 日志开关由 HBlogger/BuildConfig 统一管理。将在下一个主版本移除。
     */
    @Deprecated
    public boolean isSDKLoggingEnabled() {
        return false;
    }

    /**
     * 验证是否已安装成功。
     *
     * @return 如果已安装返回 true，否则返回 false
     */
    public static boolean verifyInstall() {
        if (isInstalled()) {
            return true;
        }

        // install 进行中：避免误导为“失败”，只做低级别提示（并限流）
        try {
            if (installInProgress.get()) {
                // 关键：初始化过程中不要刷 Error（会误导宿主认为 install 失败）
                if (hasWarnedNotInstalled.compareAndSet(false, true)) {
                    HBlogger.w(TAG, "HelpBot install 正在进行中：请等待 onInitSuccess 后再调用相关 API");
                }
                return false;
            }
        } catch (final Exception ignored) {
        }

        // 未安装/未调用 install：只提示一次，避免刷屏（也避免误导为“失败”）
        if (hasWarnedNotInstalled.compareAndSet(false, true)) {
            // Debug 也不要用 Error：宿主可能只是提前做 isInitialized() / 状态检查
            HBlogger.w(TAG, "HelpBot SDK 未初始化：请先调用 HelpBot.install(...) 完成初始化");
        }
        return false;
    }

    /**
     * SDK 内部使用：设置 install 是否进行中。
     *
     * 注意：该方法为 SDK 内部状态机使用，宿主不应调用。
     */
    public static void setInstallInProgress(final boolean inProgress) {
        try {
            installInProgress.set(inProgress);
            // install 周期重置一次提示限流，保证下一轮 install 能正常提示
            if (!inProgress) {
                hasWarnedNotInstalled.set(false);
            }
        } catch (final Exception ignored) {
        }
    }

    /**
     * 销毁 HelpBotContext，释放所有资源。
     *
     * 此方法会清理所有单例引用和资源，调用后需要重新初始化才能使用 SDK。
     */
    public static synchronized void destroy() {
        try {
            HBlogger.d(TAG, "开始销毁 HelpBotContext");

            if (instance != null) {
                // 清理事件代理
                if (instance.eventProxy != null) {
                    instance.eventProxy.setHelpshiftEventsListener(null);
                    instance.eventProxy = null;
                }

                // 清理其他组件引用
                instance.device = null;

                // 清理单例
                instance = null;
            }

            // 重置初始化标志
            if (installCallSuccessful != null) {
                installCallSuccessful.set(false);
            }

            HBlogger.d(TAG, "HelpBotContext 销毁完成");
        } catch (final Exception e) {
            HBlogger.e(TAG, "销毁异常", e);
        }
    }

    static {
        HelpBotContext.installCallSuccessful = new AtomicBoolean(false);
    }
}
