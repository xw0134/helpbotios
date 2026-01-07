# HelpBotDemo 使用指南

## 简介

HelpBotDemo 是 HelpBot iOS SDK 的示例应用，目标是**对齐 Android Demo 的“测试台”能力**，用于验证 SDK 在不同网络、不同调用顺序、异常输入等场景下的稳定性与安全基线。

主要能力：
- SDK 初始化（install）与 WebView 预加载
- Token 生成（Demo）与登录（login）
- 打开/隐藏会话窗口（show/hideConversation）
- 事件监听与日志面板（支持复制日志/导出报告）
- 网络波动监听与 install 自动重试
- 压力回归（open/hide 循环）
- WebView 清理与安全基线扫描（只读快照）
- 负向用例（错误输入/错误顺序/重复调用）

## 功能特性

### 1. 基础参数（对齐 Android Demo）
- **channelId**：渠道标识符
- **domain(baseURL)**：API 域名（可直接填 `host[:port]`，SDK 会自动补全为 `https://`，非 https 会拒绝）
- **identity.identifier / identity.value**：用于 Token 生成接口的身份参数（Demo 用途）
- **Token 生成接口（Demo）**：例如 `https://host:port/generate_token`
- **preGeneratedToken (JWT)**：预生成的 JWT（也可通过 GenToken 自动填入）

### 2. 核心流程
- **Install**：初始化 SDK（可配置 initTimeout/webViewLoadTimeout/enableSseNotification/showTitleBar）
- **GenToken（Demo）**：调用 tokenUrl 生成 token（UI 只脱敏展示，复制才会使用原 token）
- **Login**：注入 token 并触发 WebSDK 登录（内部对齐 `HelpBot('setTokenAndConnect', token)`）
- **OpenConversation / HideConversation**：打开/隐藏会话窗口（隐藏不销毁 WebView）
- **Logout**：退出登录（不销毁 install 配置）
- **destroy 后重新安装（install-reinstall）**：验证状态复位与资源释放可靠性

### 3. 质量保障（对齐 Android Demo）
- **一键自检**：输出版本、设备信息、网络诊断、SDK 状态
- **安全基线扫描**：输出 WKWebView 配置与 Bridge 通道快照（只读，不包含 token/cookie）
- **负向用例**：覆盖未安装直接打开、空 token 登录、非 https domain install、重复 install 等

### 4. 网络与通知
- **监听网络变化**：记录网络状态变化；可开启“网络恢复后自动重试 Install”
- **启用 SSE 通知（系统通知）**：控制 WebSDK 的新消息本地通知（SDK 不主动弹窗申请权限；Demo 提供“请求通知权限”按钮）

## 运行步骤

### 前提条件
- macOS 10.15+
- Xcode 15.2+（推荐使用最新稳定版）
- XcodeGen（可选，仅当你需要重新生成 `.xcodeproj` 时使用）

### 方式一：直接打开工程（推荐）

仓库已提交 `HelpBotDemo.xcodeproj`，可直接打开运行：

```bash
cd SDK/iOS/HelpBotDemo
open HelpBotDemo.xcodeproj
```

如需真机调试：在 Xcode 里设置 `Signing & Capabilities` 的 `Team`（或修改 `project.yml` 的 `DEVELOPMENT_TEAM` 后重新生成）。

### 方式二: 使用 XcodeGen（仅在需要重生成时）

1. **安装 XcodeGen**
   ```bash
   brew install xcodegen
   ```

2. **生成项目**
   ```bash
   cd SDK/iOS/HelpBotDemo
   xcodegen generate
   ```

3. **打开项目**
   ```bash
   open HelpBotDemo.xcodeproj
   ```

4. **运行**
   - 在 Xcode 中选择目标设备(模拟器或真机)
   - 点击 Run (⌘+R)

> 说明：为满足“开箱即用”，**正常使用不需要执行任何脚本**。只有当你修改了 `project.yml` 并希望重生成工程文件时，才需要使用 XcodeGen。

