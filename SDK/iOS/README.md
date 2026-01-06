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

## 📦 本地开发 (需要 macOS)

### Demo 运行

Demo 采用 XcodeGen 生成工程 (避免提交巨大的 `*.pbxproj`):

#### 方式一: 使用自动脚本 (推荐)

```bash
cd SDK/iOS
chmod +x generate_project.sh
./generate_project.sh
```

脚本会自动:
- 检查 XcodeGen 是否安装
- 生成 Xcode 项目
- 提供下一步操作提示

#### 方式二: 手动生成

1. **安装 XcodeGen**
   ```bash
   brew install xcodegen
   ```

2. **生成项目**
   ```bash
   cd SDK/iOS/HelpBotDemo
   xcodegen generate
   ```

3. **打开并运行**
   ```bash
   open HelpBotDemo.xcodeproj
   ```
   
   在 Xcode 中选择模拟器或真机,点击 Run (⌘+R)

📖 **详细说明**: 查看 [XcodeGen 使用指南](XCODEGEN_GUIDE.md)

### SDK 本地编译

#### 方式一: 使用自动化脚本

```bash
cd SDK/iOS/HelpBotSDK
chmod +x ../build_local.sh
../build_local.sh
```

编译产物位于 `build/HelpBotSDK.xcframework`

#### 方式二: 手动编译

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

## 📁 项目结构

```
iOS/
├── HelpBotSDK/                    # SDK 源码 (Swift Package)
│   ├── Package.swift              # Swift Package 配置
│   └── Sources/
│       └── HelpBotSDK/
│           ├── HelpBot.swift      # 主入口
│           ├── Core/              # 核心组件
│           ├── Web/               # WebView 管理
│           ├── Bridge/            # JS 桥接
│           ├── Storage/           # 存储管理
│           ├── Log/               # 日志系统
│           └── Utils/             # 工具类
├── HelpBotDemo/                   # Demo 应用
│   ├── project.yml                # XcodeGen 配置
│   ├── Sources/                   # 源代码
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── ContentView.swift
│   │   └── HelpBotDemoViewModel.swift
│   ├── Assets.xcassets/           # 资源文件
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   ├── Supporting/
│   │   └── Info.plist
│   └── README.md                  # Demo 使用文档
├── generate_project.sh            # 项目生成脚本
├── build_local.sh                 # 本地编译脚本
├── README.md                      # 本文档
├── XCODEGEN_GUIDE.md             # XcodeGen 使用指南
├── GITHUB_ACTIONS_GUIDE.md       # GitHub Actions 指南
└── QUICKSTART.md                  # 快速开始指南
```

---

## 🔧 集成方式

### 方式一: Swift Package (推荐)

在 Xcode 中:

1. File → Add Packages… → Add Local…
2. 选择 `SDK/iOS/HelpBotSDK`
3. 在代码中导入:

```swift
import HelpBotSDK
```

### 方式二: XCFramework

1. 下载或编译 `HelpBotSDK.xcframework`
2. 拖拽到 Xcode 项目
3. Target → General → Frameworks, Libraries, and Embedded Content
4. 设置为 `Embed & Sign`

---

## 💡 使用示例

### 基本流程

```swift
import HelpBotSDK

// 1. 初始化 SDK
let configMap: [String: Any] = [
    "fullPrivacyMode": false,
    "showTitleBar": true
]

HelpBot.install(
    channelId: "your_channel_id",
    domain: "https://your-api-domain.com",
    configMap: configMap,
    callback: self
)

// 2. 用户登录
HelpBot.login("your_jwt_token") { result in
    if result.isSuccess {
        print("登录成功")
    } else {
        print("登录失败: \(result.errorMessage ?? "")")
    }
}

// 3. 显示对话窗口
HelpBot.showConversation(from: viewController)

// 4. 隐藏对话窗口
HelpBot.hideConversation()

// 5. 退出登录
HelpBot.logout { result in
    print("已退出登录")
}
```

### 事件监听

```swift
// 实现 HelpBotEventsListener
extension YourClass: HelpBotEventsListener {
    func onEventOccurred(_ eventName: String, _ data: [String: Any]?) {
        print("事件: \(eventName), 数据: \(data ?? [:])")
    }
    
    func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason) {
        print("认证失败: \(reason.rawValue)")
    }
}

// 设置监听器
HelpBot.setEventsListener(self)
```

### 初始化回调

```swift
extension YourClass: HelpBotInitCallback {
    func onInitStart() {
        print("初始化开始")
    }
    
    func onInitProgress(_ progress: Int, _ message: String) {
        print("初始化进度: \(progress)% - \(message)")
    }
    
    func onInitSuccess() {
        print("初始化成功")
    }
    
    func onInitFailure(_ errorCode: HelpBotErrorCode, _ errorMessage: String) {
        print("初始化失败: \(errorMessage)")
    }
}
```

---

## 📚 相关文档

- [HelpBotDemo 使用指南](HelpBotDemo/README.md) - Demo 应用详细说明
- [XcodeGen 使用指南](XCODEGEN_GUIDE.md) - XcodeGen 工具使用
- [GitHub Actions 编译指南](GITHUB_ACTIONS_GUIDE.md) - 云端编译详细说明
- [快速开始指南](QUICKSTART.md) - 快速上手指南
- [本地编译脚本](build_local.sh) - macOS 本地编译自动化脚本

---

## ❓ 常见问题

### Q: 如何在 Windows 上开发?

A: iOS 开发需要 macOS 环境,但您可以:
1. 使用 GitHub Actions 云端编译 SDK
2. 在 Windows 上编辑代码
3. 推送到 GitHub 触发编译
4. 下载编译产物

### Q: XcodeGen 是什么?

A: XcodeGen 是一个从 YAML 配置生成 Xcode 项目的工具,优势:
- 避免提交巨大的 `.xcodeproj` 文件
- 减少合并冲突
- 配置清晰可读

详见: [XcodeGen 使用指南](XCODEGEN_GUIDE.md)

### Q: 如何修改 Bundle ID?

A: 编辑 `HelpBotDemo/project.yml`:
```yaml
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.app
```
然后重新运行 `xcodegen generate`

### Q: 真机调试需要什么?

A: 需要设置开发团队:
1. 在 `project.yml` 中设置 `DEVELOPMENT_TEAM`
2. 或在 Xcode 中: Target → Signing & Capabilities → Team

---

## 🛠️ 技术栈

- **语言**: Swift 5.10+
- **最低支持**: iOS 12.0+
- **Demo 最低支持**: iOS 13.0+
- **依赖管理**: Swift Package Manager
- **项目生成**: XcodeGen
- **CI/CD**: GitHub Actions

---

## 📄 许可证

查看项目根目录的 LICENSE 文件

