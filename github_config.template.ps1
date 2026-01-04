# ========================================
# HelpBot SDK - 全自动化推送脚本
# ========================================
# 使用方法:
# 1. 复制此文件为 github_config.ps1
# 2. 填写您的 GitHub 信息
# 3. 运行 .\auto_push.ps1
# ========================================

# GitHub 配置
$env:GITHUB_USERNAME = "YOUR_USERNAME"        # 替换为您的 GitHub 用户名
$env:GITHUB_REPO = "YOUR_REPO"                # 替换为您的仓库名
$env:GITHUB_TOKEN = "YOUR_TOKEN"              # 替换为您的 Personal Access Token (可选)

# 示例:
# $env:GITHUB_USERNAME = "zhangsan"
# $env:GITHUB_REPO = "HelpBotSDK"
# $env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxx"
