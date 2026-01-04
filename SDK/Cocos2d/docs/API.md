# HelpBot Cocos2d SDK API 文档

## 目录

- [初始化相关](#初始化相关)
- [登录相关](#登录相关)
- [UI 相关](#ui-相关)
- [数据更新相关](#数据更新相关)
- [事件监听](#事件监听)
- [通知相关](#通知相关)
- [资源管理](#资源管理)
- [会话/状态相关](#会话状态相关)
- [错误码](#错误码)

---

## 初始化相关

### HelpBot::install

初始化 HelpBot SDK(异步)。

**签名**:
```cpp
static void install(const HelpBotConfig& config, HelpBotInitCallback* callback = nullptr);
```

**参数**:
- `config`: SDK 配置对象(必须)
- `callback`: 初始化回调(可选,建议提供)

**示例**:
```cpp
HelpBotConfig config = HelpBotConfig::Builder()
    .channelId("your_channel_id")
    .domain("https://your-domain.com")
    .fullPrivacyMode(false)
    .enableSseNotification(true)
    .initTimeout(30000)
    .webViewLoadTimeout(15000)
    .build();

class MyCallback : public HelpBotInitCallback {
    void onInitStart() override { /* ... */ }
    void onInitProgress(int progress, const std::string& message) override { /* ... */ }
    void onInitSuccess() override { /* ... */ }
    void onInitFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) override { /* ... */ }
};

auto callback = std::make_shared<MyCallback>();
HelpBot::install(config, callback.get());
```

### HelpBot::isInitialized

检查 SDK 是否已初始化。

**签名**:
```cpp
static bool isInitialized();
```

**返回值**:
- `true`: 已初始化
- `false`: 未初始化

### HelpBot::getSDKVersion

获取 SDK 版本号。

**签名**:
```cpp
static std::string getSDKVersion();
```

**返回值**: SDK 版本字符串,例如 "1.0.0"

---

## 登录相关

### HelpBot::login

用户登录(异步)。

**签名**:
```cpp
static void login(
    const std::string& identitiesJWT,
    const std::map<std::string, std::string>* loginConfig = nullptr,
    HelpBotCallback<void>* callback = nullptr
);
```

**参数**:
- `identitiesJWT`: WebSDK 预生成 Token(必须,由后端生成)
- `loginConfig`: 登录配置(可选)
- `callback`: 登录回调(可选)

**示例**:
```cpp
class LoginCallback : public HelpBotCallback<void> {
    void onSuccess() override {
        CCLOG("登录成功");
    }
    void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) override {
        CCLOG("登录失败: %s", errorMessage.c_str());
    }
};

std::string token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
auto callback = std::make_shared<LoginCallback>();
HelpBot::login(token, nullptr, callback.get());
```

### HelpBot::logout

用户登出。

**签名**:
```cpp
static HelpBotResult<void> logout();
```

**返回值**: `HelpBotResult<void>` 操作结果

---

## UI 相关

### HelpBot::showConversation

显示对话界面。

**签名**:
```cpp
static HelpBotResult<void> showConversation();
```

**返回值**: `HelpBotResult<void>` 操作结果

**示例**:
```cpp
HelpBotResult<void> result = HelpBot::showConversation();
if (result.isSuccess()) {
    CCLOG("对话界面已打开");
} else {
    CCLOG("失败: %s", result.getErrorMessage().c_str());
}
```

### HelpBot::hideConversation

隐藏对话界面。

**签名**:
```cpp
static HelpBotResult<void> hideConversation();
```

### HelpBot::isConversationVisible

检查对话界面是否可见。

**签名**:
```cpp
static bool isConversationVisible();
```

### HelpBot::showFAQs

显示 FAQ 列表。

**签名**:
```cpp
static HelpBotResult<void> showFAQs();
```

### HelpBot::showFAQSection

显示指定 FAQ 分类。

**签名**:
```cpp
static HelpBotResult<void> showFAQSection(const std::string& sectionId);
```

**参数**:
- `sectionId`: FAQ 分类 ID

### HelpBot::showSingleFAQ

显示单个 FAQ 问题。

**签名**:
```cpp
static HelpBotResult<void> showSingleFAQ(const std::string& questionId);
```

**参数**:
- `questionId`: FAQ 问题 ID

---

## 数据更新相关

### HelpBot::updateSDKMeta

更新 SDK 元数据。

**签名**:
```cpp
static HelpBotResult<void> updateSDKMeta(const std::map<std::string, std::string>& sdkMeta);
```

**参数**:
- `sdkMeta`: SDK 元数据 Map

**示例**:
```cpp
std::map<std::string, std::string> meta;
meta["app_version"] = "1.0.0";
meta["device_model"] = "iPhone 13";
HelpBot::updateSDKMeta(meta);
```

### HelpBot::updateCustomMeta

更新自定义元数据。

**签名**:
```cpp
static HelpBotResult<void> updateCustomMeta(const std::map<std::string, std::string>& customMeta);
```

### HelpBot::addIssueTags

添加问题标签。

**签名**:
```cpp
static HelpBotResult<void> addIssueTags(const std::vector<std::string>& tags);
```

**参数**:
- `tags`: 标签列表

**示例**:
```cpp
std::vector<std::string> tags = {"bug", "urgent"};
HelpBot::addIssueTags(tags);
```

### HelpBot::removeIssueTags

移除问题标签。

**签名**:
```cpp
static HelpBotResult<void> removeIssueTags(const std::vector<std::string>& tags);
```

---

## WebSDK 命令（异步返回 JSON）

> 说明：Android SDK 中这类接口的成功回调类型为 `Map<String,Object>`。为保证跨语言“数据保真”，Cocos2d 版统一以 **JSON 字符串**透传。

### HelpBot::sendMessageAsync

发送文本消息（异步）。

**签名**:
```cpp
static void sendMessageAsync(const std::string& message, HelpBotCallback<std::string>* callback = nullptr);
```

**成功回调**: `onSuccess(jsonString)`，其中 `jsonString` 为 WebSDK 返回结果的 JSON。

### HelpBot::getHistoryMessagesAsync

获取历史消息（异步）。

**签名**:
```cpp
static void getHistoryMessagesAsync(HelpBotCallback<std::string>* callback = nullptr);
```

### HelpBot::loadMoreMessagesAsync

分页加载更多历史消息（异步）。

**签名**:
```cpp
static void loadMoreMessagesAsync(int limit, int offset, HelpBotCallback<std::string>* callback = nullptr);
```

---

## 事件监听

### HelpBot::setHelpBotEventsListener

设置事件监听器。

**签名**:
```cpp
static void setHelpBotEventsListener(HelpBotEventsListener* listener);
```

**参数**:
- `listener`: 事件监听器(SDK 不持有所有权,调用方需保证生命周期)

**示例**:
```cpp
class MyEventsListener : public HelpBotEventsListener {
    void onEventOccurred(const std::string& eventName, const EventData& data) override {
        CCLOG("事件: %s", eventName.c_str());
    }
    
    void onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) override {
        CCLOG("认证失败: %d", static_cast<int>(reason));
    }
};

auto listener = std::make_shared<MyEventsListener>();
HelpBot::setHelpBotEventsListener(listener.get());
```

### HelpBot::removeHelpBotEventsListener

移除事件监听器。

**签名**:
```cpp
static void removeHelpBotEventsListener();
```

---

## 通知相关

### HelpBot::enableSseNotification

启用 SSE 通知。

**签名**:
```cpp
static void enableSseNotification();
```

### HelpBot::enableSseNotification(bool)

对齐 Android：`enableSseNotification(boolean)`。

**签名**:
```cpp
static void enableSseNotification(bool enable);
```

### HelpBot::isSseNotificationEnabled

对齐 Android：`isSseNotificationEnabled()`。

**签名**:
```cpp
static bool isSseNotificationEnabled();
```

### HelpBot::setNotificationSmallIconResId / setNotificationChannelId

用于 Android 通知展示配置。

**签名**:
```cpp
static void setNotificationSmallIconResId(int resId);
static void setNotificationChannelId(const std::string& channelId);
```

### HelpBot::disableSseNotification

禁用 SSE 通知。

**签名**:
```cpp
static void disableSseNotification();
```

### HelpBot::getUnreadCount

获取未读消息数。

**签名**:
```cpp
static int getUnreadCount();
```

**返回值**: 未读消息数量

---

## 资源管理

### HelpBot::clearWebViewData

清理 WebView 数据。

**签名**:
```cpp
static HelpBotResult<void> clearWebViewData();
```

### HelpBot::destroy

销毁 SDK(释放所有资源)。

**签名**:
```cpp
static void destroy();
```

**注意**: 销毁后需要重新 `install` 才能使用。

---

## 会话/状态相关

### HelpBot::closeSession

对齐 Android：`closeSession()`，关闭当前会话（不销毁 SDK）。

**签名**:
```cpp
static HelpBotResult<void> closeSession();
```

### HelpBot::getWebSdkHealthSnapshotJson

对齐 Android：`getWebSdkHealthSnapshot()`，返回 WebSDK 健康快照。

**签名**:
```cpp
static std::string getWebSdkHealthSnapshotJson();
```

### HelpBot::markLoginConfirmedFromWeb / getPendingLoginToken / consumePendingLoginToken

对齐 Android 的登录确认与 token 中转能力。

**签名**:
```cpp
static void markLoginConfirmedFromWeb();
static std::string getPendingLoginToken();
static std::string consumePendingLoginToken();
```

## 错误码

### HelpBotErrorCode

所有错误码定义:

| 错误码 | 值 | 说明 |
|--------|-----|------|
| SDK_NOT_INITIALIZED | 1000 | SDK 未初始化 |
| SDK_ALREADY_INITIALIZED | 1001 | SDK 已初始化 |
| INVALID_PARAMETER | 1002 | 参数无效 |
| CONTEXT_NULL | 1003 | Context 为 null |
| WEBVIEW_UNAVAILABLE | 1100 | WebView 组件不可用 |
| WEBVIEW_INIT_FAILED | 1101 | WebView 初始化失败 |
| NETWORK_UNAVAILABLE | 1200 | 网络不可用 |
| NETWORK_TIMEOUT | 1202 | 网络超时 |
| INVALID_TOKEN | 1300 | Token 无效 |
| LOGIN_FAILED | 1303 | 登录失败 |
| ALREADY_LOGGED_IN | 1306 | 已登录 |
| INTERNAL_ERROR | 9001 | 内部错误 |
| OPERATION_TIMEOUT | 9002 | 操作超时 |
| OPERATION_IN_PROGRESS | 9004 | 操作进行中 |
| OPERATION_NOT_ALLOWED | 9006 | 操作不允许 |

### HelpBotResult

操作结果封装类:

```cpp
template<typename T>
class HelpBotResult {
public:
    bool isSuccess() const;
    bool isFailure() const;
    HelpBotErrorCode getErrorCode() const;
    std::string getErrorMessage() const;
    std::shared_ptr<T> getData() const;
};
```

**示例**:
```cpp
HelpBotResult<void> result = HelpBot::showConversation();
if (result.isFailure()) {
    HelpBotErrorCode code = result.getErrorCode();
    std::string message = result.getErrorMessage();
    CCLOG("错误码: %d, 信息: %s", static_cast<int>(code), message.c_str());
}
```

---

## 配置类

### HelpBotConfig::Builder

配置构建器:

```cpp
HelpBotConfig config = HelpBotConfig::Builder()
    .channelId("your_channel_id")              // 必填
    .domain("https://your-domain.com")         // 必填,必须 https
    .fullPrivacyMode(false)                    // 可选,默认 false
    .enableSseNotification(true)               // 可选,默认 true
    .initTimeout(30000)                        // 可选,默认 30000ms
    .webViewLoadTimeout(15000)                 // 可选,默认 15000ms
    .addCustomConfig("key", "value")           // 可选,自定义配置
    .build();
```

---

## 回调接口

### HelpBotInitCallback

初始化回调接口:

```cpp
class HelpBotInitCallback {
public:
    virtual void onInitStart() = 0;
    virtual void onInitProgress(int progress, const std::string& message) = 0;
    virtual void onInitSuccess() = 0;
    virtual void onInitFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) = 0;
};
```

### HelpBotCallback<T>

通用回调接口:

```cpp
template<typename T>
class HelpBotCallback {
public:
    virtual void onSuccess(const T& result) = 0;
    virtual void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) = 0;
};
```

### HelpBotEventsListener

事件监听器接口:

```cpp
class HelpBotEventsListener {
public:
    virtual void onEventOccurred(const std::string& eventName, const EventData& data) = 0;
    virtual void onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) = 0;
};
```
