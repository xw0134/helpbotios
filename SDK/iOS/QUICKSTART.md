# iOS SDK 编译快速开始

## ✅ 已完成配置

您的 iOS SDK 已配置好 **GitHub Actions 云端编译**,无需 macOS 环境即可编译!

## 🚀 立即开始编译

### 步骤 1: 推送代码到 GitHub

```bash
cd d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo

# 添加所有文件
git add .

# 提交更改
git commit -m "配置 iOS SDK GitHub Actions 编译"

# 推送到远程仓库 (假设远程分支是 main)
git push origin main
```

### 步骤 2: 触发编译

**方式 A: 自动触发** (推荐)
- 推送代码后会自动触发编译
- 访问 `https://github.com/YOUR_USERNAME/YOUR_REPO/actions` 查看进度

**方式 B: 手动触发**
1. 访问 `https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build-ios-sdk.yml`
2. 点击右侧 `Run workflow` 按钮
3. 选择 `Release` 配置
4. 点击绿色的 `Run workflow` 按钮

### 步骤 3: 下载编译产物

1. 等待编译完成 (约 5-10 分钟)
2. 在 Actions 页面找到成功的工作流运行
3. 滚动到底部的 `Artifacts` 区域
4. 下载 `HelpBotSDK-Release-XXXXXXX.zip`

### 步骤 4: 使用编译产物

```bash
# 解压下载的文件
unzip HelpBotSDK-Release-XXXXXXX.zip

# 解压 XCFramework
unzip HelpBotSDK.xcframework.zip

# 现在可以将 HelpBotSDK.xcframework 集成到您的 iOS 项目中
```

## 📦 编译产物说明

下载的压缩包包含:

1. **HelpBotSDK.xcframework.zip** - iOS SDK Framework
   - 支持 iOS 真机 (arm64)
   - 支持 iOS 模拟器 (x86_64, arm64)
   - 最低支持 iOS 12.0+

2. **build-report.txt** - 编译报告
   - 编译环境信息
   - 架构详情
   - 文件大小统计

## 🔧 集成到项目

### Xcode 集成

1. 打开您的 Xcode 项目
2. 将 `HelpBotSDK.xcframework` 拖拽到项目导航器
3. 勾选 `Copy items if needed`
4. 在 Target → General → Frameworks, Libraries, and Embedded Content
5. 确认 `HelpBotSDK.xcframework` 设置为 `Embed & Sign`

### 代码使用

```swift
import HelpBotSDK

// 初始化配置
let config = HelpBotConfig(
    appId: "your_app_id",
    appKey: "your_app_key"
)

// 安装 SDK
HelpBot.install(config: config) { result in
    switch result {
    case .success:
        print("SDK 安装成功")
    case .failure(let error):
        print("SDK 安装失败: \(error)")
    }
}

// 用户登录
HelpBot.login(userId: "user123", userName: "张三") { result in
    switch result {
    case .success:
        print("登录成功")
    case .failure(let error):
        print("登录失败: \(error)")
    }
}

// 打开聊天界面
HelpBot.open(from: self)
```

## 📚 更多文档

- [GitHub Actions 详细指南](SDK/iOS/GITHUB_ACTIONS_GUIDE.md)
- [本地编译说明](SDK/iOS/README.md)
- [iOS SDK README](SDK/iOS/README.md)

## ❓ 常见问题

### Q: 编译失败怎么办?
A: 查看 Actions 页面的编译日志,找到具体错误信息。常见问题:
- Swift 语法错误: 修复后重新推送
- 依赖问题: 检查 Package.swift 配置

### Q: 如何查看编译进度?
A: 访问 `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`,点击正在运行的工作流查看实时日志。

### Q: Artifacts 在哪里下载?
A: 在成功的工作流运行页面,滚动到底部的 `Artifacts` 区域。

### Q: 可以在 Windows 上使用编译的 Framework 吗?
A: 编译的 XCFramework 只能在 macOS 的 Xcode 项目中使用,但编译过程可以在 GitHub Actions (云端 macOS) 上完成。

## 🎉 下一步

- ✅ 推送代码触发编译
- ✅ 下载编译产物
- ✅ 集成到您的 iOS 项目
- ✅ 运行 Demo 验证功能

---

**需要帮助?** 查看详细文档或提交 Issue。