## 配置说明

### 修改 Bundle ID
编辑 `project.yml`:
```yaml
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.helpbot.demo
```

### 设置开发团队 (真机调试)
编辑 `project.yml`:
```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
```

或在 Xcode 中:
1. 选择项目 → Target → Signing & Capabilities
2. 选择您的开发团队

### 修改部署目标
编辑 `project.yml`:
```yaml
options:
  deploymentTarget:
    iOS: "13.0"  # 修改为所需版本
```

## 项目结构

```
HelpBotDemo/
├── Sources/
│   ├── AppDelegate.swift          # 应用入口
│   ├── SceneDelegate.swift        # 场景管理
│   ├── ContentView.swift          # 主界面 (SwiftUI)
│   ├── HelpBotDemoViewModel.swift # 业务逻辑
│   └── UIApplication+TopVC.swift  # 工具扩展
├── Assets.xcassets/
│   ├── AppIcon.appiconset/        # 应用图标
│   └── AccentColor.colorset/      # 主题色
├── Supporting/
│   └── Info.plist                 # 应用配置
└── project.yml                    # XcodeGen 配置
```

## 使用示例

### 基本流程

```swift
// 1. 初始化 SDK
let configMap: [String: Any] = [
    "fullPrivacyMode": false,
    "showTitleBar": true,
    "enableSseNotification": true,
    "initTimeout": 30_000,
    "webViewLoadTimeout": 15_000
]
HelpBot.install(
    channelId: "demo_channel",
    domain: "https://api.example.com",
    configMap: configMap,
    callback: self
)

// 2. 登录
HelpBot.login("your_jwt_token") { result in
    if result.isSuccess {
        print("登录成功")
    }
}

// 3. 显示对话
HelpBot.showConversation(from: viewController)
```

### 事件监听

```swift
// 实现 HelpBotEventsListener
extension YourClass: HelpBotEventsListener {
    func onEventOccurred(_ eventName: String, _ data: [String: Any]?) {
        print("事件: \(eventName)")
    }
    
    func onUserAuthenticationFailure(_ reason: HelpBotAuthenticationFailureReason) {
        print("认证失败: \(reason)")
    }
}

// 设置监听器
HelpBot.setEventsListener(self)
```

## 故障排除

### 问题: XcodeGen 未安装
**解决方案:**
```bash
brew install xcodegen
```

### 问题: 项目生成失败
**可能原因:**
- `project.yml` 语法错误
- 缺少必要的文件或目录

**解决方案:**
1. 检查 `project.yml` 格式
2. 确认所有源文件存在
3. 查看 XcodeGen 错误信息

### 问题: 编译失败 - WebKit 找不到
**解决方案:**
确保 `Package.swift` 中正确链接了 WebKit:
```swift
linkerSettings: [
    .linkedFramework("WebKit")
]
```

### 问题: 真机运行失败 - 签名错误
**解决方案:**
1. 在 Xcode 中设置开发团队
2. 或修改 `project.yml` 中的 `DEVELOPMENT_TEAM`

## 测试配置

Demo 默认配置:
- **channelId / domain / tokenUrl / identity**：已预填一组测试参数（可按需替换为真实环境）
- **token**：默认为空（可手动粘贴或使用 GenToken 自动生成）

实际使用时,请替换为您的真实配置。

## 更多资源

- [iOS SDK README](../README.md)
- [XcodeGen 使用指南](../XCODEGEN_GUIDE.md)
- [GitHub Actions 编译指南](../GITHUB_ACTIONS_GUIDE.md)
- [HelpBot SDK API 文档](../HelpBotSDK/README.md)

## 技术支持

如遇问题,请:
1. 查看本文档的故障排除部分
2. 检查 Xcode 控制台日志
3. 查看 SDK 日志输出
4. 提交 Issue 到项目仓库
