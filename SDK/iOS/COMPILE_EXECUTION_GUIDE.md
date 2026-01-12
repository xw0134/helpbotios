# iOS SDK 编译执行指南

## 当前状态

✅ GitHub Actions 配置已完成  
❌ 项目尚未推送到 GitHub

## 🚀 执行编译的步骤

由于 iOS SDK 编译需要 macOS 环境,我们配置了 GitHub Actions 云端编译。要触发编译,需要完成以下步骤:

### 步骤 1: 初始化 Git 仓库 (如果尚未初始化)

```bash
cd d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo

# 初始化 Git 仓库
git init

# 添加所有文件
git add .

# 首次提交
git commit -m "feat: 初始化 HelpBot SDK 项目并配置 iOS GitHub Actions 编译"
```

### 步骤 2: 关联 GitHub 远程仓库

**选项 A: 如果您已有 GitHub 仓库**
```bash
# 添加远程仓库 (替换为您的仓库地址)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 推送代码
git push -u origin main
```

**选项 B: 如果需要创建新的 GitHub 仓库**
1. 访问 https://github.com/new
2. 创建新仓库 (例如: `HelpBotSDK`)
3. 执行以下命令:
```bash
git remote add origin https://github.com/YOUR_USERNAME/HelpBotSDK.git
git branch -M main
git push -u origin main
```

### 步骤 3: 触发 GitHub Actions 编译

推送代码后,编译会自动触发。您也可以手动触发:

1. 访问: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build-ios-sdk.yml`
2. 点击 `Run workflow`
3. 选择 `Release` 配置
4. 点击绿色的 `Run workflow` 按钮

### 步骤 4: 查看编译进度

1. 访问: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`
2. 点击正在运行的工作流
3. 查看实时编译日志

### 步骤 5: 下载编译产物

编译完成后 (约 5-10 分钟):
1. 在工作流运行页面滚动到底部
2. 在 `Artifacts` 区域下载 `HelpBotSDK-Release-XXXXXXX.zip`
3. 解压获得 `HelpBotSDK.xcframework`

---

## 📱 方案 C：仅 Windows + iPhone 真机测试（自签安装 IPA）

> 适用场景：你没有 Mac，但已经在 GitHub Actions 编译出了 Demo 的 `HelpBotDemo.ipa`，希望装到自己的 iPhone 运行验证。
>
> 重要说明（iOS 限制）：
> - iOS App **必须签名**才能安装。CI 默认产出的 `.ipa` 为 **未签名（unsigned）**，需要在安装时用 Apple ID 进行“自签名”。
> - 免费 Apple ID 自签的 App 通常 **7 天过期**，需要重新签名安装（这是 Apple 规则，不是 SDK 限制）。
> - 免费账号通常最多同时装 **3 个自签 App**（含扩展）。

### 1) 先拿到“真机版 IPA”

- 在 GitHub Actions 里运行并下载 Demo 工作流产物（工作流：`build-ios-demo.yml`）
- 优先使用：`HelpBotDemo.ipa`（它在 CI 中是从 iPhoneOS 构建产物复制出来的）

### 2) 推荐工具：Sideloadly（Windows 一步自签安装）

#### 前置条件
- 一台 Windows 电脑 + 数据线
- 一台 iPhone（建议 iOS 16+）
- 一个 Apple ID（建议开启双重认证）
- 安装 **iTunes** 与 **iCloud**（建议安装 Apple 官网版本，尽量避免 Microsoft Store 版本导致驱动/识别问题）

#### 安装步骤（按顺序）
1. 在 iPhone 上：连接电脑，点击“信任此电脑”，输入锁屏密码。
2. 在 Windows 上：打开 Sideloadly，确认顶部设备下拉框能选到你的 iPhone。
3. 把 `HelpBotDemo.ipa` 拖入 Sideloadly（或点击选择 IPA）。
4. 输入 Apple ID：
   - 建议使用“专用于测试的 Apple ID”，避免与主账号混用。
   - 若你的 Apple ID 开启了双重认证，通常需要生成 **App 专用密码** 给 Sideloadly 使用（不要使用主密码）。
5. 点击 Start 开始自签并安装，等待完成。
6. 在 iPhone 上信任开发者证书：
   - `设置` → `通用` → `VPN 与设备管理`（或“设备管理”）→ 选择你的 Apple ID → 点击“信任”。
7. 若 iPhone 提示需要开发者模式：
   - `设置` → `隐私与安全性` → `开发者模式` → 打开 → 重启后确认。
