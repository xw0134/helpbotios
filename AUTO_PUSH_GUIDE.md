# HelpBot SDK - 全自动化推送使用指南

## 🚀 快速开始 (3 步完成)

### 方式一: 首次使用 (需要配置)

```powershell
# 1. 运行自动推送脚本
.\auto_push.ps1

# 2. 选择 "2. 创建配置文件"

# 3. 输入您的 GitHub 信息:
#    - GitHub 用户名: myusername
#    - 仓库名称: HelpBotSDK

# 完成! 脚本会自动:
# - 保存配置到 github_config.ps1
# - 推送代码到 GitHub
# - 触发 iOS SDK 编译
# - 打开 Actions 页面
```

### 方式二: 已配置后 (一键执行)

```powershell
# 直接运行,自动读取配置并推送
.\auto_push.ps1
```

---

## 📋 配置方式

### 选项 A: 交互式配置 (推荐)

运行 `.\auto_push.ps1`,脚本会引导您创建配置文件。

### 选项 B: 手动创建配置文件

1. 复制模板文件:
   ```powershell
   Copy-Item github_config.template.ps1 github_config.ps1
   ```

2. 编辑 `github_config.ps1`,填写您的信息:
   ```powershell
   $env:GITHUB_USERNAME = "myusername"
   $env:GITHUB_REPO = "HelpBotSDK"
   # $env:GITHUB_TOKEN = "ghp_xxxx"  # 可选
   ```

3. 保存后运行:
   ```powershell
   .\auto_push.ps1
   ```

### 选项 C: 命令行参数

```powershell
.\auto_push.ps1 -Username "myusername" -Repo "HelpBotSDK"
```

---

## 🎯 脚本功能

### 自动化操作

✅ 自动读取配置文件  
✅ 自动检查 Git 状态  
✅ 自动提交未保存的更改 (可选)  
✅ 自动配置远程仓库  
✅ 自动重命名分支为 main  
✅ 自动推送代码  
✅ 自动打开 Actions 页面  

### 智能检测

✅ 检测是否已配置远程仓库  
✅ 检测是否有未提交的更改  
✅ 检测分支名称并自动修正  
✅ 检测推送是否成功  

---

## 📦 完整流程演示

```powershell
PS D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo> .\auto_push.ps1

========================================
HelpBot SDK - 全自动推送
========================================

📋 读取配置文件...
✅ 配置文件已加载

========================================
配置信息
========================================
用户名: myusername
仓库名: HelpBotSDK
仓库URL: https://github.com/myusername/HelpBotSDK.git
========================================

📋 检查 Git 状态...
✅ 工作区干净,无未提交更改

🚀 开始推送流程...

📡 添加远程仓库...
🔄 重命名分支为 main...

📤 推送代码到 GitHub...

Enumerating objects: 150, done.
Writing objects: 100% (150/150), done.
Total 150 (delta 30)

========================================
✅ 推送成功!
========================================

🎉 GitHub Actions 已自动触发 iOS SDK 编译!

📊 查看编译进度:
https://github.com/myusername/HelpBotSDK/actions

🌐 在浏览器中打开 Actions 页面? (y/n): y
✅ 已打开浏览器

✨ 全自动推送完成!
```

---

## ❓ 常见问题

### Q: 配置文件保存在哪里?
A: `d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\github_config.ps1`

### Q: 配置文件会被提交到 Git 吗?
A: 不会,已在 `.gitignore` 中排除 `github_config.ps1`

### Q: 如何修改配置?
A: 直接编辑 `github_config.ps1` 文件,或删除后重新运行脚本

### Q: 推送时要求输入密码怎么办?
A: 使用 Personal Access Token 替代密码:
1. 访问: https://github.com/settings/tokens
2. 生成 token (勾选 `repo` 权限)
3. 推送时用 token 作为密码

### Q: 如何强制推送而不提示?
A: 使用 `-Force` 参数:
```powershell
.\auto_push.ps1 -Force
```

---

## 🔐 安全提示

- ✅ 配置文件已自动排除在 Git 之外
- ✅ 不要将 Token 提交到代码仓库
- ✅ 定期更新 Personal Access Token
- ✅ 使用最小权限原则 (只勾选必要的权限)

---

## 📚 相关文件

- `auto_push.ps1` - 全自动推送脚本
- `github_config.template.ps1` - 配置模板
- `github_config.ps1` - 您的配置 (自动生成)
- `push_to_github.ps1` - 交互式推送脚本 (备用)

---

**准备好了吗? 运行 `.\auto_push.ps1` 开始全自动推送!** 🚀
