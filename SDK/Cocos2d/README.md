# HelpBot Cocos2d SDK

HelpBot Cocos2d SDK 是基于 HelpBot Android/iOS SDK 的跨平台封装,为 Cocos2d-x 游戏提供客服支持功能。

## 特性

- ✅ 完整的 C++ API,与 Android SDK 功能对齐
- ✅ 支持 Android 和 iOS 平台
- ✅ 异步 API 设计,避免阻塞游戏主线程
- ✅ 统一的错误码和回调机制
- ✅ 线程安全设计
- ✅ 完整的事件监听支持
- ✅ 敏感信息自动脱敏

## 系统要求

### Android
- 最低 API 21 (Android 5.0)
- NDK r21 或更高版本
- Cocos2d-x 3.17+ 或 4.0+

### iOS
- 最低 iOS 12.0
- Xcode 12.0 或更高版本
- Cocos2d-x 3.17+ 或 4.0+

## 快速开始

### 1. 集成 SDK

#### Android 集成

1. 将 `HelpBot` 目录复制到您的 Cocos2d-x 项目中
2. 在 `proj.android/app/build.gradle` 中添加依赖:

```gradle
dependencies {
    implementation files('libs/HelpBot-release.aar')
}
```

3. 在 `proj.android/app/jni/Android.mk` 中添加:

```makefile
$(call import-add-path, $(LOCAL_PATH)/../../../HelpBot)
$(call import-module, platform/android)
```

#### iOS 集成

1. 将 `HelpBot` 目录添加到 Xcode 项目
2. 在 Build Phases → Link Binary With Libraries 中添加 `HelpBot.framework`
3. 确保 Header Search Paths 包含 `HelpBot/include`

### 2. 初始化 SDK

```cpp
#include "HelpBot.h"

using namespace helpbot;

// 创建配置
HelpBotConfig config = HelpBotConfig::Builder()
    .channelId("your_channel_id")
    .domain("https://your-domain.com")
    .fullPrivacyMode(false)
    .enableSseNotification(true)
    .build();

// 创建回调
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
        CCLOG("SDK 初始化失败: %s", errorMessage.c_str());
    }
};

// 初始化
auto callback = std::make_shared<MyInitCallback>();
HelpBot::install(config, callback.get());
```

### 3. 用户登录

```cpp
// 创建登录回调
class MyLoginCallback : public HelpBotCallback<void> {
public:
    void onSuccess() override {
        CCLOG("登录成功");
    }
    
    void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) override {
        CCLOG("登录失败: %s", errorMessage.c_str());
    }
};

// 登录
std::string token = "your_jwt_token";
auto loginCallback = std::make_shared<MyLoginCallback>();
HelpBot::login(token, nullptr, loginCallback.get());
```

### 4. 显示对话界面

```cpp
HelpBotResult<void> result = HelpBot::showConversation();
if (result.isSuccess()) {
    CCLOG("对话界面已打开");
} else {
    CCLOG("打开对话界面失败: %s", result.getErrorMessage().c_str());
}
```

## API 文档

详细 API 文档请参见 [API.md](docs/API.md)

## 示例代码

完整的示例代码请参见 `Demo` 目录。

### 运行 Demo

#### Android
```bash
cd Demo/proj.android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

#### iOS
1. 打开 `Demo/proj.ios_mac/HelpBotDemo.xcodeproj`
2. 选择目标设备
3. 点击 Run

## 常见问题

### Android 编译错误

**问题**: 找不到 HelpBot 类

**解决**: 确保 `HelpBot-release.aar` 已正确添加到 `libs` 目录,并在 `build.gradle` 中声明依赖。

### iOS 编译错误

**问题**: Undefined symbols for architecture arm64

**解决**: 确保 `HelpBotBridge.mm` 已添加到 Xcode 项目的 Compile Sources 中。

### 运行时错误

**问题**: SDK 初始化失败,提示网络不可用

**解决**: 
1. 检查设备网络连接
2. 确保 `domain` 配置正确且可访问
3. 检查 Android 清单文件中是否声明了 `INTERNET` 权限

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

## 技术支持

如有问题,请联系技术支持团队。

## 许可证

Copyright © 2026 HelpBot. All rights reserved.
