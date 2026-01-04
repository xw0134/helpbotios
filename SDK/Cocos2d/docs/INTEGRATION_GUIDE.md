# HelpBot Cocos2d SDK 集成指南

本指南详细说明如何将 HelpBot Cocos2d SDK 集成到您的 Cocos2d-x 项目中。

## 目录

- [前置要求](#前置要求)
- [Android 集成](#android-集成)
- [iOS 集成](#ios-集成)
- [基础使用](#基础使用)
- [高级配置](#高级配置)
- [故障排查](#故障排查)

---

## 前置要求

### 开发环境

- **Cocos2d-x**: 3.17+ 或 4.0+
- **C++ 标准**: C++11 或更高

### Android
- **最低 API**: 21 (Android 5.0)
- **NDK**: r21 或更高版本
- **Gradle**: 7.0+
- **Android Studio**: 4.0+

### iOS
- **最低版本**: iOS 12.0
- **Xcode**: 12.0+
- **CocoaPods**: 1.10+ (可选)

---

## Android 集成

### 步骤 1: 添加 SDK 文件

1. 将 `HelpBot` 目录复制到您的 Cocos2d-x 项目根目录:

```
YourProject/
├── cocos2d/
├── Classes/
├── Resources/
├── HelpBot/              # 复制到这里
│   ├── include/
│   ├── src/
│   └── platform/
└── proj.android/
```

2. 将 HelpBot Android SDK AAR 文件复制到 `proj.android/app/libs/`:

```bash
cp HelpBot-release.aar proj.android/app/libs/
```

3. **拷贝 Cocos2d Java Bridge（必须）**

> 说明：C++ 侧无法直接构造 Java 的 `HelpBotInitCallback/HelpBotCallback/HelpBotEventsListener` 实例，因此需要一个极小的 Java Bridge 承载回调并回传给 native。

将以下目录复制到您的 Android 工程源码目录中：

```
HelpBot/platform/android/java/com/example/HelpBot/cocos2d/HelpBotCocos2dBridge.java
→ proj.android/app/src/main/java/com/example/HelpBot/cocos2d/HelpBotCocos2dBridge.java
```

### 步骤 2: 配置 Gradle

编辑 `proj.android/app/build.gradle`:

```gradle
android {
    // ...
    
    defaultConfig {
        // ...
        
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'
        }
    }
    
    externalNativeBuild {
        cmake {
            path "../../CMakeLists.txt"  // 或您的 CMake 路径
        }
    }
}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
    implementation files('libs/HelpBot-release.aar')
    
    // 其他依赖...
}
```

> 若您开启了 R8/ProGuard，请在混淆规则中 keep `com.example.HelpBot.cocos2d.**`，见下方 ProGuard 配置。

### 步骤 3: 配置 CMake

编辑项目的 `CMakeLists.txt`,添加 HelpBot 库:

```cmake
# 添加 HelpBot 头文件目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/HelpBot/include
)

# 添加 HelpBot 源文件
set(HELPBOT_SRC
    HelpBot/src/HBLogger.cpp
    HelpBot/src/HelpBot.cpp
    HelpBot/platform/android/HelpBotJNI.cpp
    HelpBot/platform/android/HelpBotAndroid.cpp
)

# 将 HelpBot 源文件添加到您的目标
add_library(${APP_NAME} SHARED
    ${GAME_SRC}
    ${HELPBOT_SRC}  # 添加这一行
)

# 链接必要的库
target_link_libraries(${APP_NAME}
    cocos2d
    log
    android
)
```

### 步骤 3.1: 初始化 native ClassLoader（强烈建议）

在您的 Android `Application` 或主 `Activity` 的 `onCreate` 中调用一次：

```java
com.example.HelpBot.cocos2d.HelpBotCocos2dBridge.initNativeClassLoader();
```

> 作用：解决 native 线程中 `FindClass` 可能失败的问题（ClassLoader 不一致）。

### 步骤 4: 配置 AndroidManifest.xml

编辑 `proj.android/app/src/main/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="your.package.name">

    <!-- 必需权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- Android 13+ 通知权限(可选) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:usesCleartextTraffic="false">  <!-- 安全基线:禁用明文流量 -->
        
        <!-- HelpBot Activity -->
        <activity
            android:name="com.example.HelpBot.activity.HelpBotActivity"
            android:configChanges="orientation|keyboardHidden|screenSize"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
        
        <!-- 您的主 Activity -->
        <activity
            android:name=".AppActivity"
            android:configChanges="orientation|keyboardHidden|screenSize"
            android:label="@string/app_name"
            android:screenOrientation="landscape"
            android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 步骤 5: ProGuard 配置(如果使用混淆)

编辑 `proj.android/app/proguard-rules.pro`:

```proguard
# HelpBot SDK
-keep class com.example.HelpBot.** { *; }
-keep interface com.example.HelpBot.** { *; }
-keep class com.example.HelpBot.cocos2d.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Cocos2d Bridge（native 方法）
-keepclassmembers class com.example.HelpBot.cocos2d.** {
    native <methods>;
}
```

---

## iOS 集成

### 步骤 1: 添加 SDK 文件

1. 在 Xcode 中打开您的 iOS 项目(`proj.ios_mac/YourProject.xcodeproj`)

2. 右键点击项目 → Add Files to "YourProject"

3. 选择 `HelpBot` 目录,勾选:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to targets: YourProject

### 步骤 2: 添加 HelpBot iOS SDK Framework

1. 将 `HelpBot.framework` 拖到 Xcode 项目中

2. 在 Target → General → Frameworks, Libraries, and Embedded Content 中:
   - 确保 `HelpBot.framework` 存在
   - 设置为 "Embed & Sign"

### 步骤 3: 配置 Build Settings

1. 在 Build Settings 中搜索 "Header Search Paths"

2. 添加:
   ```
   $(PROJECT_DIR)/../HelpBot/include
   ```

3. 搜索 "Other Linker Flags",添加:
   ```
   -ObjC
   ```

### 步骤 4: 配置 Info.plist

编辑 `Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 允许 HTTP 请求(仅开发环境,生产环境应使用 HTTPS) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <!-- 如果需要访问特定域名,使用 NSExceptionDomains -->
    </dict>
    
    <!-- 其他配置... -->
</dict>
</plist>
```

### 步骤 5: 编译源文件

确保以下文件已添加到 Build Phases → Compile Sources:
- `HBLogger.cpp`
- `HelpBotBridge.mm` (注意是 .mm 文件)

---

## 基础使用

### 1. 包含头文件

在您的 Cocos2d-x 场景中:

```cpp
#include "HelpBot.h"

using namespace helpbot;
```

### 2. 实现回调类

```cpp
class MyInitCallback : public HelpBotInitCallback {
public:
    void onInitStart() override {
        CCLOG("SDK 初始化开始");
    }
    
    void onInitProgress(int progress, const std::string& message) override {
        CCLOG("初始化进度: %d%% - %s", progress, message.c_str());
    }
    
    void onInitSuccess() override {
        CCLOG("SDK 初始化成功");
    }
    
    void onInitFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) override {
        CCLOG("SDK 初始化失败: [%d] %s", 
              static_cast<int>(errorCode), errorMessage.c_str());
    }
};
```

### 3. 初始化 SDK

在场景的 `init()` 方法中:

```cpp
bool HelloWorld::init() {
    if (!Scene::init()) {
        return false;
    }
    
    // 创建配置
    HelpBotConfig config = HelpBotConfig::Builder()
        .channelId("your_channel_id")
        .domain("https://your-domain.com")
        .fullPrivacyMode(false)
        .enableSseNotification(true)
        .build();
    
    // 创建回调(注意生命周期管理)
    m_initCallback = std::make_shared<MyInitCallback>();
    
    // 初始化
    HelpBot::install(config, m_initCallback.get());
    
    return true;
}
```

### 4. 用户登录

```cpp
void HelloWorld::onLoginButtonClicked() {
    std::string token = "your_jwt_token";  // 从后端获取
    
    class LoginCallback : public HelpBotCallback<void> {
    public:
        void onSuccess() override {
            CCLOG("登录成功");
        }
        void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) override {
            CCLOG("登录失败: %s", errorMessage.c_str());
        }
    };
    
    auto callback = std::make_shared<LoginCallback>();
    HelpBot::login(token, nullptr, callback.get());
}
```

### 5. 显示对话界面

```cpp
void HelloWorld::onShowConversationClicked() {
    HelpBotResult<void> result = HelpBot::showConversation();
    if (result.isFailure()) {
        CCLOG("打开对话失败: %s", result.getErrorMessage().c_str());
    }
}
```

---

## 高级配置

### 自定义配置

```cpp
HelpBotConfig config = HelpBotConfig::Builder()
    .channelId("your_channel_id")
    .domain("https://your-domain.com")
    .fullPrivacyMode(false)
    .enableSseNotification(true)
    .initTimeout(30000)              // 初始化超时 30 秒
    .webViewLoadTimeout(15000)       // WebView 加载超时 15 秒
    .addCustomConfig("showTitleBar", "true")  // 自定义配置
    .addCustomConfig("theme", "dark")
    .build();
```

### 事件监听

```cpp
class MyEventsListener : public HelpBotEventsListener {
public:
    void onEventOccurred(const std::string& eventName, const EventData& data) override {
        CCLOG("收到事件: %s", eventName.c_str());
        // 处理事件数据
    }
    
    void onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) override {
        CCLOG("认证失败: %d", static_cast<int>(reason));
        // 处理认证失败
    }
};

// 设置监听器
m_eventsListener = std::make_shared<MyEventsListener>();
HelpBot::setHelpBotEventsListener(m_eventsListener.get());
```

### 元数据更新

```cpp
// 更新 SDK 元数据
std::map<std::string, std::string> sdkMeta;
sdkMeta["app_version"] = "1.0.0";
sdkMeta["device_model"] = "iPhone 13";
HelpBot::updateSDKMeta(sdkMeta);

// 更新自定义元数据
std::map<std::string, std::string> customMeta;
customMeta["user_level"] = "VIP";
customMeta["user_id"] = "12345";
HelpBot::updateCustomMeta(customMeta);
```

---

## 故障排查

### Android 常见问题

#### 问题 1: 找不到 HelpBot 类

**错误信息**:
```
java.lang.ClassNotFoundException: com.example.HelpBot.HelpBot
```

**解决方案**:
1. 确保 `HelpBot-release.aar` 在 `proj.android/app/libs/` 目录
2. 检查 `build.gradle` 中是否正确添加依赖
3. Clean 并 Rebuild 项目

#### 问题 2: JNI 错误

**错误信息**:
```
java.lang.UnsatisfiedLinkError: No implementation found for ...
```

**解决方案**:
1. 确保 `HelpBotJNI.cpp` 已添加到 CMakeLists.txt
2. 检查 `JNI_OnLoad` 是否正确实现
3. 确认 NDK ABI 配置正确

#### 问题 3: 网络权限

**错误信息**: SDK 初始化失败,网络不可用

**解决方案**:
在 `AndroidManifest.xml` 中添加:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS 常见问题

#### 问题 1: Undefined symbols

**错误信息**:
```
Undefined symbols for architecture arm64:
  "helpbot::HelpBot::install(...)"
```

**解决方案**:
1. 确保 `HelpBotBridge.mm` 已添加到 Compile Sources
2. 检查 Header Search Paths 是否正确
3. 确认链接了必要的 Framework

#### 问题 2: Objective-C++ 编译错误

**解决方案**:
1. 确保文件扩展名是 `.mm` 而不是 `.cpp`
2. 在 Build Settings 中启用 Objective-C++

#### 问题 3: WebView 不显示

**解决方案**:
1. 检查 Info.plist 中的 NSAppTransportSecurity 配置
2. 确认 domain 使用 HTTPS
3. 检查 iOS 版本是否 >= 12.0

### 通用问题

#### 问题: SDK 初始化超时

**可能原因**:
- 网络连接问题
- domain 配置错误
- 防火墙拦截

**解决方案**:
1. 检查设备网络连接
2. 验证 domain 是否可访问
3. 增加 initTimeout 时间
4. 检查防火墙/代理设置

#### 问题: 回调未触发

**可能原因**:
- 回调对象生命周期问题
- 线程问题

**解决方案**:
1. 使用 `std::shared_ptr` 管理回调对象生命周期
2. 确保回调对象在异步操作完成前不被销毁

---

## 最佳实践

### 1. 生命周期管理

```cpp
class HelloWorld : public Scene {
private:
    // 使用智能指针管理回调对象
    std::shared_ptr<HelpBotInitCallback> m_initCallback;
    std::shared_ptr<HelpBotCallback<void>> m_loginCallback;
    std::shared_ptr<HelpBotEventsListener> m_eventsListener;
};
```

### 2. 错误处理

```cpp
HelpBotResult<void> result = HelpBot::showConversation();
if (result.isFailure()) {
    HelpBotErrorCode code = result.getErrorCode();
    std::string message = result.getErrorMessage();
    
    // 根据错误码进行不同处理
    switch (code) {
        case HelpBotErrorCode::SDK_NOT_INITIALIZED:
            // 提示用户先初始化
            break;
        case HelpBotErrorCode::NETWORK_UNAVAILABLE:
            // 提示网络问题
            break;
        default:
            // 通用错误处理
            break;
    }
}
```

### 3. 日志管理

```cpp
// 设置日志级别(生产环境建议设为 ERROR)
HBLogger::setLogLevel(LogLevel::ERROR);

// 敏感信息脱敏
std::string token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
std::string sanitized = HBLogger::sanitizeValue(token);
CCLOG("Token: %s", sanitized.c_str());  // 输出: eyJhbG***VCJ9
```

---

## 下一步

- 查看 [API 文档](API.md) 了解完整 API
- 参考 [Demo 应用](../Demo) 查看完整示例
- 阅读 [README](../README.md) 了解更多信息

如有问题,请联系技术支持团队。
