package com.example.sdk_webview_test;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.pm.PackageInfo;
import android.content.pm.ApplicationInfo;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.os.StrictMode;
import android.security.NetworkSecurityPolicy;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.EdgeToEdge;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.core.HelpBotAuthenticationFailureReason;
import com.example.HelpBot.core.HelpBotCallback;
import com.example.HelpBot.core.HelpBotConfig;
import com.example.HelpBot.core.HelpBotErrorCode;
import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.core.HelpBotInitCallback;
import com.example.HelpBot.core.HelpBotResult;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.log.HelpBotLogger;
import com.example.HelpBot.utils.NetworkUtils;
import com.example.HelpBot.web.HelpBotWebViewSession;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * MainActivity - HelpBot SDK 测试台
 *
 * 
 * 兼容性：系统版本 / WebView 版本 / 前后台切换 / 多窗口 / 权限缺失
 * 安全性：WebView 安全基线扫描（文件访问/混合内容/安全浏览/调试开关等）+ Token 脱敏
 * 稳定性：压力回归（open/hide 循环）+ 异常注入（负向用例）+ 资源清理（Handler/监听器）
 * 网络波动：监听网络变化、弱网/断网提示、网络恢复后可选自动重试 install
 * 
 *
 * 
 * 注意：
 * - Demo 允许读取 SDK 内部 WebView settings 做“诊断”，但不在 Demo 里修改 SDK 内部实现。
 * - 全部关键路径 try-catch 包裹，确保测试台本身不崩溃，避免干扰问题定位。
 */
