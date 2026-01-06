# UnrealEngine SDK 编译测试指南

本文档提供 HelpBotUE 插件在 Android 和 iOS 平台的编译测试步骤和说明。

## 目录

- [环境要求](#环境要求)
- [Android 编译测试](#android-编译测试)
- [iOS 编译测试](#ios-编译测试)
- [常见问题](#常见问题)
- [验证方法](#验证方法)

## 环境要求

### 通用要求

- **Unreal Engine**: 5.0 或更高版本
- **Git**: 用于克隆代码仓库
- **磁盘空间**: 至少 50GB 可用空间

### Android 编译环境

- **操作系统**: Windows 10/11, macOS, 或 Linux
- **Android Studio**: 最新稳定版
- **Android SDK**: API Level 33 或更高
- **Android NDK**: 25.1.8937393 (推荐)
- **JDK**: 17 或更高版本

### iOS 编译环境

- **操作系统**: macOS 13.0 或更高版本
- **Xcode**: 15.0 或更高版本
- **CocoaPods**: 1.12.0 或更高版本 (可选)
- **XcodeGen**: 用于生成 Xcode 项目 (可选)

## Android 编译测试

### 方法 1: 本地编译 (推荐)

#### 前提条件

确保已安装 Unreal Engine 5.0 并配置好 Android 开发环境。

#### 步骤

1. **打开 UE 编辑器**

   在 UE 编辑器中打开项目:
   ```bash
   # Windows
   "C:\Program Files\Epic Games\UE_5.0\Engine\Binaries\Win64\UnrealEditor.exe" "D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\SDK\UnrealEngine\Demo\HelpBotUEDemo.uproject"
   
   # macOS
   /Users/Shared/Epic\ Games/UE_5.0/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor ~/HelpBotSdkDemo/SDK/UnrealEngine/Demo/HelpBotUEDemo.uproject
   ```

2. **配置 Android 项目设置**

   在 UE 编辑器中:
   - 打开 `Edit` → `Project Settings`
   - 导航到 `Platforms` → `Android`
   - 配置以下设置:
     - **Minimum SDK Version**: 23
     - **Target SDK Version**: 33
     - **Package Name**: `com.helpbot.ue.demo`
     - **Store Version**: 1

3. **打包 Android APK**

   - 选择 `File` → `Package Project` → `Android` → `Android (ASTC)`
   - 选择输出目录
   - 等待打包完成

4. **使用命令行打包 (高级)**

   ```bash
   # Windows
   cd "C:\Program Files\Epic Games\UE_5.0\Engine\Build\BatchFiles"
   RunUAT.bat BuildCookRun ^
     -project="D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\SDK\UnrealEngine\Demo\HelpBotUEDemo.uproject" ^
     -platform=Android ^
     -clientconfig=Development ^
     -cook ^
     -stage ^
     -package ^
     -build ^
     -archive ^
     -archivedirectory="D:\xinhuo\HelpBotSdkDemo\Builds\Android"
   
   # macOS/Linux
   cd ~/Epic\ Games/UE_5.0/Engine/Build/BatchFiles
   ./RunUAT.sh BuildCookRun \
     -project="~/HelpBotSdkDemo/SDK/UnrealEngine/Demo/HelpBotUEDemo.uproject" \
     -platform=Android \
     -clientconfig=Development \
     -cook \
     -stage \
     -package \
     -build \
     -archive \
     -archivedirectory="~/HelpBotSdkDemo/Builds/Android"
   ```

### 方法 2: GitHub Actions 云端编译

#### 触发工作流

1. **手动触发**

   ```bash
   # 使用 GitHub CLI
   gh workflow run ue-android-build.yml
   ```

2. **通过 Git Push 触发**

   ```bash
   # 修改 SDK/UnrealEngine/ 下的任何文件后提交
   git add SDK/UnrealEngine/
   git commit -m "Update UnrealEngine SDK"
   git push origin main
   ```

3. **查看构建状态**

   访问 GitHub Actions 页面查看构建进度和日志。

#### 下载编译产物

构建完成后,从 GitHub Actions 页面下载:
- `ue-android-validation-report` - 配置验证报告

> [!NOTE]
> 由于 GitHub Actions 环境限制,完整的 UE 编译需要专用构建服务器。当前工作流主要用于配置验证。

## iOS 编译测试

### 方法 1: 本地编译 (推荐)

#### 前提条件

- macOS 系统
- 已安装 Unreal Engine 5.0
- 已安装 Xcode 15.0+

#### 步骤

1. **准备 iOS Framework**

   首先需要构建 HelpBot iOS Framework:

   ```bash
   cd SDK/iOS/HelpBotSDK
   
   # 安装 XcodeGen (如果未安装)
   brew install xcodegen
   
   # 生成 Xcode 项目
   xcodegen generate
   
   # 构建 Framework
   xcodebuild build \
     -project HelpBotSDK.xcodeproj \
     -scheme HelpBotSDK \
     -configuration Release \
     -sdk iphoneos \
     BUILD_LIBRARY_FOR_DISTRIBUTION=YES
   
   # 复制到 UnrealEngine ThirdParty 目录
   mkdir -p ../../UnrealEngine/HelpBotUE/ThirdParty/iOS/
   cp -R build/Release-iphoneos/HelpBot.framework \
        ../../UnrealEngine/HelpBotUE/ThirdParty/iOS/
   ```

2. **打开 UE 项目**

   ```bash
   /Users/Shared/Epic\ Games/UE_5.0/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor \
     ~/HelpBotSdkDemo/SDK/UnrealEngine/Demo/HelpBotUEDemo.uproject
   ```

3. **配置 iOS 项目设置**

   在 UE 编辑器中:
   - 打开 `Edit` → `Project Settings`
   - 导航到 `Platforms` → `iOS`
   - 配置以下设置:
     - **Minimum iOS Version**: 13.0
     - **Bundle Identifier**: `com.helpbot.ue.demo`
     - **Bundle Display Name**: `HelpBotUEDemo`

4. **打包 iOS 项目**

   - 选择 `File` → `Package Project` → `iOS`
   - 选择输出目录
   - 等待打包完成

5. **使用命令行打包 (高级)**

   ```bash
   cd ~/Epic\ Games/UE_5.0/Engine/Build/BatchFiles
   ./RunUAT.sh BuildCookRun \
     -project="~/HelpBotSdkDemo/SDK/UnrealEngine/Demo/HelpBotUEDemo.uproject" \
     -platform=iOS \
     -clientconfig=Development \
     -cook \
     -stage \
     -package \
     -build \
     -archive \
     -archivedirectory="~/HelpBotSdkDemo/Builds/iOS"
   ```

### 方法 2: GitHub Actions 云端编译

#### 触发工作流

1. **手动触发**

   ```bash
   # 使用 GitHub CLI
   gh workflow run ue-ios-build.yml
   ```

2. **通过 Git Push 触发**

   ```bash
   git add SDK/UnrealEngine/
   git commit -m "Update UnrealEngine SDK for iOS"
   git push origin main
   ```

#### 工作流说明

iOS 工作流包含两个 Job:

1. **prepare-ios-framework**: 构建或准备 iOS Framework
2. **validate-ios-config**: 验证 iOS 配置和 Framework 集成

#### 下载编译产物

构建完成后,从 GitHub Actions 页面下载:
- `helpbot-ios-framework` - iOS Framework 文件
- `ue-ios-validation-report` - 配置验证报告

## 常见问题

### Android 编译问题

#### Q1: 找不到 Android SDK/NDK

**解决方案**:
1. 在 UE 编辑器中设置 Android SDK/NDK 路径:
   - `Edit` → `Project Settings` → `Platforms` → `Android SDK`
2. 或设置环境变量:
   ```bash
   # Windows
   set ANDROID_HOME=C:\Users\YourName\AppData\Local\Android\Sdk
   set ANDROID_NDK_HOME=%ANDROID_HOME%\ndk\25.1.8937393
   
   # macOS/Linux
   export ANDROID_HOME=~/Library/Android/sdk
   export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.1.8937393
   ```

#### Q2: Gradle 构建失败

**解决方案**:
1. 检查 `HelpBotUE_APL.xml` 中的依赖版本
2. 确保 AAR 文件存在: `SDK/UnrealEngine/HelpBotUE/ThirdParty/Android/HelpBot-release.aar`
3. 清理构建缓存后重试

#### Q3: JNI 桥接错误

**解决方案**:
1. 验证 `HelpBotUEBridge.java` 的包名为 `com.helpbot.ue`
2. 检查 native 方法签名是否与 C++ 代码匹配
3. 确保 ProGuard 规则正确配置

### iOS 编译问题

#### Q4: 找不到 HelpBot.framework

**解决方案**:
1. 确保已构建 iOS Framework (参见 iOS 编译步骤 1)
2. 验证 Framework 路径: `SDK/UnrealEngine/HelpBotUE/ThirdParty/iOS/HelpBot.framework`
3. 检查 `HelpBotUE.Build.cs` 中的 Framework 配置

#### Q5: WebKit 链接错误

**解决方案**:
1. 确保 `HelpBotUE.Build.cs` 中已添加 WebKit 框架:
   ```csharp
   PublicFrameworks.AddRange(new string[]
   {
       "WebKit",
       "Foundation",
       "UIKit"
   });
   ```

#### Q6: 代码签名错误

**解决方案**:
1. 在 Xcode 中配置开发者账号和证书
2. 或在命令行构建时禁用签名 (仅用于测试):
   ```bash
   CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
   ```

## 验证方法

### Android APK 验证

1. **检查 APK 信息**

   ```bash
   # 使用 aapt 工具
   aapt dump badging HelpBotUEDemo.apk
   
   # 检查 APK 内容
   unzip -l HelpBotUEDemo.apk | grep -i helpbot
   ```

2. **安装到设备**

   ```bash
   adb install HelpBotUEDemo.apk
   ```

3. **查看日志**

   ```bash
   adb logcat | grep -i "HelpBot\|UE"
   ```

### iOS 应用验证

1. **检查 IPA 信息**

   ```bash
   # 解压 IPA
   unzip HelpBotUEDemo.ipa -d HelpBotUEDemo_extracted
   
   # 检查 Framework
   ls -la HelpBotUEDemo_extracted/Payload/HelpBotUEDemo.app/Frameworks/
   ```

2. **在模拟器中运行**

   ```bash
   # 安装到模拟器
   xcrun simctl install booted HelpBotUEDemo.app
   
   # 启动应用
   xcrun simctl launch booted com.helpbot.ue.demo
   ```

3. **查看日志**

   ```bash
   # 实时日志
   xcrun simctl spawn booted log stream --predicate 'processImagePath contains "HelpBotUEDemo"'
   ```

### 功能验证

在应用运行后,验证以下功能:

- [ ] HelpBot SDK 初始化成功
- [ ] WebView 正常加载
- [ ] JavaScript 桥接通信正常
- [ ] 事件回调正常触发
- [ ] UI 显示正常

## 技术支持

如遇到问题,请提供以下信息:

1. UE 版本
2. 目标平台 (Android/iOS)
3. 完整的错误日志
4. 编译配置 (Development/Shipping)
5. 设备/模拟器信息

## 更新日志

- **2026-01-06**: 初始版本,支持 UE 5.0 Android 和 iOS 编译
