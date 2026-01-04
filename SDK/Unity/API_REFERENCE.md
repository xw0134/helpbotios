# HelpBot Unity SDK API 参考文档

本文档详细描述了 HelpBot Unity SDK 的所有公共 API、接口和类型定义。

## 目录

- [核心类](#核心类)
- [配置类](#配置类)
- [回调接口](#回调接口)
- [错误码](#错误码)
- [事件类型](#事件类型)
- [日志系统](#日志系统)

---

## 核心类

### HelpBot

SDK 主入口类，提供所有公共 API。

#### 静态方法

##### Install

初始化 SDK（必须在使用其他 API 之前调用）

```csharp
public static void Install(HelpBotConfig config, IHelpBotInitCallback callback = null)
```

**参数**:
- `config` (HelpBotConfig): SDK 配置对象
- `callback` (IHelpBotInitCallback, 可选): 初始化回调

**示例**:
```csharp
var config = new HelpBotConfig.Builder()
    .SetChannelId("channel_id")
    .SetDomain("https://domain.com")
    .Build();

HelpBot.Install(config, new MyInitCallback());
```

---

```csharp
public static void Install(string channelId, string domain, 
    Dictionary<string, object> configMap = null, 
    IHelpBotInitCallback callback = null)
```

**参数**:
- `channelId` (string): 频道 ID
- `domain` (string): 域名（必须 https）
- `configMap` (Dictionary<string, object>, 可选): 配置参数
- `callback` (IHelpBotInitCallback, 可选): 初始化回调

**示例**:
```csharp
var configMap = new Dictionary<string, object>
{
    { "fullPrivacyMode", false }
};

HelpBot.Install("channel_id", "https://domain.com", configMap, callback);
```

---

##### Login

用户登录认证

```csharp
public static void Login(string identitiesJWT, 
    Dictionary<string, object> loginConfig = null, 
    IHelpBotCallback<object> callback = null)
```

**参数**:
- `identitiesJWT` (string): WebSDK 预生成 Token（必须）
- `loginConfig` (Dictionary<string, object>, 可选): 登录配置
- `callback` (IHelpBotCallback<object>, 可选): 登录回调

**示例**:
```csharp
HelpBot.Login("jwt_token", null, new MyLoginCallback());
```

---

##### ShowConversation

显示客服对话界面

```csharp
public static void ShowConversation()
```

**示例**:
```csharp
HelpBot.ShowConversation();
```

---

##### ShowFAQs

显示 FAQ 页面

```csharp
public static void ShowFAQs(Dictionary<string, object> configMap = null)
```

**参数**:
- `configMap` (Dictionary<string, object>, 可选): 配置参数

**示例**:
```csharp
var config = new Dictionary<string, object>
{
    { "tn", "custom_tn" }
};

HelpBot.ShowFAQs(config);
```

---

##### Logout

用户登出

```csharp
public static void Logout(IHelpBotCallback<object> callback = null)
```

**参数**:
- `callback` (IHelpBotCallback<object>, 可选): 登出回调

**示例**:
```csharp
HelpBot.Logout(new MyLogoutCallback());
```

---

##### Destroy

销毁 SDK，释放资源

```csharp
public static void Destroy()
```

**示例**:
```csharp
HelpBot.Destroy();
```

---

##### SetEventsListener

设置事件监听器

```csharp
public static void SetEventsListener(IHelpBotEventsListener listener)
```

**参数**:
- `listener` (IHelpBotEventsListener): 事件监听器（传 null 清除监听器）

**示例**:
```csharp
HelpBot.SetEventsListener(new MyEventsListener());
```

---

##### UpdateMasterAttributes

更新主属性

```csharp
public static void UpdateMasterAttributes(Dictionary<string, object> attributes, 
    IHelpBotCallback<object> callback = null)
```

**参数**:
- `attributes` (Dictionary<string, object>): 属性字典
- `callback` (IHelpBotCallback<object>, 可选): 回调

**示例**:
```csharp
var attributes = new Dictionary<string, object>
{
    { "userLevel", 10 },
    { "vipStatus", "gold" }
};

HelpBot.UpdateMasterAttributes(attributes, callback);
```

---

##### UpdateAppAttributes

更新应用属性

```csharp
public static void UpdateAppAttributes(Dictionary<string, object> attributes, 
    IHelpBotCallback<object> callback = null)
```

**参数**:
- `attributes` (Dictionary<string, object>): 属性字典
- `callback` (IHelpBotCallback<object>, 可选): 回调

**示例**:
```csharp
var attributes = new Dictionary<string, object>
{
    { "appVersion", "1.0.0" },
    { "platform", "Unity" }
};

HelpBot.UpdateAppAttributes(attributes, callback);
```

---

##### GetSDKVersion

获取 SDK 版本

```csharp
public static string GetSDKVersion()
```

**返回值**: SDK 版本字符串

**示例**:
```csharp
string version = HelpBot.GetSDKVersion();
Debug.Log($"SDK 版本: {version}");
```

---

## 配置类

### HelpBotConfig

SDK 配置类，使用 Builder 模式构建。

#### Builder 方法

##### SetChannelId

设置频道 ID（必填）

```csharp
public Builder SetChannelId(string channelId)
```

---

##### SetDomain

设置域名（必填，必须 https）

```csharp
public Builder SetDomain(string domain)
```

---

##### SetFullPrivacyMode

设置完全隐私模式（默认 false）

```csharp
public Builder SetFullPrivacyMode(bool fullPrivacyMode)
```

---

##### SetEnableSseNotification

设置是否启用 SSE 通知（默认 true）

```csharp
public Builder SetEnableSseNotification(bool enable)
```

---

##### SetInitTimeout

设置初始化超时时间（默认 30000ms）

```csharp
public Builder SetInitTimeout(int timeoutMs)
```

---

##### SetWebViewLoadTimeout

设置 WebView 加载超时时间（默认 15000ms）

```csharp
public Builder SetWebViewLoadTimeout(int timeoutMs)
```

---

##### AddCustomConfig

添加自定义配置

```csharp
public Builder AddCustomConfig(string key, object value)
```

---

##### SetUseDevApi

设置是否使用 Dev API（仅测试环境，默认 false）

```csharp
public Builder SetUseDevApi(bool useDevApi)
```

---

##### SetCompanyId

设置公司 ID（仅 useDevApi=true 时需要）

```csharp
public Builder SetCompanyId(string companyId)
```

---

##### SetUserId

设置用户 ID（仅 useDevApi=true 时需要）

```csharp
public Builder SetUserId(string userId)
```

---

##### SetPreGeneratedToken

设置预生成 Token

```csharp
public Builder SetPreGeneratedToken(string preGeneratedToken)
```

---

##### Build

构建配置对象

```csharp
public HelpBotConfig Build()
```

**返回值**: HelpBotConfig 对象

**异常**: 
- `ArgumentException`: 参数验证失败

---

## 回调接口

### IHelpBotInitCallback

初始化回调接口

#### 方法

##### OnInitStart

初始化开始

```csharp
void OnInitStart()
```

---

##### OnInitProgress

初始化进度更新

```csharp
void OnInitProgress(int progress, string message)
```

**参数**:
- `progress` (int): 进度百分比 (0-100)
- `message` (string): 当前步骤描述

---

##### OnInitSuccess

初始化成功

```csharp
void OnInitSuccess()
```

---

##### OnInitFailure

初始化失败

```csharp
void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage)
```

**参数**:
- `errorCode` (HelpBotErrorCode): 错误码
- `errorMessage` (string): 错误描述

---

### IHelpBotCallback<T>

通用回调接口

#### 方法

##### OnSuccess

操作成功

```csharp
void OnSuccess(T result)
```

**参数**:
- `result` (T): 操作结果数据（可能为 null）

---

##### OnFailure

操作失败

```csharp
void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
```

**参数**:
- `errorCode` (HelpBotErrorCode): 错误码
- `errorMessage` (string): 错误描述

---

### IHelpBotEventsListener

事件监听器接口

#### 方法

##### OnEventOccurred

事件发生

```csharp
void OnEventOccurred(string eventName, string data)
```

**参数**:
- `eventName` (string): 事件名称（参见 HelpBotEvent 常量）
- `data` (string): 事件数据（JSON 字符串）

---

##### OnUserAuthenticationFailure

用户认证失败

```csharp
void OnUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason)
```

**参数**:
- `reason` (HelpBotAuthenticationFailureReason): 失败原因

---

## 错误码

### HelpBotErrorCode

错误码枚举

#### 初始化相关错误 (1000-1099)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| SDK_NOT_INITIALIZED | 1000 | SDK 未初始化 |
| SDK_ALREADY_INITIALIZED | 1001 | SDK 已初始化 |
| INVALID_PARAMETER | 1002 | 参数无效 |
| CONTEXT_NULL | 1003 | Context 为 null |
| INVALID_CHANNEL_ID | 1004 | ChannelId 无效 |
| INVALID_DOMAIN | 1005 | Domain 无效 |

#### WebView 相关错误 (1100-1199)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| WEBVIEW_UNAVAILABLE | 1100 | WebView 组件不可用 |
| WEBVIEW_INIT_FAILED | 1101 | WebView 初始化失败 |
| WEBVIEW_LOAD_TIMEOUT | 1102 | WebView 加载超时 |
| WEBVIEW_LOAD_FAILED | 1103 | WebView 加载失败 |
| WEBVIEW_DESTROYED | 1104 | WebView 已销毁 |

#### 网络相关错误 (1200-1299)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| NETWORK_UNAVAILABLE | 1200 | 网络不可用 |
| NETWORK_REQUEST_FAILED | 1201 | 网络请求失败 |
| NETWORK_TIMEOUT | 1202 | 网络超时 |

#### 认证相关错误 (1300-1399)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| INVALID_TOKEN | 1300 | Token 无效 |
| TOKEN_EXPIRED | 1301 | Token 过期 |
| NOT_LOGGED_IN | 1302 | 未登录 |
| LOGIN_FAILED | 1303 | 登录失败 |
| MISSING_PRE_GENERATED_TOKEN | 1304 | 缺少预生成 Token |
| INVALID_PRE_GENERATED_TOKEN | 1305 | 预生成 Token 无效 |
| ALREADY_LOGGED_IN | 1306 | 已登录 |

#### 存储相关错误 (1400-1499)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| STORAGE_FAILED | 1400 | 存储失败 |
| READ_FAILED | 1401 | 读取失败 |
| ENCRYPTION_FAILED | 1402 | 加密失败 |
| DECRYPTION_FAILED | 1403 | 解密失败 |

#### 权限相关错误 (1500-1599)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| PERMISSION_DENIED | 1500 | 权限被拒绝 |
| PERMISSION_REQUIRED | 1501 | 缺少必要权限 |

#### 其他错误 (9000-9999)

| 错误码 | 值 | 描述 |
|--------|-----|------|
| UNKNOWN_ERROR | 9000 | 未知错误 |
| INTERNAL_ERROR | 9001 | 内部错误 |
| OPERATION_TIMEOUT | 9002 | 操作超时 |
| OPERATION_CANCELLED | 9003 | 操作被取消 |
| OPERATION_IN_PROGRESS | 9004 | 操作进行中 |
| NOT_SUPPORTED | 9005 | 功能暂不支持 |
| OPERATION_NOT_ALLOWED | 9006 | 当前状态不允许该操作 |

#### 扩展方法

##### GetCode

获取错误码的数值

```csharp
public static int GetCode(this HelpBotErrorCode errorCode)
```

---

##### GetMessage

获取错误描述

```csharp
public static string GetMessage(this HelpBotErrorCode errorCode)
```

---

##### FromCode

根据错误码数值获取枚举

```csharp
public static HelpBotErrorCode FromCode(int code)
```

---

## 事件类型

### HelpBotEvent

事件常量定义

#### Widget 相关

- `WIDGET_TOGGLE`: Widget 切换
- `DATA_SDK_VISIBLE`: SDK 可见性

#### 用户操作

- `ACTION_CLICKED`: 用户点击操作
- `DATA_ACTION_TYPE`: 操作类型
- `DATA_ACTION_TYPE_CALL`: 呼叫操作
- `DATA_ACTION_TYPE_LINK`: 链接操作
- `DATA_ACTION`: 操作数据

#### 对话相关

- `CONVERSATION_START`: 对话开始
- `CONVERSATION_END`: 对话结束
- `CONVERSATION_REJECTED`: 对话被拒绝
- `CONVERSATION_RESOLVED`: 对话已解决
- `CONVERSATION_REOPENED`: 对话重新打开
- `CONVERSATION_STATUS`: 对话状态

#### 消息相关

- `MESSAGE_ADD`: 消息添加
- `AGENT_MESSAGE_RECEIVED`: 收到客服消息
- `DATA_MESSAGE`: 消息数据
- `DATA_MESSAGE_TYPE`: 消息类型
- `DATA_MESSAGE_BODY`: 消息内容
- `DATA_MESSAGE_TYPE_TEXT`: 文本消息
- `DATA_MESSAGE_TYPE_ATTACHMENT`: 附件消息

#### CSAT 相关

- `CSAT_SUBMIT`: CSAT 提交
- `DATA_CSAT_RATING`: CSAT 评分
- `DATA_ADDITIONAL_FEEDBACK`: 附加反馈

#### SDK 会话

- `SDK_SESSION_STARTED`: SDK 会话开始
- `SDK_SESSION_ENDED`: SDK 会话结束

#### 未读消息

- `RECEIVED_UNREAD_MESSAGE_COUNT`: 收到未读消息计数
- `DATA_MESSAGE_COUNT`: 消息数量
- `DATA_MESSAGE_COUNT_FROM_CACHE`: 来自缓存的消息数量

#### 认证相关

- `USER_SESSION_EXPIRED`: 用户会话过期
- `IDENTITY_FEATURE_NOT_ENABLED`: 身份功能未启用
- `REFRESH_USER_CREDENTIALS`: 刷新用户凭证
- `INVALID_IDENTITY_TOKEN`: 无效的身份 Token

#### 属性验证

- `MASTER_ATTRIBUTES_VALIDATION_FAILED`: 主属性验证失败
- `MASTER_ATTRIBUTES_SYNC_FAILED`: 主属性同步失败
- `MASTER_ATTRIBUTES_LIMIT_EXCEEDED`: 主属性超限
- `APP_ATTRIBUTES_VALIDATION_FAILED`: 应用属性验证失败
- `APP_ATTRIBUTES_SYNC_FAILED`: 应用属性同步失败
- `APP_ATTRIBUTES_LIMIT_EXCEEDED`: 应用属性超限
- `IDENTITY_DATA_INVALID`: 身份数据无效
- `IDENTITY_DATA_SYNC_FAILED`: 身份数据同步失败
- `IDENTITY_DATA_LIMIT_EXCEEDED`: 身份数据超限

---

## 日志系统

### HBLogger

统一日志系统

#### 属性

##### DebugEnabled

启用或禁用调试日志

```csharp
public static bool DebugEnabled { get; set; }
```

#### 方法

##### D

调试日志

```csharp
public static void D(string tag, string message)
```

---

##### I

信息日志

```csharp
public static void I(string tag, string message)
```

---

##### W

警告日志

```csharp
public static void W(string tag, string message)
```

---

##### E

错误日志

```csharp
public static void E(string tag, string message)
public static void E(string tag, string message, Exception exception)
```

---

## 枚举类型

### HelpBotAuthenticationFailureReason

认证失败原因

| 值 | 描述 |
|----|------|
| UNKNOWN | 未知原因 |
| INVALID_AUTH_TOKEN | Token 无效 |
| AUTH_TOKEN_EXPIRED | Token 过期 |

---

## 完整示例

### 基础使用流程

```csharp
using HelpBot;
using UnityEngine;

public class HelpBotManager : MonoBehaviour
{
    private void Start()
    {
        // 1. 初始化 SDK
        var config = new HelpBotConfig.Builder()
            .SetChannelId("your_channel_id")
            .SetDomain("https://your-domain.com")
            .Build();

        HelpBot.HelpBot.Install(config, new InitCallback());
    }

    private class InitCallback : IHelpBotInitCallback
    {
        public void OnInitStart()
        {
            Debug.Log("初始化开始");
        }

        public void OnInitProgress(int progress, string message)
        {
            Debug.Log($"初始化进度: {progress}% - {message}");
        }

        public void OnInitSuccess()
        {
            Debug.Log("初始化成功");
            
            // 2. 登录
            HelpBot.HelpBot.Login("jwt_token", null, new LoginCallback());
        }

        public void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage)
        {
            Debug.LogError($"初始化失败: [{errorCode}] {errorMessage}");
        }
    }

    private class LoginCallback : IHelpBotCallback<object>
    {
        public void OnSuccess(object result)
        {
            Debug.Log("登录成功");
            
            // 3. 显示对话窗口
            HelpBot.HelpBot.ShowConversation();
        }

        public void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
        {
            Debug.LogError($"登录失败: [{errorCode}] {errorMessage}");
        }
    }

    private void OnApplicationQuit()
    {
        // 4. 销毁 SDK
        HelpBot.HelpBot.Destroy();
    }
}
```

---

**最后更新**: 2024-01-04
**SDK 版本**: 1.0.0