public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    // ===== UI =====
    private EditText editIdentify;
    private EditText editValue;
    private EditText editDomain;
    private EditText editChannel;
    private EditText editTokenUrl;

    private Button btnSelfCheck;
    private Button btnSecurityAudit;
    private Button btnNegativeTests;
    private Button btnInstallAsync;
    private Button btnGenToken;
    private Button btnLoginAsync;
    private Button btnShowConversation;
    private Button btnCopyToken;
    private Button btnClearWebView;
    private Button btnStressStart;
    private Button btnStressStop;
    private Button btnReinstall;
    private Button btnHealthSnapshot;
    private Button btnExportReport;
    private Button btnClearLog;
    private Button btnCopyLog;

    private com.google.android.material.switchmaterial.SwitchMaterial switchNetworkMonitor;
    private com.google.android.material.switchmaterial.SwitchMaterial switchAutoRetry;

    private TextView textViewToken;
    private TextView textViewStatus;
    private TextView textViewLog;

    // ===== State =====
    @Nullable
    private volatile String rawToken;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // 日志缓冲（环形：控制长度避免 OOM）
    private static final int LOG_MAX_CHARS = 40_000;
    private final StringBuilder logBuffer = new StringBuilder(8_000);

    // 网络监听
    @Nullable
    private ConnectivityManager connectivityManager;
    @Nullable
    private ConnectivityManager.NetworkCallback networkCallback;
    private volatile boolean networkMonitorRegistered = false;

    // 自动重试 install
    @Nullable
    private volatile HelpBotConfig lastInstallConfig;
    private volatile boolean lastInstallFailedDueToNetwork = false;
    private volatile long lastInstallAttemptAtMs = 0L;

    // 压力回归
    private volatile boolean stressRunning = false;
    private volatile int stressLoopCount = 0;
    private volatile int stressSuccessCount = 0;
    private volatile int stressFailureCount = 0;

    // Android 13+ 通知权限申请
    private final ActivityResultLauncher<String> requestNotificationPermissionLauncher = registerForActivityResult(
            new ActivityResultContracts.RequestPermission(), granted -> {
                try {
                    HBlogger.d(TAG, "POST_NOTIFICATIONS granted=" + granted);
                    if (!granted) {
                        Toast.makeText(this, "未授权通知权限", Toast.LENGTH_LONG).show();
                    }
                } catch (final Exception ignored) {
                }
            });

    @Override
    protected void onCreate(@Nullable final Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            EdgeToEdge.enable(this);
            setContentView(R.layout.activity_main);
            setupInsets();

            initViews();
            initLogger();
            enableStrictModeInDebug();
            requestNotificationPermission();
            setupListeners();
            setupNetworkMonitor();

            clearLog(); // 初始化日志面板
            updateStatusUi("状态：已启动（等待操作）");
            appendLog("App 启动完成，pid=" + Process.myPid());
        } catch (final Exception e) {
            try {
                Toast.makeText(this, "MainActivity 启动异常: " + e.getMessage(), Toast.LENGTH_LONG).show();
            } catch (final Exception ignored) {
            }
        }
    }

    /**
     * 全面屏/沉浸式 insets 适配（稳定性：避免被状态栏/手势条遮挡导致误判“白屏/不可点”）。
     */
    private void setupInsets() {
        try {
            ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.Main), (v, insets) -> {
                try {
                    final Insets systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
                    v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom);
                } catch (final Exception ignored) {
                }
                return insets;
            });
        } catch (final Exception ignored) {
        }
    }

    /**
     * 初始化 UI 组件
     */
    private void initViews() {
        try {
            editIdentify = findViewById(R.id.editIdentify);
            editValue = findViewById(R.id.editValue);
            editDomain = findViewById(R.id.editDomain);
            editChannel = findViewById(R.id.editChannel);
            editTokenUrl = findViewById(R.id.editTokenUrl);

            btnSelfCheck = findViewById(R.id.btn_self_check);
            btnSecurityAudit = findViewById(R.id.btn_security_audit);
            btnNegativeTests = findViewById(R.id.btn_negative_tests);
            btnInstallAsync = findViewById(R.id.btn_install);
            btnGenToken = findViewById(R.id.btn_token);
            btnLoginAsync = findViewById(R.id.btn_login);
            btnShowConversation = findViewById(R.id.btn_helpbot);
            btnCopyToken = findViewById(R.id.btn_copy_token);
            btnClearWebView = findViewById(R.id.btn_clear_webview);
            btnStressStart = findViewById(R.id.btn_stress_start);
            btnStressStop = findViewById(R.id.btn_stress_stop);
            btnReinstall = findViewById(R.id.btn_reinstall);
            btnHealthSnapshot = findViewById(R.id.btn_health_snapshot);
            btnExportReport = findViewById(R.id.btn_export_report);
            btnClearLog = findViewById(R.id.btn_clear_log);
            btnCopyLog = findViewById(R.id.btn_copy_log);

            switchNetworkMonitor = findViewById(R.id.switch_network_monitor);
            switchAutoRetry = findViewById(R.id.switch_auto_retry);

            textViewToken = findViewById(R.id.textViewToken);
            textViewStatus = findViewById(R.id.textViewStatus);
            textViewLog = findViewById(R.id.textViewLog);
        } catch (final Exception e) {
            HBlogger.e(TAG, "initViews 异常", e);
        }
    }

    /**
     * 初始化日志系统（Demo 主动注入，便于排障；release 变体下 SDK 会自动禁用输出）。
     */
    private void initLogger() {
        try {
            HBlogger.initLoggerIfAbsent(new HelpBotLogger(true));
        } catch (final Exception ignored) {
        }
    }

    /**
     * 仅 Debug 版本开启 StrictMode
     */
    private void enableStrictModeInDebug() {
        try {
            if (!isAppDebuggable()) {
                return;
            }
            StrictMode.setThreadPolicy(new StrictMode.ThreadPolicy.Builder()
                    .detectAll()
                    .penaltyLog()
                    .build());
            StrictMode.setVmPolicy(new StrictMode.VmPolicy.Builder()
                    .detectAll()
                    .penaltyLog()
                    .build());
            appendLog("StrictMode 已开启（仅 Debug）");
        } catch (final Exception e) {
            appendLog("StrictMode 开启失败: " + e.getMessage());
        }
    }

    /**
     * 申请通知权限（Demo 用途）
     */
    private void requestNotificationPermission() {
        try {
            if (Build.VERSION.SDK_INT < 33) {
                return;
            }
            if (ContextCompat.checkSelfPermission(this,
                    Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                return;
            }
            requestNotificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS);
        } catch (final Exception e) {
            HBlogger.e(TAG, "申请通知权限异常", e);
        }
    }

    /**
     * 绑定按钮事件
     */
    private void setupListeners() {
        try {
            btnSelfCheck.setOnClickListener(v -> runSelfCheck());
            btnSecurityAudit.setOnClickListener(v -> runSecurityBaselineAudit());
            btnNegativeTests.setOnClickListener(v -> runNegativeTests());

            btnInstallAsync.setOnClickListener(v -> testInstallAsync());
            btnGenToken.setOnClickListener(v -> testGenerateToken());
            btnLoginAsync.setOnClickListener(v -> testLoginAsync());
            btnShowConversation.setOnClickListener(v -> testShowConversation());

            btnCopyToken.setOnClickListener(v -> copyTokenToClipboard());
            btnClearWebView.setOnClickListener(v -> clearWebViewData());

            btnStressStart.setOnClickListener(v -> startStressTest());
            btnStressStop.setOnClickListener(v -> stopStressTest());
            btnReinstall.setOnClickListener(v -> testReinstallation());

            btnHealthSnapshot.setOnClickListener(v -> dumpHealthSnapshot());
            btnExportReport.setOnClickListener(v -> exportReportToClipboard());

            btnClearLog.setOnClickListener(v -> clearLog());
            btnCopyLog.setOnClickListener(v -> copyLogToClipboard());

            // 长按：补充“隐藏入口”但不影响 UI 简洁
            btnShowConversation.setOnLongClickListener(v -> {
                testOtherUIAPIs();
                return true;
            });
            btnGenToken.setOnLongClickListener(v -> {
                testDataUpdateAPIs();
                return true;
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "setupListeners 异常", e);
        }
    }

    // ==================== 自检/扫描/负向 ====================

    /**
     * 一键自检：兼容性/权限/网络/WebView/清单基线。
     */
    private void runSelfCheck() {
        try {
            appendLog("========== 一键自检开始 ==========");
            updateStatusUi("状态：自检中...");

            // 1) 基础信息
            appendLog("AppId=" + getPackageName()
                    + " versionName=" + getAppVersionName()
                    + " versionCode=" + getAppVersionCode());
            appendLog("Android=" + Build.VERSION.RELEASE
                    + " sdkInt=" + Build.VERSION.SDK_INT
                    + " brand=" + Build.BRAND
                    + " model=" + Build.MODEL);
            appendLog("HelpBotSDKVersion=" + safe(HelpBot.getSDKVersion()));

            // 2) 权限状态
            appendLog("Permission.INTERNET=" + hasPermission(Manifest.permission.INTERNET));
            appendLog("Permission.ACCESS_NETWORK_STATE=" + hasPermission(Manifest.permission.ACCESS_NETWORK_STATE));
            if (Build.VERSION.SDK_INT >= 33) {
                appendLog("Permission.POST_NOTIFICATIONS=" + hasPermission(Manifest.permission.POST_NOTIFICATIONS));
            }

            // 3) Cleartext 安全基线
            try {
                final boolean cleartextAllowed = NetworkSecurityPolicy.getInstance().isCleartextTrafficPermitted();
                appendLog("NetworkSecurityPolicy.cleartextPermitted=" + cleartextAllowed + "（建议 false）");
            } catch (final Exception e) {
                appendLog("NetworkSecurityPolicy 检测失败: " + e.getMessage());
            }

            // 4) WebView 组件/版本
            dumpWebViewPackageInfo();

            // 5) 网络诊断
            dumpNetworkDiagnosis();

            // 6) SDK 状态
            appendLog("HelpBot.isInitialized=" + HelpBot.isInitialized());
            appendLog("HelpBot.isConversationVisible=" + HelpBot.isConversationVisible());

            updateStatusUi("状态：自检完成（详见日志）");
            appendLog("========== 一键自检完成 ==========");
        } catch (final Exception e) {
            HBlogger.e(TAG, "runSelfCheck 异常", e);
            updateStatusUi("状态：自检异常: " + e.getMessage());
        }
    }

    /**
     * 安全基线扫描：读取 SDK 内 WebView 的关键 WebSettings。
     */
    private void runSecurityBaselineAudit() {
        try {
            appendLog("========== 安全基线扫描开始 ==========");
            updateStatusUi("状态：安全扫描中...");

            final WebView webView = getSdkWebView();
            if (webView == null) {
                appendLog("WebView 未创建：请先点击 Install（或 OpenConversation）让 SDK 创建 WebView 后再扫描");
                updateStatusUi("状态：WebView 未创建（先 Install）");
                return;
            }

            final WebSettings s = webView.getSettings();
            appendLog("WebSettings.javaScriptEnabled=" + safeBool(s::getJavaScriptEnabled));
            appendLog("WebSettings.domStorageEnabled=" + safeBool(s::getDomStorageEnabled));
            appendLog("WebSettings.databaseEnabled=" + safeBool(s::getDatabaseEnabled) + "（建议 false）");
            appendLog("WebSettings.javaScriptCanOpenWindowsAutomatically="
                    + safeBool(s::getJavaScriptCanOpenWindowsAutomatically) + "（建议 false）");
            appendLog("WebSettings.supportMultipleWindows=" + safeBool(s::supportMultipleWindows) + "（建议 false）");
            appendLog("WebSettings.allowFileAccess=" + safeBool(s::getAllowFileAccess) + "（建议 false）");
            appendLog("WebSettings.allowContentAccess=" + safeBool(s::getAllowContentAccess) + "（按 file input 能力决定）");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                appendLog("WebSettings.allowFileAccessFromFileURLs=" + safeBool(s::getAllowFileAccessFromFileURLs)
                        + "（建议 false）");
                appendLog("WebSettings.allowUniversalAccessFromFileURLs="
                        + safeBool(s::getAllowUniversalAccessFromFileURLs) + "（建议 false）");
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                appendLog("WebSettings.mixedContentMode=" + safeInt(s::getMixedContentMode) + "（建议 NEVER_ALLOW=2）");
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appendLog("WebSettings.safeBrowsingEnabled=" + safeBool(s::getSafeBrowsingEnabled) + "（建议 true）");
            }
            appendLog("WebSettings.cacheMode=" + safeInt(s::getCacheMode) + "（SDK 默认 NO_CACHE）");

            // Cookie 基线（不强制，但记录）
            try {
                final CookieManager cm = CookieManager.getInstance();
                appendLog("CookieManager.acceptCookie=" + cm.acceptCookie());
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    appendLog("CookieManager.acceptThirdPartyCookies=" + cm.acceptThirdPartyCookies(webView));
                }
            } catch (final Exception e) {
                appendLog("CookieManager 读取失败: " + e.getMessage());
            }

            // Token 展示基线（Demo 侧保证不泄露）
            appendLog("Token 展示策略：UI 仅脱敏展示；复制操作才使用原 token（不写入日志）");

            updateStatusUi("状态：安全扫描完成（详见日志）");
            appendLog("========== 安全基线扫描完成 ==========");
        } catch (final Exception e) {
            HBlogger.e(TAG, "runSecurityBaselineAudit 异常", e);
            updateStatusUi("状态：安全扫描异常: " + e.getMessage());
        }
    }

    /**
     * 负向用例：验证 SDK 在错误输入/错误顺序/重复调用下是否稳定且有明确错误码。
     */
    private void runNegativeTests() {
        try {
            appendLog("========== 负向用例开始 ==========");
            updateStatusUi("状态：负向用例执行中...");

            // 1) 未登录/未 install 直接 showConversation
            try {
                final HelpBotResult<Void> r = HelpBot.showConversation(this);
                appendLog("Negative.showConversationWithoutLogin: success=" + r.isSuccess() + " err="
                        + safe(r.getErrorMessage()));
            } catch (final Exception e) {
                appendLog("Negative.showConversationWithoutLogin: exception=" + e.getMessage());
            }

            // 2) login 空 token
            try {
                HelpBot.login("", null, new HelpBotCallback<Void>() {
                    @Override
                    public void onSuccess(final Void result) {
                        appendLog("Negative.loginEmptyToken: unexpected success");
                    }

                    @Override
                    public void onFailure(@NonNull final HelpBotErrorCode errorCode,
                            @NonNull final String errorMessage) {
                        appendLog("Negative.loginEmptyToken: expected failure code=" + errorCode + " msg="
                                + errorMessage);
                    }
                });
            } catch (final Exception e) {
                appendLog("Negative.loginEmptyToken: exception=" + e.getMessage());
            }

            // 3) install 非 https domain（应抛异常）
            try {
                final HelpBotConfig cfg = new HelpBotConfig.Builder()
                        .channelId("test_channel")
                        .domain("http://example.com")
                        .build();
                HelpBot.install(this, cfg, new HelpBotInitCallback() {
                    @Override
                    public void onInitStart() {
                        appendLog("Negative.installHttpDomain: onInitStart");
                    }

                    @Override
                    public void onInitProgress(final int progress, @NonNull final String message) {
                        appendLog("Negative.installHttpDomain: progress=" + progress + " msg=" + message);
                    }

                    @Override
                    public void onInitSuccess() {
                        appendLog("Negative.installHttpDomain: unexpected success");
                    }

                    @Override
                    public void onInitFailure(@NonNull final HelpBotErrorCode errorCode,
                            @NonNull final String errorMessage) {
                        appendLog("Negative.installHttpDomain: expected failure code=" + errorCode + " msg="
                                + errorMessage);
                    }
                });
            } catch (final Exception e) {
                appendLog("Negative.installHttpDomain: expected exception=" + e.getMessage());
            }

            // 4) 重复 install（SDK 应拒绝/返回明确错误码）
            try {
                testInstallAsync();
                testInstallAsync();
                appendLog("Negative.doubleInstall: 已触发两次 install（查看回调/错误码）");
            } catch (final Exception e) {
                appendLog("Negative.doubleInstall: exception=" + e.getMessage());
            }

            updateStatusUi("状态：负向用例完成（详见日志）");
            appendLog("========== 负向用例完成 ==========");
        } catch (final Exception e) {
            HBlogger.e(TAG, "runNegativeTests 异常", e);
            updateStatusUi("状态：负向用例异常: " + e.getMessage());
        }
    }

    // ==================== Core Flow：Install / Token / Login / Open
    // ====================

    /**
     * Install（异步）
     */
    private void testInstallAsync() {
        try {
            appendLog("========== 测试：Install(异步) ==========");
            updateStatusUi("状态：Install 开始...");

            final String channelId = safeTrim(editChannel);
            final String domain = safeTrim(editDomain);

            final HelpBotConfig config = new HelpBotConfig.Builder()
                    .channelId(channelId)
                    .domain(domain)
                    .fullPrivacyMode(false)
                    .enableSseNotification(true)
                    .initTimeout(30_000)
                    .webViewLoadTimeout(15_000)
                    // Demo：传入 customConfig 控制 UI（示例：标题栏开关）
                    .addCustomConfig("showTitleBar", true)
                    .build();

            lastInstallConfig = config;
            lastInstallFailedDueToNetwork = false;
            lastInstallAttemptAtMs = System.currentTimeMillis();

            HelpBot.install(this, config, new HelpBotInitCallback() {
                @Override
                public void onInitStart() {
                    appendLog("Install.onInitStart");
                    updateStatusUi("状态：Install 初始化开始...");
                }

                @Override
                public void onInitProgress(final int progress, @NonNull final String message) {
                    appendLog("Install.onInitProgress: " + progress + "% - " + message);
                    updateStatusUi(String.format(Locale.US, "状态：Install %d%% - %s", progress, message));
                }

                @Override
                public void onInitSuccess() {
                    appendLog("Install.onInitSuccess");
                    updateStatusUi("状态：Install 成功");
                    toast("Install 成功");

                    setupEventListeners();
                    appendLog("提示：可点击“安全基线扫描”检查 WebView 设置是否符合基线");
                }

                @Override
                public void onInitFailure(@NonNull final HelpBotErrorCode errorCode,
                        @NonNull final String errorMessage) {
                    appendLog("Install.onInitFailure: " + errorCode + " - " + errorMessage);
                    updateStatusUi("状态：Install 失败: " + errorMessage);
                    toastLong(errorMessage);

                    // 网络相关失败：标记，便于网络恢复时自动重试
                    if (errorCode == HelpBotErrorCode.NETWORK_UNAVAILABLE
                            || errorCode == HelpBotErrorCode.NETWORK_TIMEOUT
                            || errorCode == HelpBotErrorCode.OPERATION_TIMEOUT) {
                        lastInstallFailedDueToNetwork = true;
                    }
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "testInstallAsync 异常", e);
            updateStatusUi("状态：Install 异常: " + e.getMessage());
        }
    }

    /**
     * Login（异步）
     */
    private void testLoginAsync() {
        try {
            appendLog("========== 测试：Login(异步) ==========");
            updateStatusUi("状态：Login 开始...");

            final String token = rawToken;
            if (token == null || token.trim().isEmpty()) {
                toast("请先生成 Token");
                updateStatusUi("状态：Login 失败（Token 为空）");
                return;
            }

            final Map<String, Object> loginConfig = new HashMap<>();
            loginConfig.put("full_privacy_enabled", false);

            HelpBot.login(token, loginConfig, new HelpBotCallback<Void>() {
                @Override
                public void onSuccess(final Void result) {
                    appendLog("Login.onSuccess");
                    updateStatusUi("状态：Login 成功");
                    toast("Login 成功");
                }

                @Override
                public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                    appendLog("Login.onFailure: " + errorCode + " - " + errorMessage);
                    updateStatusUi("状态：Login 失败: " + errorMessage);
                    toastLong(errorMessage);
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "testLoginAsync 异常", e);
            updateStatusUi("状态：Login 异常: " + e.getMessage());
        }
    }

    /**
     * OpenConversation
     */
    private void testShowConversation() {
        try {
            appendLog("========== 测试：OpenConversation ==========");
            final HelpBotResult<Void> result = HelpBot.showConversation(this);
            if (result.isSuccess()) {
                appendLog("OpenConversation: success（若 install/login 未完成可能为入队等待）");
                updateStatusUi("状态：OpenConversation 已触发");
            } else {
                appendLog("OpenConversation: failure=" + result.getErrorMessage());
                updateStatusUi("状态：OpenConversation 失败: " + result.getErrorMessage());
                toast(String.valueOf(result.getErrorMessage()));
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "testShowConversation 异常", e);
            updateStatusUi("状态：OpenConversation 异常: " + e.getMessage());
        }
    }

    /**
     * 生成 Token（Demo）
     */
    private void testGenerateToken() {
        try {
            appendLog("========== 测试：GenToken ==========");
            updateStatusUi("状态：正在生成 Token...");

            final JSONObject requestBody = new JSONObject();
            final JSONArray identitiesArray = new JSONArray();
            final JSONObject identity = new JSONObject();
            identity.put("identifier", safeTrim(editIdentify));
            identity.put("value", safeTrim(editValue));
            identitiesArray.put(identity);
            requestBody.put("identities", identitiesArray);

            final String jsonString = requestBody.toString();
            final String url = safeTrim(editTokenUrl);

            OkHttpUtils.postRequest(url, jsonString, new OkHttpUtils.PostCallback() {
                @SuppressLint("SetTextI18n")
                @Override
                public void onSuccess(final String response) {
                    mainHandler.post(() -> {
                        try {
                            rawToken = extractTokenFromResponse(response);
                            final String masked = (rawToken == null) ? null : HBlogger.sanitizeValue(rawToken);
                            textViewToken.setText("Token（脱敏）： " + (masked == null ? "Token获取失败" : masked));
                            updateStatusUi(rawToken == null ? "状态：Token 获取失败" : "状态：Token 已生成（脱敏显示）");
                            appendLog(rawToken == null ? "GenToken: fail（解析失败）" : "GenToken: success（已脱敏）");
                        } catch (final Exception e) {
                            appendLog("GenToken.onSuccess 处理异常: " + e.getMessage());
                        }
                    });
                }

                @Override
                public void onFailure(final Exception e) {
                    mainHandler.post(() -> {
                        try {
                            HBlogger.e(TAG, "Token生成失败", e);
                            updateStatusUi("状态：Token 生成失败: " + e.getMessage());
                            toastLong("Token生成失败: " + e.getMessage());
                            appendLog("GenToken: failure=" + e.getMessage());
                        } catch (final Exception ignored) {
                        }
                    });
                }
            });

            toast("正在生成 Token...");
        } catch (final Exception e) {
            HBlogger.e(TAG, "构造Token请求失败", e);
            updateStatusUi("状态：构造请求失败: " + e.getMessage());
            toast("构造请求失败: " + e.getMessage());
        }
    }

    @Nullable
    private String extractTokenFromResponse(@Nullable final String responseJson) {
        try {
            final JSONObject jsonResponse = new JSONObject(responseJson == null ? "" : responseJson);
            return jsonResponse.getString("token");
        } catch (final Exception e) {
            HBlogger.e(TAG, "解析Token失败", e);
            return null;
        }
    }

    // ==================== 事件监听 / UI 其它接口 / 数据更新 ====================

    private void setupEventListeners() {
        try {
            appendLog("========== 事件监听：已设置 ==========");
            HelpBot.setHelpBotEventsListener(new HelpBotEventsListener() {
                @Override
                public void onEventOccurred(@NonNull final String eventName, final Map<String, Object> data) {
                    appendLog("Event.onEventOccurred: " + eventName + " data=" + data);
                    runOnUiThread(
                            () -> Toast.makeText(MainActivity.this, "事件: " + eventName, Toast.LENGTH_SHORT).show());
                }

                @Override
                public void onUserAuthenticationFailure(final HelpBotAuthenticationFailureReason reason) {
                    appendLog("Event.onUserAuthenticationFailure: " + reason);
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "认证失败: " + reason, Toast.LENGTH_LONG).show());
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "setupEventListeners 异常", e);
        }
    }

    /**
     * 长按 OpenConversation 触发：测试其他 UI 接口
     */
    private void testOtherUIAPIs() {
        try {
            appendLog("========== 测试：其他UI接口 ==========");
            final HelpBotResult<Void> r1 = HelpBot.showFAQs(this);
            appendLog("showFAQs: " + (r1.isSuccess() ? "success" : ("fail=" + r1.getErrorMessage())));
            final HelpBotResult<Void> r2 = HelpBot.showFAQSection(this, "test_section_id");
            appendLog("showFAQSection: " + (r2.isSuccess() ? "success" : ("fail=" + r2.getErrorMessage())));
            final HelpBotResult<Void> r3 = HelpBot.showSingleFAQ(this, "test_question_id");
            appendLog("showSingleFAQ: " + (r3.isSuccess() ? "success" : ("fail=" + r3.getErrorMessage())));
            toast("UI接口测试完成，查看日志");
        } catch (final Exception e) {
            appendLog("testOtherUIAPIs 异常: " + e.getMessage());
        }
    }

    /**
     * 长按 GenToken 触发：测试数据更新接口
     */
    private void testDataUpdateAPIs() {
        try {
            appendLog("========== 测试：数据更新接口 ==========");
            final Map<String, Object> sdkMeta = new HashMap<>();
            sdkMeta.put("app_version", getAppVersionName());
            sdkMeta.put("device_model", Build.MODEL);
            final HelpBotResult<Void> r1 = HelpBot.updateSDKMeta(sdkMeta);
            appendLog("updateSDKMeta: " + (r1.isSuccess() ? "success" : ("fail=" + r1.getErrorMessage())));

            final Map<String, Object> customMeta = new HashMap<>();
            customMeta.put("user_level", "VIP");
            customMeta.put("test_key", "test_value");
            final HelpBotResult<Void> r2 = HelpBot.updateCustomMeta(customMeta);
            appendLog("updateCustomMeta: " + (r2.isSuccess() ? "success" : ("fail=" + r2.getErrorMessage())));

            final ArrayList<String> tags = new ArrayList<>();
            tags.add("test_tag_1");
            tags.add("test_tag_2");
            final HelpBotResult<Void> r3 = HelpBot.addIssueTags(tags);
            appendLog("addIssueTags: " + (r3.isSuccess() ? "success" : ("fail=" + r3.getErrorMessage())));
            final HelpBotResult<Void> r4 = HelpBot.removeIssueTags(tags);
            appendLog("removeIssueTags: " + (r4.isSuccess() ? "success" : ("fail=" + r4.getErrorMessage())));

            final HelpBotResult<Void> r5 = HelpBot.reportSystemInfoToServer();
            appendLog("reportSystemInfoToServer: " + (r5.isSuccess() ? "success" : ("fail=" + r5.getErrorMessage())));

            toast("数据更新接口测试完成，查看日志");
        } catch (final Exception e) {
            appendLog("testDataUpdateAPIs 异常: " + e.getMessage());
        }
    }

    // ==================== 网络波动 / 监听 / 自动重试 ====================

    private void setupNetworkMonitor() {
        try {
            connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                appendLog("ConnectivityManager 为空，无法监听网络变化");
                return;
            }
            networkCallback = new ConnectivityManager.NetworkCallback() {
                @Override
                public void onAvailable(@NonNull final Network network) {
                    onNetworkChanged("onAvailable", network);
                }

                @Override
                public void onLost(@NonNull final Network network) {
                    onNetworkChanged("onLost", network);
                }

                @Override
                public void onCapabilitiesChanged(@NonNull final Network network,
                        @NonNull final NetworkCapabilities networkCapabilities) {
                    onNetworkChanged("onCapabilitiesChanged", network);
                }
            };

            if (switchNetworkMonitor != null && switchNetworkMonitor.isChecked()) {
                registerNetworkCallbackIfNeeded();
            }
        } catch (final Exception e) {
            appendLog("setupNetworkMonitor 异常: " + e.getMessage());
        }
    }

    private void registerNetworkCallbackIfNeeded() {
        try {
            if (networkMonitorRegistered) {
                return;
            }
            if (connectivityManager == null || networkCallback == null) {
                return;
            }
            final NetworkRequest req = new NetworkRequest.Builder().build();
            connectivityManager.registerNetworkCallback(req, networkCallback);
            networkMonitorRegistered = true;
            appendLog("网络监听已注册");
        } catch (final Exception e) {
            appendLog("注册网络监听失败: " + e.getMessage());
        }
    }

    private void unregisterNetworkCallbackIfNeeded() {
        try {
            if (!networkMonitorRegistered) {
                return;
            }
            if (connectivityManager != null && networkCallback != null) {
                connectivityManager.unregisterNetworkCallback(networkCallback);
            }
            networkMonitorRegistered = false;
            appendLog("网络监听已注销");
        } catch (final Exception ignored) {
            networkMonitorRegistered = false;
        }
    }

    private void onNetworkChanged(@NonNull final String type, @NonNull final Network network) {
        try {
            if (switchNetworkMonitor != null && !switchNetworkMonitor.isChecked()) {
                return;
            }
            appendLog("Network." + type + " network=" + network);
            dumpNetworkDiagnosis();

            // 网络恢复：自动重试 install（避免狂重试：至少间隔 3 秒）
            if ("onAvailable".equals(type) || "onCapabilitiesChanged".equals(type)) {
                if (switchAutoRetry != null
                        && switchAutoRetry.isChecked()
                        && lastInstallFailedDueToNetwork
                        && lastInstallConfig != null
                        && (System.currentTimeMillis() - lastInstallAttemptAtMs) > 3_000L) {
                    appendLog("检测到网络恢复，触发自动重试 Install（有间隔）");
                    testInstallAsync();
                }
            }
        } catch (final Exception ignored) {
        }
    }

    private void dumpNetworkDiagnosis() {
        try {
            final NetworkUtils.NetworkDiagnosis d = NetworkUtils.diagnose(getApplicationContext());
            appendLog("NetworkDiagnosis: hasPerm=" + d.hasAccessNetworkStatePermission
                    + " connected=" + d.networkConnected
                    + " internet=" + d.hasInternetCapability
                    + " validated=" + d.validated
                    + " transport=" + d.transport
                    + " hint=" + d.buildUserHint());
        } catch (final Exception e) {
            appendLog("NetworkDiagnosis 异常: " + e.getMessage());
        }
    }

    // ==================== 稳定性：压力回归 / WebView 清理 / 健康快照 ====================

    /**
     * 压力回归：循环 open/hide（验证 Activity 复用、WebView attach/detach 稳定性）。
     */
    private void startStressTest() {
        try {
            if (stressRunning) {
                toast("压力回归已在运行");
                return;
            }
            stressRunning = true;
            stressLoopCount = 0;
            stressSuccessCount = 0;
            stressFailureCount = 0;

            appendLog("========== 压力回归开始（open/hide 循环） ==========");
            updateStatusUi("状态：压力回归运行中...");
            scheduleNextStressStep();
        } catch (final Exception e) {
            stressRunning = false;
            updateStatusUi("状态：压力回归启动失败: " + e.getMessage());
        }
    }

    private void scheduleNextStressStep() {
        mainHandler.postDelayed(() -> {
            try {
                if (!stressRunning) {
                    return;
                }
                stressLoopCount++;
                final HelpBotResult<Void> open = HelpBot.showConversation(MainActivity.this);
                if (open.isSuccess()) {
                    stressSuccessCount++;
                } else {
                    stressFailureCount++;
                    appendLog("Stress.open fail: " + open.getErrorMessage());
                }

                // 延迟 hide，避免过快导致 UI 还未 attach
                mainHandler.postDelayed(() -> {
                    try {
                        if (!stressRunning) {
                            return;
                        }
                        final HelpBotResult<Void> hide = HelpBot.hideConversation();
                        if (!hide.isSuccess()) {
                            stressFailureCount++;
                            appendLog("Stress.hide fail: " + hide.getErrorMessage());
                        }
                        if (stressLoopCount % 10 == 0) {
                            appendLog("Stress progress: loops=" + stressLoopCount + " ok=" + stressSuccessCount
                                    + " fail=" + stressFailureCount);
                            updateStatusUi("状态：压力回归 loops=" + stressLoopCount + " ok=" + stressSuccessCount + " fail="
                                    + stressFailureCount);
                        }
                        // 默认跑 60 次，避免 Demo 无限制运行
                        if (stressLoopCount >= 60) {
                            stopStressTest();
                            return;
                        }
                        scheduleNextStressStep();
                    } catch (final Exception e) {
                        stressFailureCount++;
                        appendLog("Stress.hide exception: " + e.getMessage());
                        scheduleNextStressStep();
                    }
                }, 800);
            } catch (final Exception e) {
                stressFailureCount++;
                appendLog("Stress.step exception: " + e.getMessage());
                scheduleNextStressStep();
            }
        }, 500);
    }

    private void stopStressTest() {
        try {
            if (!stressRunning) {
                toast("压力回归未运行");
                return;
            }
            stressRunning = false;
            appendLog("========== 压力回归停止 loops=" + stressLoopCount + " ok=" + stressSuccessCount + " fail="
                    + stressFailureCount + " ==========");
            updateStatusUi("状态：压力回归已停止 loops=" + stressLoopCount + " ok=" + stressSuccessCount + " fail="
                    + stressFailureCount);
            toast("压力回归已停止");
        } catch (final Exception ignored) {
        }
    }

    private void dumpHealthSnapshot() {
        try {
            appendLog("========== WebSDK 健康快照 ==========");
            final Map<String, Object> snapshot = HelpBot.getWebSdkHealthSnapshot();
            appendLog("healthSnapshot=" + snapshot);
            updateStatusUi("状态：已读取健康快照（详见日志）");
        } catch (final Exception e) {
            appendLog("读取健康快照失败: " + e.getMessage());
            updateStatusUi("状态：读取健康快照失败: " + e.getMessage());
        }
    }

    private void clearWebViewData() {
        try {
            appendLog("========== 清理 WebView 缓存 ==========");
            final WebView webView = getSdkWebView();
            if (webView == null) {
                appendLog("WebView 未创建，跳过清理（请先 Install）");
                toast("WebView 未创建，先 Install");
                return;
            }
            mainHandler.post(() -> {
                try {
                    webView.clearCache(true);
                    webView.clearHistory();
                    appendLog("WebView.clearCache/clearHistory 已执行");
                    toast("已清理 WebView 缓存/历史");
                } catch (final Exception e) {
                    appendLog("清理 WebView 异常: " + e.getMessage());
                    toast("清理 WebView 异常: " + e.getMessage());
                }
            });
        } catch (final Exception e) {
            appendLog("clearWebViewData 异常: " + e.getMessage());
        }
    }

    // ==================== Reinstall 回归 ====================

    /**
     * 测试：destroy 后重新 install（验证 SDK 状态复位与资源清理是否可靠）。
     */
    private void testReinstallation() {
        appendLog("========== 测试：destroy 后重新安装 ==========");
        updateStatusUi("状态：开始重新安装测试...");

        try {
            HelpBot.destroy();
            appendLog("✓ HelpBot.destroy 已调用");
        } catch (final Exception e) {
            appendLog("✗ HelpBot.destroy 异常: " + e.getMessage());
            updateStatusUi("状态：✗ destroy 异常: " + e.getMessage());
            toastLong("destroy 异常: " + e.getMessage());
            return;
        }

        mainHandler.postDelayed(() -> {
            try {
                appendLog("步骤：重新 install");
                testInstallAsync();
            } catch (final Exception e) {
                appendLog("reinstall 触发 install 异常: " + e.getMessage());
            }
        }, 800);
    }

    // ==================== Token 安全：脱敏展示/复制 ====================

    private void copyTokenToClipboard() {
        try {
            final String token = rawToken;
            if (token == null || token.trim().isEmpty()) {
                toast("Token 为空，无法复制");
                return;
            }
            copyToClipboard("helpbot_token", token);
            toast("Token 已复制到剪贴板（注意保护敏感信息）");
            appendLog("Token 已复制到剪贴板（未写入日志内容）");
        } catch (final Exception e) {
            toast("复制 Token 失败: " + e.getMessage());
        }
    }

    private void copyToClipboard(@NonNull final String label, @NonNull final String content) {
        final ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (cm == null) {
            throw new IllegalStateException("ClipboardManager 为空");
        }
        cm.setPrimaryClip(ClipData.newPlainText(label, content));
    }

    // ==================== 报告 / 日志 ====================

    private void clearLog() {
        try {
            synchronized (logBuffer) {
                logBuffer.setLength(0);
                logBuffer.append("日志：\n");
            }
            if (textViewLog != null) {
                textViewLog.setText("日志：\n");
            }
        } catch (final Exception ignored) {
        }
    }

    private void copyLogToClipboard() {
        try {
            final String content;
            synchronized (logBuffer) {
                content = logBuffer.toString();
            }
            copyToClipboard("helpbot_log", content);
            toast("日志已复制到剪贴板");
        } catch (final Exception e) {
            toast("复制日志失败: " + e.getMessage());
        }
    }

    private void exportReportToClipboard() {
        try {
            final String report = buildReport();
            copyToClipboard("helpbot_report", report);
            toast("报告已复制到剪贴板");
        } catch (final Exception e) {
            toast("导出报告失败: " + e.getMessage());
        }
    }

    @NonNull
    private String buildReport() {
        final StringBuilder sb = new StringBuilder(8_000);
        sb.append("HelpBot SDK 测试报告\n");
        sb.append("time=").append(System.currentTimeMillis()).append('\n');
        sb.append("appId=").append(getPackageName()).append('\n');
        sb.append("appVersion=").append(getAppVersionName()).append(" (").append(getAppVersionCode()).append(")\n");
        sb.append("android=").append(Build.VERSION.RELEASE).append(" (").append(Build.VERSION.SDK_INT).append(")\n");
        sb.append("device=").append(Build.BRAND).append(" ").append(Build.MODEL).append('\n');
        sb.append("helpBotSdkVersion=").append(safe(HelpBot.getSDKVersion())).append('\n');
        sb.append("initialized=").append(HelpBot.isInitialized()).append('\n');
        sb.append("conversationVisible=").append(HelpBot.isConversationVisible()).append('\n');
        sb.append("tokenMasked=").append(rawToken == null ? "null" : HBlogger.sanitizeValue(rawToken)).append('\n');

        // 网络诊断
        try {
            final NetworkUtils.NetworkDiagnosis d = NetworkUtils.diagnose(getApplicationContext());
            sb.append("network.hasPermission=").append(d.hasAccessNetworkStatePermission).append('\n');
            sb.append("network.connected=").append(d.networkConnected).append('\n');
            sb.append("network.hasInternet=").append(d.hasInternetCapability).append('\n');
            sb.append("network.validated=").append(d.validated).append('\n');
            sb.append("network.transport=").append(d.transport).append('\n');
        } catch (final Exception ignored) {
        }

        // Cleartext 基线
        try {
            sb.append("cleartextPermitted=").append(NetworkSecurityPolicy.getInstance().isCleartextTrafficPermitted())
                    .append('\n');
        } catch (final Exception ignored) {
        }

        // WebView 版本
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                final android.content.pm.PackageInfo p = WebView.getCurrentWebViewPackage();
                if (p != null) {
                    sb.append("webview.package=").append(p.packageName).append('\n');
                    sb.append("webview.version=").append(p.versionName).append('\n');
                }
            }
        } catch (final Exception ignored) {
        }

        // 健康快照
        try {
            sb.append("websdk.healthSnapshot=").append(HelpBot.getWebSdkHealthSnapshot()).append('\n');
        } catch (final Exception ignored) {
        }

        // 追加最近日志（Demo 不打印原 token；HBlogger 自带脱敏）
        sb.append("\n--- logs ---\n");
        try {
            synchronized (logBuffer) {
                sb.append(logBuffer);
            }
        } catch (final Exception ignored) {
        }
        return sb.toString();
    }

    // ==================== 工具方法 ====================

    private void updateStatusUi(@NonNull final String status) {
        try {
            runOnUiThread(() -> {
                try {
                    if (textViewStatus != null) {
                        textViewStatus.setText(status);
                    }
                } catch (final Exception ignored) {
                }
            });
        } catch (final Exception ignored) {
        }
    }

    /**
     * 追加日志（同时输出到 HBlogger + 屏幕日志面板）
     */
    private void appendLog(@NonNull final String message) {
        try {
            final String line = "[" + System.currentTimeMillis() + "] " + message;
            HBlogger.d(TAG, line);
            synchronized (logBuffer) {
                logBuffer.append(line).append('\n');
                if (logBuffer.length() > LOG_MAX_CHARS) {
                    final int start = logBuffer.length() - (LOG_MAX_CHARS / 2);
                    logBuffer.delete(0, Math.max(start, 0));
                    logBuffer.insert(0, "[trimmed] 日志过长已裁剪\n");
                }
            }
            runOnUiThread(() -> {
                try {
                    if (textViewLog != null) {
                        synchronized (logBuffer) {
                            textViewLog.setText(logBuffer.toString());
                        }
                    }
                } catch (final Exception ignored) {
                }
            });
        } catch (final Exception ignored) {
        }
    }

    private void toast(@NonNull final String msg) {
        try {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
        } catch (final Exception ignored) {
        }
    }

    private void toastLong(@NonNull final String msg) {
        try {
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
        } catch (final Exception ignored) {
        }
    }

    private boolean hasPermission(@NonNull final String permission) {
        try {
            return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED;
        } catch (final Exception ignored) {
            return false;
        }
    }

    @NonNull
    private String safe(@Nullable final String s) {
        return (s == null) ? "" : s;
    }

    @NonNull
    private String safeTrim(@Nullable final EditText editText) {
        try {
            if (editText == null) {
                return "";
            }
            return String.valueOf(editText.getText()).trim();
        } catch (final Exception ignored) {
            return "";
        }
    }

    @Nullable
    private WebView getSdkWebView() {
        try {
            return HelpBotWebViewSession.getInstance().getWebView();
        } catch (final Exception e) {
            appendLog("getSdkWebView 异常: " + e.getMessage());
            return null;
        }
    }

    /**
     * 获取 App versionName（运行时读取，避免依赖 BuildConfig 生成策略）。
     */
    @NonNull
    private String getAppVersionName() {
        try {
            final PackageManager pm = getPackageManager();
            if (pm == null) {
                return "";
            }
            final PackageInfo pi = pm.getPackageInfo(getPackageName(), 0);
            return (pi == null || pi.versionName == null) ? "" : pi.versionName;
        } catch (final Exception ignored) {
            return "";
        }
    }

    /**
     * 获取 App versionCode（运行时读取，避免依赖 BuildConfig 生成策略）。
     */
    private long getAppVersionCode() {
        try {
            final PackageManager pm = getPackageManager();
            if (pm == null) {
                return -1L;
            }
            final PackageInfo pi = pm.getPackageInfo(getPackageName(), 0);
            if (pi == null) {
                return -1L;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                return pi.getLongVersionCode();
            }
            // noinspection deprecation
            return pi.versionCode;
        } catch (final Exception ignored) {
            return -1L;
        }
    }

    /**
     * 判断当前 App 是否 debuggable（替代 BuildConfig.DEBUG）。
     */
    private boolean isAppDebuggable() {
        try {
            final ApplicationInfo ai = getApplicationInfo();
            if (ai == null) {
                return false;
            }
            return (ai.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        } catch (final Exception ignored) {
            return false;
        }
    }

    private void dumpWebViewPackageInfo() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                final android.content.pm.PackageInfo p = WebView.getCurrentWebViewPackage();
                if (p == null) {
                    appendLog("WebViewPackage: null（可能未安装/被禁用）");
                    return;
                }
                appendLog("WebViewPackage: " + p.packageName + " version=" + p.versionName);
            } else {
                appendLog("WebViewPackage: API<26 不支持 getCurrentWebViewPackage（跳过）");
            }
        } catch (final Exception e) {
            appendLog("dumpWebViewPackageInfo 异常: " + e.getMessage());
        }
    }

    // Java 11 兼容：用自定义函数接口避免引入 java.util.function（Android 旧工具链偶发问题）
    private interface BoolSupplier {
        boolean get() throws Exception;
    }

    private interface IntSupplier {
        int get() throws Exception;
    }

    private boolean safeBool(@NonNull final BoolSupplier s) {
        try {
            return s.get();
        } catch (final Exception ignored) {
            return false;
        }
    }

    private int safeInt(@NonNull final IntSupplier s) {
        try {
            return s.get();
        } catch (final Exception ignored) {
            return -1;
        }
    }

    // ==================== 生命周期：注册/注销监听，清理资源 ====================

    @Override
    protected void onStart() {
        super.onStart();
        try {
            if (switchNetworkMonitor != null && switchNetworkMonitor.isChecked()) {
                registerNetworkCallbackIfNeeded();
            }
        } catch (final Exception ignored) {
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        try {
            unregisterNetworkCallbackIfNeeded();
        } catch (final Exception ignored) {
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        try {
            appendLog("========== Activity 销毁，清理资源 ==========");
            stopStressTest();
            unregisterNetworkCallbackIfNeeded();
            mainHandler.removeCallbacksAndMessages(null);
            HelpBot.removeHelpBotEventsListener();
        } catch (final Exception ignored) {
        }
    }
}
