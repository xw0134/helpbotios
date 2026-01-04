# HelpBot Unity SDK 集成指南

本指南详细说明如何将 HelpBot Unity SDK 集成到您的 Unity 项目中。

## 目录

- [前置要求](#前置要求)
- [SDK 导入](#sdk-导入)
- [Android 平台集成](#android-平台集成)
- [iOS 平台集成](#ios-平台集成)
- [配置说明](#配置说明)
- [故障排查](#故障排查)

---

## 前置要求

### Unity 版本

- Unity 2019.4 LTS 或更高版本
- 推荐使用 Unity 2020.3 LTS 或 2021.3 LTS

### 平台要求

#### Android
- 最低 API Level: 21 (Android 5.0)
- 目标 API Level: 33 或更高
- Gradle 版本: 7.0+
- Android Gradle Plugin: 7.0+

#### iOS
- 最低版本: iOS 12.0
- Xcode: 13.0 或更高
- CocoaPods: 1.10.0 或更高（可选）

---

## SDK 导入

### 步骤 1: 下载 SDK

从发布页面下载最新版本的 HelpBot Unity SDK。

### 步骤 2: 导入到 Unity 项目

1. 解压下载的 SDK 包
2. 将 `HelpBotSDK` 文件夹复制到您的 Unity 项目的 `Assets` 目录下

目录结构应如下所示:

```
Assets/
├── HelpBotSDK/
│   ├── Scripts/
│   │   ├── HelpBot.cs
│   │   ├── HelpBotConfig.cs
│   │   ├── HelpBotErrorCode.cs
│   │   ├── HelpBotEvent.cs
│   │   ├── HelpBotCallbacks.cs
│   │   └── HBLogger.cs
│   ├── Plugins/
│   │   ├── Android/
│   │   │   ├── HelpBotUnityBridge.java
│   │   │   └── helpbot-android-sdk.aar
│   │   └── iOS/
│   │       ├── HelpBotUnityBridge.h
│   │       └── HelpBotUnityBridge.mm
│   └── README.md
```

### 步骤 3: 验证导入

在 Unity Editor 中，检查 `Assets/HelpBotSDK` 目录是否正确显示所有文件。

---

## Android 平台集成

### 1. 添加 Android SDK AAR

1. 将 HelpBot Android SDK AAR 文件放置到 `Assets/Plugins/Android/` 目录
2. 在 Unity Editor 中选择该 AAR 文件
3. 在 Inspector 中确保以下设置:
   - Platform: Android
   - CPU: Any CPU

### 2. 配置 AndroidManifest.xml

在 `Assets/Plugins/Android/AndroidManifest.xml` 中添加必要的权限和配置:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- 必需权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- 可选权限（用于文件上传等功能） -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application
        android:allowBackup="true"
        android:icon="@drawable/app_icon"
        android:label="@string/app_name"
        android:usesCleartextTraffic="false">

        <!-- HelpBot Activity -->
        <activity
            android:name="com.example.HelpBot.activity.HelpBotActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            android:windowSoftInputMode="adjustResize" />

    </application>
</manifest>
```

### 3. 配置 Gradle

#### mainTemplate.gradle

在 `Assets/Plugins/Android/mainTemplate.gradle` 中添加依赖:

```gradle
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
    
    // HelpBot SDK 依赖
    implementation(name: 'helpbot-android-sdk', ext: 'aar')
}
```

#### gradleTemplate.properties

在 `Assets/Plugins/Android/gradleTemplate.properties` 中添加:

```properties
android.useAndroidX=true
android.enableJetifier=true
```

### 4. ProGuard 配置

如果启用了代码混淆，在 `proguard-user.txt` 中添加:

```proguard
# HelpBot SDK
-keep class com.example.HelpBot.** { *; }
-keep interface com.example.HelpBot.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Unity Bridge
-keep class com.example.HelpBot.unity.HelpBotUnityBridge { *; }

# WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
```

### 5. 构建设置

1. 打开 `File > Build Settings`
2. 选择 `Android` 平台
3. 点击 `Player Settings`
4. 配置以下选项:
   - **Minimum API Level**: Android 5.0 (API Level 21)
   - **Target API Level**: 33 或更高
   - **Scripting Backend**: IL2CPP（推荐）或 Mono
   - **API Compatibility Level**: .NET Standard 2.1

---

## iOS 平台集成

### 1. 添加 iOS SDK Framework

有两种方式添加 iOS SDK:

#### 方式 1: 手动添加 Framework

1. 构建 Unity 项目到 iOS
2. 在 Xcode 中打开生成的项目
3. 将 `HelpBot.framework` 拖拽到项目中
4. 在 `General > Frameworks, Libraries, and Embedded Content` 中设置为 `Embed & Sign`

#### 方式 2: 使用 CocoaPods

1. 在 Unity 项目中创建 `Assets/Editor/PostProcessBuild.cs`:

```csharp
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using System.IO;

public class HelpBotPostProcessBuild
{
    [PostProcessBuild]
    public static void OnPostProcessBuild(BuildTarget buildTarget, string path)
    {
        if (buildTarget == BuildTarget.iOS)
        {
            string podfilePath = path + "/Podfile";
            string podfileContent = @"
platform :ios, '12.0'

target 'Unity-iPhone' do
  use_frameworks!
  
  pod 'HelpBot', '~> 1.0.0'
end
";
            File.WriteAllText(podfilePath, podfileContent);
        }
    }
}
```

2. 构建后在终端中运行:

```bash
cd /path/to/xcode/project
pod install
```

### 2. 配置 Info.plist

在 Xcode 项目的 `Info.plist` 中添加:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-domain.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSTemporaryExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>

<!-- 相机权限（用于上传图片） -->
<key>NSCameraUsageDescription</key>
<string>需要访问相机以上传图片</string>

<!-- 相册权限（用于上传图片） -->
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以上传图片</string>
```

### 3. 配置 Framework Search Paths

在 Xcode 项目设置中:

1. 选择 Target
2. 进入 `Build Settings`
3. 搜索 `Framework Search Paths`
4. 添加 Framework 所在路径

### 4. Unity 构建设置

1. 打开 `File > Build Settings`
2. 选择 `iOS` 平台
3. 点击 `Player Settings`
4. 配置以下选项:
   - **Target minimum iOS Version**: 12.0
   - **Architecture**: ARM64
   - **Scripting Backend**: IL2CPP
   - **API Compatibility Level**: .NET Standard 2.1

---

## 配置说明

### HelpBotConfig 参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| channelId | string | 是 | - | 频道 ID |
| domain | string | 是 | - | 域名（必须 https） |
| fullPrivacyMode | bool | 否 | false | 完全隐私模式 |
| enableSseNotification | bool | 否 | true | SSE 通知开关 |
| initTimeoutMs | int | 否 | 30000 | 初始化超时（毫秒） |
| webViewLoadTimeoutMs | int | 否 | 15000 | WebView 加载超时（毫秒） |
| useDevApi | bool | 否 | false | 是否使用开发 API |
| companyId | string | 否 | null | 公司 ID（useDevApi=true 时必填） |
| userId | string | 否 | null | 用户 ID（useDevApi=true 时必填） |
| preGeneratedToken | string | 否 | null | 预生成 Token |

### 环境配置

#### 开发环境

```csharp
var config = new HelpBotConfig.Builder()
    .SetChannelId("dev_channel_id")
    .SetDomain("https://dev.your-domain.com")
    .SetUseDevApi(true)
    .SetCompanyId("dev_company_id")
    .SetUserId("dev_user_id")
    .Build();
```

#### 生产环境

```csharp
var config = new HelpBotConfig.Builder()
    .SetChannelId("prod_channel_id")
    .SetDomain("https://your-domain.com")
    .SetUseDevApi(false)
    .Build();

// 登录时使用后端生成的 Token
HelpBot.HelpBot.Login(backendGeneratedToken, null, callback);
```

---

## 故障排查

### Android 平台

#### 问题 1: 找不到 HelpBotUnityBridge 类

**错误信息**: `java.lang.ClassNotFoundException: com.example.HelpBot.unity.HelpBotUnityBridge`

**解决方案**:
1. 检查 `HelpBotUnityBridge.java` 的包名是否为 `com.example.HelpBot.unity`
2. 确保 AAR 文件已正确导入
3. 清理并重新构建项目

#### 问题 2: WebView 初始化失败

**错误信息**: `WEBVIEW_INIT_FAILED`

**解决方案**:
1. 检查网络权限是否已添加
2. 检查设备是否安装了 WebView 组件
3. 检查域名是否可访问

#### 问题 3: ProGuard 混淆导致崩溃

**解决方案**:
确保 ProGuard 规则已正确配置，保留 HelpBot SDK 相关类。

### iOS 平台

#### 问题 1: Framework not found

**错误信息**: `ld: framework not found HelpBot`

**解决方案**:
1. 检查 Framework Search Paths 是否正确
2. 确保 Framework 已添加到项目
3. 检查 Framework 的 Embed 设置

#### 问题 2: Undefined symbols

**错误信息**: `Undefined symbols for architecture arm64`

**解决方案**:
1. 确保 Architecture 设置为 ARM64
2. 检查 Framework 是否支持当前架构
3. 清理并重新构建项目

#### 问题 3: Info.plist 权限问题

**错误信息**: 相机或相册访问被拒绝

**解决方案**:
确保 `Info.plist` 中已添加相应的权限描述。

### 通用问题

#### 问题 1: 初始化超时

**错误信息**: `OPERATION_TIMEOUT`

**解决方案**:
1. 检查网络连接
2. 增加 `initTimeoutMs` 值
3. 检查域名是否可访问

#### 问题 2: Token 无效

**错误信息**: `INVALID_TOKEN`

**解决方案**:
1. 确保 Token 由后端正确生成
2. 检查 Token 是否过期
3. 验证 Token 格式是否正确

#### 问题 3: 回调未执行

**解决方案**:
1. 确保回调对象未被垃圾回收
2. 检查是否在正确的线程调用
3. 查看日志输出

---

## 最佳实践

### 1. 错误处理

始终实现完整的回调接口并处理所有错误情况:

```csharp
public class MyInitCallback : IHelpBotInitCallback
{
    public void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage)
    {
        switch (errorCode)
        {
            case HelpBotErrorCode.NETWORK_UNAVAILABLE:
                // 提示用户检查网络
                break;
            case HelpBotErrorCode.WEBVIEW_UNAVAILABLE:
                // 提示用户更新 WebView
                break;
            default:
                // 通用错误处理
                break;
        }
    }
}
```

### 2. 生命周期管理

在适当的时机调用 `Destroy()`:

```csharp
void OnApplicationQuit()
{
    HelpBot.HelpBot.Destroy();
}
```

### 3. Token 管理

不要在客户端硬编码 Token，始终从后端获取:

```csharp
// ❌ 错误做法
string token = "hardcoded_token";

// ✅ 正确做法
StartCoroutine(GetTokenFromBackend((token) => {
    HelpBot.HelpBot.Login(token, null, callback);
}));
```

### 4. 日志管理

在生产环境中禁用调试日志:

```csharp
#if !UNITY_EDITOR && !DEVELOPMENT_BUILD
HBLogger.DebugEnabled = false;
#endif
```

---

## 技术支持

如需帮助，请联系:

- 技术支持邮箱: support@helpbot.com
- 文档: https://docs.helpbot.com
- GitHub: https://github.com/helpbot/unity-sdk

---

**最后更新**: 2024-01-04
