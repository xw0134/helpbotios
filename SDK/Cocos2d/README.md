# HelpBot SDK - Cocos2d-x Demo

## 概述

这是 HelpBot SDK 的 Cocos2d-x 集成示例项目，展示如何在 Cocos2d-x 游戏中集成 HelpBot 客服功能。

## 功能特性

- ✅ Android AAR 集成
- ✅ iOS Framework 集成
- ✅ C++ 桥接层
- ✅ 完整的 SDK 功能演示
- ✅ 与 Android 原生 Demo 功能一致

## 环境要求

### Android
- Android Studio 4.0+
- Android SDK API 21+
- Gradle 7.0+
- NDK r21+

### iOS
- Xcode 12.0+
- iOS 11.0+
- CocoaPods (可选)

### Cocos2d-x
- Cocos2d-x 3.17.2 或更高版本

## 项目结构

```
Cocos2d/
├── CMakeLists.txt                      # CMake 构建配置
├── proj.android/                       # Android 项目
│   ├── app/
│   │   ├── build.gradle               # Android 构建配置
│   │   ├── libs/
│   │   │   └── HelpBot-release-0.1.13.aar  # HelpBot Android SDK
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── java/com/helpbot/cocos/
│   │           └── AppActivity.java   # 主 Activity
│   ├── build.gradle
│   └── settings.gradle
├── proj.ios_mac/                      # iOS 项目
│   └── ios/
│       ├── Frameworks/
│       │   └── HelpBotSDK.framework/  # HelpBot iOS SDK
│       ├── Info.plist
│       └── main.m
├── Classes/                           # C++ 源代码
│   ├── AppDelegate.h/cpp             # 应用委托
│   ├── HelpBotBridge.h/cpp           # HelpBot 桥接层
│   └── MainScene.h/cpp               # 主场景
└── Resources/                         # 资源文件
    └── res/

```

## Android 集成步骤

### 1. 准备 AAR 文件

首先需要编译 HelpBot Android SDK：

```bash
cd ../../
./gradlew :HelpBot:assembleRelease
```

编译完成后，AAR 文件位于：
```
HelpBot/build/outputs/aar/HelpBot-release-0.1.13.aar
```

将 AAR 文件复制到：
```
SDK/Cocos2d/proj.android/app/libs/
```

### 2. 配置 Gradle

在 `proj.android/app/build.gradle` 中已配置：

```gradle
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
}
```

### 3. 配置 AndroidManifest.xml

已添加必要的权限和配置：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 4. 编译 Android 版本

```bash
cd proj.android
./gradlew assembleRelease
```

生成的 APK 位于：
```
proj.android/app/build/outputs/apk/release/app-release.apk
```

## iOS 集成步骤

### 1. 准备 Framework

iOS Framework 通过 GitHub Actions 自动编译，下载后放置到：
```
SDK/Cocos2d/proj.ios_mac/ios/Frameworks/HelpBotSDK.framework
```

或者手动编译：
```bash
cd ../../iOS
./build_local.sh
```

### 2. 配置 Xcode 项目

1. 打开 `proj.ios_mac/HelpBotCocos.xcodeproj`
2. 在 **General** → **Frameworks, Libraries, and Embedded Content** 中添加 `HelpBotSDK.framework`
3. 设置为 **Embed & Sign**

### 3. 编译 iOS 版本

```bash
xcodebuild -project proj.ios_mac/HelpBotCocos.xcodeproj \
           -scheme HelpBotCocos \
           -configuration Release \
           -sdk iphoneos \
           archive
```

## API 使用示例

### 初始化 SDK

```cpp
#include "HelpBotBridge.h"

// 在 AppDelegate::applicationDidFinishLaunching() 中初始化
bool AppDelegate::applicationDidFinishLaunching() {
    // ... Cocos2d-x 初始化代码
    
    // 初始化 HelpBot SDK
    HelpBotBridge::getInstance()->install(
        "your_channel_id",
        "https://your-domain.com",
        [](bool success, const std::string& message) {
            if (success) {
                CCLOG("HelpBot SDK 初始化成功");
            } else {
                CCLOG("HelpBot SDK 初始化失败: %s", message.c_str());
            }
        }
    );
    
    return true;
}
```

### 用户登录

```cpp
// 生成 JWT Token 后登录
std::string jwtToken = "your_jwt_token";
HelpBotBridge::getInstance()->login(
    jwtToken,
    [](bool success, const std::string& message) {
        if (success) {
            CCLOG("登录成功");
        } else {
            CCLOG("登录失败: %s", message.c_str());
        }
    }
);
```

### 显示对话界面

```cpp
// 点击按钮时显示客服对话
void MainScene::onShowConversationClicked() {
    HelpBotBridge::getInstance()->showConversation(
        [](bool success, const std::string& message) {
            if (success) {
                CCLOG("打开对话界面成功");
            } else {
                CCLOG("打开对话界面失败: %s", message.c_str());
            }
        }
    );
}
```

### 更新用户元数据

```cpp
// 更新自定义元数据
std::map<std::string, std::string> customMeta;
customMeta["user_level"] = "VIP";
customMeta["server_id"] = "30012";

HelpBotBridge::getInstance()->updateCustomMeta(customMeta);
```

### 事件监听

```cpp
// 设置事件监听器
HelpBotBridge::getInstance()->setEventListener(
    [](const std::string& eventName, const std::map<std::string, std::string>& data) {
        CCLOG("收到事件: %s", eventName.c_str());
        // 处理事件
    }
);
```

## Demo 功能

本 Demo 实现了与 Android 原生 Demo 相同的功能：

1. **SDK 初始化** - 配置 Channel ID 和 Domain
2. **生成 Token** - 通过服务器 API 生成 JWT Token
3. **用户登录** - 使用 JWT Token 登录
4. **显示对话** - 打开客服对话界面
5. **显示 FAQ** - 显示常见问题列表
6. **更新元数据** - 更新 SDK Meta 和 Custom Meta
7. **事件监听** - 监听 SDK 事件回调

## 构建脚本

### 本地构建 Android

```bash
# Windows
build_android.bat

# Linux/Mac
./build_android.sh
```

### GitHub Actions 构建 iOS

项目已配置 GitHub Actions 自动构建 iOS 版本：
- Workflow: `.github/workflows/cocos2d-build.yml`
- 触发：Push 到 main 分支或手动触发
- 产物：iOS IPA 文件

## 故障排查

### Android 编译错误

**问题**: 找不到 AAR 文件
```
Could not find HelpBot-release-0.1.13.aar
```

**解决**: 确保 AAR 文件已复制到 `proj.android/app/libs/` 目录

---

**问题**: NDK 版本不匹配
```
NDK version mismatch
```

**解决**: 在 `local.properties` 中指定正确的 NDK 路径：
```properties
ndk.dir=C\:\\Android\\sdk\\ndk\\21.4.7075529
```

### iOS 编译错误

**问题**: Framework not found
```
ld: framework not found HelpBotSDK
```

**解决**: 
1. 检查 Framework 是否在正确位置
2. 在 Xcode 中重新添加 Framework
3. 确保 Framework Search Paths 正确

---

**问题**: Code signing 错误
```
Code signing error
```

**解决**: 在 Xcode 中配置正确的开发者证书和 Provisioning Profile

## 技术支持

如有问题，请参考：
- [HelpBot SDK 需求文档](../../HelpBot_SDK_需求文档.md)
- [Android SDK 文档](../../HelpBot/README.md)
- [iOS SDK 文档](../iOS/README.md)

## 许可证

本项目遵循与 HelpBot SDK 相同的许可证。
