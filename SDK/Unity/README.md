# HelpBot SDK - Unity Demo

## 概述

这是 HelpBot SDK 的 Unity 集成示例项目，展示如何在 Unity 游戏中集成 HelpBot 客服功能。

## 功能特性

- ✅ Android AAR 集成
- ✅ iOS Framework 集成
- ✅ C# 跨平台封装
- ✅ 完整的 SDK 功能演示
- ✅ 与 Android 原生 Demo 功能一致

## 环境要求

### Unity
- Unity 2020.3 LTS 或更高版本
- 支持 Android 和 iOS 构建模块

### Android
- Android SDK API 21+
- Gradle 7.0+

### iOS
- Xcode 12.0+
- iOS 11.0+

## 项目结构

```
Unity/
├── Assets/
│   ├── Plugins/
│   │   ├── Android/
│   │   │   ├── HelpBot-release-0.1.13.aar    # Android SDK
│   │   │   ├── AndroidManifest.xml           # Android 配置
│   │   │   └── mainTemplate.gradle           # Gradle 配置
│   │   └── iOS/
│   │       ├── HelpBotSDK.framework/         # iOS SDK
│   │       └── HelpBotBridge.mm              # iOS 桥接代码
│   ├── Scripts/
│   │   ├── HelpBotSDK.cs                     # SDK 主类
│   │   ├── HelpBotConfig.cs                  # 配置类
│   │   └── HelpBotDemoUI.cs                  # Demo UI
│   ├── Scenes/
│   │   └── HelpBotDemo.unity                 # Demo 场景
│   └── Editor/
│       └── HelpBotBuildProcessor.cs          # 构建后处理
├── ProjectSettings/
└── README.md
```

## 快速开始

### 1. 准备 SDK 文件

#### Android AAR
```bash
# 编译 HelpBot AAR
cd ../../
./gradlew :HelpBot:assembleRelease

# 复制到 Unity 项目
copy HelpBot\build\outputs\aar\HelpBot-release-0.1.13.aar SDK\Unity\Assets\Plugins\Android\
```

#### iOS Framework
从 GitHub Actions 下载或本地编译：
```bash
cd ../iOS
./build_local.sh

# 复制到 Unity 项目
cp -r HelpBotSDK/build/HelpBotSDK.framework SDK/Unity/Assets/Plugins/iOS/
```

### 2. 打开 Unity 项目

1. 启动 Unity Hub
2. 添加项目: `SDK/Unity`
3. 使用 Unity 2020.3 LTS 或更高版本打开

### 3. 配置项目

#### Android 配置
1. File → Build Settings → Android
2. Player Settings → Publishing Settings
   - Custom Main Gradle Template: ✅
   - Custom Gradle Properties File: ✅
3. 确保 `Assets/Plugins/Android/AndroidManifest.xml` 存在

#### iOS 配置
1. File → Build Settings → iOS
2. Player Settings → Other Settings
   - Target minimum iOS Version: 11.0
3. 构建后会自动链接 Framework (通过 HelpBotBuildProcessor)

## API 使用示例

### 初始化 SDK

```csharp
using HelpBot;

public class GameManager : MonoBehaviour
{
    void Start()
    {
        // 创建配置
        HelpBotConfig config = new HelpBotConfig
        {
            ChannelId = "your_channel_id",
            Domain = "https://your-domain.com",
            FullPrivacyMode = false,
            EnableSseNotification = true
        };
        
        // 初始化 SDK
        HelpBotSDK.Instance.Install(config, (success, message) =>
        {
            if (success)
            {
                Debug.Log("HelpBot SDK 初始化成功");
            }
            else
            {
                Debug.LogError($"HelpBot SDK 初始化失败: {message}");
            }
        });
    }
}
```

### 用户登录

```csharp
public void LoginToHelpBot(string jwtToken)
{
    HelpBotSDK.Instance.Login(jwtToken, (success, message) =>
    {
        if (success)
        {
            Debug.Log("登录成功");
        }
        else
        {
            Debug.LogError($"登录失败: {message}");
        }
    });
}
```

