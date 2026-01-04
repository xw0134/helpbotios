# HelpBot Unity SDK

HelpBot Unity SDK 是一个跨平台的客户支持解决方案，支持 Android 和 iOS 平台。

## 特性

- ✅ 完整的 API 对齐 Android/iOS 原生 SDK
- ✅ 异步回调机制
- ✅ 统一的错误码体系
- ✅ 事件监听系统
- ✅ 属性管理
- ✅ 跨平台支持 (Android/iOS)
- ✅ 线程安全
- ✅ 完整的中文注释

## 系统要求

- **Unity**: 2019.4 LTS 或更高版本
- **Android**: API Level 21 (Android 5.0) 或更高
- **iOS**: iOS 12.0 或更高
- **Scripting Backend**: IL2CPP 或 Mono

## 快速开始

### 1. 导入 SDK

将 `HelpBotSDK` 文件夹复制到您的 Unity 项目的 `Assets` 目录下。

### 2. 初始化 SDK

```csharp
using HelpBot;

// 创建配置
var config = new HelpBotConfig.Builder()
    .SetChannelId("your_channel_id")
    .SetDomain("https://your-domain.com")
    .Build();

// 初始化 SDK
HelpBot.HelpBot.Install(config, new MyInitCallback());
```

### 3. 用户登录

```csharp
// 使用后端生成的 JWT Token 登录
HelpBot.HelpBot.Login("your_jwt_token", null, new MyLoginCallback());
```

### 4. 显示对话窗口

```csharp
// 显示客服对话界面
HelpBot.HelpBot.ShowConversation();
```

## 核心 API

### Install

初始化 SDK（必须在使用其他 API 之前调用）

```csharp
// 方式 1: 使用 HelpBotConfig
var config = new HelpBotConfig.Builder()
    .SetChannelId("channel_id")
    .SetDomain("https://domain.com")
    .SetFullPrivacyMode(false)
    .Build();

HelpBot.HelpBot.Install(config, callback);

// 方式 2: 使用 channelId/domain/configMap
var configMap = new Dictionary<string, object>
{
    { "fullPrivacyMode", false }
};

HelpBot.HelpBot.Install("channel_id", "https://domain.com", configMap, callback);
```

### Login

用户登录认证

```csharp
// 基础登录
HelpBot.HelpBot.Login("jwt_token", null, callback);

// 带配置的登录
var loginConfig = new Dictionary<string, object>
{
    { "customKey", "customValue" }
};

HelpBot.HelpBot.Login("jwt_token", loginConfig, callback);
```

### ShowConversation

显示客服对话界面

```csharp
HelpBot.HelpBot.ShowConversation();
```

### ShowFAQs

显示 FAQ 页面

```csharp
// 基础调用
HelpBot.HelpBot.ShowFAQs();

// 带配置
var config = new Dictionary<string, object>
{
    { "tn", "custom_tn" }
};

HelpBot.HelpBot.ShowFAQs(config);
```

### Logout

用户登出

```csharp
HelpBot.HelpBot.Logout(callback);
```

### Destroy

销毁 SDK（释放资源）

```csharp
HelpBot.HelpBot.Destroy();
```

### SetEventsListener

设置事件监听器

```csharp
HelpBot.HelpBot.SetEventsListener(new MyEventsListener());
```

### UpdateMasterAttributes

更新主属性

```csharp
var attributes = new Dictionary<string, object>
{
    { "userLevel", 10 },
    { "vipStatus", "gold" }
};

HelpBot.HelpBot.UpdateMasterAttributes(attributes, callback);
```

### UpdateAppAttributes

更新应用属性

```csharp
var attributes = new Dictionary<string, object>
{
    { "appVersion", "1.0.0" },
    { "platform", "Unity" }
};

HelpBot.HelpBot.UpdateAppAttributes(attributes, callback);
```

## 回调接口

### IHelpBotInitCallback

初始化回调接口

```csharp
public class MyInitCallback : IHelpBotInitCallback
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
    }

    public void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage)
    {
        Debug.LogError($"初始化失败: [{errorCode}] {errorMessage}");
    }
}
```

### IHelpBotCallback<T>

通用回调接口

