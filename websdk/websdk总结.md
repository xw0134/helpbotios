# websdk 总结（仅供对接参考，严禁在 Android 代码中直接引用 websdk 文件）

> 目标：帮助 Android SDK（HelpBot）对齐 Web SDK 的**命令接口**、**Native Bridge 事件协议**、**SSE 通知回调**，用于实现 WebView 封装、消息通知、元数据上报等能力。
>
> 约束：本目录 `websdk/` 下文件**仅供阅读与总结**；Android 代码中不得通过 `file://`、asset 或任何形式直接引用这些 JS/HTML。

---

## 1. 文件角色与职责

- `websdk/js/helpbot-loader.js`
  - **核心入口**：定义全局 `window.HelpBot(command, ...args)`。
  - **命令队列**：SDK 未加载时，除 `getStatus` 外的命令都会入队，待 SDK 加载后执行。
  - **UI 创建**：创建 `chatBubble`（气泡按钮，可配置隐藏）与 `chatIframe`（聊天窗口 iframe）。
  - **连接流程**：`connect` 触发 `autoInitialize()`：`getToken` → `login` → `getMyIssue` → `connectRealtime(SSE)`（按需跳过）。
  - **事件系统**：`HelpBot('on'/'off')` 注册监听；内部 `triggerEvent()` 对外派发 `ready/message/error/...`。
  - **Native 通知点**：
    - `HelpBotBridge.notifySDKReady(...)`
    - `HelpBotBridge.notifyConversationStatus(...)`
    - `HelpBotBridge.notifyWidgetToggle(true/false)`
    - 收到实时消息 `handleRealtimeMessage()` 时：
      - 客服消息：`HelpBotBridge.notifyAgentMessageReceived(...)`
      - 用户消息：`HelpBotBridge.notifyUserMessageSend(...)`
    - 错误：`HelpBotBridge.notifySDKError(...)`
    - 认证失败：`HelpBotBridge.sendUserAuthFailureEvent(error.code)`

- `websdk/js/helpbot-sdk.js`
  - **网络层**：`HttpClient`（超时、重试、拦截器）。
  - **SSE**：`SSEClient` 用 `fetch + ReadableStream` 读取 `text/event-stream` 并解析事件。
  - **SSE → Native 通知**：当收到 `message.new` 且是客服消息时，会调用 `_notifyNative('onSSEMessage', formattedText)` 把“可展示的消息摘要”推给 Native。
  - **业务接口**：`login/getMyIssue/sendMessage/uploadFile/sendFileMessage/updateUserMeta/updateUserSdkMeta/addIssueTags/removeIssueTags/getMessageHistory/connectRealtime/...`

- `websdk/js/helpbot-bridge.js`
  - **WebView → Native**：通过 `window.HelpBotNativeAndroid.*`（Android）或 iOS handler 发送事件。
    - `sendEvent(payloadStr)`：payload 为 `{ eventName: eventData }` 的 JSON 字符串
    - `sendUserAuthFailureEvent(reason)`
  - **Native → WebView**：暴露全局：
    - `window.onSSEMessage(data)`：Native 推送 SSE 消息给 Web（由 Web 内部 `HelpBot('handleSSEMessage', message)` 处理）
    - `window.onWebChatError(errorData)`：Native 推送错误给 Web（由 `HelpBot('handleNativeError', error)` 处理）

- `websdk/js/helpbot-logger.js`
  - Web 侧日志系统（等级、本地存储、可选远程上报）。Android SDK 仅需对齐“事件/命令”，不应依赖此实现。

---

## 2. Web 侧命令接口清单（Android 需要封装为 evaluateJavascript 调用）

Web 侧统一入口：`HelpBot(command, ...args)`

### 2.1 基础控制

- `init(config?)`：初始化 SDK（`HelpBotSDK` 实例），不一定立刻连接
- `connect()`：触发 `autoInitialize()` 完整连接流程
- `open()`：打开聊天窗口
- `close()`：关闭聊天窗口
- `toggle()`：切换打开/关闭
- `destroy()`：销毁 SDK 并移除 UI
- `getStatus()`：获取状态（是否加载、是否已认证、是否连接 SSE、是否有 issue 等）

### 2.2 Token/认证

- `setToken(token, autoConnect?)`：设置 token，可选自动连接
- `setTokenAndConnect(token)`：设置 token 并自动连接（Android 当前已使用此命令）

