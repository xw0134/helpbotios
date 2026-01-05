# HelpBot iOS SDK (Swift) & Demo

## 目录说明

- `HelpBotSDK/`: iOS 版 HelpBot SDK (Swift Package),对齐 Android 版对外 API 与 WebSDK Bridge 协议。
- `HelpBotDemo/`: iOS Demo (通过 XcodeGen 生成工程),演示 install/login/展示会话/事件回调。

## 关键约束 

- 架构风格: MVC + 事件驱动; JS 通信: WKWebView + `WKScriptMessageHandler` (等价 Android `@JavascriptInterface`)。

## 🚀 快速开始: GitHub Actions 云端编译 (推荐)

**无需 macOS 环境,直接在 GitHub 上编译 iOS SDK!**

### 方式一: 手动触发编译

1. 访问 [GitHub Actions](../../actions/workflows/build-ios-sdk.yml)
2. 点击 `Run workflow` → 选择 `Release` → 点击 `Run workflow`
3. 等待 5-10 分钟编译完成
4. 下载 `Artifacts` 中的 `HelpBotSDK-Release-XXXXXXX.zip`

### 方式二: 推送代码自动编译

修改 `SDK/iOS/HelpBotSDK/**` 下的文件并推送到 `main` 或 `develop` 分支,会自动触发编译。

📖 **详细说明**: 查看 [GitHub Actions 编译指南](GITHUB_ACTIONS_GUIDE.md)

---

## 📦 本地编译 (需要 macOS)

### 方式一: 使用自动化脚本

```bash
cd SDK/iOS/HelpBotSDK
chmod +x ../build_local.sh
../build_local.sh
```

编译产物位于 `build/HelpBotSDK.xcframework`

### 方式二: 手动编译

```bash
# 1. 编译 iOS 真机
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS" \
  -archivePath "build/ios.xcarchive" \
  -configuration Release \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 2. 编译 iOS 模拟器
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "build/ios-simulator.xcarchive" \
  -configuration Release \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 3. 创建 XCFramework
xcodebuild -create-xcframework \
  -framework "build/ios.xcarchive/Products/Library/Frameworks/HelpBotSDK.framework" \
  -framework "build/ios-simulator.xcarchive/Products/Library/Frameworks/HelpBotSDK.framework" \
  -output "build/HelpBotSDK.xcframework"
```

---

## 集成 (推荐: Swift Package)

在 Xcode 中:

- File → Add Packages… → Add Local…
- 选择 `SDK/iOS/HelpBotSDK`

然后在代码里:

```swift
import HelpBotSDK
```

## Demo 运行

Demo 采用 XcodeGen 生成工程 (避免提交巨大的 `*.pbxproj`):

1. 安装 XcodeGen: `brew install xcodegen`
2. 进入 `SDK/iOS/HelpBotDemo`
3. 运行 `xcodegen generate`
4. 打开生成的 `HelpBotDemo.xcodeproj`,选择真机/模拟器运行

---

## 📚 相关文档

- [GitHub Actions 编译指南](GITHUB_ACTIONS_GUIDE.md) - 云端编译详细说明
- [本地编译脚本](build_local.sh) - macOS 本地编译自动化脚本
- [API 文档](HelpBotSDK/README.md) - SDK API 使用说明
