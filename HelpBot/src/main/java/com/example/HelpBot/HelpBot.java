package com.example.HelpBot;

import com.example.HelpBot.activity.HelpBotActivity;
import com.example.HelpBot.core.HelpBotCallback;
import com.example.HelpBot.core.HelpBotConfig;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.core.HelpBotErrorCode;
import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.core.HelpBotInitCallback;
import com.example.HelpBot.core.HelpBotResult;
import com.example.HelpBot.core.HelpBotUserLoginEventsListener;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.storage.EncryptedStorage;
import com.example.HelpBot.thread.HelpBotThreadPool;
import com.example.HelpBot.utils.NetworkUtils;
import com.example.HelpBot.utils.Utils;
import com.example.HelpBot.web.HelpBotJsCommand;
import com.example.HelpBot.web.HelpBotWebViewContextUtils;
import com.example.HelpBot.web.HelpBotWebViewSession;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

import androidx.annotation.DrawableRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.lang.ref.WeakReference;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * HelpBot SDK 主入口类。
 * 设计要点：
 * 1. 仅提供异步 API（SDK 作为依赖库，避免宿主误在主线程调用阻塞接口导致 ANR/死锁）。
 * 2. 统一错误码与回调机制。
 * 3. 线程安全与资源生命周期管理。
 * 线程约束：
 * - SDK 内部所有涉及 WebView/JS 回执等待的逻辑都在后台线程执行。
 */
public final class HelpBot {
    private static final String TAG = "HelpBot";
    private static final String TOKEN_STORAGE_KEY_JWT = "jwt_token";

    /**
     * install 等待 WebSDK 初始化回执的默认超时（毫秒）。
     * 需要覆盖 WebSDK loader 加载 + init 轮询 + 一次 reload 重试的总时长。
     */
    private static final long DEFAULT_WEBSDK_INIT_WAIT_TIMEOUT_MS = 35_000L;

    /**
     * login 等待 WebSDK 登录完成（SDK_READY）的默认超时（毫秒）。
     */
    private static final long DEFAULT_WEBSDK_LOGIN_WAIT_TIMEOUT_MS = 30_000L;

    /**
     * install 阶段：等待 WebSDK bridge/native 通道“全就绪”的超时（毫秒）。
     */
    private static final long DEFAULT_WEBSDK_BOOTSTRAP_WAIT_TIMEOUT_MS = 20_000L;

    /**
     * SDK 内部登录确认标记（用于 showConversation 快速判定，避免主线程阻塞）。
     * 说明：按约定，只有调用 HelpBot.login 并被确认成功后才置为 true。
     */
    private static final AtomicBoolean loginConfirmed = new AtomicBoolean(false);

    /**
     * install 并发标志：避免并发/重复 install 造成状态互相污染（尤其是 WebViewSession 的 latch/flag）。
     */
    private static final AtomicBoolean installInProgress = new AtomicBoolean(false);

    // ==================== install/login/showConversation 状态机（强约束） ====================

    /**
     * install 状态机：
     * - 只有 FAILED 才允许再次 install（符合需求：只有 install 明确失败后才能重新 install）
     */
    private enum InstallState {
        NOT_INSTALLED,
        INSTALLING,
        INSTALLED,
        FAILED
    }

    /**
     * login 状态机：
     * - 只有 FAILED / NOT_LOGGED_IN / logout 后才允许再次 login
     * - install 未完成时允许进入 LOGIN_PENDING（排队）
     */
    private enum LoginState {
        NOT_LOGGED_IN,
        LOGIN_PENDING,
        LOGGING_IN,
        LOGGED_IN,
        FAILED
    }

    /**
     * 全局操作锁：确保 install/login/showConversation 的状态切换与排队行为是原子性的。
     */
    private static final Object operationLock = new Object();

    @NonNull
    private static volatile InstallState installState = InstallState.NOT_INSTALLED;
    @NonNull
    private static volatile LoginState loginState = LoginState.NOT_LOGGED_IN;

    /**
     * 入队请求的 TTL（毫秒）：避免宿主错误调用导致“未来某个时刻突然执行”。
     */
    private static final long PENDING_REQUEST_TTL_MS = 2 * 60 * 1000L;

    @Nullable
    private static volatile PendingLoginRequest pendingLoginRequest;
    @Nullable
    private static volatile PendingShowConversationRequest pendingShowConversationRequest;
    @Nullable
    private static volatile PendingEventsListenerRequest pendingEventsListenerRequest;

    /**
     * 待执行的 login 请求（install 未完成时入队）。
     */
    private static final class PendingLoginRequest {
        @NonNull
        final String token;
        @Nullable
        final Map<String, Object> loginConfig;
        @Nullable
        final HelpBotCallback<Void> callback;
        final long createdAtMs;

        private PendingLoginRequest(@NonNull final String token,
                @Nullable final Map<String, Object> loginConfig,
                @Nullable final HelpBotCallback<Void> callback) {
            this.token = token;
            this.loginConfig = loginConfig;
            this.callback = callback;
            this.createdAtMs = System.currentTimeMillis();
        }
    }

    /**
     * 待执行的 showConversation 请求（install/login 未完成时入队）。
     * 说明：
     * - 只保存 applicationContext，避免持有 Activity 导致泄漏
     */
    private static final class PendingShowConversationRequest {
        @NonNull
        final Context appContext;
        final long createdAtMs;

        private PendingShowConversationRequest(@NonNull final Context context) {
            this.appContext = context.getApplicationContext();
            this.createdAtMs = System.currentTimeMillis();
        }
    }

    /**
     * 待执行的 EventsListener 设置请求（install 未完成时入队）。
     *
     * 设计约束：
     * - 必须在 install 完成后才真正绑定到 EventProxy（与需求对齐）。
     * - 只保留最后一次设置（避免宿主频繁调用导致状态错乱/内存增长）。
     * - 允许 listener=null（表示移除监听器）。
     */
    private static final class PendingEventsListenerRequest {
        @Nullable
        final WeakReference<HelpBotEventsListener> listenerRef;
        final long createdAtMs;

        private PendingEventsListenerRequest(@Nullable final HelpBotEventsListener listener) {
            this.listenerRef = (listener == null) ? null : new WeakReference<>(listener);
            this.createdAtMs = System.currentTimeMillis();
        }

        @Nullable
        private HelpBotEventsListener getListener() {
            return (listenerRef == null) ? null : listenerRef.get();
        }
    }

    // ==================== 私有静态字段 ====================

    /**
     * SDK 配置（私有，通过 install 设置）
     */
    private static volatile HelpBotConfig config;

    /**
     * 当前展示 HelpBot UI 的 Activity 引用（WeakReference 防止内存泄漏）
     */
    private static volatile WeakReference<HelpBotActivity> currentActivityRef = new WeakReference<>(null);

    /**
     * 待补发的 login token（临时存储，使用后立即清除）
     */
    private static volatile String pendingLoginToken;

    /**
     * SSE 通知开关的运行时覆盖值（避免 HelpBotConfig 不可变导致 enableSseNotification 空实现）。
     * - null：未覆盖，使用 config 默认值
     * - non-null：使用覆盖值
     */
    private static volatile Boolean sseNotificationEnabledOverride;

    /**
     * 主线程 Handler
     */
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    // ==================== 私有构造函数 ====================

    /**
     * 私有构造函数，防止实例化
     */
    private HelpBot() {
        throw new AssertionError("HelpBot 不能被实例化");
    }

    /**
     * 初始化 HelpBot SDK（异步，推荐）
     * 此方法会在后台线程执行初始化，不会阻塞主线程。
     * 
     * @param application Application Context（必须）
     * @param config      SDK 配置（必须）
     */
    public static void install(@NonNull final Context application,
            @NonNull final HelpBotConfig config) {
        install(application, config, null);
    }

