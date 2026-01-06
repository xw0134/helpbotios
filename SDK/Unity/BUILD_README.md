# Unity SDK 编译测试说明

## 概述

本文档说明如何使用GitHub Actions对Unity SDK进行Android和iOS平台的编译测试。

## 前提条件

### 不需要Unity许可证

所有工作流使用 **GameCI** (免费的Unity CI/CD工具),无需Unity许可证即可编译。

### GitHub Secrets配置 (可选)

如果要使用Unity许可证,可配置以下Secrets:
- `UNITY_LICENSE`: Unity许可证内容
- `UNITY_EMAIL`: Unity账号邮箱
- `UNITY_PASSWORD`: Unity账号密码

> **注意**: 使用GameCI的免费版本,这些Secrets可以留空或不配置。

## 工作流说明

### 1. Android编译 (`unity-android-build.yml`)

**功能**:
- 使用GameCI构建Unity Android APK
- 自动检查并复制Android AAR依赖
- 生成编译报告
- 上传APK和日志

**触发方式**:
```bash
# 手动触发
GitHub Actions -> Unity Android Build -> Run workflow

# 自动触发
git push (当SDK/Unity/目录有变更时)
```

**编译产物**:
- `HelpBotUnityDemo.apk` - Android应用包
- `build-report.txt` - 编译报告

### 2. iOS编译 - 手动Framework (`unity-ios-build.yml`)

**功能**:
- Unity导出iOS Xcode项目
- 从iOS SDK构建HelpBot Framework
- 使用Xcode编译iOS应用
- 支持模拟器和真机版本

**触发方式**:
```bash
# 手动触发
GitHub Actions -> Unity iOS Build -> Run workflow
```

**编译产物**:
- `Unity-iPhone.xcarchive` - iOS归档文件
- `Unity-iPhone.xcodeproj` - Xcode项目(可下载后本地签名)

### 3. iOS编译 - CocoaPods (`unity-ios-build-cocoapods.yml`)

**功能**:
- Unity导出iOS Xcode项目
- 使用CocoaPods管理依赖
- 自动创建Podfile
- 使用Xcode编译iOS应用

**优势**:
- 依赖管理更规范
- 支持第三方库集成
- 便于版本控制

**触发方式**:
```bash
# 手动触发
GitHub Actions -> Unity iOS Build (CocoaPods) -> Run workflow
```

**编译产物**:
- `Unity-iPhone.xcarchive` - iOS归档文件
- `Podfile.lock` - 依赖锁定文件

## 使用步骤

### 步骤1: 提交代码

```bash
cd d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo
git add .github/workflows/unity-*.yml
git commit -m "Add Unity compilation workflows"
git push
```

### 步骤2: 触发编译

1. 访问GitHub仓库的Actions页面
2. 选择要运行的工作流:
   - `Unity Android Build` - Android编译
   - `Unity iOS Build` - iOS编译(手动Framework)
   - `Unity iOS Build (CocoaPods)` - iOS编译(CocoaPods)
3. 点击 "Run workflow"
4. 选择编译配置 (Development/Release)
5. 点击 "Run workflow" 确认

### 步骤3: 查看编译进度

在Actions页面可以实时查看:
- 编译进度
- 各步骤日志
- 错误信息

### 步骤4: 下载编译产物

编译成功后:
1. 进入对应的workflow run页面
2. 滚动到底部 "Artifacts" 区域
3. 下载编译产物:
   - Android: `HelpBotUnityAndroid-*.zip`
   - iOS: `HelpBotUnityiOS-*.zip`

## 编译产物说明

### Android APK

```
HelpBotUnityAndroid-Development-{commit}.zip
├── HelpBotUnityDemo.apk          # Android应用包
└── build-report.txt              # 编译报告
```

**安装方式**:
```bash
# 安装到Android设备
adb install HelpBotUnityDemo.apk

# 或直接传输到设备安装
```

### iOS Archive

```
HelpBotUnityiOS-Development-{commit}.zip
├── Unity-iPhone.xcarchive/       # iOS归档
│   ├── Products/
│   └── dSYMs/
└── build-report.txt              # 编译报告
```

**使用方式**:
1. 下载并解压
2. 在macOS上打开Xcode
3. 导入xcarchive文件
4. 配置签名证书
5. 导出IPA并安装到设备

### Xcode项目

```
Unity-iOS-XcodeProject-{commit}.zip
├── Unity-iPhone.xcodeproj/       # Xcode项目
├── Unity-iPhone.xcworkspace/     # Workspace (CocoaPods)
├── Classes/                      # Unity生成的代码
├── Libraries/                    # Unity库
└── Frameworks/                   # 依赖框架
```

**使用方式**:
1. 下载并解压
2. 在macOS上用Xcode打开 `.xcworkspace` (CocoaPods) 或 `.xcodeproj`
3. 配置签名
4. 直接编译运行

## 故障排查

### Android编译失败

**问题**: AAR文件未找到
```
解决方案:
1. 检查 SDK/Unity/HelpBotSDK/Plugins/Android/helpbot-android-sdk.aar 是否存在
2. 或确保 HelpBot/build/outputs/aar/HelpBot-release.aar 存在
3. 工作流会自动复制AAR文件
```

**问题**: Unity版本不匹配
```
解决方案:
修改工作流中的 unityVersion 参数
```

### iOS编译失败

**问题**: Framework未找到
```
解决方案:
1. 检查 SDK/iOS/HelpBotSDK 是否存在
2. 确保 project.yml 配置正确
3. 工作流会自动构建Framework
```

**问题**: CocoaPods安装失败
```
解决方案:
1. 检查Podfile语法
2. 更新CocoaPods版本
3. 清除缓存重试
```

### Unity License问题

**问题**: Unity激活失败
```
解决方案:
GameCI免费版本无需许可证,如果出现许可证错误:
1. 删除工作流中的UNITY_LICENSE等环境变量
2. 或配置正确的Unity Secrets
```

## 本地测试 (可选)

如果有Unity编辑器,可以本地测试:

### Android本地编译

```bash
# 打开Unity项目
Unity.exe -projectPath "SDK/Unity/HelpBotDemo"

# 或使用命令行编译
Unity.exe -quit -batchmode \
  -projectPath "SDK/Unity/HelpBotDemo" \
  -buildTarget Android \
  -executeMethod BuildScript.BuildAndroid
```

### iOS本地编译

```bash
# 导出Xcode项目
Unity.exe -quit -batchmode \
  -projectPath "SDK/Unity/HelpBotDemo" \
  -buildTarget iOS \
  -executeMethod BuildScript.BuildiOS

# 然后在Xcode中打开并编译
```

## 下一步

1. **提交工作流**: 将创建的workflow文件提交到Git
2. **触发编译**: 在GitHub Actions中手动触发
3. **验证产物**: 下载并测试编译产物
4. **完善文档**: 根据实际编译结果更新文档

## 参考资料

- [GameCI Documentation](https://game.ci/)
- [Unity Manual - Building for Android](https://docs.unity3d.com/Manual/android-BuildProcess.html)
- [Unity Manual - Building for iOS](https://docs.unity3d.com/Manual/iphone-BuildProcess.html)
- [CocoaPods Guide](https://guides.cocoapods.org/)
