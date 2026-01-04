package com.example.HelpBot.web;

import android.app.Activity;
import android.content.Context;
import android.content.MutableContextWrapper;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import android.webkit.ValueCallback;
import android.webkit.WebView;

import androidx.annotation.MainThread;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.BuildConfig;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.chat.EventProxy;
import com.example.HelpBot.thread.HelpBotThreadPool;
import com.example.HelpBot.utils.Utils;

import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * HelpBot WebView 会话管理器（SDK 内部单例）。
 * - install 阶段：无 UI 预创建 WebView + 加载 WebSDK loader 并完成 HelpBot('init') 初始化
 * - showConversation 阶段：Activity 接管同一个 WebView，避免透明 Activity 黑屏等兼容性问题
 */
public final class HelpBotWebViewSession {
    private static final String TAG = "HBWebViewSession";
    private static final HelpBotWebViewSession INSTANCE = new HelpBotWebViewSession();

    // 监控轮询间隔常量
    private static final long MONITOR_HIGH_FREQ_DURATION_MS = 30_000L; // 高频监控持续时间：30秒
    private static final long MONITOR_HIGH_FREQ_INTERVAL_MS = 1_000L; // 高频监控间隔：1秒
    private static final long MONITOR_LOW_FREQ_INTERVAL_MS = 5_000L; // 低频监控间隔：5秒
    private static final long BOOTSTRAP_REFRESH_INTERVAL_MS = 10_000L; // Bootstrap刷新间隔：10秒
    private static final long STATUS_BLOCKING_TIMEOUT_MS = 1_200L; // 状态查询超时：1.2秒
    private static final long BOOTSTRAP_BLOCKING_TIMEOUT_MS = 1_200L; // Bootstrap查询超时：1.2秒
    private static final long POLLING_STEP_INTERVAL_MS = 200L; // 轮询步进间隔：200毫秒
    private static final long SESSION_DESTROY_TIMEOUT_MS = 6_000L; // 会话销毁超时：6秒

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicBoolean isPreloading = new AtomicBoolean(false);
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final AtomicBoolean hasInitFailed = new AtomicBoolean(false);

    /**
     * WebSDK 初始化完成信号量：
     * - install 需要等待 WebSDK 确认初始化完成后才算成功
     * - 注意：不能在主线程等待，否则会导致死锁（初始化流程需要主线程执行 WebView 任务）
     */
    private volatile CountDownLatch webSdkInitLatch = new CountDownLatch(1);

    /**
     * WebSDK 初始化失败原因（用于诊断/错误消息）
     */
    @Nullable
    private volatile String webSdkInitFailedReason;

    /**
     * WebSDK 登录完成信号量：
     * - login 必须等待 WebSDK 触发 SDK_READY 事件后才算成功
     * - 采用“单会话单等待”模型：后发的 login 会取消前一个等待
     */
    private final Object loginWaitLock = new Object();
    @Nullable
    private volatile LoginWaiter currentLoginWaiter;

    private volatile int initRetryCount = 0;
    private volatile boolean pendingOpenConversation = false;

    private volatile String pendingLoginToken;

    private volatile Context appContext;
    private volatile boolean fullscreen;
    private volatile MutableContextWrapper contextWrapper;
    private volatile WebView webView;

    // 页面加载兜底重试次数（弱网/偶发 DNS 抖动）
    private volatile int pageLoadRetryCount = 0;
    @Nullable
    private volatile WebViewLoadErrorSnapshot lastLoadErrorSnapshot;

    private volatile WeakReference<Activity> attachedActivityRef = new WeakReference<>(null);
    private volatile WeakReference<ViewGroup> attachedContainerRef = new WeakReference<>(null);

    // ------------------------
    // WebSDK 状态监管（轮询 getStatus + 健康判定）
    // ------------------------
    private final AtomicBoolean isMonitoring = new AtomicBoolean(false);
    @Nullable
    private volatile JSONObject lastStatusSnapshot;
    @Nullable
    private volatile JSONObject lastBootstrapSnapshot;
    @Nullable
    private volatile String lastHealthLevel; // OK / DEGRADED / ERROR / UNKNOWN
    @Nullable
    private volatile String lastStatusJson;
    private volatile long lastStatusUpdatedAtMs = 0L;
    private volatile long lastBootstrapUpdatedAtMs = 0L;
    private volatile long firstAuthenticatedAtMs = 0L;
    private volatile long lastRealtimeConnectedAtMs = 0L;
    private volatile long lastIssueSeenAtMs = 0L;
    @Nullable
    private volatile EventProxy monitorEventProxy;

    private HelpBotWebViewSession() {
    }

    @NonNull
    public static HelpBotWebViewSession getInstance() {
        return INSTANCE;
    }

