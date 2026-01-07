## HelpBotSDK（iOS / Swift Package）

### 概述

`HelpBotSDK` 是 iOS 平台的 HelpBot SDK（Swift Package），核心能力是 **用 WKWebView 封装 WebChat**，并通过事件驱动（`HelpBotEventsListener`）把 Web 侧事件回调给宿主。

### 关键约束（SDK 级）

- **严禁引用 `websdk/` 目录文件**：SDK 仅通过网络加载 WebChat。
- **WebChat 链接必须写死**：入口由 `HelpBotSDKUrls` 固定（index/loader）。
- **安全基线**：主框架 URL 严格白名单、TLS 校验失败直接拒绝加载、Bridge 入参全程 try-catch。

### 目录结构

- `Package.swift`：Swift Package 配置（最低 iOS 12）
- `Sources/HelpBotSDK/HelpBot.swift`：SDK 主入口
- `Sources/HelpBotSDK/Web/HelpBotWebViewSession.swift`：WKWebView 生命周期/预加载/健康监控
- `Sources/HelpBotSDK/Bridge/ChatToNativeBridge.swift`：Web → Native Bridge
- `Sources/HelpBotSDK/Utils/HelpBotSDKUrls.swift`：**写死的 WebChat index/loader**

### 集成（推荐）

在 Xcode 中：

1. `File` → `Add Packages…` → `Add Local…`
2. 选择 `SDK/iOS/HelpBotSDK`
3. 代码中：

```swift
import HelpBotSDK
```

### 最小使用示例

```swift
import HelpBotSDK

// 1) install
HelpBot.install(
  channelId: "your_channel_id",
  domain: "https://your-api-domain.com",
  configMap: [
    "fullPrivacyMode": false,
    "showTitleBar": true,
    "enableSseNotification": true,
    "initTimeout": 30_000,
    "webViewLoadTimeout": 15_000
  ],
  callback: nil
)

// 2) login（注入 JWT token）
HelpBot.login("your_jwt_token") { result in
  // handle result
}
```

### 编译验证

仓库已提供 GitHub Actions 工作流：

- `build-ios-sdk.yml`：编译 SDK（输出 `HelpBotSDK.xcframework.zip`）
- `build-ios-demo.yml`：编译 Demo（验证 Demo 工程与 SDK 可在 Xcode 环境下通过编译）







