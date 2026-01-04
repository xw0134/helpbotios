package com.example.HelpBot.utils;

public class SDKUrls {

    /**
     * SDK 内部写死的 WebChat 入口地址（必须写死，禁止宿主侧自定义）。
     *
     * 说明：
     * - 该 SDK 将被封装为对外发布的 SDK，为保证安全与一致性，index/loader 必须固定。
     * - 历史版本曾提供 updateHosts(...) 用于切换 CDN，但会导致“入口可变”与白名单校验失效。
     */
    public static final String WEBCHAT_INDEX =
            "https://dev-bot-server.yuedongcs.com:8443/v0.1.3/index.html";

    /**
     * WebSDK Loader（loader.js）
     */
    public static final String WEBCHAT_LOADER_JS =
            "https://dev-bot-server.yuedongcs.com:8443/v0.1.3/helpbot-loader.js";

    // 预留：映射/缓存配置（当前未启用）
    public static final String CACHE_URLS_CONFIG = null;

    private SDKUrls() {
        super();
    }


    /**
     * 历史兼容：保留方法签名避免宿主旧代码编译失败，但该方法不再允许改写入口。
     *
     * @deprecated SDK 内 index/loader 必须写死，禁止动态切换。
     */
    @Deprecated
    public static void updateHosts(final String webchatHostName, final String helpCenterHostName) {
        // no-op
    }
}
