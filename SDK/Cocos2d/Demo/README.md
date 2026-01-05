# HelpBot Cocos2d-x Demo

这是 HelpBot SDK 的 Cocos2d-x 演示项目,展示了如何在 Cocos2d-x 游戏中集成和使用 HelpBot 客服功能。

## 功能特性

- ✅ SDK 初始化和配置
- ✅ 用户登录和认证
- ✅ 对话界面显示
- ✅ FAQ 功能测试
- ✅ 元数据更新
- ✅ 事件监听和回调
- ✅ 完整的日志系统

## 项目结构

```
Demo/
├── Classes/                    # 共享 C++ 代码
│   ├── HelloWorldScene.h       # 主场景头文件
│   └── HelloWorldScene.cpp     # 主场景实现
├── proj.android/               # Android 项目
│   ├── app/
│   │   ├── build.gradle        # 应用构建配置
│   │   ├── jni/
│   │   │   └── CMakeLists.txt  # Native 构建配置
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── java/           # Java 代码
│   ├── build.gradle            # 根构建配置
│   └── settings.gradle         # 项目设置
└── proj.ios_mac/               # iOS 项目
    ├── project.yml             # XcodeGen 配置
    ├── Info.plist              # iOS 应用配置
    ├── AppController.h/mm      # 应用控制器
    └── main.m                  # 入口点
```

## 编译和运行

### Android

```powershell
# 进入 Android 项目目录
cd proj.android

# 编译 Debug 版本
.\gradlew.bat assembleDebug

# 安装到设备
adb install -r app\build\outputs\apk\debug\app-debug.apk

# 启动应用
adb shell am start -n com.helpbot.cocos2d.demo/.AppActivity
```

### iOS

```bash
# 进入 iOS 项目目录
cd proj.ios_mac

# 生成 Xcode 项目
xcodegen generate

# 编译模拟器版本
xcodebuild \
  -project HelpBotDemo.xcodeproj \
  -scheme HelpBotDemo \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

## 使用说明

### 1. 配置 SDK

启动应用后,在输入框中填写:
- **Channel ID**: 您的渠道 ID
- **Domain**: 您的业务域名 (必须是 HTTPS)
- **Token URL**: Token 生成服务地址

### 2. 初始化 SDK

点击 "Install SDK" 按钮,观察日志输出:
- 初始化开始
- 初始化进度 (0-100%)
- 初始化成功/失败

### 3. 生成 Token 并登录

1. 点击 "Gen Token" 生成测试 Token
2. 点击 "Login" 进行用户登录
3. 等待登录成功回调

### 4. 测试功能

- **Show Chat**: 显示对话界面
- **Test FAQ**: 测试 FAQ 功能
- **Test Meta**: 测试元数据更新

## 依赖项

### Android

- Cocos2d-x 4.0
- Android SDK API 21-34
- NDK r21e+
- CMake 3.22.1+
- HelpBot Android SDK (AAR)

### iOS

- Cocos2d-x 4.0
- iOS 12.0+
- Xcode 14.0+
- HelpBot iOS SDK

## 故障排除

### Android 编译失败

1. **NDK 未找到**: 设置 `ANDROID_NDK_HOME` 环境变量
2. **Cocos2d-x 库未找到**: 检查 CMakeLists.txt 中的路径
3. **AAR 未找到**: 确保 `../../HelpBot-release.aar` 存在

### iOS 编译失败

1. **XcodeGen 未安装**: `brew install xcodegen`
2. **头文件未找到**: 检查 project.yml 中的 HEADER_SEARCH_PATHS
3. **Framework 链接失败**: 确保所有依赖的 Framework 已添加

## 技术支持

如有问题,请查看:
- [编译测试指南](../../../compilation_guide.md)
- [API 文档](../../docs/API.md)
- [SDK README](../../README.md)

## 许可证

Copyright © 2026 HelpBot. All rights reserved.
