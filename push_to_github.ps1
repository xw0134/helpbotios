# ========================================
# HelpBot SDK - GitHub 推送和编译脚本
# ========================================
# 用途: 一键推送代码到 GitHub 并触发 iOS SDK 云端编译
# 使用: 在 PowerShell 中运行此脚本
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "HelpBot SDK - GitHub 推送向导" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否在正确的目录
$currentPath = Get-Location
$expectedPath = "d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo"

if ($currentPath.Path -ne $expectedPath) {
    Write-Host "⚠️  当前不在项目目录,正在切换..." -ForegroundColor Yellow
    Set-Location $expectedPath
}

# 检查 Git 状态
Write-Host "📋 检查 Git 状态..." -ForegroundColor Blue
git status

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "请提供您的 GitHub 仓库信息" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 获取用户输入
Write-Host "如果您还没有创建 GitHub 仓库,请先访问:" -ForegroundColor Yellow
Write-Host "https://github.com/new" -ForegroundColor Green
Write-Host ""

$username = Read-Host "请输入您的 GitHub 用户名"
$reponame = Read-Host "请输入您的仓库名称 (例如: HelpBotSDK)"

# 构建仓库 URL
$repoUrl = "https://github.com/$username/$reponame.git"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "将要推送到:" -ForegroundColor Cyan
Write-Host $repoUrl -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "确认推送? (y/n)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "❌ 已取消推送" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "🚀 开始推送流程..." -ForegroundColor Blue
Write-Host ""

# 检查是否已有远程仓库
$remotes = git remote
if ($remotes -contains "origin") {
    Write-Host "⚠️  检测到已存在的 origin,正在移除..." -ForegroundColor Yellow
    git remote remove origin
}

# 添加远程仓库
Write-Host "📡 添加远程仓库..." -ForegroundColor Blue
git remote add origin $repoUrl

# 重命名分支为 main
Write-Host "🔄 重命名分支为 main..." -ForegroundColor Blue
git branch -M main

# 推送代码
Write-Host ""
Write-Host "📤 推送代码到 GitHub..." -ForegroundColor Blue
Write-Host "提示: 如果要求输入密码,请使用 Personal Access Token" -ForegroundColor Yellow
Write-Host ""

git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ 推送成功!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 GitHub Actions 已自动触发 iOS SDK 编译!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 查看编译进度:" -ForegroundColor Cyan
    Write-Host "https://github.com/$username/$reponame/actions" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 编译完成后 (约 5-10 分钟),下载编译产物:" -ForegroundColor Cyan
    Write-Host "1. 访问上面的 Actions 页面" -ForegroundColor White
    Write-Host "2. 点击 'Build iOS SDK' 工作流" -ForegroundColor White
    Write-Host "3. 滚动到底部的 Artifacts 区域" -ForegroundColor White
    Write-Host "4. 下载 HelpBotSDK-Release-XXXXXXX.zip" -ForegroundColor White
    Write-Host ""
    Write-Host "🌐 在浏览器中打开 Actions 页面? (y/n)" -ForegroundColor Cyan
    $openBrowser = Read-Host
    
    if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
        Start-Process "https://github.com/$username/$reponame/actions"
    }
    
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ 推送失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "1. GitHub 仓库不存在 - 请先在 GitHub 上创建仓库" -ForegroundColor White
    Write-Host "2. 认证失败 - 请使用 Personal Access Token 而不是密码" -ForegroundColor White
    Write-Host "3. 网络问题 - 检查网络连接" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 获取 Personal Access Token:" -ForegroundColor Cyan
    Write-Host "https://github.com/settings/tokens" -ForegroundColor Green
    Write-Host ""
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
