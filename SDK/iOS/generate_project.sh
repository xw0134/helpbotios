#!/bin/bash

# HelpBotDemo Xcode 项目生成脚本
# 使用 XcodeGen 从 project.yml 生成 Xcode 项目文件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$SCRIPT_DIR/HelpBotDemo"

echo "========================================="
echo "HelpBotDemo Xcode 项目生成脚本"
echo "========================================="
echo ""

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 错误: 此脚本只能在 macOS 上运行"
    echo ""
    echo "如果您在 Windows/Linux 上,请使用 GitHub Actions 云端编译:"
    echo "  1. 推送代码到 GitHub"
    echo "  2. 访问 Actions 页面触发编译"
    echo "  3. 下载编译产物"
    echo ""
    echo "详见: SDK/iOS/GITHUB_ACTIONS_GUIDE.md"
    exit 1
fi

# 检查 XcodeGen 是否已安装
if ! command -v xcodegen &> /dev/null; then
    echo "❌ 错误: XcodeGen 未安装"
    echo ""
    echo "请使用 Homebrew 安装 XcodeGen:"
    echo "  brew install xcodegen"
    echo ""
    echo "或访问: https://github.com/yonaskolb/XcodeGen"
    exit 1
fi

echo "✅ XcodeGen 已安装: $(xcodegen --version)"
echo ""

# 进入 Demo 目录
cd "$DEMO_DIR"

echo "📂 当前目录: $DEMO_DIR"
echo ""

# 若已提交 xcodeproj，则默认无需生成（避免覆盖手改/引入差异）
if [ -d "HelpBotDemo.xcodeproj" ]; then
    echo "✅ 检测到已提交的 HelpBotDemo.xcodeproj"
    echo ""
    echo "下一步:"
    echo "  1. 打开项目: open HelpBotDemo.xcodeproj"
    echo "  2. 在 Xcode 中选择模拟器或真机"
    echo "  3. 设置 DEVELOPMENT_TEAM (如需真机调试)"
    echo "  4. 点击 Run (⌘+R) 运行 Demo"
    echo ""
    echo "如需强制重新生成（会覆盖现有工程），请手动执行："
    echo "  rm -rf HelpBotDemo.xcodeproj && xcodegen generate"
    exit 0
fi

# 检查 project.yml 是否存在
if [ ! -f "project.yml" ]; then
    echo "❌ 错误: project.yml 文件不存在"
    exit 1
fi

echo "🔨 正在生成 Xcode 项目..."
echo ""

# 运行 XcodeGen
if xcodegen generate; then
    echo ""
    echo "========================================="
    echo "✅ 项目生成成功!"
    echo "========================================="
    echo ""
    echo "生成的项目文件: HelpBotDemo.xcodeproj"
    echo ""
    echo "下一步:"
    echo "  1. 打开项目: open HelpBotDemo.xcodeproj"
    echo "  2. 在 Xcode 中选择模拟器或真机"
    echo "  3. 设置 DEVELOPMENT_TEAM (如需真机调试)"
    echo "  4. 点击 Run (⌘+R) 运行 Demo"
    echo ""
else
    echo ""
    echo "========================================="
    echo "❌ 项目生成失败"
    echo "========================================="
    echo ""
    echo "请检查 project.yml 配置是否正确"
    exit 1
fi
