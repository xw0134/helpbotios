# iOS Demo GitHub Actions 编译指南

## 📋 概述

iOS Demo 应用已配置 GitHub Actions 自动编译,支持:
- ✅ XcodeGen 自动生成项目
- ✅ Swift Package Manager 依赖管理
- ✅ 模拟器和真机编译
- ✅ 自动上传编译产物

## 🚀 使用方式

### 方式一: 手动触发编译

1. **访问 GitHub Actions 页面**
   ```
   https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build-ios-demo.yml
   ```

2. **点击 "Run workflow"**
   - 选择分支: `main`
   - 编译配置: `Debug` 或 `Release`
   - 导出方式: `development` (默认)
   - 点击绿色的 "Run workflow" 按钮

3. **等待编译完成** (约 8-12 分钟)

4. **下载编译产物**
   - 在 Artifacts 区域下载 `HelpBotDemo-Debug-XXXXXXX.zip`
   - 包含 `HelpBotDemo.xcarchive` 和编译报告

### 方式二: 自动触发

修改以下文件并推送会自动触发编译:
- `SDK/iOS/HelpBotDemo/**` - Demo 应用代码
- `SDK/iOS/HelpBotSDK/**` - SDK 代码

## 📦 编译产物说明

### HelpBotDemo.xcarchive

这是 Xcode Archive 文件,包含:
- 编译好的应用二进制
- dSYM 符号文件 (用于崩溃分析)
- 应用资源文件

**注意**: GitHub Actions 编译的 Archive **未签名**,仅用于验证编译流程。

### 如何使用 Archive

#### 方法 1: 在 Xcode 中打开

1. 下载并解压 Archive
2. 双击 `HelpBotDemo.xcarchive` 在 Xcode 中打开
3. 在 Xcode Organizer 中:
   - 选择 Archive
   - 点击 "Distribute App"
   - 选择导出方式并签名

#### 方法 2: 命令行导出

```bash
xcodebuild -exportArchive \
  -archivePath HelpBotDemo.xcarchive \
  -exportPath output \
  -exportOptionsPlist ExportOptions.plist
```

## 🔧 本地编译 (推荐用于开发)

如果您有 macOS 和 Xcode,本地编译更方便:

```bash
# 1. 进入 Demo 目录
cd SDK/iOS/HelpBotDemo

# 2. 安装 XcodeGen (首次)
brew install xcodegen

# 3. 生成项目
xcodegen generate

# 4. 打开项目
open HelpBotDemo.xcodeproj

# 5. 在 Xcode 中选择模拟器或真机运行
```

## 📊 编译流程详解

### 步骤 1: 环境准备
- macOS 14
- Xcode 15.2
- Swift 5.9
- XcodeGen (自动安装)

### 步骤 2: 项目生成
```bash
xcodegen generate
```
根据 `project.yml` 生成 `HelpBotDemo.xcodeproj`

### 步骤 3: 依赖解析
```bash
xcodebuild -resolvePackageDependencies
```
解析 Swift Package (HelpBotSDK)

### 步骤 4: 编译模拟器版本
```bash
xcodebuild build \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

### 步骤 5: 编译真机版本
```bash
xcodebuild archive \
  -archivePath build/HelpBotDemo.xcarchive
```

## ⚠️ 重要说明

### 关于代码签名

GitHub Actions 编译时使用以下设置跳过签名:
```
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO
```

**这意味着**:
- ✅ 可以验证代码编译通过
- ✅ 可以检查编译产物结构
- ❌ 无法直接安装到真机
- ❌ 无法提交到 App Store

### 如需真机安装

**方法 1**: 本地 Xcode 编译
- 在 Xcode 中打开项目
- 配置开发者账号和证书
- 选择真机运行

**方法 2**: 配置 GitHub Actions 签名
- 需要上传证书和 Provisioning Profile
- 配置 Secrets 存储敏感信息
- 修改工作流添加签名步骤

## 🐛 故障排查

### 编译失败: XcodeGen not found

**原因**: XcodeGen 安装失败

**解决**: 检查 Homebrew 是否正常工作

### 编译失败: Package resolution failed

**原因**: Swift Package 依赖解析失败

**解决**: 
1. 检查 `project.yml` 中的 package 路径
2. 确认 HelpBotSDK 存在于 `../HelpBotSDK`

### 编译失败: Build input file cannot be found

**原因**: 源文件路径错误

**解决**: 检查 `project.yml` 中的 sources 路径配置

## 📚 相关文档

- [XcodeGen 文档](https://github.com/yonaskolb/XcodeGen)
- [GitHub Actions 工作流](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/.github/workflows/build-ios-demo.yml)
- [Demo README](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/SDK/iOS/HelpBotDemo/README.md)
- [project.yml 配置](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/SDK/iOS/HelpBotDemo/project.yml)

## 🎯 下一步

1. **推送代码**: 触发自动编译
   ```bash
   git add .
   git commit -m "feat: 添加 iOS Demo GitHub Actions 编译"
   git push
   ```

2. **查看编译进度**: 访问 Actions 页面

3. **下载编译产物**: 验证 Archive 完整性

4. **本地测试**: 使用 Xcode 运行 Demo

---

**需要帮助?** 查看编译日志或提交 Issue