    /**
     * 初始化 HelpBot SDK（兼容需求文档签名：channelId/domain/configMap）。
     * 说明：
     * - SDK 内 WebChat index/loader 链接已写死，domain 仅作为 WebSDK baseURL（业务域名）使用。
     * - configMap 会被写入 HelpBotConfig.customConfig（供 UI/行为开关读取）。
     *
     * @param application Application/Activity Context（必须）
     * @param channelId   channelId（必填）
     * @param domain      baseURL（必填，必须 https）
     * @param configMap   配置（可选）
     * @param callback    初始化回调（可选）
     */
    public static void install(@NonNull final Context application,
            @NonNull final String channelId,
            @NonNull final String domain,
            @Nullable final Map<String, Object> configMap,
            @Nullable final HelpBotInitCallback callback) {
        try {
            final HelpBotConfig.Builder builder = new HelpBotConfig.Builder()
                    .channelId(channelId)
                    .domain(domain);

            builder.fullPrivacyMode(readBooleanFromMap(configMap, "fullPrivacyMode", false));

            // customConfig：保存所有原始配置，供 SDK 内部（如标题栏）读取
            try {
                if (configMap != null && !configMap.isEmpty()) {
                    for (final Map.Entry<String, Object> e : configMap.entrySet()) {
                        if (e == null) {
                            continue;
                        }
                        final String k = e.getKey();
                        final Object v = e.getValue();
                        if (k == null || k.trim().isEmpty() || v == null) {
                            continue;
                        }
                        builder.addCustomConfig(k, v);
                    }
                }
            } catch (final Exception ignored) {
            }

            install(application, builder.build(), callback);
        } catch (final Exception e) {
            HBlogger.e(TAG, "install(channelId/domain/configMap) 异常", e);
            notifyInitFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "初始化参数非法: " + e.getMessage());
        }
    }

    public static void install(@NonNull final Context application,
            @NonNull final String channelId,
            @NonNull final String domain,
            @Nullable final Map<String, Object> configMap) {
        install(application, channelId, domain, configMap, null);
    }

    /**
     * 初始化 HelpBot SDK（异步，推荐）。
     *
     * @param application Application Context（必须）
     * @param config      SDK 配置（必须）
     * @param callback    初始化回调（可选）
     */
    public static void install(@NonNull final Context application,
            @NonNull final HelpBotConfig config,
            @Nullable final HelpBotInitCallback callback) {

        // install 状态机（强约束）：
        // - install 进行中：拒绝重复调用
        // - install 已成功：拒绝重复调用
        // - 只有 install 明确失败（FAILED）才允许重试
        synchronized (operationLock) {
            // 以 HelpBotContext 为准，避免状态漂移
            if (HelpBotContext.isInstalled() || installState == InstallState.INSTALLED) {
                installState = InstallState.INSTALLED;
                HBlogger.w(TAG, "HelpBot 已初始化，忽略重复调用");
                notifyInitFailure(callback, HelpBotErrorCode.SDK_ALREADY_INITIALIZED, "SDK 已初始化");
                return;
            }
            if (installState == InstallState.INSTALLING) {
                HBlogger.w(TAG, "install 被重复调用：install 已在进行中");
                notifyInitFailure(callback, HelpBotErrorCode.OPERATION_IN_PROGRESS, "install 正在进行中，请勿重复调用");
                return;
            }
            if (installState != InstallState.NOT_INSTALLED && installState != InstallState.FAILED) {
                HBlogger.w(TAG, "install 当前状态不允许：state=" + installState);
                notifyInitFailure(callback, HelpBotErrorCode.OPERATION_NOT_ALLOWED, "当前状态不允许 install");
                return;
            }
            // 并发标志：install 只能串行执行（与状态机绑定，防止竞态）
            if (!installInProgress.compareAndSet(false, true)) {
                HBlogger.w(TAG, "install 被重复调用：install 已在进行中");
                notifyInitFailure(callback, HelpBotErrorCode.OPERATION_IN_PROGRESS, "install 正在进行中，请勿重复调用");
                return;
            }

            // 本次 install 开始：强制清理“上一次请求残留”（只允许 FAILED 后重试）
            installState = InstallState.INSTALLING;
            loginState = LoginState.NOT_LOGGED_IN;
            pendingLoginRequest = null;
            pendingShowConversationRequest = null;
            try {
                loginConfirmed.set(false);
            } catch (final Exception ignored) {
            }
        }
        // 标记 install 进行中（用于避免 verifyInstall 误报）
        try {
            HelpBotContext.setInstallInProgress(true);
        } catch (final Exception ignored) {
        }

        notifyInitStart(callback);

        notifyInitProgress(callback, 8, "检查网络状态");
        try {
            final NetworkUtils.NetworkDiagnosis diagnosis = NetworkUtils.diagnose(application.getApplicationContext());
            if (diagnosis.hasAccessNetworkStatePermission) {
                if (!diagnosis.networkConnected || !diagnosis.hasInternetCapability) {
                    notifyInitFailure(callback, HelpBotErrorCode.NETWORK_UNAVAILABLE,
                            "网络不可用，WebSDK 初始化无法完成。"
                                    + diagnosis.buildUserHint());
                    onInstallFinished(false, HelpBotErrorCode.NETWORK_UNAVAILABLE,
                            "网络不可用，WebSDK 初始化无法完成。" + diagnosis.buildUserHint());
                    installInProgress.set(false);
                    try {
                        HelpBotContext.setInstallInProgress(false);
                    } catch (final Exception ignored) {
                    }
                    return;
                }
            }
        } catch (final Exception ignored) {
        }

        notifyInitProgress(callback, 10, "检查 WebView 可用性");
        if (!checkWebViewAvailability(application)) {
            HBlogger.e(TAG, "install 失败: WebView 组件不可用");
            notifyInitFailure(callback, HelpBotErrorCode.WEBVIEW_UNAVAILABLE,
                    HelpBotErrorCode.WEBVIEW_UNAVAILABLE.getMessage());
            onInstallFinished(false, HelpBotErrorCode.WEBVIEW_UNAVAILABLE,
                    HelpBotErrorCode.WEBVIEW_UNAVAILABLE.getMessage());
            installInProgress.set(false);
            try {
                HelpBotContext.setInstallInProgress(false);
            } catch (final Exception ignored) {
            }
            return;
        }

        HelpBotThreadPool.getInstance().submit(() -> {
            try {
                final HelpBotResult<Void> result = installInternal(application, config, callback);

                if (result.isSuccess()) {
                    onInstallFinished(true, null, null);
                    notifyInitSuccess(callback);

                } else {
                    onInstallFinished(false, result.getErrorCode(), result.getErrorMessage());
                    notifyInitFailure(callback, result.getErrorCode(), result.getErrorMessage());
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "install 异常", e);
                onInstallFinished(false, HelpBotErrorCode.INTERNAL_ERROR, "初始化异常: " + e.getMessage());
                notifyInitFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, "初始化异常: " + e.getMessage());
            } finally {
                // 确保并发标志释放
                installInProgress.set(false);
                try {
                    HelpBotContext.setInstallInProgress(false);
                } catch (final Exception ignored) {
                }
            }
        });
    }

    /**
     * install 结束（成功/失败）后的统一收口处理：
     * - 成功：根据排队请求触发 login/showConversation
     * - 失败：中止排队的 login/showConversation（install 出错直接中止 login/showConversation 执行）
     * 注意：该方法必须是线程安全的，且不能在锁内触发宿主回调，避免死锁/重入。
     */
    private static void onInstallFinished(final boolean success,
            @Nullable final HelpBotErrorCode errorCode,
            @Nullable final String errorMessage) {
        PendingLoginRequest loginToRun = null;
        PendingLoginRequest loginToCancel = null;
        PendingShowConversationRequest showToRun = null;
        PendingEventsListenerRequest eventsListenerToApply = null;

        synchronized (operationLock) {
            if (success) {
                installState = InstallState.INSTALLED;
            } else {
                installState = InstallState.FAILED;
            }

            final long now = System.currentTimeMillis();
            // 清理过期请求（避免未来突然执行）
            if (pendingLoginRequest != null && now - pendingLoginRequest.createdAtMs > PENDING_REQUEST_TTL_MS) {
                pendingLoginRequest = null;
                if (loginState == LoginState.LOGIN_PENDING) {
                    loginState = LoginState.NOT_LOGGED_IN;
                }
            }
            if (pendingShowConversationRequest != null
                    && now - pendingShowConversationRequest.createdAtMs > PENDING_REQUEST_TTL_MS) {
                pendingShowConversationRequest = null;
            }
            if (pendingEventsListenerRequest != null
                    && now - pendingEventsListenerRequest.createdAtMs > PENDING_REQUEST_TTL_MS) {
                pendingEventsListenerRequest = null;
            }

            if (!success) {
                // install 失败：中止排队请求（login/showConversation）
                if (pendingLoginRequest != null) {
                    loginToCancel = pendingLoginRequest;
                    pendingLoginRequest = null;
                }
                pendingShowConversationRequest = null;
                pendingEventsListenerRequest = null;
                loginState = LoginState.FAILED;
                try {
                    loginConfirmed.set(false);
                } catch (final Exception ignored) {
                }
            } else {
                // install 成功：优先应用排队的事件监听器（必须在 install 完成后才生效）
                if (pendingEventsListenerRequest != null) {
                    eventsListenerToApply = pendingEventsListenerRequest;
                    pendingEventsListenerRequest = null;
                }
                // install 成功：若有排队 login，则执行（只执行一次）
                if (pendingLoginRequest != null && loginState == LoginState.LOGIN_PENDING) {
                    loginToRun = pendingLoginRequest;
                    pendingLoginRequest = null;
                    loginState = LoginState.LOGGING_IN;
                }
                // install 成功：若没有待执行 login 且已登录确认，则可以执行排队的 showConversation
                if (loginToRun == null
                        && pendingShowConversationRequest != null
                        && (loginConfirmed.get() || loginState == LoginState.LOGGED_IN)) {
                    showToRun = pendingShowConversationRequest;
                    pendingShowConversationRequest = null;
                }
            }
        }

        // install 失败：回调中止 login（锁外执行）
        if (!success) {
            if (loginToCancel != null) {
                final HelpBotErrorCode code = (errorCode == null) ? HelpBotErrorCode.INTERNAL_ERROR : errorCode;
                final String msg = (errorMessage == null || errorMessage.trim().isEmpty())
                        ? "install 失败，已中止 login 执行"
                        : ("install 失败，已中止 login 执行: " + errorMessage);
                notifyFailure(loginToCancel.callback, code, msg);
            }
            return;
        }

        // install 成功：先绑定事件监听器（锁外执行，避免回调重入）
        if (eventsListenerToApply != null) {
            try {
                applyEventsListenerNow(eventsListenerToApply.getListener());
            } catch (final Exception e) {
                HBlogger.e(TAG, "install 后应用 EventsListener 异常", e);
            }
        }

        // install 成功：触发排队操作
        if (loginToRun != null) {
            submitLoginInternal(loginToRun);
        }
        if (showToRun != null) {
            final PendingShowConversationRequest req = showToRun;
            mainHandler.post(() -> {
                try {
                    showConversationNow(req.appContext);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "install 后执行 showConversation 异常", e);
                }
            });
        }
    }

    /**
     * 立即应用事件监听器（要求：必须在 install 成功后调用）。
     */
    private static void applyEventsListenerNow(@Nullable final HelpBotEventsListener listener) {
        try {
            if (!HelpBotContext.verifyInstall()) {
                return;
            }
            final HelpBotContext ctx = HelpBotContext.getInstance();
            if (ctx == null || ctx.getEventProxy() == null) {
                return;
            }
            ctx.getEventProxy().setHelpshiftEventsListener(listener);
        } catch (final Exception e) {
            HBlogger.e(TAG, "applyEventsListenerNow 异常", e);
        }
    }

    /**
     * 内部初始化实现
     */
    @NonNull
    private static HelpBotResult<Void> installInternal(@NonNull final Context application,
            @NonNull final HelpBotConfig config,
            @Nullable final HelpBotInitCallback callback) {
        boolean installed = false;
        try {

            // 进度：15% - 清理上次失败的残留状态
            notifyInitProgress(callback, 15, "清理上次安装残留状态");
            try {
                // 1) 强制复位 WebViewSession（关键：复位 hasInitFailed/latch/WebView，避免污染下一次 install）
                final HelpBotWebViewSession session = HelpBotWebViewSession.getInstance();
                final boolean resetOk = session.destroySessionBlocking(6_000L);
                if (!resetOk) {
                    HBlogger.w(TAG, "destroySessionBlocking 超时/失败，将继续 install（下次仍会再次尝试清理）");
                }

                // 2) 复位 HelpBotContext（避免组件/事件代理处于半初始化状态）
                try {
                    HelpBotContext.destroy();
                } catch (final Exception e) {
                    HBlogger.d(TAG, "HelpBotContext.destroy 异常（可忽略）", e);
                }
            } catch (final Exception e) {
                // 清理失败不应直接中断 install，但必须记录日志，避免“重试永远失败”
                HBlogger.e(TAG, "install: 清理残留状态异常", e);
            }

            // 进度：30% - 保存配置
            notifyInitProgress(callback, 30, "保存配置");
            HelpBot.config = config;

            // 进度：50% - 初始化 Context
            notifyInitProgress(callback, 50, "初始化环境");
            final Context appContext = application.getApplicationContext();
            HelpBotContext.initInstance(appContext);
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            hbContext.initialiseComponents(appContext);

            // 进度：70% - 预加载 WebView
            notifyInitProgress(callback, 70, "预加载 WebView");
            try {
                // 预加载并等待 WebSDK 初始化完成（必须有明确回执才算 install 完成）
                final HelpBotWebViewSession session = HelpBotWebViewSession.getInstance();
                session.preload(appContext, true);

                notifyInitProgress(callback, 80, "等待 WebSDK 初始化回执");
                final boolean ok = session.awaitWebSdkInitialized(DEFAULT_WEBSDK_INIT_WAIT_TIMEOUT_MS);
                if (!ok) {
                    final String reason = session.getWebSdkInitFailedReason();
                    if ("init_timeout".equalsIgnoreCase(reason)) {
                        // 超时高概率与网络相关：无网/受限网络/企业防火墙或域名不可达
                        try {
                            String webViewHint = "";
                            try {
                                final HelpBotWebViewSession.WebViewLoadErrorSnapshot err = session
                                        .getLastLoadErrorSnapshot();
                                if (err != null) {
                                    final StringBuilder sb = new StringBuilder();
                                    sb.append("（最近一次 WebView 错误：").append(err.type);
                                    if (err.httpStatus != null) {
                                        sb.append(" httpStatus=").append(err.httpStatus);
                                    }
                                    if (err.errorCode != null) {
                                        sb.append(" errorCode=").append(err.errorCode);
                                    }
                                    if (err.mainFrame) {
                                        sb.append(" mainFrame=true");
                                    }
                                    sb.append("）");
                                    webViewHint = sb.toString();
                                }
                            } catch (final Exception e) {
                                HBlogger.d(TAG, "获取 WebView 错误快照异常", e);
                                webViewHint = "";
                            }

                            final NetworkUtils.NetworkDiagnosis diagnosis = NetworkUtils.diagnose(appContext);
                            if (diagnosis.hasAccessNetworkStatePermission) {
                                if (!diagnosis.networkConnected || !diagnosis.hasInternetCapability) {
                                    return HelpBotResult.failure(HelpBotErrorCode.NETWORK_UNAVAILABLE,
                                            "WebSDK 初始化超时：当前网络不可用或被禁用。"
                                                    + diagnosis.buildUserHint()
                                                    + webViewHint);
                                }
                                return HelpBotResult.failure(HelpBotErrorCode.NETWORK_TIMEOUT,
                                        "WebSDK 初始化超时：网络可能受限/被策略拦截或目标域名不可达。"
                                                + diagnosis.buildUserHint()
                                                + webViewHint);
                            }
                        } catch (final Exception e) {
                            HBlogger.d(TAG, "网络诊断异常", e);
                        }
                        return HelpBotResult.failure(HelpBotErrorCode.OPERATION_TIMEOUT,
                                "WebSDK 初始化确认超时（可能与网络不可用/受限/被策略拦截有关，请检查网络与域名访问策略）");
                    }
                    if (reason != null && !reason.trim().isEmpty()) {
                        return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_INIT_FAILED,
                                "WebSDK 初始化失败: " + reason);
                    }
                    return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_INIT_FAILED, "WebSDK 初始化失败");
                }

                // 进一步：等待 bridge/native 通道就绪（确保 SDK_READY/SDK_ERROR 能可靠送达宿主）
                notifyInitProgress(callback, 85, "等待 WebSDK 通道就绪");
                final boolean bootstrapOk = session.awaitWebSdkBootstrapReady(DEFAULT_WEBSDK_BOOTSTRAP_WAIT_TIMEOUT_MS);
                if (!bootstrapOk) {
                    return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_INIT_FAILED,
                            "WebSDK 通道未就绪（Bridge/Native 通信异常）");
                }

                // 启动健康监管（install 完成后持续运行，直到 destroy）
                try {
                    session.startMonitoring(hbContext.getEventProxy());
                } catch (final Exception e) {
                    HBlogger.d(TAG, "启动 WebSDK 监控异常", e);
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "preload/await WebSDK 初始化异常", e);
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_INIT_FAILED, "WebSDK 初始化异常: " + e.getMessage());
            }

            // 进度：90% - 设置完成标志
            notifyInitProgress(callback, 90, "完成初始化");
            HelpBotContext.installCallSuccessful.compareAndSet(false, true);
            installed = true;

            // 进度：100% - 完成
            notifyInitProgress(callback, 100, "初始化完成");
            HBlogger.d(TAG, "HelpBot 初始化成功");

            return HelpBotResult.success();

        } catch (final Exception e) {
            HBlogger.e(TAG, "installInternal 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "初始化失败: " + e.getMessage());
        } finally {
            // install 失败：清理关键内存态，避免宿主误用（例如 getConfig() 非空但 verifyInstall=false）
            if (!installed) {
                try {
                    HelpBot.config = null;
                } catch (final Exception e) {
                    HBlogger.d(TAG, "清理 config 异常", e);
                }
                try {
                    HelpBotContext.installCallSuccessful.set(false);
                } catch (final Exception e) {
                    HBlogger.d(TAG, "重置 installCallSuccessful 异常", e);
                }
            }
        }
    }

    /**
     * 检测 WebView 组件可用性
     */
    private static boolean checkWebViewAvailability(@NonNull final Context context) {
        try {
            // 方法1: 检查 WebView 包信息 (API 26+)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                final android.content.pm.PackageInfo webViewPackage = WebView.getCurrentWebViewPackage();
                if (webViewPackage == null) {
                    HBlogger.e(TAG, "WebView 组件未安装");
                    return false;
                }
                HBlogger.d(TAG, "WebView 组件: " + webViewPackage.packageName + " v" + webViewPackage.versionName);
            }

            // 方法2: 尝试创建 WebView 实例（兼容低版本）
            // 重要：WebView 必须在主线程创建；且部分系统对不是UI环境有更严格校验
            final Context appCtx = context.getApplicationContext();
            final Handler mainHandler = new Handler(Looper.getMainLooper());

            // 如果本身就在主线程，直接创建/销毁就可以（避免主线程等待导致死锁）
            if (Looper.myLooper() == Looper.getMainLooper()) {
                return createAndDestroyTestWebViewOnMainThread(appCtx);
            }

            final CountDownLatch latch = new CountDownLatch(1);
            final boolean[] ok = new boolean[] { false };
            mainHandler.post(() -> {
                try {
                    ok[0] = createAndDestroyTestWebViewOnMainThread(appCtx);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "WebView 创建检测：主线程执行异常", e);
                    ok[0] = false;
                } finally {
                    latch.countDown();
                }
            });

            final boolean finished = latch.await(1200L, TimeUnit.MILLISECONDS);
            if (!finished) {
                HBlogger.e(TAG, "WebView 创建检测超时（可能主线程繁忙/卡顿）");
                return false;
            }
            return ok[0];
        } catch (final Exception e) {
            HBlogger.e(TAG, "WebView 可用性检测异常", e);
            return false;
        }
    }

    /**
     * 仅在主线程调用：创建并销毁一个 WebView，用于判定 WebView 组件是否可用。
     * - 使用离屏安全 Context，兼容 StrictMode/厂商校验
     */
    private static boolean createAndDestroyTestWebViewOnMainThread(@NonNull final Context appCtx) {
        try {
            final Context safeCtx = HelpBotWebViewContextUtils.buildPreloadContext(appCtx);
            final WebView testWebView = new WebView(safeCtx);
            testWebView.destroy();
            HBlogger.d(TAG, "WebView 组件可用");
            return true;
        } catch (final Exception e) {
            HBlogger.e(TAG, "WebView 创建失败", e);
            return false;
        }
    }

    /**
     * 用户登录（异步，推荐）
     * 
     * @param identitiesJWT WebSDK 预生成 Token（preGeneratedToken，必须）
     *                      说明：生产环境必须由宿主后端生成并下发该 token；测试环境可选 useDevAPI（不建议用于生产）。
     * @param loginConfig   登录配置（可选）
     * @param callback      登录回调（可选）
     */
    public static void login(@NonNull final String identitiesJWT,
            @Nullable final Map<String, Object> loginConfig,
            @Nullable final HelpBotCallback<Void> callback) {
        if (Utils.isEmpty(identitiesJWT)) {
            notifyFailure(callback, HelpBotErrorCode.INVALID_TOKEN, "Token 不能为空");
            return;
        }

        // install 未完成时，login 入队等待；install 失败则中止 login
        synchronized (operationLock) {
            // install 进行中：允许入队一次
            if (installState == InstallState.INSTALLING) {
                if (loginState == LoginState.LOGIN_PENDING || loginState == LoginState.LOGGING_IN) {
                    notifyFailure(callback, HelpBotErrorCode.OPERATION_IN_PROGRESS, "login 正在进行中，请勿重复调用");
                    return;
                }
                if (loginState == LoginState.LOGGED_IN || loginConfirmed.get()) {
                    notifyFailure(callback, HelpBotErrorCode.ALREADY_LOGGED_IN,
                            HelpBotErrorCode.ALREADY_LOGGED_IN.getMessage());
                    return;
                }
                pendingLoginRequest = new PendingLoginRequest(identitiesJWT, loginConfig, callback);
                loginState = LoginState.LOGIN_PENDING;
                HBlogger.d(TAG, "login 已入队：等待 install 完成后执行");
                return;
            }

            // install 未开始/已失败：直接拒绝（无配置无法自动 install）
            if (installState != InstallState.INSTALLED || !HelpBotContext.isInstalled()) {
                HBlogger.w(TAG, "login: SDK 未初始化，请先调用 HelpBot.install(...) 完成初始化后再登录");
                notifyFailure(callback, HelpBotErrorCode.SDK_NOT_INITIALIZED,
                        "SDK 未初始化：请先调用 HelpBot.install(...) 完成初始化后再登录");
                return;
            }

            // install 已完成：login 状态
            if (loginState == LoginState.LOGGING_IN) {
                notifyFailure(callback, HelpBotErrorCode.OPERATION_IN_PROGRESS, "login 正在进行中，请勿重复调用");
                return;
            }
            if (loginState == LoginState.LOGGED_IN || loginConfirmed.get()) {
                notifyFailure(callback, HelpBotErrorCode.ALREADY_LOGGED_IN,
                        HelpBotErrorCode.ALREADY_LOGGED_IN.getMessage());
                return;
            }
            // 只有明确失败（FAILED）或未登录才允许 login
            if (loginState != LoginState.NOT_LOGGED_IN && loginState != LoginState.FAILED) {
                notifyFailure(callback, HelpBotErrorCode.OPERATION_NOT_ALLOWED, "当前状态不允许 login");
                return;
            }
            loginState = LoginState.LOGGING_IN;
        }

        submitLoginInternal(new PendingLoginRequest(identitiesJWT, loginConfig, callback));
    }

    public static void login(@NonNull final String identitiesJWT, @Nullable final HelpBotCallback<Void> callback) {
        login(identitiesJWT, null, callback);
    }

    public static void login(@NonNull final String identitiesJWT) {
        login(identitiesJWT, null, (HelpBotCallback<Void>) null);
    }

    /**
     * 提交一次 loginInternal（后台线程执行，结束后更新状态机并触发排队的 showConversation）。
     */
    private static void submitLoginInternal(@NonNull final PendingLoginRequest req) {
        HelpBotThreadPool.getInstance().submit(() -> {
            try {
                final HelpBotResult<Void> result = loginInternal(req.token, req.loginConfig);
                if (result.isSuccess()) {
                    onLoginFinished(true);
                    notifySuccess(req.callback, null);
                } else {
                    onLoginFinished(false);
                    notifyFailure(req.callback,
                            (result.getErrorCode() == null) ? HelpBotErrorCode.LOGIN_FAILED : result.getErrorCode(),
                            (result.getErrorMessage() == null) ? HelpBotErrorCode.LOGIN_FAILED.getMessage()
                                    : result.getErrorMessage());
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "login 异常", e);
                onLoginFinished(false);
                notifyFailure(req.callback, HelpBotErrorCode.INTERNAL_ERROR, "登录异常: " + e.getMessage());
            }
        });
    }

    /**
     * login 结束后的状态机收口。
     * - 成功：允许 showConversation 执行（若之前已入队）
     * - 失败：保持 FAILED，允许宿主重试 login
     */
    private static void onLoginFinished(final boolean success) {
        PendingShowConversationRequest showToRun = null;
        synchronized (operationLock) {
            if (success) {
                loginState = LoginState.LOGGED_IN;
            } else {
                loginState = LoginState.FAILED;
                try {
                    loginConfirmed.set(false);
                } catch (final Exception ignored) {
                }
            }

            // 清理过期 showConversation 请求
            final long now = System.currentTimeMillis();
            if (pendingShowConversationRequest != null
                    && now - pendingShowConversationRequest.createdAtMs > PENDING_REQUEST_TTL_MS) {
                pendingShowConversationRequest = null;
            }

            // login 成功：执行排队的 showConversation
            if (success
                    && installState == InstallState.INSTALLED
                    && pendingShowConversationRequest != null) {
                showToRun = pendingShowConversationRequest;
                pendingShowConversationRequest = null;
            }
        }

        if (showToRun != null) {
            final PendingShowConversationRequest req = showToRun;
            mainHandler.post(() -> {
                try {
                    showConversationNow(req.appContext);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "login 后执行 showConversation 异常", e);
                }
            });
        }
    }

    /**
     * 用户登录认证
     */
    public static void login(@NonNull final String identitiesJWT,
            @Nullable final Map<String, Object> loginConfig,
            @Nullable final HelpBotUserLoginEventsListener userLoginEventsListener) {
        login(identitiesJWT, loginConfig, new HelpBotCallback<Void>() {
            @Override
            public void onSuccess(final Void result) {
                try {
                    if (userLoginEventsListener != null) {
                        userLoginEventsListener.onLoginSuccess();
                    }
                } catch (final Exception ignored) {
                }
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                try {
                    if (userLoginEventsListener == null) {
                        return;
                    }
                    final Map<String, String> err = new HashMap<>();
                    err.put("code", String.valueOf(errorCode));
                    err.put("message", errorMessage);
                    userLoginEventsListener.onLoginFailure(String.valueOf(errorCode), err);
                } catch (final Exception ignored) {
                }
            }
        });
    }

    private static boolean readBooleanFromMap(@Nullable final Map<String, Object> map, @NonNull final String key, final boolean defaultValue) {
        try {
            if (map == null) {
                return defaultValue;
            }
            final Object v = map.get(key);
            if (v == null) {
                return defaultValue;
            }
            if (v instanceof Boolean) {
                return (Boolean) v;
            }
            if (v instanceof Number) {
                return ((Number) v).intValue() != 0;
            }
            final String s = String.valueOf(v).trim();
            if (s.isEmpty()) {
                return defaultValue;
            }
            return "true".equalsIgnoreCase(s) || "1".equalsIgnoreCase(s) || "yes".equalsIgnoreCase(s);
        } catch (final Exception ignored) {
            return defaultValue;
        }
    }

    /**
     * WebSDK SDK_READY 到达时的登录确认（供 JSBridge 调用）。
     * 说明：即使宿主未显式等待 loginInternal（例如先 login 后 install 的自动补执行），只要 Web 侧完成登录并发出
     * SDK_READY，SDK 也应切换为“已登录确认”状态。
     */
    public static void markLoginConfirmedFromWeb() {
        try {
            loginConfirmed.set(true);
            synchronized (operationLock) {
                // Web 侧已确认登录：同步更新状态机，避免宿主重复 login 导致状态错乱
                loginState = LoginState.LOGGED_IN;
            }
        } catch (final Exception ignored) {
        }
    }

    /**
     * 内部登录实现
     */
    @NonNull
    private static HelpBotResult<Void> loginInternal(@NonNull final String identitiesJWT,
            @Nullable final Map<String, Object> loginConfig) {
        try {
            // 新一轮登录开始，先清理确认标记（避免旧状态误判）
            loginConfirmed.set(false);

            // 使用加密存储保存 Token
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null && hbContext.context != null) {
                final EncryptedStorage storage = EncryptedStorage.getInstance(hbContext.context);
                if (storage != null && storage.isAvailable()) {
                    storage.putEncryptedString(TOKEN_STORAGE_KEY_JWT, identitiesJWT);
                    HBlogger.d(TAG, "Token 已加密存储");
                }
            }

            // 关键：login 必须等待 WebSDK 明确 SDK_READY 回执才算成功
            final HelpBotWebViewSession session = HelpBotWebViewSession.getInstance();
            final HelpBotWebViewSession.LoginWaiter waiter = session.beginLoginWait();

            // 可靠的登录触发：
            // - 先确保 WebSDK 初始化完成 + Bridge/Native 通道可用
            // - 再直接执行 setTokenAndConnect（不依赖间接链路），确保 token 被设置并开始与服务器建立连接
            boolean triggered = false;
            try {
                final boolean ready = session.awaitWebSdkInitialized(DEFAULT_WEBSDK_INIT_WAIT_TIMEOUT_MS);
                final boolean bootstrapReady = session
                        .awaitWebSdkBootstrapReady(DEFAULT_WEBSDK_BOOTSTRAP_WAIT_TIMEOUT_MS);
                final WebView wv = session.getWebView();
                if (ready && bootstrapReady && wv != null) {
                    evaluateOnUiNoLog(wv, HelpBotJsCommand.buildSetTokenAndConnect(identitiesJWT),
                            "login_setTokenAndConnect");
                    triggered = true;
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "login: 触发 setTokenAndConnect 异常", e);
            }

            // 兜底：若无法直接触发（例如 WebView 尚未创建），走旧链路（pending token + session 自动执行）
            if (!triggered) {
                pendingLoginToken = identitiesJWT;
                HelpBotWebViewSession.getInstance().ensureAutoLoginIfPossible();
            }

            // 等待 WebSDK 登录确认（按约定：authenticated=true 即表示 WebSDK 已与服务器完成登录认证）
            // - SDK_READY 仍可作为快捷成功信号，但不再强制等待 SSE realtimeConnected
            final long deadline = System.currentTimeMillis() + DEFAULT_WEBSDK_LOGIN_WAIT_TIMEOUT_MS;
            while (System.currentTimeMillis() < deadline) {
                final long remaining = deadline - System.currentTimeMillis();
                final long step = Math.min(250L, Math.max(remaining, 0L));

                // 1) 等待 SDK_READY/失败回执（短步等待，避免一直阻塞）
                waiter.awaitStep(step);

                // 2) 如果 waiter 已结束，直接按结果返回
                if (waiter.isFinished()) {
                    if (waiter.isSuccess()) {
                        HBlogger.d(TAG, "登录成功（WebSDK SDK_READY 已确认）");
                        loginConfirmed.set(true);
                        return HelpBotResult.success();
                    }
                    final String failReason = waiter.getFailReason();
                    final String failDetail = waiter.getFailDetail();
                    if ("user_authentication_failed".equalsIgnoreCase(failReason)) {
                        return HelpBotResult.failure(HelpBotErrorCode.INVALID_TOKEN,
                                (failDetail == null || failDetail.trim().isEmpty())
                                        ? "WebSDK 认证失败"
                                        : ("WebSDK 认证失败: " + failDetail));
                    }
                    if ("websdk_error".equalsIgnoreCase(failReason)) {
                        // failDetail 来自 WebSDK 的 SDK_ERROR 事件数据，通常为 JSON 字符串：{CODE,MESSAGE,DETAILS,...}
                        try {
                            if (failDetail != null && !failDetail.trim().isEmpty()) {
                                final JSONObject err = new JSONObject(failDetail.trim());
                                final String code = err.optString("CODE", err.optString("code", ""));
                                final String message = err.optString("MESSAGE", err.optString("message", ""));

                                if ("MISSING_PRE_GENERATED_TOKEN".equalsIgnoreCase(code)) {
                                    return HelpBotResult.failure(HelpBotErrorCode.MISSING_PRE_GENERATED_TOKEN,
                                            message.trim().isEmpty() ? "生产环境必须提供 preGeneratedToken。请通过后端 API 生成 token 并传入。" : message);
                                }
                                if ("INVALID_PRE_GENERATED_TOKEN".equalsIgnoreCase(code)) {
                                    return HelpBotResult.failure(HelpBotErrorCode.INVALID_PRE_GENERATED_TOKEN,
                                            message.trim().isEmpty() ? "预生成 token 无效，请检查格式" : message);
                                }
                                if (!message.trim().isEmpty()) {
                                    return HelpBotResult.failure(HelpBotErrorCode.LOGIN_FAILED,
                                            "WebSDK 登录失败: " + message);
                                }
                                return HelpBotResult.failure(HelpBotErrorCode.LOGIN_FAILED,
                                        "WebSDK 登录失败: " + failDetail);
                            }
                        } catch (final Exception ignored) {
                        }
                        return HelpBotResult.failure(HelpBotErrorCode.LOGIN_FAILED, "WebSDK 登录失败");
                    }
                    if ("login_replaced".equalsIgnoreCase(failReason)
                            || "session_destroyed".equalsIgnoreCase(failReason)) {
                        return HelpBotResult.failure(HelpBotErrorCode.OPERATION_CANCELLED, "登录操作被取消");
                    }
                    return HelpBotResult.failure(HelpBotErrorCode.LOGIN_FAILED,
                            (failReason == null || failReason.trim().isEmpty())
                                    ? "WebSDK 登录失败"
                                    : ("WebSDK 登录失败: " + failReason));
                }

                // 3) 兜底：检查 WebSDK 状态是否已认证成功
                try {
                    final JSONObject s = session.getWebSdkStatusBlocking(800L);
                    if (s != null) {
                        final boolean authenticated = s.optBoolean("authenticated", false);
                        if (authenticated) {
                            HBlogger.d(TAG, "登录成功（WebSDK authenticated=true 已确认）");
                            loginConfirmed.set(true);
                            return HelpBotResult.success();
                        }
                    }
                } catch (final Exception ignored) {
                }
            }

            return HelpBotResult.failure(HelpBotErrorCode.OPERATION_TIMEOUT, "等待 WebSDK 登录确认超时");

        } catch (final Exception e) {
            HBlogger.e(TAG, "loginInternal 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.LOGIN_FAILED, "登录失败: " + e.getMessage());
        }
    }

    /**
     * 用户登出（异步）
     * 
     * @param callback 登出回调（可选）
     */
    public static void logoutAsync(@Nullable final HelpBotCallback<Void> callback) {
        if (!HelpBotContext.verifyInstall()) {
            notifyFailure(callback, HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
            return;
        }

        HelpBotThreadPool.getInstance().submit(() -> {
            try {
                final HelpBotResult<Void> result = logoutInternal();
                if (result.isSuccess()) {
                    notifySuccess(callback, null);
                } else {
                    notifyFailure(callback, result.getErrorCode(), result.getErrorMessage());
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "logoutAsync 异常", e);
                notifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, "登出异常: " + e.getMessage());
            }
        });
    }

    /**
     * 用户登出（同步）
     * 
     * @return 登出结果
     */
    @NonNull
    public static HelpBotResult<Void> logout() {
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            return logoutInternal();
        } catch (final Exception e) {
            HBlogger.e(TAG, "logout 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "登出异常: " + e.getMessage());
        }
    }

    /**
     * 内部登出实现
     */
    @NonNull
    private static HelpBotResult<Void> logoutInternal() {
        try {
            // 清理加密存储中的 Token
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null && hbContext.context != null) {
                final EncryptedStorage storage = EncryptedStorage.getInstance(hbContext.context);
                if (storage != null) {
                    storage.remove(TOKEN_STORAGE_KEY_JWT);
                    HBlogger.d(TAG, "Token 已从加密存储中移除");
                }
            }

            // 清理内存中的 Token
            consumePendingLoginToken();
            pendingLoginToken = null;
            loginConfirmed.set(false);
            synchronized (operationLock) {
                // logout 明确退出登录态，允许后续重新 login
                loginState = LoginState.NOT_LOGGED_IN;
                pendingLoginRequest = null;
                pendingShowConversationRequest = null;
            }

            // 调用 WebView 销毁
            final WebView webView = getActiveWebView();
            if (webView != null) {
                evaluateOnUi(webView, HelpBotJsCommand.buildDestroy(), "logout");
            }

            HBlogger.d(TAG, "登出成功");
            return HelpBotResult.success();

        } catch (final Exception e) {
            HBlogger.e(TAG, "logoutInternal 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "登出失败: " + e.getMessage());
        }
    }

    /**
     * 显示对话窗口
     * 
     * @param context Context(必须)
     * @return 操作结果
     */
    @NonNull
    public static HelpBotResult<Void> showConversation(@NonNull final Context context) {

        // install/login 未完成时：showConversation 入队等待（只保留 1 个，避免狂点导致内存增长）
        synchronized (operationLock) {
            // install 进行中：入队并立即返回 success（表示“已接收请求”）
            if (installState == InstallState.INSTALLING) {
                pendingShowConversationRequest = new PendingShowConversationRequest(context);
                HBlogger.d(TAG, "showConversation 已入队：等待 install/login 完成后执行");
                return HelpBotResult.success();
            }
            // install 未完成：直接失败（没有 install 配置，无法自动处理）
            if (installState != InstallState.INSTALLED || !HelpBotContext.isInstalled()) {
                return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
            }
            // login 未完成：入队等待
            if (loginState == LoginState.LOGIN_PENDING || loginState == LoginState.LOGGING_IN) {
                pendingShowConversationRequest = new PendingShowConversationRequest(context);
                HBlogger.d(TAG, "showConversation 已入队：等待 login 完成后执行");
                return HelpBotResult.success();
            }
        }

        return showConversationNow(context);
    }

    /**
     * 立即执行 showConversation（不做“入队”决策，避免递归）。
     */
    @NonNull
    private static HelpBotResult<Void> showConversationNow(@NonNull final Context context) {
        try {
            if (!HelpBotContext.verifyInstall()) {
                return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
            }

            // 登录确认：优先使用 loginConfirmed，其次使用监控快照兜底（避免偶发“ready 已到但标记未同步”）
            boolean loggedIn = loginConfirmed.get();
            if (!loggedIn) {
                try {
                    loggedIn = HelpBotWebViewSession.getInstance().isAuthenticatedSnapshot(3_000L);
                } catch (final Exception ignored) {
                    loggedIn = false;
                }
            }
            if (!loggedIn) {
                return HelpBotResult.failure(HelpBotErrorCode.NOT_LOGGED_IN, "请先调用 HelpBot.login(...) 完成登录");
            }

            // 已在会话界面：避免重复启动 Activity 导致 back stack 出现空白页
            final HelpBotActivity current = getCurrentActivity();
            if (current != null && !current.isFinishing()) {
                // 上报系统信息到服务器
                try {
                    reportSystemInfoToServer();
                } catch (final Exception e) {
                    HBlogger.e(TAG, "showConversation: 系统信息上报失败", e);
                }

                HelpBotWebViewSession.getInstance().openWhenReady();
                HBlogger.d(TAG, "showConversation: 已在 HelpBotActivity,直接 openWhenReady");
                return HelpBotResult.success();
            }

            // 启动 Activity
            final Context appContext = context.getApplicationContext();
            final Intent intent = new Intent(appContext, HelpBotActivity.class);

            // 避免重复实例：配合 AndroidManifest launchMode=singleTask,确保复用现有 Activity
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);

            // 如果 context 是 Activity,不需要 FLAG_ACTIVITY_NEW_TASK
            if (context instanceof Activity) {
                context.startActivity(intent);
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                appContext.startActivity(intent);
            }

            // 上报系统信息到服务器
            try {
                reportSystemInfoToServer();
            } catch (final Exception e) {
                HBlogger.e(TAG, "showConversation: 系统信息上报失败", e);
            }

            // 打开聊天窗口
            HelpBotWebViewSession.getInstance().openWhenReady();

            HBlogger.d(TAG, "showConversation 成功");
            return HelpBotResult.success();

        } catch (final Exception e) {
            HBlogger.e(TAG, "showConversation 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "显示对话窗口失败: " + e.getMessage());
        }
    }

    /**
     * 显示客服对话界面。
     *
     */
    @NonNull
    public static HelpBotResult<Void> showConversation(@NonNull final Context context,
            @Nullable final Map<String, Object> configMap) {
        // 先保持行为与 showConversation(context) 一致，避免宿主传参导致行为分叉
        return showConversation(context);
    }

    /**
     * 隐藏对话窗口（不销毁会话）。
     * 设计目标：
     * 1. 满足显示/隐藏/任意位置唤起的需求。
     * 2. 隐藏仅关闭 UI Activity，保持 WebViewSession 可复用，使下次唤起更快。
     */
    @NonNull
    public static HelpBotResult<Void> hideConversation() {
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }
        try {
            final HelpBotActivity activity = getCurrentActivity();
            if (activity == null) {
                // 已经处于隐藏态
                return HelpBotResult.success();
            }

            // 尽量先关闭 WebChat（让 Web 侧同步触发 WIDGET_TOGGLE=false 等事件），再 finish Activity
            try {
                final WebView webView = getActiveWebView();
                if (webView != null) {
                    evaluateOnUi(webView, HelpBotJsCommand.buildClose(), "hideConversation_close");
                }
            } catch (final Exception ignored) {
            }

            mainHandler.post(() -> {
                try {
                    activity.finish();
                } catch (final Exception ignored) {
                }
            });
            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "hideConversation 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "隐藏对话窗口失败: " + e.getMessage());
        }
    }

    /**
     * 发送文本消息（异步）。
     * 对齐 WebSDK：HelpBot('sendMessage', text)
     */
    public static void sendMessageAsync(@NonNull final String message,
            @Nullable final HelpBotCallback<Map<String, Object>> callback) {
        if (Utils.isEmpty(message)) {
            notifyFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "message 不能为空");
            return;
        }
        if (!HelpBotContext.verifyInstall()) {
            notifyFailure(callback, HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
            return;
        }
        final WebView webView = getActiveWebViewOrNotify(callback);
        if (webView == null) {
            return;
        }
        // WebSDK sendMessage 返回 Promise，需要 async/await 包装
        final String js = "(async function(){try{"
                + "var r=await HelpBot('sendMessage'," + JSONObject.quote(message) + ");"
                + "return JSON.stringify({ok:true,data:(r||{})});"
                + "}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();";
        evaluateJsonResultOnUi(webView, js, "sendMessageAsync", callback);
    }

    /**
     * 获取历史消息（异步）。
     * 对齐 WebSDK：HelpBot('getHistoryMessages')
     */
    public static void getHistoryMessagesAsync(@Nullable final HelpBotCallback<Map<String, Object>> callback) {
        if (!HelpBotContext.verifyInstall()) {
            notifyFailure(callback, HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
            return;
        }
        final WebView webView = getActiveWebViewOrNotify(callback);
        if (webView == null) {
            return;
        }
        final String js = "(function(){try{"
                + "var r=HelpBot('getHistoryMessages');"
                + "return JSON.stringify({ok:true,data:(r||{})});"
                + "}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();";
        evaluateJsonResultOnUi(webView, js, "getHistoryMessagesAsync", callback);
    }

    /**
     * 分页加载更多历史消息（异步）。
     * 对齐 WebSDK：HelpBot('loadMoreMessages', limit, offset)
     */
    public static void loadMoreMessagesAsync(final int limit, final int offset,
            @Nullable final HelpBotCallback<Map<String, Object>> callback) {
        if (limit < 0 || offset < 0) {
            notifyFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "limit/offset 不能为负数");
            return;
        }
        if (!HelpBotContext.verifyInstall()) {
            notifyFailure(callback, HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
            return;
        }
        final WebView webView = getActiveWebViewOrNotify(callback);
        if (webView == null) {
            return;
        }
        final String js = "(async function(){try{"
                + "var r=await HelpBot('loadMoreMessages'," + limit + "," + offset + ");"
                + "return JSON.stringify({ok:true,data:(r||{})});"
                + "}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();";
        evaluateJsonResultOnUi(webView, js, "loadMoreMessagesAsync", callback);
    }

    /**
     * 获取当前可用 WebView；若不可用则通过 callback 直接返回错误。
     * 说明：仅用于异步 API（callback 形态），避免重复样板代码。
     */
    @Nullable
    private static <T> WebView getActiveWebViewOrNotify(@Nullable final HelpBotCallback<T> callback) {
        final WebView webView = getActiveWebView();
        if (webView == null) {
            notifyFailure(callback, HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            return null;
        }
        return webView;
    }

    /**
     * 对话窗口是否正在显示（仅表示 UI Activity 是否存在，不代表 WebSDK 是否已连接/认证）。
     */
    public static boolean isConversationVisible() {
        try {
            final HelpBotActivity activity = getCurrentActivity();
            return activity != null && !activity.isFinishing();
        } catch (final Exception ignored) {
            return false;
        }
    }

    /**
     * 显示 FAQ 主页面
     * 说明:直接使用系统浏览器打开 FAQ URL
     * 
     * @param context   上下文对象(必须)
     * @param configMap 配置参数(可选)
     *                  - tn: 可变参数(可选,默认 "68018901_16_pg")
     * @return 操作结果
     */
    @NonNull
    public static HelpBotResult<Void> showFAQs(@NonNull final Context context,
            @NonNull final Map<String, Object> configMap) {

        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
        }

        try {
            final String tn = readStringFromMap(configMap, "tn");
            final String url = buildFaqUrl(tn, null, null);

            final Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.getApplicationContext().startActivity(intent);

            HBlogger.d(TAG, "showFAQs 成功,URL: " + url);
            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQs 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR,
                    "打开 FAQ 失败: " + e.getMessage());
        }
    }

    /**
     * 显示 FAQ 文章分组页面
     * 
     * @param context          上下文对象(必须)
     * @param sectionPublishId 分组 ID(必须)
     * @param configMap        配置参数(可选)
     *                         - tn: 可变参数(可选)
     * @return 操作结果
     */
    @NonNull
    public static HelpBotResult<Void> showFAQSection(@NonNull final Context context,
            @NonNull final String sectionPublishId,
            @NonNull final Map<String, Object> configMap) {

        if (Utils.isEmpty(sectionPublishId)) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER,
                    "sectionPublishId 不能为空");
        }
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
        }

        try {
            final String tn = readStringFromMap(configMap, "tn");
            final String url = buildFaqUrl(tn, "sectionPublishId", sectionPublishId);

            final Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.getApplicationContext().startActivity(intent);

            HBlogger.d(TAG, "showFAQSection 成功,URL: " + url);
            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "showFAQSection 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR,
                    "打开 FAQ 失败: " + e.getMessage());
        }
    }

    /**
     * 显示 FAQ 单页
     * 
     * @param context           上下文对象(必须)
     * @param questionPublishId 问题 ID(必须)
     * @param configMap         配置参数(可选)
     *                          - tn: 可变参数(可选)
     * @return 操作结果
     */
    @NonNull
    public static HelpBotResult<Void> showSingleFAQ(@NonNull final Context context,
            @NonNull final String questionPublishId,
            @NonNull final Map<String, Object> configMap) {

        if (Utils.isEmpty(questionPublishId)) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER,
                    "questionPublishId 不能为空");
        }
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED, "SDK 未初始化");
        }

        try {
            final String tn = readStringFromMap(configMap, "tn");
            final String url = buildFaqUrl(tn, "questionPublishId", questionPublishId);

            final Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.getApplicationContext().startActivity(intent);

            HBlogger.d(TAG, "showSingleFAQ 成功,URL: " + url);
            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "showSingleFAQ 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR,
                    "打开 FAQ 失败: " + e.getMessage());
        }
    }

    /**
     * 未传 configMap 时,使用空 map
     */
    @NonNull
    public static HelpBotResult<Void> showFAQs(@NonNull final Context context) {
        return showFAQs(context, new HashMap<>());
    }

    /**
     * 未传 configMap 时,使用空 map
     */
    @NonNull
    public static HelpBotResult<Void> showFAQSection(@NonNull final Context context,
            @NonNull final String sectionPublishId) {
        return showFAQSection(context, sectionPublishId, new HashMap<>());
    }

    /**
     * 未传 configMap 时,使用空 map
     */
    @NonNull
    public static HelpBotResult<Void> showSingleFAQ(@NonNull final Context context,
            @NonNull final String questionPublishId) {
        return showSingleFAQ(context, questionPublishId, new HashMap<>());
    }

    /**
     * 构建 FAQ URL
     * 
     * @param tn         可变参数(可选,默认 "68018901_16_pg")
     * @param extraKey   额外参数的 key(可选)
     * @param extraValue 额外参数的 value(可选)
     * @return 完整的 FAQ URL
     */
    @NonNull
    private static String buildFaqUrl(@Nullable final String tn,
            @Nullable final String extraKey,
            @Nullable final String extraValue) {
        // 基础 URL
        final String baseUrl = "https://www.baidu.com/";

        final Uri.Builder builder = Uri.parse(baseUrl).buildUpon();

        // 添加 tn 参数
        if (!Utils.isEmpty(tn)) {
            builder.appendQueryParameter("tn", tn);
        } else {
            // 默认值
            builder.appendQueryParameter("tn", "68018901_16_pg");
        }

        // 添加额外参数
        if (!Utils.isEmpty(extraKey) && !Utils.isEmpty(extraValue)) {
            builder.appendQueryParameter(extraKey, extraValue);
        }

        return builder.build().toString();
    }

    /**
     * 从 Map 中读取字符串值
     */
    @Nullable
    private static String readStringFromMap(@Nullable final Map<String, Object> map,
            @NonNull final String key) {
        try {
            if (map == null) {
                return null;
            }
            final Object v = map.get(key);
            if (v == null) {
                return null;
            }
            return String.valueOf(v).trim();
        } catch (final Exception ignored) {
            return null;
        }
    }

    /**
     * 设置事件监听器
     */
    public static void setHelpBotEventsListener(@Nullable final HelpBotEventsListener listener) {
        try {
            // install 未完成时入队；只有 install 完成后才真正执行
            synchronized (operationLock) {
                if (installState != InstallState.INSTALLED || !HelpBotContext.isInstalled()) {
                    pendingEventsListenerRequest = new PendingEventsListenerRequest(listener);
                    HBlogger.d(TAG, "setHelpBotEventsListener 已入队：等待 install 完成后执行");
                    return;
                }
            }
            HBlogger.d(TAG, "setHelpBotEventsListener: " + listener);
            applyEventsListenerNow(listener);
        } catch (final Exception e) {
            HBlogger.e(TAG, "setHelpBotEventsListener 异常", e);
        }
    }

    /**
     * 移除事件监听器
     */
    public static void removeHelpBotEventsListener() {
        // install 未完成时入队，install 完成后执行移除
        setHelpBotEventsListener(null);
    }

    /**
     * 是否启用 SSE 新消息通知
     */
    public static void enableSseNotification(final boolean enable) {
        try {
            sseNotificationEnabledOverride = enable;
            HBlogger.d(TAG, "enableSseNotification: " + enable);
        } catch (final Exception e) {
            HBlogger.e(TAG, "enableSseNotification 异常", e);
        }
    }

    /**
     * 是否已启用 SSE 通知
     */
    public static boolean isSseNotificationEnabled() {
        final Boolean override = sseNotificationEnabledOverride;
        if (override != null) {
            return override;
        }
        return config != null && config.isEnableSseNotification();
    }

    /**
     * 获取 SDK 版本
     */
    @NonNull
    public static String getSDKVersion() {
        return BuildConfig.VERSION_NAME;
    }

    /**
     * 获取 WEB SDK 版本
     * TODO web端未完成接口
     */

    @NonNull
    public static String getWEBSDKVersion(){
        if (!HelpBotContext.verifyInstall()) {
            HBlogger.w(TAG, "SDK 未初始化");
            return "unknown";
        }

        final WebView webView = getActiveWebView();
        if (webView == null) {
            return "unknown";
        }

        final String script = HelpBotJsCommand.buildWebSdkVersion();
        evaluateOnUi(webView, script, "getWebSdkVersion");

        return "v0.1.4";
    }
    /**
     * 获取SDK配置
     * 
     * @return SDK配置对象，如果未初始化则返回 null
     */
    @Nullable
    public static HelpBotConfig getConfig() {
        return config;
    }

    /**
     * 是否处于 Debug 模式
     * 说明:
     * - Debug 模式由 SDK 编译模式自动决定(BuildConfig.DEBUG)
     * - 宿主应用无法配置此参数,确保生产环境安全
     * - Debug 模式影响:
     * 1. 日志输出(HBlogger)
     * 2. WebView 远程调试(需同时满足宿主也是 debug 模式)
     * 3. WebSDK 控制台日志输出
     */
    private static boolean isDebugMode() {
        return BuildConfig.DEBUG;
    }

    /**
     * 是否已初始化
     */
    public static boolean isInitialized() {
        return HelpBotContext.verifyInstall();
    }

    /**
     * 获取 WebSDK 健康快照（只读）。
     * 说明：该方法不触发 JS 执行，仅返回 SDK 监控循环最近一次采样结果，适合宿主做诊断/埋点。
     *
     * @return 健康快照数据（Map），若未安装/未启动监控则返回空 Map。
     */
    @NonNull
    public static Map<String, Object> getWebSdkHealthSnapshot() {
        try {
            if (!HelpBotContext.verifyInstall()) {
                return new java.util.HashMap<>();
            }
            return HelpBotWebViewSession.getInstance().getHealthSnapshot();
        } catch (final Exception e) {
            HBlogger.e(TAG, "getWebSdkHealthSnapshot 异常", e);
            return new java.util.HashMap<>();
        }
    }

    /**
     * 更新 SDK Meta 数据
     */
    @NonNull
    public static HelpBotResult<Void> updateSDKMeta(@NonNull final Map<String, Object> meta) {
        if (meta.isEmpty()) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER, "meta 不能为空");
        }

        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            final WebView webView = getActiveWebView();
            if (webView == null) {
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            }

            final JSONObject jsonMeta = new JSONObject(meta);
            final String script = HelpBotJsCommand.buildUpdateUserSdkMeta(jsonMeta);
            evaluateOnUi(webView, script, "updateSDKMeta");

            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateSDKMeta 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "更新失败: " + e.getMessage());
        }
    }

    /**
     * 更新用户自定义 Meta 数据
     */
    @NonNull
    public static HelpBotResult<Void> updateCustomMeta(@NonNull final Map<String, Object> customMeta) {
        if (customMeta.isEmpty()) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER, "customMeta 不能为空");
        }

        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            final WebView webView = getActiveWebView();
            if (webView == null) {
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            }

            final JSONObject jsonMeta = new JSONObject(customMeta);
            final String script = HelpBotJsCommand.buildUpdateUserMeta(jsonMeta);
            evaluateOnUi(webView, script, "updateCustomMeta");

            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "updateCustomMeta 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "更新失败: " + e.getMessage());
        }
    }

    /**
     * 添加 Issue 标签
     */
    @NonNull
    public static HelpBotResult<Void> addIssueTags(@NonNull final ArrayList<String> tags) {
        if (tags.isEmpty()) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER, "tags 不能为空");
        }

        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            final WebView webView = getActiveWebView();
            if (webView == null) {
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            }

            final JSONArray jsonArray = new JSONArray(tags);
            final String script = HelpBotJsCommand.buildAddIssueTags(jsonArray);
            evaluateOnUi(webView, script, "addIssueTags");

            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "addIssueTags 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "添加标签失败: " + e.getMessage());
        }
    }

    /**
     * 移除 Issue 标签
     */
    @NonNull
    public static HelpBotResult<Void> removeIssueTags(@NonNull final ArrayList<String> tags) {
        if (tags.isEmpty()) {
            return HelpBotResult.failure(HelpBotErrorCode.INVALID_PARAMETER, "tags 不能为空");
        }

        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            final WebView webView = getActiveWebView();
            if (webView == null) {
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            }

            final JSONArray jsonArray = new JSONArray(tags);
            final String script = HelpBotJsCommand.buildRemoveIssueTags(jsonArray);
            evaluateOnUi(webView, script, "removeIssueTags");

            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "removeIssueTags 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "移除标签失败: " + e.getMessage());
        }
    }

    /**
     * 上报系统信息到服务器
     */
    @NonNull
    public static HelpBotResult<Void> reportSystemInfoToServer() {
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null || hbContext.getDevice() == null) {
                return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "设备信息不可用");
            }

            final WebView webView = getActiveWebView();
            if (webView == null) {
                return HelpBotResult.failure(HelpBotErrorCode.WEBVIEW_DESTROYED, "WebView 未初始化");
            }

            final JSONObject meta = new JSONObject();
            // 隐私模式：减少可识别信息与敏感信息的采集/上报（SDK 最小化原则）
            final boolean privacyMode = (config != null) && config.isFullPrivacyMode();
            meta.put("os_type", hbContext.getDevice().getOsType());
            meta.put("os_version", hbContext.getDevice().getOSVersion());
            meta.put("device_model", hbContext.getDevice().getDeviceModel());
            meta.put("app_name", hbContext.getDevice().getAppName());
            meta.put("app_version", hbContext.getDevice().getAppVersion());
            meta.put("sdk_version", hbContext.getDevice().getSDKVersion());

            if (!privacyMode) {
                meta.put("battery_level", hbContext.getDevice().getBatteryLevel());
                meta.put("battery_status", hbContext.getDevice().getBatteryStatus());
                meta.put("network_type", hbContext.getDevice().getNetworkType());
                meta.put("carrier_name", hbContext.getDevice().getCarrierName());
                meta.put("country_code", hbContext.getDevice().getCountryCode());
                meta.put("language", hbContext.getDevice().getLanguage());
                meta.put("app_identifier", hbContext.getDevice().getAppIdentifier());
                meta.put("device_id", hbContext.getDevice().getDeviceId());
                meta.put("is_online", hbContext.getDevice().isOnline());
            } else {
                meta.put("full_privacy_mode", true);
            }

            evaluateOnUi(webView, HelpBotJsCommand.buildUpdateUserSdkMeta(meta), "reportSystemInfo");

            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "reportSystemInfoToServer 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "上报失败: " + e.getMessage());
        }
    }

    /**
     * 设置通知小图标资源 ID
     */
    public static void setNotificationSmallIconResId(@DrawableRes final int resId) {
        try {
            if (!HelpBotContext.verifyInstall()) {
                return;
            }
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null) {
                hbContext.getPersistentStorage().setNotificationIcon(resId);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "setNotificationSmallIconResId 异常", e);
        }
    }

    /**
     * 设置通知渠道 ID
     */
    public static void setNotificationChannelId(@NonNull final String channelId) {
        try {
            if (!HelpBotContext.verifyInstall()) {
                return;
            }
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null) {
                hbContext.getPersistentStorage().setNotificationChannelId(channelId);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "setNotificationChannelId 异常", e);
        }
    }

    /**
     * 关闭当前会话
     */
    @NonNull
    public static HelpBotResult<Void> closeSession() {
        if (!HelpBotContext.verifyInstall()) {
            return HelpBotResult.failure(HelpBotErrorCode.SDK_NOT_INITIALIZED);
        }

        try {
            // 调用 WebView close
            final WebView webView = getActiveWebView();
            if (webView != null) {
                evaluateOnUi(webView, HelpBotJsCommand.buildClose(), "closeSession");
            }

            // 销毁 WebView 会话
            HelpBotWebViewSession.getInstance().destroySession();

            // 会话销毁会导致 Web 侧登录态丢失：清理登录确认与状态机，避免 showConversation 误判
            try {
                loginConfirmed.set(false);
            } catch (final Exception ignored) {
            }
            synchronized (operationLock) {
                loginState = LoginState.NOT_LOGGED_IN;
                pendingLoginRequest = null;
                pendingShowConversationRequest = null;
            }

            HBlogger.d(TAG, "closeSession 成功");
            return HelpBotResult.success();
        } catch (final Exception e) {
            HBlogger.e(TAG, "closeSession 异常", e);
            return HelpBotResult.failure(HelpBotErrorCode.INTERNAL_ERROR, "关闭会话失败: " + e.getMessage());
        }
    }

    /**
     * 完全销毁 SDK，释放所有资源
     * 
     * 调用此方法后，需要重新调用 install 才能使用 SDK。
     */
    public static void destroy() {
        try {
            HBlogger.d(TAG, "开始销毁 SDK");

            // 1. 关闭会话
            closeSession();

            // 2. 清理 Token
            consumePendingLoginToken();
            pendingLoginToken = null;
            loginConfirmed.set(false);
            synchronized (operationLock) {
                installState = InstallState.NOT_INSTALLED;
                loginState = LoginState.NOT_LOGGED_IN;
                pendingLoginRequest = null;
                pendingShowConversationRequest = null;
                pendingEventsListenerRequest = null;
                pendingEventsListenerRequest = null;
            }
            try {
                installInProgress.set(false);
            } catch (final Exception ignored) {
            }
            try {
                HelpBotContext.setInstallInProgress(false);
            } catch (final Exception ignored) {
            }

            // 3. 清理加密存储
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null && hbContext.context != null) {
                final EncryptedStorage storage = EncryptedStorage.getInstance(hbContext.context);
                if (storage != null) {
                    storage.clear();
                }
            }

            // 4. 立即关闭线程池
            try {
                HelpBotThreadPool.getInstance().shutdownNow();
            } catch (final Exception e) {
                HBlogger.e(TAG, "关闭线程池异常", e);
            }

            // 5. 清理 Context
            HelpBotContext.destroy();

            // 6. 清理配置
            config = null;
            sseNotificationEnabledOverride = null;

            // 7. 清理 Activity 引用
            currentActivityRef = new WeakReference<>(null);

            HBlogger.d(TAG, "SDK 销毁完成");
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroy 异常", e);
        }
    }

    /**
     * 设置当前活动的 HelpBotActivity 实例（由 HelpBotActivity 调用）
     */
    public static void setCurrentActivity(@Nullable final HelpBotActivity activity) {
        currentActivityRef = new WeakReference<>(activity);
    }

    /**
     * 清除当前活动的 HelpBotActivity 实例（由 HelpBotActivity 调用）
     */
    public static void clearCurrentActivity() {
        currentActivityRef = new WeakReference<>(null);
    }

    /**
     * 获取当前活动的 HelpBotActivity 实例
     */
    @Nullable
    private static HelpBotActivity getCurrentActivity() {
        if (currentActivityRef == null) {
            return null;
        }
        return currentActivityRef.get();
    }

    /**
     * 获取活动的 WebView
     */
    @Nullable
    private static WebView getActiveWebView() {
        try {
            return HelpBotWebViewSession.getInstance().getWebView();
        } catch (final Exception ignored) {
            return null;
        }
    }

    /**
     * 获取待补发的 login token
     */
    @Nullable
    public static String getPendingLoginToken() {
        return pendingLoginToken;
    }

    /**
     * 读取并清空待补发的 login token
     */
    @Nullable
    public static synchronized String consumePendingLoginToken() {
        final String token = pendingLoginToken;
        pendingLoginToken = null;
        return token;
    }

    /**
     * 在主线程执行 JavaScript。
     */
    private static void evaluateOnUi(@NonNull final WebView webView, @NonNull final String js,
            @NonNull final String apiName) {
        evaluateOnUiInternal(webView, js, apiName, true);
    }

    /**
     * 在主线程执行 JavaScript（不输出 JS 内容，避免泄露 token/隐私信息）。
     */
    private static void evaluateOnUiNoLog(@NonNull final WebView webView, @NonNull final String js,
            @NonNull final String apiName) {
        evaluateOnUiInternal(webView, js, apiName, false);
    }

    /**
     * 在主线程执行 JavaScript（SDK 内部统一入口）。
     *
     * @param allowLogJsInDebug 是否允许在 Debug 模式输出完整 JS（release 永不输出完整 JS）
     */
    private static void evaluateOnUiInternal(@NonNull final WebView webView,
            @NonNull final String js,
            @NonNull final String apiName,
            final boolean allowLogJsInDebug) {
        try {
            mainHandler.post(() -> {
                try {
                    webView.evaluateJavascript(js, value -> HBlogger.d(TAG, apiName + " 返回: " + value));
                } catch (final Exception e) {
                    HBlogger.e(TAG, apiName + " evaluateJavascript 异常", e);
                }
            });
            logJsInvoke(apiName, js, allowLogJsInDebug);
        } catch (final Exception e) {
            HBlogger.e(TAG, apiName + " 调用异常", e);
        }
    }

    /**
     * 记录 JS 调用日志（安全基线：release 不输出完整 JS）。
     */
    private static void logJsInvoke(@NonNull final String apiName,
            @NonNull final String js,
            final boolean allowLogJsInDebug) {
        try {
            if (allowLogJsInDebug && isDebugMode()) {
                HBlogger.d(TAG, apiName + " 已调用: " + js);
            } else {
                HBlogger.d(TAG, apiName + " 已调用");
            }
        } catch (final Exception ignored) {
        }
    }

    /**
     * 在主线程执行 JS 并解析 JSON 结果，回调到宿主。
     *
     * 约定：JS 返回格式为 {"ok":true,"data":{...}} 或 {"ok":false,"error":"..."}。
     */
    private static void evaluateJsonResultOnUi(
            @NonNull final WebView webView,
            @NonNull final String js,
            @NonNull final String apiName,
            @Nullable final HelpBotCallback<Map<String, Object>> callback) {
        try {
            mainHandler.post(() -> {
                try {
                    webView.evaluateJavascript(js, value -> {
                        try {
                            final String raw = unquoteJsString(value);
                            final Map<String, Object> map = com.example.HelpBot.utils.JsonUtils.jsonStringToMap(raw);
                            final Object okObj = (map == null) ? null : map.get("ok");
                            final boolean ok = (okObj instanceof Boolean) ? (Boolean) okObj : false;
                            if (ok) {
                                final Object dataObj = (map == null) ? null : map.get("data");
                                if (dataObj instanceof Map) {
                                    @SuppressWarnings("unchecked")
                                    final Map<String, Object> dataMap = (Map<String, Object>) dataObj;
                                    notifySuccess(callback, dataMap);
                                } else {
                                    notifySuccess(callback, map);
                                }
                            } else {
                                final Object err = (map == null) ? null : map.get("error");
                                final String msg = (err == null) ? "JS 执行失败" : String.valueOf(err);
                                notifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, apiName + " 失败: " + msg);
                            }
                        } catch (final Exception e) {
                            HBlogger.e(TAG, apiName + " parseResult 异常", e);
                            notifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR,
                                    apiName + " 解析失败: " + e.getMessage());
                        }
                    });
                } catch (final Exception e) {
                    HBlogger.e(TAG, apiName + " evaluateJavascript 异常", e);
                    notifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, apiName + " 执行失败: " + e.getMessage());
                }
            });

            logJsInvoke(apiName, js, true);
        } catch (final Exception e) {
            HBlogger.e(TAG, apiName + " 调用异常", e);
            notifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, apiName + " 调用异常: " + e.getMessage());
        }
    }

    @NonNull
    private static String unquoteJsString(@Nullable final String value) {
        return Utils.unquoteJsString(value);
    }

    /**
     * 通知初始化开始
     */
    private static void notifyInitStart(@Nullable final HelpBotInitCallback callback) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onInitStart();
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onInitStart 回调异常", e);
                }
            });
        }
    }

    /**
     * 通知初始化进度
     */
    private static void notifyInitProgress(@Nullable final HelpBotInitCallback callback,
            final int progress, @NonNull final String message) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onInitProgress(progress, message);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onInitProgress 回调异常", e);
                }
            });
        }
    }

    /**
     * 通知初始化成功
     */
    private static void notifyInitSuccess(@Nullable final HelpBotInitCallback callback) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onInitSuccess();
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onInitSuccess 回调异常", e);
                }
            });
        }
    }

    /**
     * 通知初始化失败
     */
    private static void notifyInitFailure(@Nullable final HelpBotInitCallback callback,
            @NonNull final HelpBotErrorCode errorCode,
            @NonNull final String errorMessage) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onInitFailure(errorCode, errorMessage);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onInitFailure 回调异常", e);
                }
            });
        }
    }

    /**
     * 通知操作成功
     */
    private static <T> void notifySuccess(@Nullable final HelpBotCallback<T> callback, @Nullable final T result) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onSuccess(result);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onSuccess 回调异常", e);
                }
            });
        }
    }

    /**
     * 通知操作失败
     */
    private static <T> void notifyFailure(@Nullable final HelpBotCallback<T> callback,
            @NonNull final HelpBotErrorCode errorCode,
            @NonNull final String errorMessage) {
        if (callback != null) {
            mainHandler.post(() -> {
                try {
                    callback.onFailure(errorCode, errorMessage);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onFailure 回调异常", e);
                }
            });
        }
    }

}