```csharp
public class MyLoginCallback : IHelpBotCallback<object>
{
    public void OnSuccess(object result)
    {
        Debug.Log("登录成功");
    }

    public void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
    {
        Debug.LogError($"登录失败: [{errorCode}] {errorMessage}");
    }
}
```

### IHelpBotEventsListener

事件监听器接口

```csharp
public class MyEventsListener : IHelpBotEventsListener
{
    public void OnEventOccurred(string eventName, string data)
    {
        Debug.Log($"事件: {eventName}, 数据: {data}");
    }

    public void OnUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason)
    {
        Debug.LogError($"认证失败: {reason}");
    }
}
```

## 错误码

SDK 使用统一的错误码体系，所有错误码定义在 `HelpBotErrorCode` 枚举中：

- **1000-1099**: 初始化相关错误
- **1100-1199**: WebView 相关错误
- **1200-1299**: 网络相关错误
- **1300-1399**: 认证相关错误
- **1400-1499**: 存储相关错误
- **1500-1599**: 权限相关错误
- **9000-9999**: 其他错误

详细错误码请参考 [API_REFERENCE.md](API_REFERENCE.md)

## 事件类型

SDK 支持多种事件类型，所有事件常量定义在 `HelpBotEvent` 类中：

- `WIDGET_TOGGLE`: Widget 切换
- `CONVERSATION_START`: 对话开始
- `AGENT_MESSAGE_RECEIVED`: 收到客服消息
- `MESSAGE_ADD`: 消息添加
- `CSAT_SUBMIT`: CSAT 提交
- `CONVERSATION_STATUS`: 对话状态
- 更多事件请参考 [API_REFERENCE.md](API_REFERENCE.md)

## 平台集成

### Android 集成

1. 将 HelpBot Android SDK AAR 放置到 `Assets/Plugins/Android` 目录
2. 确保 `HelpBotUnityBridge.java` 在正确的包路径下
3. 在 `AndroidManifest.xml` 中添加必要的权限

详细步骤请参考 [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

### iOS 集成

1. 将 HelpBot iOS SDK Framework 添加到 Xcode 项目
2. 确保 `HelpBotUnityBridge.h` 和 `HelpBotUnityBridge.mm` 在正确位置
3. 配置 Framework Search Paths

详细步骤请参考 [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

## Demo 应用

SDK 包含完整的 Demo 应用，展示所有功能的使用方法：

- Install 测试（多种配置）
- Login 测试（正常流程、错误流程）
- ShowConversation 测试
- ShowFAQs 测试
- Logout 测试
- Destroy 测试
- 事件监听测试
- 属性更新测试
- 压力测试

Demo 代码位于 `HelpBotDemo/Assets/Scripts/HelpBotDemoController.cs`

## 注意事项

1. **线程安全**: 所有 SDK API 都是线程安全的，回调会在 Unity 主线程执行
2. **生命周期**: 确保在适当的时机调用 `Destroy()` 释放资源
3. **Token 安全**: JWT Token 必须由后端生成，不要在客户端硬编码
4. **错误处理**: 始终实现回调接口并处理错误情况
5. **网络权限**: 确保应用有网络访问权限

## 常见问题

### Q: 初始化失败，提示 "SDK_NOT_INITIALIZED"
A: 请确保先调用 `Install()` 方法完成初始化，再调用其他 API。

### Q: 登录失败，提示 "INVALID_TOKEN"
A: 请检查 JWT Token 是否正确，Token 必须由后端生成。

### Q: Android 平台找不到 HelpBotUnityBridge 类
A: 请确保 `HelpBotUnityBridge.java` 的包名为 `com.example.HelpBot.unity`，并且 Android SDK AAR 已正确导入。

### Q: iOS 平台编译错误
A: 请确保 HelpBot iOS Framework 已正确添加到 Xcode 项目，并配置了 Framework Search Paths。

## 技术支持

如有问题，请联系技术支持或查看完整文档：

- [API 参考文档](API_REFERENCE.md)
- [集成指南](INTEGRATION_GUIDE.md)
- [更新日志](CHANGELOG.md)

## 许可证

Copyright © 2024 HelpBot. All rights reserved.
