package com.example.HelpBot.web;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.Activity;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.net.http.SslError;
import android.webkit.ConsoleMessage;
import android.webkit.HttpAuthHandler;
import android.webkit.SslErrorHandler;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.BuildConfig;
import com.example.HelpBot.HelpBot;
import com.example.HelpBot.chat.ChatEventsHandler;
import com.example.HelpBot.chat.ChatToNativeBridge;
import com.example.HelpBot.chat.WebViewConsoleLogger;
import com.example.HelpBot.core.HelpBotConfig;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.utils.ApplicationUtils;
import com.example.HelpBot.utils.SDKUrls;
import com.example.HelpBot.utils.Utils;

import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.util.Locale;

/**
 * WebView 初始化与安全加固工具类
 * 目标：
 * - 统一 SDK 内 WebView 的配置
 * - 限制跳转域名、减少不必要能力开启、所有回调 try-catch
 */
public final class HelpBotWebViewHelper {
    private static final String TAG = "HBWebViewHelper";

    // 提前解析，避免每次导航都重复 Uri.parse()。
    private static final Uri WEBCHAT_INDEX_URI = Uri.parse(SDKUrls.WEBCHAT_INDEX);
    private static final Uri WEBCHAT_LOADER_URI = Uri.parse(SDKUrls.WEBCHAT_LOADER_JS);
    @Nullable
    private static final String WEBCHAT_INDEX_HOST = WEBCHAT_INDEX_URI.getHost();
    @Nullable
    private static final String WEBCHAT_LOADER_HOST = WEBCHAT_LOADER_URI.getHost();
    private static final int WEBCHAT_INDEX_PORT = WEBCHAT_INDEX_URI.getPort();
    private static final int WEBCHAT_LOADER_PORT = WEBCHAT_LOADER_URI.getPort();

    public interface FileChooserHandler {
        void openFileChooser(@NonNull ValueCallback<Uri[]> callback, @NonNull String acceptType, boolean allowMultiple);
    }

    private HelpBotWebViewHelper() {
        super();
    }

    @SuppressLint("SetJavaScriptEnabled")
    public static void initWebView(
            @NonNull final Activity activity,
            @NonNull final WebView webView,
            final boolean fullscreen,
            @NonNull final FileChooserHandler fileChooserHandler) {
        initWebView(activity.getApplicationContext(), webView, fullscreen, fileChooserHandler);
    }