### 显示对话界面

```csharp
public void ShowCustomerService()
{
    HelpBotSDK.Instance.ShowConversation((success, message) =>
    {
        if (success)
        {
            Debug.Log("对话界面已打开");
        }
        else
        {
            Debug.LogError($"打开对话界面失败: {message}");
        }
    });
}
```

### 更新用户元数据

```csharp
public void UpdateUserInfo()
{
    // 更新自定义元数据
    var customMeta = new Dictionary<string, string>
    {
        { "user_level", "VIP" },
        { "server_id", "30012" },
        { "player_id", "123456" }
    };
    
    HelpBotSDK.Instance.UpdateCustomMeta(customMeta);
    
    // 更新 SDK 元数据
    var sdkMeta = new Dictionary<string, string>
    {
        { "app_version", Application.version },
        { "unity_version", Application.unityVersion },
        { "device_model", SystemInfo.deviceModel }
    };
    
    HelpBotSDK.Instance.UpdateSDKMeta(sdkMeta);
}
```

## 构建项目

### Android 构建

#### 方法 1: Unity 编辑器
1. File → Build Settings
2. 选择 Android 平台
3. 点击 "Build" 或 "Build And Run"

#### 方法 2: 命令行
```bash
# Windows
Unity.exe -quit -batchmode -projectPath "SDK/Unity" -buildTarget Android -executeMethod BuildScript.BuildAndroid

# macOS/Linux
/Applications/Unity/Hub/Editor/2020.3.x/Unity.app/Contents/MacOS/Unity -quit -batchmode -projectPath "SDK/Unity" -buildTarget Android -executeMethod BuildScript.BuildAndroid
```

### iOS 构建

#### 本地构建
1. File → Build Settings
2. 选择 iOS 平台
3. 点击 "Build"
4. 打开生成的 Xcode 项目
5. 在 Xcode 中编译和运行

#### GitHub Actions 构建
项目已配置自动构建，推送代码后自动触发：
- Workflow: `.github/workflows/unity-ios-build.yml`

## Demo 功能

本 Demo 实现了与 Android 原生 Demo 相同的功能：

1. **SDK 初始化** - 配置 Channel ID 和 Domain
2. **生成 Token** - 通过服务器 API 生成 JWT Token
3. **用户登录** - 使用 JWT Token 登录
4. **显示对话** - 打开客服对话界面
5. **显示 FAQ** - 显示常见问题列表
6. **更新元数据** - 更新 SDK Meta 和 Custom Meta
7. **事件监听** - 监听 SDK 事件回调

## 故障排查

### Android 问题

**问题**: 找不到 AAR 文件
```
Unable to find HelpBot-release-0.1.13.aar
```

**解决**: 
1. 确保 AAR 文件在 `Assets/Plugins/Android/` 目录
2. 重新导入 AAR: 右键 → Reimport

---

**问题**: Gradle 构建失败
```
Execution failed for task ':launcher:processReleaseManifest'
```

**解决**:
1. 检查 `AndroidManifest.xml` 配置
2. 确保 `mainTemplate.gradle` 正确配置
3. 清理项目: Edit → Preferences → External Tools → Clear Cache

### iOS 问题

**问题**: Framework not found
```
ld: framework not found HelpBotSDK
```

**解决**:
1. 确保 Framework 在 `Assets/Plugins/iOS/` 目录
2. 检查 `HelpBotBuildProcessor.cs` 是否正确执行
3. 在 Xcode 中手动添加 Framework

---

**问题**: P/Invoke 错误
```
DllNotFoundException: __Internal
```

**解决**:
1. 确保在真机或模拟器上运行（不是编辑器）
2. 检查 `HelpBotBridge.mm` 是否正确编译
3. 确保 Framework 正确链接

## 技术支持

如有问题，请参考：
- [HelpBot SDK 需求文档](../../HelpBot_SDK_需求文档.md)
- [Android SDK 文档](../../HelpBot/README.md)
- [iOS SDK 文档](../iOS/README.md)

## 许可证

本项目遵循与 HelpBot SDK 相同的许可证。
