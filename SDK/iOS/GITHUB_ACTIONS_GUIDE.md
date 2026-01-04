# iOS SDK GitHub Actions 编译指南

## 📋 概述

本项目已配置 GitHub Actions 自动编译 iOS SDK,无需本地 macOS 环境即可完成编译。

## 🚀 使用方式

### 方式一: 手动触发编译 (推荐)

1. **访问 GitHub Actions 页面**
   - 打开仓库: `https://github.com/YOUR_USERNAME/YOUR_REPO`
   - 点击顶部的 `Actions` 标签
   - 在左侧选择 `Build iOS SDK` 工作流

2. **触发编译**
   - 点击右侧的 `Run workflow` 按钮
   - 选择编译配置:
     - `Debug`: 调试版本(包含符号表)
     - `Release`: 发布版本(优化性能)
   - 点击 `Run workflow` 开始编译

3. **等待编译完成**
   - 编译时间约 5-10 分钟
   - 可以实时查看编译日志

4. **下载编译产物**
   - 编译成功后,滚动到页面底部的 `Artifacts` 区域
   - 下载 `HelpBotSDK-Release-XXXXXXX.zip`
   - 解压后包含:
     - `HelpBotSDK.xcframework.zip` - iOS SDK Framework
     - `build-report.txt` - 编译报告

### 方式二: 代码推送自动触发

当您推送代码到以下分支时,会自动触发编译:
- `main` 分支
- `develop` 分支

**触发条件**: 修改了以下路径的文件
- `SDK/iOS/HelpBotSDK/**`
- `.github/workflows/build-ios-sdk.yml`

### 方式三: Pull Request 触发

创建 PR 时,如果修改了 iOS SDK 相关文件,会自动编译验证。

## 📦 编译产物说明

### HelpBotSDK.xcframework

这是一个通用的 XCFramework,包含以下架构:

```
HelpBotSDK.xcframework/
├── ios-arm64/                          # iOS 真机 (iPhone, iPad)
│   └── HelpBotSDK.framework/
│       ├── HelpBotSDK                  # 二进制文件 (arm64)
│       ├── Headers/                    # 公开头文件
│       ├── Modules/                    # Swift 模块
│       └── Info.plist
└── ios-arm64_x86_64-simulator/         # iOS 模拟器
    └── HelpBotSDK.framework/
        ├── HelpBotSDK                  # 二进制文件 (arm64, x86_64)
        ├── Headers/
        ├── Modules/
        └── Info.plist
```

**支持的架构**:
- **iOS 真机**: `arm64` (iPhone 5s 及以上)
- **iOS 模拟器**: `arm64` (Apple Silicon Mac) + `x86_64` (Intel Mac)

**最低系统要求**: iOS 12.0+

## 🔧 集成到项目

### 方式一: 手动集成

1. **下载并解压 XCFramework**
   ```bash
   unzip HelpBotSDK.xcframework.zip
   ```

2. **拖拽到 Xcode 项目**
   - 打开您的 Xcode 项目
   - 将 `HelpBotSDK.xcframework` 拖拽到项目导航器
   - 确保勾选 `Copy items if needed`

3. **配置 Target**
   - 选择项目 Target
   - 进入 `General` → `Frameworks, Libraries, and Embedded Content`
   - 确认 `HelpBotSDK.xcframework` 的 `Embed` 设置为 `Embed & Sign`

4. **导入使用**
   ```swift
   import HelpBotSDK
   
   // 初始化
   let config = HelpBotConfig(
       appId: "your_app_id",
       appKey: "your_app_key"
   )
   HelpBot.install(config: config)
   ```

### 方式二: Swift Package Manager (推荐)

如果您的项目使用 SPM,可以直接引用源码:

1. **在 Xcode 中添加 Package**
   - File → Add Packages...
   - 输入仓库 URL
   - 选择 `HelpBotSDK` 产品

2. **或在 Package.swift 中添加依赖**
   ```swift
   dependencies: [
       .package(url: "https://github.com/YOUR_USERNAME/YOUR_REPO", from: "1.0.0")
   ]
   ```

## 📊 编译报告说明

`build-report.txt` 包含以下信息:
- 编译时间和配置
- Git commit 信息
- 系统和 Xcode 版本
- XCFramework 架构详情
- 文件大小统计

示例:
```
=== HelpBot iOS SDK 编译报告 ===

编译时间: 2026-01-04 16:20:00
编译配置: Release
Git Commit: abc123def456
Git Branch: main

=== 环境信息 ===
macOS 14.2
Xcode 15.2
Swift 5.9

=== 架构信息 ===
iOS 真机: arm64
iOS 模拟器: x86_64 arm64
```

## 🐛 故障排查

### 编译失败

1. **检查编译日志**
   - 在 Actions 页面点击失败的工作流
   - 查看具体的错误步骤
   - 展开日志查看详细错误信息

2. **常见问题**
   - **Swift 版本不兼容**: 确保使用 Swift 5.7+
   - **依赖缺失**: 检查 `Package.swift` 配置
   - **语法错误**: 在本地修复后重新推送

### 下载不到 Artifacts

- **权限问题**: 确保您有仓库的访问权限
- **过期清理**: Artifacts 默认保留 30 天,过期后会自动删除
- **编译未完成**: 等待编译完全成功后再下载

## 🔐 私有仓库注意事项

如果您的仓库是私有的:

1. **Actions 权限**
   - Settings → Actions → General
   - 确保 `Allow all actions and reusable workflows` 已启用

2. **Artifacts 访问**
   - 只有仓库成员可以下载 Artifacts
   - 可以通过 GitHub API 或 CLI 下载

## 📝 自定义编译配置

如需修改编译配置,编辑 `.github/workflows/build-ios-sdk.yml`:

```yaml
# 修改 Xcode 版本
- name: ⚙️ 选择 Xcode 版本
  run: |
    sudo xcode-select -switch /Applications/Xcode_15.2.app

# 修改编译参数
xcodebuild archive \
  -configuration Release \
  OTHER_SWIFT_FLAGS="-D CUSTOM_FLAG"
```

## 🎯 下一步

- ✅ 下载编译好的 XCFramework
- ✅ 集成到您的 iOS 项目
- ✅ 运行 Demo 应用验证功能
- ✅ 查看 [API 文档](../HelpBotSDK/README.md)

## 📞 支持

如有问题,请:
1. 查看编译日志
2. 检查 [Issues](https://github.com/YOUR_USERNAME/YOUR_REPO/issues)
3. 提交新的 Issue