    /**
     * 预加载模式初始化 WebView（不依赖 Activity）。
     * - fileChooserHandler 可以是 null，会安全降级（直接取消文件选择）。
     * - 这个方法可用于 install 阶段“无 UI 预热”，后续让 Activity 接管展示。
     */
    @SuppressLint("SetJavaScriptEnabled")
    public static void initWebView(
            @NonNull final android.content.Context context,
            @NonNull final WebView webView,
            final boolean fullscreen,
            @Nullable final FileChooserHandler fileChooserHandler) {
        try {
            // Debugging：仅在 Debug 且 app 为 debug build 时开启
            try {
                // 发布版 SDK 禁止开启 WebView 远程调试（即使宿主是 debug 包也不允许）
                if (BuildConfig.DEBUG && ApplicationUtils.isApplicationInDebugMode(context)) {
                    WebView.setWebContentsDebuggingEnabled(true);
                }
            } catch (final Exception ignored) {
            }

            final WebSettings webSettings = webView.getSettings();
            webSettings.setJavaScriptEnabled(true);
            webSettings.setDomStorageEnabled(true);
            webSettings.setDatabaseEnabled(false);
            webSettings.setSupportZoom(false);
            webSettings.setBuiltInZoomControls(false);
            webSettings.setDisplayZoomControls(false);
            webSettings.setJavaScriptCanOpenWindowsAutomatically(false);
            webSettings.setSupportMultipleWindows(false);

            webSettings.setAllowFileAccess(false);
            // 默认禁止 content:// 访问（减少攻击面）。
            // 仅当开启文件选择/上传能力时再打开（部分系统的 file input 依赖 content:// 读取）。
            webSettings.setAllowContentAccess(fileChooserHandler != null);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                webSettings.setAllowFileAccessFromFileURLs(false);
                // 注意：setAllowUniversalAccessFromFileURLs 保持 false 以确保安全
                // 但我们需要通过 shouldInterceptRequest 来处理同域名跨端口的 CORS 请求
                webSettings.setAllowUniversalAccessFromFileURLs(false);
            }

            // Safe Browsing（API 26+）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    webSettings.setSafeBrowsingEnabled(true);
                } catch (final Exception ignored) {
                }
            }

            // 避免混合内容
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                webSettings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
            }

            // 关闭缓存，SDK 侧由服务端/HTTP 控制
            webSettings.setCacheMode(WebSettings.LOAD_NO_CACHE);

            // 禁止保存密码
            webSettings.setSavePassword(false);

            // 禁止定位（除非业务明确需要，客服 SDK 通常不需要 Web 侧直接定位）
            webSettings.setGeolocationEnabled(false);

            // 添加 JS Bridge（暴露必要方法）
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext != null) {
                webView.addJavascriptInterface(
                        // 使用 applicationContext 避免持有 Activity 导致泄漏
                        new ChatToNativeBridge(context.getApplicationContext(), hbContext.getEventProxy(),
                                new ChatEventsHandler()),
                        "HelpBotNativeAndroid");
            }

            bindWebChromeClient(webView, fileChooserHandler);

            webView.setWebViewClient(new WebViewClient() {
                @Override
                public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                    try {
                        if (request == null) {
                            return super.shouldInterceptRequest(view, request);
                        }
                        final Uri uri = request.getUrl();
                        final boolean mainFrame = request.isForMainFrame();
                        final WebResourceResponse blocked = interceptIfBlocked(uri, mainFrame);
                        return (blocked != null) ? blocked : super.shouldInterceptRequest(view, request);
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "shouldInterceptRequest 异常", e);
                        return super.shouldInterceptRequest(view, request);
                    }
                }

                @Override
                public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
                    try {
                        final Uri uri = (url == null) ? null : Uri.parse(url);
                        final WebResourceResponse blocked = interceptIfBlocked(uri, false);
                        return (blocked != null) ? blocked : super.shouldInterceptRequest(view, url);
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "shouldInterceptRequest(legacy) 异常", e);
                        return super.shouldInterceptRequest(view, url);
                    }
                }

                @Override
                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    try {
                        final Uri uri = (url == null) ? null : Uri.parse(url);
                        return !isUrlAllowed(uri);
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "shouldOverrideUrlLoading(legacy) 异常", e);
                        return true;
                    }
                }

                @Override
                public void onPageFinished(WebView view, String url) {
                    super.onPageFinished(view, url);
                    try {
                        // WebSDK 读取 window.HelpBotConfig：这里仅注入业务参数，不提供可被宿主篡改的入口 URL。
                        final JSONObject config = new JSONObject();
                        final HelpBotConfig sdkConfig = HelpBot.getConfig();
                        if (sdkConfig != null) {
                            config.put("baseURL", sdkConfig.getDomain());
                            config.put("channelId", sdkConfig.getChannelId());
                            // 隐私模式（兼容不同命名：fullPrivacyMode / full_privacy_enabled）
                            config.put("fullPrivacyMode", sdkConfig.isFullPrivacyMode());
                            config.put("full_privacy_enabled", sdkConfig.isFullPrivacyMode());

                            config.put("useDevAPI", sdkConfig.isUseDevApi());
                            if (sdkConfig.isUseDevApi()) {
                                if (sdkConfig.getCompanyId() != null) {
                                    config.put("companyId", sdkConfig.getCompanyId());
                                }
                                if (sdkConfig.getUserId() != null) {
                                    config.put("userId", sdkConfig.getUserId());
                                }
                            } else {
                                // 生产环境可选预置 token（推荐在 login 阶段 setTokenAndConnect 注入）。
                                if (sdkConfig.getPreGeneratedToken() != null) {
                                    config.put("preGeneratedToken", sdkConfig.getPreGeneratedToken());
                                }
                            }
                        }
                        config.put("autoInit", false);
                        // 使用原生入口图标
                        config.put("hideBubble", true);
                        config.put("fullscreen", fullscreen);

                        // 初始化 window 环境变量
                        final String initString = HelpBotJsCommand.buildInitConfig(config);
                        view.evaluateJavascript(initString, value -> HBlogger.d(TAG, "initWebChatConfig 返回: " + value));

                        // 注入 loader.js（远端加载）
                        final String loaderString = HelpBotJsCommand.buildLoadScript(SDKUrls.WEBCHAT_LOADER_JS);
                        view.evaluateJavascript(loaderString, value -> HBlogger.d(TAG, "load loader.js 返回: " + value));
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "onPageFinished 初始化异常", e);
                    }
                }

                @Override
                public void onPageStarted(WebView view, String url, Bitmap favicon) {
                    super.onPageStarted(view, url, favicon);
                }

                @Override
                public void onPageCommitVisible(WebView view, String url) {
                    super.onPageCommitVisible(view, url);
                    // 系统信息上报由 showConversation 触发
                }

                @Override
                public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                    try {
                        final Uri uri = (request == null) ? null : request.getUrl();
                        return !isUrlAllowed(uri);
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "shouldOverrideUrlLoading 异常", e);
                        return true;
                    }
                }

                @Override
                @TargetApi(Build.VERSION_CODES.M)
                public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                    super.onReceivedError(view, request, error);
                    try {
                        final Uri uri = (request == null) ? null : request.getUrl();
                        final boolean isMainFrame = request != null && request.isForMainFrame();
                        // WebResourceError#getErrorCode/#getDescription 仅在 API 23+ 可用（该回调本身也是 23+）
                        final Integer errorCode;
                        final String desc;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && error != null) {
                            errorCode = error.getErrorCode();
                            desc = (error.getDescription() == null) ? null : String.valueOf(error.getDescription());
                        } else {
                            errorCode = null;
                            desc = null;
                        }
                        HBlogger.e(TAG, "onReceivedError: url=" + ((uri == null) ? "null" : uri.toString())
                                + ", mainFrame=" + isMainFrame
                                + ", errorCode=" + errorCode
                                + ", desc=" + desc);
                        HelpBotWebViewSession.getInstance().onWebViewLoadError(
                                "onReceivedError",
                                (uri == null) ? null : uri.toString(),
                                errorCode,
                                desc,
                                isMainFrame,
                                null);
                    } catch (final Exception ignored) {
                    }
                }

                @Override
                public void onReceivedHttpError(WebView view, WebResourceRequest request,
                        WebResourceResponse errorResponse) {
                    super.onReceivedHttpError(view, request, errorResponse);
                    try {
                        final Uri uri = (request == null) ? null : request.getUrl();
                        final boolean isMainFrame = request != null && request.isForMainFrame();
                        final Integer status = (errorResponse == null) ? null : errorResponse.getStatusCode();
                        final String desc = (errorResponse == null) ? null : errorResponse.getReasonPhrase();
                        // 业务无关的“常见静态资源”404（例如 favicon）不应作为错误刷屏
                        if (!isMainFrame && isIgnorableSubresourceHttpError(uri, status)) {
                            return;
                        }

                        // 仅主框架/关键错误使用 Error；子资源 4xx 通常属于可容忍退化
                        final String msg = "onReceivedHttpError: url=" + ((uri == null) ? "null" : uri.toString())
                                + ", mainFrame=" + isMainFrame
                                + ", httpStatus=" + status
                                + ", reason=" + desc;
                        if (isMainFrame) {
                            HBlogger.e(TAG, msg);
                        } else {
                            // 避免无意义的错误：降级为警告
                            HBlogger.w(TAG, msg);
                        }
                        HelpBotWebViewSession.getInstance().onWebViewLoadError(
                                "onReceivedHttpError",
                                (uri == null) ? null : uri.toString(),
                                null,
                                desc,
                                isMainFrame,
                                status);
                    } catch (final Exception ignored) {
                    }
                }

                @Override
                public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                    // SSL 错误必须拒绝继续加载（否则会被 MITM/证书问题劫持）
                    try {
                        if (handler != null) {
                            handler.cancel();
                        }
                    } catch (final Exception ignored) {
                    }
                    try {
                        final String url = (error == null) ? null : error.getUrl();
                        final int primary = (error == null) ? -1 : error.getPrimaryError();
                        HBlogger.e(TAG, "onReceivedSslError: url=" + url + ", primaryError=" + primary);
                        HelpBotWebViewSession.getInstance().onWebViewLoadError(
                                "onReceivedSslError",
                                url,
                                null,
                                "ssl_错误:" + primary,
                                true,
                                null);
                    } catch (final Exception ignored) {
                    }
                }

                @Override
                public void onReceivedHttpAuthRequest(WebView view, HttpAuthHandler handler, String host,
                        String realm) {
                    super.onReceivedHttpAuthRequest(view, handler, host, realm);
                    HBlogger.w(TAG, "onReceivedHttpAuthRequest: " + host + " / " + realm);
                }
            });

            // 加载 WebChat 首页
            webView.loadUrl(SDKUrls.WEBCHAT_INDEX);
        } catch (final Exception e) {
            HBlogger.e(TAG, "initWebView 异常", e);
        }
    }

    /**
     * 绑定 WebChromeClient（包含文件选择 + 控制台日志策略）。
     *
     * 说明：
     * - preload 场景 fileChooserHandler=null：会安全取消文件选择，避免 Web 侧卡住；
     * - attach 场景传入 handler：恢复 file input / upload 能力。
     */
    public static void bindWebChromeClient(
            @NonNull final WebView webView,
            @Nullable final FileChooserHandler fileChooserHandler) {
        try {
            webView.setWebChromeClient(new WebChromeClient() {
                @Override
                public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> filePathCallback,
                        FileChooserParams fileChooserParams) {
                    try {
                        if (fileChooserHandler == null) {
                            // 预加载/无 UI 场景：直接取消，避免卡住 Web 侧 Promise
                            filePathCallback.onReceiveValue(null);
                            return true;
                        }
                        final String[] acceptTypes = (fileChooserParams == null) ? null
                                : fileChooserParams.getAcceptTypes();
                        String acceptType = "*/*";
                        if (acceptTypes != null && acceptTypes.length > 0 && acceptTypes[0] != null
                                && !acceptTypes[0].trim().isEmpty()) {
                            acceptType = acceptTypes[0].trim().toLowerCase(Locale.ROOT);
                        }
                        final boolean allowMultiple = fileChooserParams != null
                                && fileChooserParams.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE;
                        fileChooserHandler.openFileChooser(filePathCallback, acceptType, allowMultiple);
                        return true;
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "onShowFileChooser 异常", e);
                        try {
                            filePathCallback.onReceiveValue(null);
                        } catch (final Exception ignored) {
                        }
                        return true;
                    }
                }

                @Override
                public boolean onConsoleMessage(ConsoleMessage message) {
                    try {
                        // WebSDK 日志策略：
                        // - Release 模式：完全抑制 WebSDK 控制台日志（返回 true 表示已处理，阻止系统输出）
                        // - Debug 模式：输出 WebSDK 控制台日志（便于开发调试）
                        //
                        // 关键：返回 true = 已处理消息，系统不再输出
                        // 返回 false = 未处理，系统会输出到 Logcat（chromium 标签）
                        if (!BuildConfig.DEBUG) {
                            // Release 模式：返回 true 阻止系统输出日志
                            return true;
                        }
                        // Debug 模式：输出 WebSDK 日志到 Logcat
                        WebViewConsoleLogger.log(message.messageLevel(), TAG,
                                message.message() + " -- Console(" + message.lineNumber() + "), source: "
                                        + message.sourceId());
                    } catch (final Exception ignored) {
                    }
                    // Debug 模式：返回 true 表示已处理（我们已经通过 WebViewConsoleLogger 输出了）
                    return true;
                }
            });
        } catch (final Exception e) {
            HBlogger.e(TAG, "bindWebChromeClient 异常", e);
        }
    }

    /**
     * 严格的 URL 白名单验证（仅用于主框架导航）。
     */
    private static boolean isUrlAllowed(@Nullable final Uri uri) {
        if (uri == null) {
            return false;
        }

        final String scheme = uri.getScheme();
        final String host = uri.getHost();
        final int port = uri.getPort();

        // 允许 about:blank（仅用于 WebView 销毁/清理阶段的空白页加载），防止白名单误拦截导致资源释放不彻底
        try {
            final String raw = uri.toString();
            if ("about".equalsIgnoreCase(scheme) && "about:blank".equalsIgnoreCase(raw)) {
                return true;
            }
        } catch (final Exception ignored) {
        }

        // 严格限制只允许HTTPS协议
        if (!"https".equalsIgnoreCase(scheme)) {
            return false;
        }

        // 验证域名不为空
        if (Utils.isEmpty(host)) {
            return false;
        }

        // 端口策略：允许 443 / 未显式声明端口（-1）/ 与 SDK 固定入口一致的端口。
        if (port != -1 && port != 443 && port != WEBCHAT_INDEX_PORT && port != WEBCHAT_LOADER_PORT) {
            return false;
        }

        // 域名白名单：仅允许 index/loader 所在域名（两者可能一致或不同）。
        if (!Utils.isEmpty(WEBCHAT_INDEX_HOST) && host.equalsIgnoreCase(WEBCHAT_INDEX_HOST)) {
            return true;
        }
        if (!Utils.isEmpty(WEBCHAT_LOADER_HOST) && host.equalsIgnoreCase(WEBCHAT_LOADER_HOST)) {
            return true;
        }

        // 所有白名单都不匹配,拒绝访问
        return false;
    }

    /**
     * 子资源（script/img/xhr/font 等）放行策略：
     * - 去除“子资源域名白名单”的限制（按需求：不再校验 host/port）。
     * - 仅保留协议层面的最小安全控制：允许 https + blob/data + about:blank。
     *
     * 注意：主框架导航仍由 {@link #isUrlAllowed(Uri)} 严格校验，防止顶层跳转被劫持。
     */
    private static boolean isSubresourceAllowed(@Nullable final Uri uri) {
        if (uri == null) {
            return true;
        }
        final String scheme = uri.getScheme();
        if (scheme == null) {
            return true;
        }

        // about:blank 仅用于清理阶段
        try {
            final String raw = uri.toString();
            if ("about".equalsIgnoreCase(scheme) && "about:blank".equalsIgnoreCase(raw)) {
                return true;
            }
        } catch (final Exception ignored) {
        }

        // 子资源允许 blob/data（常见于前端生成的 URL）
        if ("blob".equalsIgnoreCase(scheme) || "data".equalsIgnoreCase(scheme)) {
            return true;
        }

        // 去除子资源域名白名单：不再校验 host/port，仅要求 https
        return "https".equalsIgnoreCase(scheme);
    }

    /**
     * 统一拦截逻辑：主框架走顶层白名单；子资源走最小协议白名单。
     *
     * @return null=放行；非 null=返回拦截响应
     */
    @Nullable
    private static WebResourceResponse interceptIfBlocked(@Nullable final Uri uri, final boolean isMainFrame) {
        try {
            final boolean allowed = isMainFrame ? isUrlAllowed(uri) : isSubresourceAllowed(uri);
            return allowed ? null : buildBlockedResponse();
        } catch (final Exception ignored) {
            return null;
        }
    }

    @NonNull
    private static WebResourceResponse buildBlockedResponse() {
        try {
            final WebResourceResponse resp = new WebResourceResponse(
                    "text/plain",
                    "utf-8",
                    new ByteArrayInputStream(new byte[0]));
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                resp.setStatusCodeAndReasonPhrase(403, "Forbidden");
            }
            return resp;
        } catch (final Exception ignored) {
            return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream(new byte[0]));
        }
    }

    /**
     * 是否为可忽略的子资源 HTTP 错误（避免无意义的错误刷屏）。
     * 
     * 说明：
     * - 仅对 mainFrame=false 生效（主框架错误必须保留）
     * - 典型：favicon.ico 404 不影响 WebChat 功能
     */
    private static boolean isIgnorableSubresourceHttpError(@Nullable final Uri uri,
            @Nullable final Integer httpStatus) {
        try {
            if (httpStatus == null) {
                return false;
            }
            final int s = httpStatus.intValue();
            if (s != 404) {
                return false;
            }
            if (uri == null) {
                return false;
            }
            final String path = uri.getPath();
            if (path == null) {
                return false;
            }
            final String p = path.toLowerCase(Locale.ROOT);
            // 常见无关静态资源
            if (p.endsWith("/favicon.ico") || p.endsWith("favicon.ico")) {
                return true;
            }
            if (p.contains("apple-touch-icon")) {
                return true;
            }
            return false;
        } catch (final Exception ignored) {
            return false;
        }
    }
}