**重要规则（生产环境）**：
- 当 `useDevAPI=false`（默认生产模式）时，WebSDK 的 `getToken()` 会强制要求 `config.preGeneratedToken`，否则会抛出 `MISSING_PRE_GENERATED_TOKEN`（并通过 Bridge 发出 `SDK_ERROR` 事件）。
- 因此 Native 必须在触发 `open()`/连接流程前**先注入 token**（推荐通过 `HelpBot('setTokenAndConnect', token)` 或 `HelpBot('setToken', token, true)`）。

### 2.3 消息/文件

- `sendMessage(text)`：发送文本消息
- `uploadFile({data,name,type,size})`：上传文件（base64→File）
- `sendFileMessage({fileKey,fileName,fileSize,fileContentType})`：发送文件消息

### 2.4 Meta/Tags（SDK 侧上报与业务标签）

- `updateUserMeta(metaObj)`：更新用户 custom meta
- `updateUserSdkMeta(metaObj)`：更新 SDK meta（适合上报电量/网络/系统信息/版本等）
- `addIssueTags(stringArray)`
- `removeIssueTags(stringArray)`

### 2.5 历史/分页

- `getHistoryMessages()`：返回 `{messages, hasMore, issueId, status}`（或旧格式数组）
- `loadMoreMessages(limit, offset)`：分页拉取更早消息

### 2.6 事件订阅

- `on(eventType, callback)`
- `off(eventType, callback?)`

常见事件：
- `ready`：SDK 初始化/连接完成
- `message`：实时消息（SSE）
- `error`：错误
- `messageSent`：发送完成
- `sseConnected`：SSE 连接完成（创建新 issue 后首次连接）

### 2.7 Native 注入处理

- `handleSSEMessage(message)`：处理 Native 推送的 SSE 消息
- `handleNativeError(error)`：处理 Native 推送的错误

---

## 3. WebView → Native 事件协议（Android `@JavascriptInterface sendEvent` 需要支持）

### 3.1 调用方式

Android 侧对象名：`window.HelpBotNativeAndroid`

Web 调用：
- `window.HelpBotNativeAndroid.sendEvent(payloadStr)`

其中 `payloadStr` 是 JSON 字符串，结构为：

- `{ "EVENT_NAME": { ...eventData... } }`

### 3.2 典型事件（以 WebBridge 定义为准）

- 会话/窗口：
  - `WIDGET_TOGGLE`
  - `CONVERSATION_STATUS`
  - `CONVERSATION_START / CONVERSATION_END / CONVERSATION_RESOLVED / CONVERSATION_REOPENED`
- 消息：
  - `AGENT_MESSAGE_RECEIVED`
  - `USER_MESSAGE_SEND`
  - `MESSAGE_ADD`
  - `UNREAD_MESSAGE_COUNT`
- SDK：
  - `SDK_READY`
  - `SDK_ERROR`
- 认证：
  - `USER_AUTHENTICATION_FAILED`

Android SDK 应将这些事件透传给宿主：`HelpBotEventsListener.onEventOccurred(eventName, dataMap)`

---

## 4. SSE → Native 的“消息通知回调”（Android `onSSEMessage` 需要实现）

Web `SSEClient` 在解析到客服侧新消息后，会执行：

- `_notifyNative('onSSEMessage', formattedText)`

其中 `formattedText` 是适合通知展示的**摘要文本**（例如 `[图片]`、`[文件]`、或截断后的正文），为空则不通知。

Android SDK 建议实现：

- **显示系统通知**（前后台均可按策略控制）
- **回调给宿主**（可选）：通过 `HelpBotEventsListener` 派发一个“新消息摘要”事件

---

## 5. Android 对接要点（安全/兼容/稳定）

- WebView 侧：
  - 仅开启必要 WebSettings（JS、DOMStorage 等）
  - 严格限制 `shouldOverrideUrlLoading` 的跳转域名白名单
  - `@JavascriptInterface` 仅暴露必要方法；所有入参必须做 JSON 校验与 try-catch
- 通知侧：
  - Android 8+ 创建 NotificationChannel
  - 小图标可用宿主应用 icon 作为默认值，支持配置替换
- UI/窗口侧：
  - Web 侧 `hideBubble`/`fullscreen` 适配 WebView 场景；若要“原生气泡/窗口位置自定义”，应由 Android SDK 提供原生入口与容器。


