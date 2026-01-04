package com.example.HelpBot.utils;

/**
 * SDK 内部写死的 WebChat 入口地址（必须写死，禁止宿主侧自定义）。
 *
 * <p>注意：这些 URL 是 SDK 的协议基线，会影响：</p>
 * <ul>
 *   <li>WebView 主框架加载（index.html）</li>
 *   <li>loader.js 注入（WebSDK 入口）</li>
 *   <li>域名白名单（参见 {@code HelpBotWebViewHelper}）</li>
 * </ul>
 */
public final class SDKUrls {

    /**
     * WebChat 主页面（index）
     */
    public static final String WEBCHAT_INDEX = "https://dev-bot-server.yuedongcs.com:8443/v0.1.4/index.html";

    /**
     * WebSDK Loader（loader.js）
     */
    public static final String WEBCHAT_LOADER_JS = "https://dev-bot-server.yuedongcs.com:8443/v0.1.4/helpbot-loader.js";

    private SDKUrls() {
        throw new AssertionError("SDKUrls 不能被实例化");
    }
}