    /**
     * install 阶段预加载（主线程创建 WebView）。
     */
    public void preload(@NonNull final Context context, final boolean fullscreen) {
        try {
            final Context appCtx = context.getApplicationContext();
            this.appContext = appCtx;
            this.fullscreen = fullscreen;

            if (isInitialized.get()) {
                return;
            }
            if (!isPreloading.compareAndSet(false, true)) {
                return;
            }

            mainHandler.post(() -> {
                try {
                    ensureWebViewCreatedOnMainThread(appCtx);
                    // 预加载：不需要文件选择能力
                    HelpBotWebViewHelper.initWebView(appCtx, webView, fullscreen, null);
                    startPollingWebSdkStatus(0);
                } catch (final Exception e) {
                    hasInitFailed.set(true);
                    isPreloading.set(false);
                    HBlogger.e(TAG, "preload 异常", e);
                    markWebSdkInitFailed("preload_exception");
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "preload: 外层异常", e);
        }
    }

    /**
     * 获取当前会话 WebView（可能尚未初始化完成）。
     */
    @Nullable
    public WebView getWebView() {
        return webView;
    }

    /**
     * showConversation 触发：当 WebView attach 到 Activity 后，尽快 open。
     */
    public void openWhenReady() {
        pendingOpenConversation = true;
        tryOpenConversationIfPossible();
    }

    /**
     * login 阶段兜底：如果 login 早于初始化完成，待初始化完成后自动 setTokenAndConnect。
     */
    public void ensureAutoLoginIfPossible() {
        try {
            // 读取并清空 HelpBot 暂存 token，避免 token 长时间滞留
            final String token = HelpBot.consumePendingLoginToken();
            if (token != null && !token.trim().isEmpty()) {
                pendingLoginToken = token;
            }
            // 如果还没 preload，则触发一次（无 UI）
            final Context ctx = appContext;
            if (ctx != null && webView == null) {
                preload(ctx, true);
            }
            tryAutoLoginIfPossible();
        } catch (final Exception e) {
            HBlogger.e(TAG, "ensureAutoLoginIfPossible 异常", e);
        }
    }

    /**
     * 等待 WebSDK 初始化完成（loaded=true 且 initialized=true）。
     * 
     * 重要：禁止在主线程调用 await，否则会导致死锁。
     *
     * @param timeoutMs 超时（毫秒）
     * @return true=初始化完成；false=超时或失败
     */
    public boolean awaitWebSdkInitialized(final long timeoutMs) {
        try {
            if (isInitialized.get()) {
                return true;
            }
            final CountDownLatch latch = webSdkInitLatch;
            if (latch == null) {
                return false;
            }
            return latch.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS) && isInitialized.get();
        } catch (final Exception e) {
            HBlogger.e(TAG, "awaitWebSdkInitialized 异常", e);
            return false;
        }
    }

    /**
     * 获取 WebSDK 初始化失败原因（可为空，仅用于日志/提示）。
     */
    @Nullable
    public String getWebSdkInitFailedReason() {
        return webSdkInitFailedReason;
    }

    /**
     * 开始一次“等待 WebSDK 登录完成”的等待。
     * - 后发的等待会取消前一个等待，避免回调错配
     */
    @NonNull
    public LoginWaiter beginLoginWait() {
        synchronized (loginWaitLock) {
            // 取消旧等待
            if (currentLoginWaiter != null) {
                currentLoginWaiter.cancel("login_已被替换");
            }
            currentLoginWaiter = new LoginWaiter();
            return currentLoginWaiter;
        }
    }

    /**
     * WebSDK 通过 JSBridge 触发 SDK_READY（代表 setTokenAndConnect 全流程完成）。
     */
    public void notifyWebSdkSdkReady(@Nullable final String eventData) {
        synchronized (loginWaitLock) {
            if (currentLoginWaiter != null) {
                currentLoginWaiter.success(eventData);
                currentLoginWaiter = null;
            }
        }
    }

    /**
     * WebSDK 登录失败（认证失败/错误等），用于解锁等待中的 login。
     */
    public void notifyWebSdkLoginFailed(@NonNull final String reason, @Nullable final String detail) {
        synchronized (loginWaitLock) {
            if (currentLoginWaiter != null) {
                currentLoginWaiter.fail(reason, detail);
                currentLoginWaiter = null;
            }
        }
    }

    /**
     * 阻塞读取 WebSDK 当前状态（通过 HelpBot('getStatus')）。
     * 
     * 注意：该方法会等待主线程执行 evaluateJavascript，禁止在主线程调用。
     * 
     */
    @Nullable
    public JSONObject getWebSdkStatusBlocking(final long timeoutMs)  {
        try {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                HBlogger.w(TAG, "getWebSdkStatusBlocking: 不能在主线程调用阻塞方法");
                return null;
            }
            if (webView == null) {
                return null;
            }

            final CountDownLatch latch = new CountDownLatch(1);
            final String[] resultHolder = new String[] { "" };

            mainHandler.post(() -> {
                try {
                    evaluateGetStatus(statusJson -> {
                        try {
                            resultHolder[0] = (statusJson == null) ? "" : statusJson;
                        } catch (final Exception ignored) {
                            resultHolder[0] = "";
                        } finally {
                            latch.countDown();
                        }
                    });
                } catch (final Exception e) {
                    HBlogger.e(TAG, "getWebSdkStatusBlocking evaluate 异常", e);
                    latch.countDown();
                }
            });

            final boolean ok = latch.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS);
            if (!ok) {
                return null;
            }
            final String s = resultHolder[0];
            if (s == null || s.trim().isEmpty()) {
                return null;
            }
            return new JSONObject(s);
        }  catch (final Exception e) {
            HBlogger.e(TAG, "getWebSdkStatusBlocking 异常", e);
            return null;
        }
    }

    /**
     * 阻塞判断 WebSDK 是否已完成认证（authenticated=true）。
     * - 用于兼容：WebSDK 某些情况下未触发 SDK_READY（例如实时连接卡住），但登录已成功。
     */
    public boolean isWebSdkAuthenticatedBlocking(final long timeoutMs) {
        try {
            final JSONObject status = getWebSdkStatusBlocking(timeoutMs);
            return status != null && status.optBoolean("authenticated", false);
        } catch (final Exception ignored) {
            return false;
        }
    }

    /**
     * Activity 接管展示：把预加载 WebView 挂到容器里，并绑定文件选择能力。
     */
    public void attachToActivity(
            @NonNull final Activity activity,
            @NonNull final ViewGroup container,
            @NonNull final HelpBotWebViewHelper.FileChooserHandler fileChooserHandler) {
        try {
            final Context appCtx = activity.getApplicationContext();
            this.appContext = appCtx;
            this.attachedActivityRef = new WeakReference<>(activity);
            this.attachedContainerRef = new WeakReference<>(container);

            mainHandler.post(() -> {
                try {
                    ensureWebViewCreatedOnMainThread(appCtx);
                    // 兜底：若宿主未在 install 阶段 preload（或进程重启），此处补一次初始化
                    if (!isInitialized.get() && !hasInitFailed.get() && !isPreloading.get()) {
                        isPreloading.set(true);
                        // Activity 场景需要文件选择能力（file input / upload），否则会导致 Web 侧上传能力异常
                        HelpBotWebViewHelper.initWebView(appCtx, webView, this.fullscreen, fileChooserHandler);
                        startPollingWebSdkStatus(0);
                    }
                    // 重绑定 Context，避免持有旧 Activity 造成泄漏（主流做法：MutableContextWrapper）
                    if (contextWrapper != null) {
                        contextWrapper.setBaseContext(activity);
                    }
                    // 从旧父容器移除
                    detachFromParent(webView);
                    container.removeAllViews();
                    container.addView(webView, new ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT));

                    // 绑定文件选择能力（preload 阶段为 null，此处恢复 file input/upload）
                    HelpBotWebViewHelper.bindWebChromeClient(webView, fileChooserHandler);

                    tryOpenConversationIfPossible();
                } catch (final Exception e) {
                    HBlogger.e(TAG, "attachToActivity 异常", e);
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "attachToActivity: 外层异常", e);
        }
    }

    /**
     * Activity 释放展示：解除挂载并把 Context 还原为 applicationContext，避免泄漏。
     */
    public void detachFromActivity() {
        try {
            final Context appCtx = appContext;
            mainHandler.post(() -> {
                try {
                    final ViewGroup container = (attachedContainerRef == null) ? null : attachedContainerRef.get();
                    if (container != null && webView != null) {
                        container.removeView(webView);
                    }
                    if (contextWrapper != null && appCtx != null) {
                        // 解除 Activity 后，返回离屏安全的环境，避免后续内部调用触发配置上下文校验
                        contextWrapper.setBaseContext(HelpBotWebViewContextUtils.buildPreloadContext(appCtx));
                    }
                    attachedActivityRef = new WeakReference<>(null);
                    attachedContainerRef = new WeakReference<>(null);
                } catch (final Exception e) {
                    HBlogger.e(TAG, "detachFromActivity 异常", e);
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "detachFromActivity: 外层异常", e);
        }
    }

    /**
     * SDK 主动销毁会话（释放 WebView 与状态）。建议在宿主明确退出/注销时调用。
     */
    public void destroySession() {
        try {
            final Context appCtx = appContext;
            mainHandler.post(() -> {
                destroySessionOnMainThread(appCtx);
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroySession: 外层异常", e);
        }
    }

    /**
     * 阻塞销毁会话（用于 install 失败后重新开始）。
     * 
     * 设计要点：
     * - installInternal 运行在后台线程，必须等待主线程完成 WebView 销毁与状态复位，否则会出现
     * “旧的 hasInitFailed/latch 状态污染下一次 install” 的问题。
     * - 为了避免死锁：若调用方在主线程，则退化为异步 destroySession() 并立即返回 true。
     *
     * @param timeoutMs 最大等待时间（毫秒）
     * @return true=已完成复位；false=等待超时或异常（下次仍会再次尝试 reset）
     */
    public boolean destroySessionBlocking(final long timeoutMs) {
        try {
            // 主线程不能阻塞等待自己
            if (Looper.myLooper() == Looper.getMainLooper()) {
                destroySession();
                return true;
            }

            final Context appCtx = appContext;
            final CountDownLatch done = new CountDownLatch(1);
            mainHandler.post(() -> {
                try {
                    destroySessionOnMainThread(appCtx);
                } finally {
                    done.countDown();
                }
            });

            return done.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS);
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroySessionBlocking: 外层异常", e);
            return false;
        }
    }

    /**
     * 主线程销毁并复位会话（统一逻辑，避免重复代码与状态不一致）。
     */
    @MainThread
    private void destroySessionOnMainThread(@Nullable final Context appCtx) {
        try {
            stopMonitoring();
            pendingOpenConversation = false;
            pendingLoginToken = null;
            pageLoadRetryCount = 0;
            initRetryCount = 0;

            attachedActivityRef = new WeakReference<>(null);
            attachedContainerRef = new WeakReference<>(null);

            // 尽量把 contextWrapper 还原到 applicationContext，避免泄漏
            try {
                if (contextWrapper != null && appCtx != null) {
                    contextWrapper.setBaseContext(HelpBotWebViewContextUtils.buildPreloadContext(appCtx));
                }
            } catch (final Exception ignored) {
            }

            destroyWebViewOnMainThread();
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroySessionOnMainThread 异常", e);
        } finally {
            resetSessionStateAfterDestroy();
        }
    }

    /**
     * 销毁后复位状态（必须在主线程调用）。
     */
    @MainThread
    private void resetSessionStateAfterDestroy() {
        try {
            isInitialized.set(false);
            isPreloading.set(false);
            hasInitFailed.set(false);
            webSdkInitFailedReason = null;
            webSdkInitLatch = new CountDownLatch(1);
            lastLoadErrorSnapshot = null;
            lastStatusSnapshot = null;
            lastBootstrapSnapshot = null;
            lastHealthLevel = null;
            lastStatusJson = null;
            lastStatusUpdatedAtMs = 0L;
            lastBootstrapUpdatedAtMs = 0L;
            firstAuthenticatedAtMs = 0L;
            lastRealtimeConnectedAtMs = 0L;
            lastIssueSeenAtMs = 0L;
            synchronized (loginWaitLock) {
                if (currentLoginWaiter != null) {
                    currentLoginWaiter.cancel("session_destroyed");
                    currentLoginWaiter = null;
                }
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "resetSessionStateAfterDestroy 异常", e);
        }
    }

    /**
     * 获取 WebSDK/Bridge 基础就绪信息（阻塞）。
     * 
     * 该信息用于 install 判定“全部加载并就绪”：
     * - HelpBot 函数存在
     * - HelpBotBridge 存在（bridge.js 加载成功）
     * - Native Bridge 对象存在且具备 sendEvent（确保 Web→Native 事件通道可用）
     */
    @Nullable
    public JSONObject getWebSdkBootstrapInfoBlocking(final long timeoutMs)  {
        try {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                HBlogger.w(TAG, "getWebSdkBootstrapInfoBlocking: 不能在主线程调用阻塞方法");
                return null;
            }
            if (webView == null) {
                return null;
            }
            final CountDownLatch latch = new CountDownLatch(1);
            final String[] resultHolder = new String[] { "" };
            final String js = "(function(){try{"
                    + "var r={};"
                    + "r.helpBotExists=(typeof window.HelpBot==='function');"
                    + "r.helpBotBridgeExists=!!window.HelpBotBridge;"
                    + "r.nativeAndroidExists=!!window.HelpBotNativeAndroid;"
                    + "r.nativeSendEventExists=!!(window.HelpBotNativeAndroid&&typeof window.HelpBotNativeAndroid.sendEvent==='function');"
                    + "return JSON.stringify(r);"
                    + "}catch(e){return '';}})();";
            mainHandler.post(() -> {
                try {
                    webView.evaluateJavascript(js, value -> {
                        try {
                            resultHolder[0] = unquoteJsString(value);
                        } catch (final Exception ignored) {
                            resultHolder[0] = "";
                        } finally {
                            latch.countDown();
                        }
                    });
                } catch (final Exception e) {
                    HBlogger.e(TAG, "getWebSdkBootstrapInfoBlocking evaluate 异常", e);
                    latch.countDown();
                }
            });
            final boolean ok = latch.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS);
            if (!ok) {
                return null;
            }
            final String s = resultHolder[0];
            if (s == null || s.trim().isEmpty()) {
                return null;
            }
            return new JSONObject(s);
        }  catch (final Exception e) {
            HBlogger.e(TAG, "getWebSdkBootstrapInfoBlocking 异常", e);
            return null;
        }
    }

    /**
     * install 用：等待 bootstrap “全就绪”。
     */
    public boolean awaitWebSdkBootstrapReady(final long timeoutMs) {
        try {
            final long deadline = System.currentTimeMillis() + Math.max(timeoutMs, 0L);
            while (System.currentTimeMillis() < deadline) {
                final JSONObject info = getWebSdkBootstrapInfoBlocking(BOOTSTRAP_BLOCKING_TIMEOUT_MS);
                if (info != null) {
                    lastBootstrapSnapshot = info;
                    final boolean ok = info.optBoolean("helpBotExists", false)
                            && info.optBoolean("helpBotBridgeExists", false)
                            && info.optBoolean("nativeAndroidExists", false)
                            && info.optBoolean("nativeSendEventExists", false);
                    if (ok) {
                        return true;
                    }
                }
                try {
                    Thread.sleep(POLLING_STEP_INTERVAL_MS);
                } catch (final Exception ignored) {
                }
            }
            return false;
        } catch (final Exception e) {
            HBlogger.e(TAG, "awaitWebSdkBootstrapReady 异常", e);
            return false;
        }
    }

    /**
     * 开始 WebSDK 状态监管：
     * - 周期性拉取 getStatus
     * - 计算健康度并在变化时通过 EventProxy 派发给宿主
     */
    public void startMonitoring(@Nullable final EventProxy eventProxy) {
        try {
            if (!isMonitoring.compareAndSet(false, true)) {
                return;
            }
            this.monitorEventProxy = eventProxy;
            HelpBotThreadPool.getInstance().submit(this::monitorLoop);
        } catch (final Exception e) {
            HBlogger.e(TAG, "startMonitoring 异常", e);
            isMonitoring.set(false);
        }
    }

    public void stopMonitoring() {
        isMonitoring.set(false);
        monitorEventProxy = null;
    }

    private void monitorLoop() {
        try {
            // 轮询策略：前 30 秒高频，之后降低频率（兼顾实时性与功耗）
            final long start = System.currentTimeMillis();
            while (isMonitoring.get()) {
                final long elapsed = System.currentTimeMillis() - start;
                final long interval = (elapsed < MONITOR_HIGH_FREQ_DURATION_MS) ? MONITOR_HIGH_FREQ_INTERVAL_MS
                        : MONITOR_LOW_FREQ_INTERVAL_MS;

                // 1) 低频刷新 bootstrap（桥接通道是否就绪）
                try {
                    if (lastBootstrapUpdatedAtMs == 0L
                            || (System.currentTimeMillis()
                                    - lastBootstrapUpdatedAtMs) > BOOTSTRAP_REFRESH_INTERVAL_MS) {
                        final JSONObject bootstrap = getWebSdkBootstrapInfoBlocking(BOOTSTRAP_BLOCKING_TIMEOUT_MS);
                        if (bootstrap != null) {
                            lastBootstrapSnapshot = bootstrap;
                            lastBootstrapUpdatedAtMs = System.currentTimeMillis();
                        }
                    }
                } catch (final Exception e) {
                    HBlogger.d(TAG, "刷新 Bootstrap 快照异常", e);
                }

                try {
                    final JSONObject status = getWebSdkStatusBlocking(STATUS_BLOCKING_TIMEOUT_MS);
                    if (status != null) {
                        emitIfChanged("WEBSDK_STATUS", status);
                        lastStatusSnapshot = status;
                        lastStatusUpdatedAtMs = System.currentTimeMillis();

                        // 记录关键时间点（用于健康判定）
                        final boolean authenticated = status.optBoolean("authenticated", false);
                        final boolean hasIssue = status.optBoolean("hasIssue", false);
                        final boolean realtimeConnected = status.optBoolean("realtimeConnected", false);
                        if (authenticated && firstAuthenticatedAtMs == 0L) {
                            firstAuthenticatedAtMs = lastStatusUpdatedAtMs;
                        }
                        if (hasIssue) {
                            lastIssueSeenAtMs = lastStatusUpdatedAtMs;
                        }
                        if (realtimeConnected) {
                            lastRealtimeConnectedAtMs = lastStatusUpdatedAtMs;
                        }

                        final String health = computeHealthLevel(status);
                        if (health != null && (lastHealthLevel == null || !health.equalsIgnoreCase(lastHealthLevel))) {
                            lastHealthLevel = health;
                            final Map<String, Object> data = new HashMap<>();
                            data.put("level", health);
                            data.put("authenticated", status.optBoolean("authenticated", false));
                            data.put("hasIssue", status.optBoolean("hasIssue", false));
                            data.put("issueId", status.optString("issueId", ""));
                            data.put("realtimeConnected", status.optBoolean("realtimeConnected", false));
                            sendEventSafe("WEBSDK_HEALTH_CHANGED", data);
                        }
                    } else {
                        // status 为空：可能是页面还没 ready 或 JS 执行异常
                        if (lastHealthLevel == null || !"UNKNOWN".equalsIgnoreCase(lastHealthLevel)) {
                            lastHealthLevel = "UNKNOWN";
                            final Map<String, Object> data = new HashMap<>();
                            data.put("level", "UNKNOWN");
                            sendEventSafe("WEBSDK_HEALTH_CHANGED", data);
                        }
                    }
                } catch (final Exception e) {
                    // 其他异常继续监控
                    HBlogger.d(TAG, "获取 WebSDK 状态异常", e);
                }

                try {
                    Thread.sleep(interval);
                } catch (final InterruptedException e) {
                    HBlogger.d(TAG, "监控轮询休眠被中断，退出监控循环");
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "monitorLoop 异常", e);
        } finally {
            isMonitoring.set(false);
        }
    }

    private void emitIfChanged(@NonNull final String eventName, @NonNull final JSONObject status) {
        try {
            // 简化：以 JSON 字符串对比，避免深度比较开销
            final String cur = status.toString();
            final String prev = lastStatusJson;
            if (prev != null && cur.equals(prev)) {
                return;
            }
            lastStatusJson = cur;
            final Map<String, Object> data = new HashMap<>();
            data.put("json", cur);
            sendEventSafe(eventName, data);
        } catch (final Exception ignored) {
        }
    }

    @Nullable
    private static String computeHealthLevel(@NonNull final JSONObject status) {
        try {
            final boolean authenticated = status.optBoolean("authenticated", false);
            final boolean hasIssue = status.optBoolean("hasIssue", false);
            final boolean realtimeConnected = status.optBoolean("realtimeConnected", false);

            if (!authenticated) {
                return "OK"; // 未登录不算异常，属于正常状态
            }
            if (hasIssue && !realtimeConnected) {
                return "DEGRADED";
            }
            return "OK";
        } catch (final Exception ignored) {
            return "UNKNOWN";
        }
    }

    /**
     * 获取 WebSDK 健康快照（用于宿主查询/埋点/诊断）。
     * 注意：此方法不触发 JS 执行，仅返回最近一次监控采样结果。
     */
    @NonNull
    public Map<String, Object> getHealthSnapshot() {
        final Map<String, Object> data = new HashMap<>();
        try {
            data.put("websdkInitialized", isInitialized.get());
            data.put("websdkInitFailed", hasInitFailed.get());
            data.put("websdkInitFailedReason", webSdkInitFailedReason);
            data.put("lastHealthLevel", lastHealthLevel == null ? "UNKNOWN" : lastHealthLevel);
            data.put("lastStatusUpdatedAtMs", lastStatusUpdatedAtMs);
            data.put("lastBootstrapUpdatedAtMs", lastBootstrapUpdatedAtMs);
            data.put("firstAuthenticatedAtMs", firstAuthenticatedAtMs);
            data.put("lastRealtimeConnectedAtMs", lastRealtimeConnectedAtMs);
            data.put("lastIssueSeenAtMs", lastIssueSeenAtMs);

            final WebViewLoadErrorSnapshot err = lastLoadErrorSnapshot;
            if (err != null) {
                data.put("lastWebViewErrorType", err.type);
                data.put("lastWebViewErrorMainFrame", err.mainFrame);
                if (err.errorCode != null) {
                    data.put("lastWebViewErrorCode", err.errorCode);
                }
                if (err.httpStatus != null) {
                    data.put("lastWebViewHttpStatus", err.httpStatus);
                }
                data.put("lastWebViewErrorAtMs", err.atMs);
            }

            final JSONObject bootstrap = lastBootstrapSnapshot;
            if (bootstrap != null) {
                data.put("bootstrap", bootstrap.toString());
            }
            final JSONObject status = lastStatusSnapshot;
            if (status != null) {
                data.put("status", status.toString());
                data.put("authenticated", status.optBoolean("authenticated", false));
                data.put("hasIssue", status.optBoolean("hasIssue", false));
                data.put("issueId", status.optString("issueId", ""));
                data.put("realtimeConnected", status.optBoolean("realtimeConnected", false));
            }
        } catch (final Exception ignored) {
        }
        return data;
    }

    /**
     * 读取“最近一次监控采样”的 authenticated 快照（不阻塞主线程，不触发 JS 执行）。
     * 用途：showConversation 等门禁逻辑的快速判断辅助（SDK 内仍以 loginConfirmed 为主）。
     */
    public boolean isAuthenticatedSnapshot(final long maxAgeMs) {
        try {
            final long age = System.currentTimeMillis() - lastStatusUpdatedAtMs;
            if (lastStatusUpdatedAtMs <= 0L || age > Math.max(maxAgeMs, 0L)) {
                return false;
            }
            final JSONObject status = lastStatusSnapshot;
            return status != null && status.optBoolean("authenticated", false);
        } catch (final Exception ignored) {
            return false;
        }
    }

    private void sendEventSafe(@NonNull final String eventName, @Nullable final Map<String, Object> data) {
        try {
            final EventProxy proxy = monitorEventProxy;
            if (proxy == null) {
                return;
            }
            proxy.sendEvent(eventName, data);
        } catch (final Exception ignored) {
        }
    }

    // ------------------------
    // internal
    // ------------------------

    @MainThread
    private void ensureWebViewCreatedOnMainThread(@NonNull final Context appCtx) {
        if (webView != null) {
            return;
        }
        try {
            // 优先使用已 attach 的 ActivityUI环境，否则用配置环境做离屏预加载
            final Activity activity = (attachedActivityRef == null) ? null : attachedActivityRef.get();
            final Context baseCtx = (activity != null) ? activity : HelpBotWebViewContextUtils.buildPreloadContext(appCtx);

            contextWrapper = new MutableContextWrapper(baseCtx);
            webView = new WebView(contextWrapper);
            // 预加载 WebView 不需要 attach 到 Window，也能执行 JS/网络加载
            HBlogger.d(TAG, "WebView 已创建用于预加载，baseCtx=" + baseCtx.getClass().getSimpleName());
        } catch (final Exception e) {
            HBlogger.e(TAG, "ensureWebViewCreatedOnMainThread 异常", e);
            throw e;
        }
    }

    private void startPollingWebSdkStatus(final int attempt) {
        if (webView == null) {
            isPreloading.set(false);
            return;
        }
        if (isInitialized.get()) {
            isPreloading.set(false);
            tryAutoLoginIfPossible();
            tryOpenConversationIfPossible();
            return;
        }
        if (hasInitFailed.get()) {
            isPreloading.set(false);
            return;
        }

        final int maxAttempts = 60; // ~60 * 250ms = 15s
        final long delayMs = 250L;

        if (attempt >= maxAttempts) {
            // 兜底：失败时做一次 reload 重试（最多 1 次），避免偶发网络/脚本加载抖动
            if (initRetryCount < 1) {
                initRetryCount++;
                HBlogger.w(TAG, "WebSDK 初始化超时，尝试重载。重试次数=" + initRetryCount);
                try {
                    webView.reload();
                } catch (final Exception e) {
                    HBlogger.e(TAG, "reload 异常", e);
                }
                mainHandler.postDelayed(() -> startPollingWebSdkStatus(0), 800L);
                return;
            }
            hasInitFailed.set(true);
            isPreloading.set(false);
            HBlogger.e(TAG, "WebSDK 初始化超时（已重试）");
            markWebSdkInitFailed("init_timeout");
            return;
        }

        evaluateGetStatus(statusJson -> {
            try {
                if (statusJson == null || statusJson.trim().isEmpty()) {
                    mainHandler.postDelayed(() -> startPollingWebSdkStatus(attempt + 1), delayMs);
                    return;
                }
                final JSONObject obj = new JSONObject(statusJson);
                final boolean loaded = obj.optBoolean("loaded", false);
                final boolean initialized = obj.optBoolean("initialized", false);
                if (loaded && initialized) {
                    markWebSdkInitialized();
                    isPreloading.set(false);
                    HBlogger.d(TAG, "WebSDK 初始化成功 (loaded=true, initialized=true)");
                    tryAutoLoginIfPossible();
                    tryOpenConversationIfPossible();
                } else {
                    mainHandler.postDelayed(() -> startPollingWebSdkStatus(attempt + 1), delayMs);
                }
            } catch (final Exception e) {
                HBlogger.e(TAG, "parse getStatus 异常: " + statusJson, e);
                mainHandler.postDelayed(() -> startPollingWebSdkStatus(attempt + 1), delayMs);
            }
        });
    }

    private void evaluateGetStatus(@NonNull final ValueCallback<String> callback) {
        try {
            if (webView == null) {
                callback.onReceiveValue("");
                return;
            }
            final String js = "(function(){try{var s=HelpBot('getStatus');return JSON.stringify(s);}catch(e){return '';}})();";
            webView.evaluateJavascript(js, value -> {
                try {
                    callback.onReceiveValue(unquoteJsString(value));
                } catch (final Exception e) {
                    callback.onReceiveValue("");
                }
            });
        } catch (final Exception e) {
            callback.onReceiveValue("");
        }
    }

    private void tryAutoLoginIfPossible() {
        try {
            if (!isInitialized.get()) {
                return;
            }
            final String token = pendingLoginToken;
            if (token == null || token.trim().isEmpty()) {
                return;
            }
            if (webView == null) {
                return;
            }
            final String js = HelpBotJsCommand.buildSetTokenAndConnect(token);
            webView.post(() -> {
                try {
                    webView.evaluateJavascript(js, v -> HBlogger.d(TAG, "autoLogin 返回: " + v));
                } catch (final Exception e) {
                    HBlogger.e(TAG, "autoLogin evaluateJavascript 异常", e);
                }
            });
            pendingLoginToken = null;
        } catch (final Exception e) {
            HBlogger.e(TAG, "tryAutoLoginIfPossible 异常", e);
        }
    }

    private void tryOpenConversationIfPossible() {
        try {
            if (!pendingOpenConversation) {
                return;
            }
            if (!isInitialized.get()) {
                return;
            }
            final Activity act = (attachedActivityRef == null) ? null : attachedActivityRef.get();
            if (act == null) {
                // 还没 attach 到 Activity，不在离屏阶段 open
                return;
            }
            if (webView == null) {
                return;
            }
            pendingOpenConversation = false;
            final String js = HelpBotJsCommand.buildOpen();
            webView.post(() -> {
                try {
                    webView.evaluateJavascript(js, v -> HBlogger.d(TAG, "open 返回: " + v));
                } catch (final Exception e) {
                    HBlogger.e(TAG, "open evaluateJavascript 异常", e);
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "tryOpenConversationIfPossible 异常", e);
        }
    }

    /**
     * WebView 页面/网络错误兜底（弱网/偶发抖动）：有限次数重试 reload，并派发事件给宿主。
     */
    public void onWebViewLoadError(@NonNull final String errorType, @Nullable final String url) {
        onWebViewLoadError(errorType, url, null, null, false, null);
    }

    /**
     * WebView 页面/网络错误（带详细信息）。
     *
     * @param errorType   错误类型（来源回调）
     * @param url         发生错误的 URL（可空）
     * @param errorCode   WebView errorCode（可空）
     * @param description 错误描述（可空）
     * @param isMainFrame 是否主框架
     * @param httpStatus  HTTP 状态码（可空）
     */
    public void onWebViewLoadError(
            @NonNull final String errorType,
            @Nullable final String url,
            @Nullable final Integer errorCode,
            @Nullable final String description,
            final boolean isMainFrame,
            @Nullable final Integer httpStatus) {
        try {
            // 记录最近一次错误快照（用于 install 超时诊断/提示）
            try {
                lastLoadErrorSnapshot = new WebViewLoadErrorSnapshot(
                        errorType,
                        url,
                        errorCode,
                        description,
                        isMainFrame,
                        httpStatus,
                        System.currentTimeMillis());
            } catch (final Exception ignored) {
            }

            notifyWebViewError(errorType, url);

            // install 阶段加速失败判定：
            // - 主框架（index.html）若返回确定性错误（401/403/404/410），继续重试通常无意义
            // - 直接标记 WebSDK init failed，释放 await，避免宿主“卡 30s+”误判为超时
            try {
                if (isMainFrame && !isInitialized.get() && httpStatus != null) {
                    final int s = httpStatus.intValue();
                    if (s == 401 || s == 403 || s == 404 || s == 410) {
                        HBlogger.e(TAG, "主框架 HTTP 错误，判定 WebSDK 初始化失败: status=" + s
                                + ", url=" + (url == null ? "" : url));
                        markWebSdkInitFailed("http_error_" + s);
                        // 失败后不再触发 reload 重试，避免无意义循环
                        return;
                    }
                }
            } catch (final Exception ignored) {
            }

            // 兜底：最多重试 2 次，避免死循环
            if (pageLoadRetryCount >= 2) {
                return;
            }
            pageLoadRetryCount++;
            final WebView wv = webView;
            if (wv == null) {
                return;
            }
            final long delay = (pageLoadRetryCount == 1) ? 1000L : 3000L;
            mainHandler.postDelayed(() -> {
                try {
                    if (webView != null) {
                        webView.reload();
                    }
                } catch (final Exception e) {
                    HBlogger.e(TAG, "onWebViewLoadError reload 异常", e);
                }
            }, delay);
        } catch (final Exception e) {
            HBlogger.e(TAG, "onWebViewLoadError 异常", e);
        }
    }

    /**
     * 获取最近一次 WebView 加载错误快照（用于错误提示/诊断）。
     */
    @Nullable
    public WebViewLoadErrorSnapshot getLastLoadErrorSnapshot() {
        return lastLoadErrorSnapshot;
    }

    /**
     * WebView 加载错误快照（只做诊断/提示用，避免在日志中输出敏感信息）。
     */
    public static final class WebViewLoadErrorSnapshot {
        @NonNull
        public final String type;
        @Nullable
        public final String url;
        @Nullable
        public final Integer errorCode;
        @Nullable
        public final String description;
        public final boolean mainFrame;
        @Nullable
        public final Integer httpStatus;
        public final long atMs;

        private WebViewLoadErrorSnapshot(
                @NonNull final String type,
                @Nullable final String url,
                @Nullable final Integer errorCode,
                @Nullable final String description,
                final boolean mainFrame,
                @Nullable final Integer httpStatus,
                final long atMs) {
            this.type = type;
            this.url = url;
            this.errorCode = errorCode;
            this.description = description;
            this.mainFrame = mainFrame;
            this.httpStatus = httpStatus;
            this.atMs = atMs;
        }
    }

    private static void detachFromParent(@Nullable final WebView webView) {
        try {
            if (webView == null) {
                return;
            }
            final android.view.ViewParent parent = webView.getParent();
            if (parent instanceof ViewGroup) {
                ((ViewGroup) parent).removeView(webView);
            }
        } catch (final Exception ignored) {
        }
    }

    @NonNull
    private static String unquoteJsString(@Nullable final String value) {
        return Utils.unquoteJsString(value);
    }

    private void destroyWebViewOnMainThread() {
        try {
            if (webView == null) {
                contextWrapper = null;
                return;
            }
            // 完整的WebView销毁流程，确保资源正确释放
            // 1. 从任何父容器移除
            detachFromParent(webView);

            // 2. 停止加载
            try {
                webView.stopLoading();
            } catch (final Exception e) {
                HBlogger.w(TAG, "stopLoading 异常", e);
            }

            // 3. 清除历史记录（Android 7.0+）
            try {
                webView.clearHistory();
            } catch (final Exception e) {
                HBlogger.w(TAG, "clearHistory 异常", e);
            }

            // 4. 加载空白页
            try {
                webView.loadUrl("about:blank");
            } catch (final Exception e) {
                HBlogger.w(TAG, "loadUrl about:blank 异常", e);
            }

            // 5. 移除所有子视图
            try {
                webView.removeAllViews();
            } catch (final Exception e) {
                HBlogger.w(TAG, "removeAllViews 异常", e);
            }

            // 6. 清除缓存（可选，但可以释放内存）
            try {
                webView.clearCache(true);
            } catch (final Exception e) {
                HBlogger.w(TAG, "clearCache 异常", e);
            }

            // 7. 销毁WebView（必须在主线程）
            try {
                webView.destroy();
            } catch (final Exception e) {
                HBlogger.w(TAG, "destroy 异常", e);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "destroyWebViewOnMainThread 异常", e);
        } finally {
            // 确保引用被清除
            webView = null;
            contextWrapper = null;
            HBlogger.d(TAG, "WebView 已销毁，引用已清除");
        }
    }

    private void notifyWebSdkInitFailed(@NonNull final String reason) {
        try {
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null || hbContext.getEventProxy() == null) {
                return;
            }
            final Map<String, Object> data = new HashMap<>();
            data.put("reason", reason);
            data.put("retryCount", initRetryCount);
            hbContext.getEventProxy().sendEvent("WEBSDK_INIT_FAILED", data);
        } catch (final Exception ignored) {
        }
    }

    /**
     * 标记 WebSDK 初始化完成，并释放等待。
     */
    private void markWebSdkInitialized() {
        try {
            if (isInitialized.compareAndSet(false, true)) {
                webSdkInitFailedReason = null;
                final CountDownLatch latch = webSdkInitLatch;
                if (latch != null) {
                    latch.countDown();
                }
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "markWebSdkInitialized 异常", e);
        }
    }

    /**
     * 标记 WebSDK 初始化失败，并释放等待。
     */
    private void markWebSdkInitFailed(@NonNull final String reason) {
        try {
            webSdkInitFailedReason = reason;
            hasInitFailed.set(true);
            notifyWebSdkInitFailed(reason);
            final CountDownLatch latch = webSdkInitLatch;
            if (latch != null) {
                latch.countDown();
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "markWebSdkInitFailed 异常", e);
        }
    }

    /**
     * 登录等待（内部使用）。
     */
    public static final class LoginWaiter {
        private final CountDownLatch latch = new CountDownLatch(1);
        private volatile boolean finished;
        private volatile boolean success;
        @Nullable
        private volatile String successData;
        @Nullable
        private volatile String failReason;
        @Nullable
        private volatile String failDetail;

        private LoginWaiter() {
            super();
        }

        private void success(@Nullable final String data) {
            this.success = true;
            this.successData = data;
            this.finished = true;
            latch.countDown();
        }

        private void fail(@NonNull final String reason, @Nullable final String detail) {
            this.success = false;
            this.failReason = reason;
            this.failDetail = detail;
            this.finished = true;
            latch.countDown();
        }

        private void cancel(@NonNull final String reason) {
            fail(reason, null);
        }

        public boolean await(final long timeoutMs) {
            try {
                return latch.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS) && success;
            } catch (final Exception ignored) {
                return false;
            }
        }

        public boolean awaitStep(final long timeoutMs) {
            try {
                latch.await(Math.max(timeoutMs, 0L), TimeUnit.MILLISECONDS);
                return finished && success;
            } catch (final Exception ignored) {
                return false;
            }
        }

        public boolean isFinished() {
            return finished;
        }

        public boolean isSuccess() {
            return finished && success;
        }

        @Nullable
        public String getFailReason() {
            return failReason;
        }

        @Nullable
        public String getFailDetail() {
            return failDetail;
        }

        @Nullable
        public String getSuccessData() {
            return successData;
        }
    }

    private void notifyWebViewError(@NonNull final String errorType, @Nullable final String url) {
        try {
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null || hbContext.getEventProxy() == null) {
                return;
            }
            final Map<String, Object> data = new HashMap<>();
            data.put("type", errorType);
            if (url != null) {
                data.put("url", url);
            }
            data.put("retryCount", pageLoadRetryCount);
            hbContext.getEventProxy().sendEvent("WEBVIEW_LOAD_ERROR", data);
        } catch (final Exception ignored) {
        }
    }
}