8. 回到桌面打开 `HelpBotDemo`，按 Demo 页面流程做 install/login/showConversation 等冒烟验证。

#### 常见问题排查（Sideloadly）
- 设备列表找不到 iPhone：优先检查 iTunes 是否能识别、数据线/驱动是否正常。
- 安装后闪退/打不开：确认已“信任开发者证书”，并开启“开发者模式”（iOS 16+）。
- 7 天后打不开：这是证书过期，需要重新用 Sideloadly 安装一次。

### 3) 备选工具：AltStore（需要常驻/定期刷新）

> AltStore 的优势是可以在 7 天内通过“刷新”延长有效期（通常要求电脑同网段、AltServer 可用）。

简要流程：
1. Windows 安装 iTunes + iCloud
2. Windows 安装 AltServer
3. 用 AltServer 给 iPhone 安装 AltStore
4. 在 iPhone 的 AltStore 里导入并安装 `HelpBotDemo.ipa`（会自动自签）
5. 后续定期“Refresh”避免过期

---

## 🔧 替代方案: 本地编译 (需要 macOS)

如果您有 macOS 设备,可以使用本地编译脚本:

```bash
# 在 macOS 上执行
cd SDK/iOS/HelpBotSDK
chmod +x ../build_local.sh
../build_local.sh
```

## 发布工件结构要求（必须满足）

发布给外部集成方的 iOS SDK 工件，必须是 **标准 `HelpBotSDK.framework`**（最终以 `HelpBotSDK.xcframework` 形式交付），并且满足：

- `HelpBotSDK.framework/Modules/HelpBotSDK.swiftmodule/` 必须存在（可 `import HelpBotSDK`）
- `HelpBotSDK.framework/Headers/` 必须存在，且至少包含一个 `.h`（用于 ObjC 兼容头/对齐外部工程引用习惯）

## 推荐的构建方式（CI/Xcode 一致）

为保证 `Modules`/`Headers` 结构稳定且可校验，仓库推荐使用构建脚本：

```bash
# 在 macOS 上执行（可选设置 CONFIGURATION=Release/Debug）
export CONFIGURATION=Release
bash SDK/Unity/iOSBuild/build_helpbot_sdk_xcframework.sh "SDK/iOS/HelpBotSDK/build/HelpBotSDK.xcframework"
```

该脚本会在打包前执行结构强校验：若 `Modules` 或 `Headers` 缺失/为空会直接失败，避免发布错误结构的工件。

编译产物位于: `build/HelpBotSDK.xcframework`

---

## ❓ 常见问题

### Q: 我没有 GitHub 账号怎么办?
A: 
1. 访问 https://github.com/signup 注册免费账号
2. 创建新仓库
3. 按照上述步骤推送代码

### Q: 可以在 Windows 上直接编译吗?
A: 不可以。iOS SDK 编译需要:
- macOS 操作系统
- Xcode 15.2+（用于解析 SwiftPM 5.9 + Swift 5.9 语言版本）
- Swift 编译器

这就是为什么我们配置了 GitHub Actions 云端编译,让您无需 macOS 也能编译 iOS SDK。

### Q: GitHub Actions 编译是免费的吗?
A: 
- 公开仓库: 完全免费,无限制
- 私有仓库: 每月 2000 分钟免费额度 (足够使用)

### Q: 编译需要多长时间?
A: 约 5-10 分钟,包括:
- 环境准备: 1-2 分钟
- 编译 iOS 真机: 2-3 分钟
- 编译 iOS 模拟器: 2-3 分钟
- 创建 XCFramework: 1 分钟

---

## 📋 我可以帮您做什么?

由于当前项目尚未推送到 GitHub,我可以帮您:

1. **初始化 Git 仓库** - 执行 `git init` 和首次提交
2. **创建 .gitignore** - 排除不需要提交的文件
3. **提供详细的推送指令** - 根据您的 GitHub 仓库地址

**请告诉我您希望如何操作:**
- 选项 1: 我帮您初始化 Git 仓库并创建 .gitignore
- 选项 2: 您已有 GitHub 仓库,告诉我仓库地址,我帮您准备推送命令
- 选项 3: 您想使用本地 macOS 编译 (需要您有 Mac 设备)

---

## 📚 相关文档

- [GitHub Actions 详细指南](./GITHUB_ACTIONS_GUIDE.md)
- [快速开始指南](./QUICKSTART.md)
- 配置总结（内部文档路径已移除，避免在仓库中出现本地绝对路径）
