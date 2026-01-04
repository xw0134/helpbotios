import Foundation

/**
 SDK 内部写死的 WebChat 入口地址（必须写死，禁止宿主侧自定义）。

 说明：与 Android `SDKUrls` 对齐。
 */
public enum HelpBotSDKUrls {
    /// WebChat 主页面（index）
    public static let webChatIndex: String = "https://dev-bot-server.yuedongcs.com:8443/v0.1.3/index.html"

    /// WebSDK Loader（loader.js）
    public static let webChatLoaderJs: String = "https://dev-bot-server.yuedongcs.com:8443/v0.1.3/helpbot-loader.js"
}


