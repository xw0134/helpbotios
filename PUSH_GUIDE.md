# HelpBot SDK - 快速推送指南

## 🚀 方式一: 使用自动化脚本 (推荐)

我已经为您创建了一个交互式推送脚本,只需运行即可!

### 步骤:

1. **打开 PowerShell** (在项目目录右键 → "在终端中打开")

2. **运行推送脚本**:
   ```powershell
   .\push_to_github.ps1
   ```

3. **按照提示操作**:
   - 输入您的 GitHub 用户名
   - 输入仓库名称 (例如: `HelpBotSDK`)
   - 确认推送
   - 等待自动推送完成

4. **查看编译进度**:
   - 脚本会自动打开 GitHub Actions 页面
   - 或手动访问: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`

### 注意事项:

- 如果 GitHub 仓库还不存在,请先访问 https://github.com/new 创建
- 推送时如果要求密码,请使用 **Personal Access Token**,不是 GitHub 密码
- Token 获取地址: https://github.com/settings/tokens

---

## 📝 方式二: 手动执行命令

如果您更喜欢手动操作,可以执行以下命令:

```powershell
# 1. 进入项目目录
cd d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo

# 2. 添加远程仓库 (替换为您的信息)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 3. 重命名分支为 main
git branch -M main

# 4. 推送代码
git push -u origin main
```

**重要**: 将 `YOUR_USERNAME` 和 `YOUR_REPO` 替换为您的实际 GitHub 用户名和仓库名。

---

## 🎯 推送后会发生什么?

### 自动触发编译

推送成功后,GitHub Actions 会**自动触发 iOS SDK 编译**:

1. **编译开始**: 约 30 秒后开始
2. **编译时间**: 5-10 分钟
3. **编译环境**: macOS 14 + Xcode 15.2
4. **编译产物**: `HelpBotSDK.xcframework`

### 查看编译进度

访问: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`

您会看到:
- ✅ 绿色勾号 = 编译成功
- 🔄 黄色圆圈 = 正在编译
- ❌ 红色叉号 = 编译失败

### 下载编译产物

编译成功后:
1. 点击成功的工作流运行
2. 滚动到页面底部
3. 在 `Artifacts` 区域下载 `HelpBotSDK-Release-XXXXXXX.zip`
4. 解压获得:
   - `HelpBotSDK.xcframework.zip` - iOS SDK
   - `build-report.txt` - 编译报告

---

## ❓ 常见问题

### Q: 如何创建 GitHub 仓库?

1. 访问: https://github.com/new
2. 填写:
   - Repository name: `HelpBotSDK`
   - Description: `HelpBot SDK for multiple platforms`
   - 选择 Public 或 Private
3. **不要**勾选任何初始化选项 (README, .gitignore, license)
4. 点击 `Create repository`

### Q: 什么是 Personal Access Token?

GitHub 不再支持密码认证,需要使用 Token:

1. 访问: https://github.com/settings/tokens
2. 点击 `Generate new token` → `Generate new token (classic)`
3. 设置:
   - Note: `HelpBot SDK`
   - Expiration: 选择有效期
   - 勾选: `repo` (完整仓库权限)
4. 点击 `Generate token`
5. **复制 token** (只显示一次!)
6. 推送时用 token 替代密码

### Q: 推送失败怎么办?

**错误: repository not found**
- 原因: GitHub 仓库不存在或名称错误
- 解决: 检查仓库是否已创建,确认名称正确

**错误: authentication failed**
- 原因: 使用了密码而不是 token
- 解决: 使用 Personal Access Token

**错误: remote origin already exists**
- 原因: 已配置过远程仓库
- 解决: 先删除 `git remote remove origin`,再重新添加

### Q: 编译失败怎么办?

1. 访问 Actions 页面,点击失败的工作流
2. 查看详细的编译日志
3. 常见问题:
   - Swift 语法错误: 修复代码后重新推送
   - 依赖问题: 检查 Package.swift
   - 环境问题: 通常是临时的,重新运行即可

---

## 🎉 成功后的下一步

### 1. 集成到 iOS 项目

```swift
// 1. 将 HelpBotSDK.xcframework 拖入 Xcode 项目
// 2. 在代码中导入
import HelpBotSDK

// 3. 初始化
let config = HelpBotConfig(appId: "your_app_id", appKey: "your_app_key")
HelpBot.install(config: config)

// 4. 登录
HelpBot.login(userId: "user123", userName: "张三")

// 5. 打开聊天
HelpBot.open(from: self)
```

### 2. 后续编译

以后修改代码后,只需:
```powershell
git add .
git commit -m "更新说明"
git push
```

推送后会自动触发编译!

---

## 📚 相关文档

- [自动化推送脚本](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/push_to_github.ps1)
- [GitHub Actions 指南](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/SDK/iOS/GITHUB_ACTIONS_GUIDE.md)
- [快速开始指南](file:///d:/xinhuo/HelpBotSdkDemo/HelpBotSdkDemo/SDK/iOS/QUICKSTART.md)
- [配置总结](file:///C:/Users/admin/.gemini/antigravity/brain/94f0796d-373b-4775-b85c-bcf7cdd5811e/walkthrough.md)

---

**准备好了吗? 运行 `.\push_to_github.ps1` 开始推送!** 🚀
