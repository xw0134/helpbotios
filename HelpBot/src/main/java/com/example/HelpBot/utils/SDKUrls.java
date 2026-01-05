package com.example.HelpBot.utils;

public class SDKUrls {

    private static final String HTTPS_PREFIX = "https://";
    public static String WEBCHAT_INDEX;
    public static String WEBCHAT_LOADER_JS;

    private SDKUrls() {
        super();
    }


    // isForChina to change the CDN
    public static void updateHosts(final String webchatHostName, final String helpCenterHostName) {
        if (!Utils.isEmpty(webchatHostName)) {
            SDKUrls.WEBCHAT_INDEX = HTTPS_PREFIX + webchatHostName + "/latest/android/webChat.js";
        }
        if (!Utils.isEmpty(helpCenterHostName)) {
            SDKUrls.WEBCHAT_INDEX = HTTPS_PREFIX + helpCenterHostName + "/android/helpCenter.js";
        }
    }


    static {
        SDKUrls.WEBCHAT_INDEX = "https://dev-bot-server.yuedongcs.com:8443/v0.1.4/index.html";
        SDKUrls.WEBCHAT_LOADER_JS = "https://dev-bot-server.yuedongcs.com:8443/v0.1.4/helpbot-loader.js";
    }
}
