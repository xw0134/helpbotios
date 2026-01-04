# HelpBot iOS SDK 审计对齐报告（对齐 Android）

> 审计目标：从 0 对 iOS SDK 做安全/稳定/规范审计，并与 Android SDK 行为尽量对齐（SDK 级别约束：**WebChat index/loader 必须写死**、WebView 封装为核心、HBlogger 统一日志、异常兜底、避免引用 `websdk/` 目录文件）。
>
> 审计范围：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/`（入口 `HelpBot.swift`、WebView/Bridge、Storage、Utils、Notification）。

---

## 1. 已确认的强约束对齐

- **WebChat index/loader 写死**：iOS `HelpBotSDKUrls.webChatIndex/webChatLoaderJs` 与 Android `SDKUrls.WEBCHAT_INDEX/WEBCHAT_LOADER_JS` 一致，且主框架导航白名单基于该常量校验。
- **禁止引用 `websdk/` 目录**：SDK 代码未通过 `file://`/bundle/asset 引用 `websdk/` 下的 JS/HTML；`websdk/websdk总结.md` 仅作为对接参考文档存在。
- **事件协议对齐**：iOS `ChatToNativeBridge` 按 `{ "EVENT_NAME": {...} }` 结构解析并透传，关键事件 `SDK_READY/SDK_ERROR/USER_AUTHENTICATION_FAILED` 行为与 Android 对齐。
- **SSE 通知对齐**：iOS 通过 `onSSEMessage` messageHandler 接收 WebSDK 消息摘要，透传 `SSE_MESSAGE` 事件，并在会话不可见且已授权时发系统通知（默认开关可控）。

---

## 2. 本次已落地的关键修复（代码已改）

### 2.1 WebView 安全对齐增强

- **禁止 JS 自动打开新窗口**（对齐 Android `setJavaScriptCanOpenWindowsAutomatically(false)`）  
  文件：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/Web/HelpBotWebViewHelper.swift`

- **禁止多窗口 / target=_blank 拦截**（对齐 Android `setSupportMultipleWindows(false)`）  
  文件：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/Web/HelpBotWebViewSession.swift`

- **TLS/证书异常显式拒绝并上报错误**（对齐 Android `onReceivedSslError -> cancel`）  
  文件：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/Web/HelpBotWebViewSession.swift`

### 2.2 对外 API 与 Android 行为对齐补齐

- **FAQ 行为对齐 Android**：iOS `showFAQs` 改为“系统浏览器打开 URL”（Android 同样如此），并新增：
  - `showFAQSection`
  - `showSingleFAQ`
- **补齐 Android 同名 API（别名/兼容）**：
  - `updateSDKMeta` / `updateCustomMeta`（内部复用 iOS 已有 `updateUserSdkMeta/updateUserMeta`）
  - `reportSystemInfoToServer`（按隐私模式最小化采集并通过 WebSDK meta 上报）
  - `closeSession`（对齐 Android：关闭 WebSDK + 销毁 WebView session，但保留 install）
  - `setNotificationSmallIconResId` / `setNotificationChannelId`（iOS 平台无对应概念，当前为 no-op 并记录警告日志）
  
  文件：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/HelpBot.swift`

### 2.3 存储安全修复

- **禁止误清空宿主 UserDefaults**：`HBPersistentStorage.clear()` 仅允许清理 SDK 自己的 suiteName 沙箱，避免误删宿主业务数据。  
  文件：`SDK/iOS/HelpBotSDK/Sources/HelpBotSDK/Storage/HBPersistentStorage.swift`

---

## 3. 当前结论（高风险项检查）

- **敏感数据落盘**：JWT token 使用 Keychain（`HBKeychainStorage`）存储；未发现 token 写入 `UserDefaults` 的路径。
- **明文 HTTP**：未发现 iOS 代码中实际使用 `http://` 发起请求/加载页面（仅存在于注释说明中）。
- **JSBridge 注入/DoS 风险**：iOS `ChatToNativeBridge` 已加入 payload 大小限制、事件名白名单、后台线程解析，降低主线程卡顿/DoS 风险。

---

## 4. 建议后续继续收敛（下一轮）

- **网络层对齐**：补齐 iOS 侧更细粒度的网络类型/运营商/在线状态采集（在隐私模式下保持最小化），并统一错误码与诊断信息对齐 Android。
- **线程/资源释放**：进一步全量扫描 iOS 的 `HelpBotWebViewSession` 与 UI 容器的生命周期，确认无循环引用、无后台线程持有 UI 对象的风险。
- **可观测性**：补齐关键路径（install/login/show/hide/destroy/closeSession）的统一日志与错误快照上报字段，保证线上可定位。


