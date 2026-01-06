#!/bin/bash
# ========================================
# UnrealEngine iOS 本地编译测试脚本 (macOS)
# ========================================

set -e

echo "========================================"
echo "UnrealEngine iOS 编译测试"
echo "========================================"
echo ""

# 配置变量
UE_ROOT="/Users/Shared/Epic Games/UE_5.0"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/Demo/HelpBotUEDemo.uproject"
OUTPUT_DIR="$PROJECT_ROOT/Builds/iOS"
BUILD_CONFIG="Development"
IOS_SDK_PATH="$PROJECT_ROOT/../iOS/HelpBotSDK"
FRAMEWORK_OUTPUT="$PROJECT_ROOT/HelpBotUE/ThirdParty/iOS"

echo "检查环境..."
echo ""

# 检查操作系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "[错误] 此脚本仅支持 macOS"
    exit 1
fi
echo "[OK] 操作系统: macOS"

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "[错误] 未找到 Xcode"
    echo "请从 App Store 安装 Xcode"
    exit 1
fi
echo "[OK] Xcode: $(xcodebuild -version | head -n 1)"

# 检查 UE 安装
if [ ! -f "$UE_ROOT/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor" ]; then
    echo "[错误] 未找到 Unreal Engine 5.0"
    echo "请修改脚本中的 UE_ROOT 变量指向正确的 UE 安装路径"
    echo "当前路径: $UE_ROOT"
    exit 1
fi
echo "[OK] Unreal Engine 5.0: $UE_ROOT"

# 检查项目文件
if [ ! -f "$PROJECT_FILE" ]; then
    echo "[错误] 未找到项目文件: $PROJECT_FILE"
    exit 1
fi
echo "[OK] 项目文件: $PROJECT_FILE"

echo ""
echo "========================================"
echo "步骤 1: 准备 iOS Framework"
echo "========================================"
echo ""

# 检查 Framework 是否已存在
if [ -d "$FRAMEWORK_OUTPUT/HelpBot.framework" ]; then
    echo "[OK] iOS Framework 已存在: $FRAMEWORK_OUTPUT/HelpBot.framework"
    read -p "是否重新构建 Framework? (y/n): " REBUILD_FRAMEWORK
    if [[ "$REBUILD_FRAMEWORK" != "y" ]]; then
        echo "跳过 Framework 构建"
        SKIP_FRAMEWORK=true
    fi
fi

if [ -z "$SKIP_FRAMEWORK" ]; then
    if [ -d "$IOS_SDK_PATH" ]; then
        echo "从 iOS SDK 构建 Framework..."
        cd "$IOS_SDK_PATH"
        
        # 检查 XcodeGen
        if ! command -v xcodegen &> /dev/null; then
            echo "安装 XcodeGen..."
            brew install xcodegen
        fi
        
        # 生成 Xcode 项目
        if [ -f "project.yml" ]; then
            echo "生成 Xcode 项目..."
            xcodegen generate
        else
            echo "[错误] 未找到 project.yml"
            exit 1
        fi
        
        # 构建 Framework (真机版本)
        echo "构建 iOS 真机 Framework..."
        xcodebuild build \
            -project HelpBotSDK.xcodeproj \
            -scheme HelpBotSDK \
            -configuration Release \
            -sdk iphoneos \
            -destination 'generic/platform=iOS' \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            SKIP_INSTALL=NO \
            -derivedDataPath build
        
        # 构建 Framework (模拟器版本)
        echo "构建 iOS 模拟器 Framework..."
        xcodebuild build \
            -project HelpBotSDK.xcodeproj \
            -scheme HelpBotSDK \
            -configuration Release \
            -sdk iphonesimulator \
            -destination 'generic/platform=iOS Simulator' \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            SKIP_INSTALL=NO \
            -derivedDataPath build
        
        # 创建 XCFramework
        echo "创建 XCFramework..."
        xcodebuild -create-xcframework \
            -framework build/Build/Products/Release-iphoneos/HelpBot.framework \
            -framework build/Build/Products/Release-iphonesimulator/HelpBot.framework \
            -output build/HelpBot.xcframework
        
        # 复制到 UnrealEngine ThirdParty 目录
        echo "复制 Framework 到 UnrealEngine..."
        mkdir -p "$FRAMEWORK_OUTPUT"
        
        # 复制真机版本的 .framework
        cp -R build/Build/Products/Release-iphoneos/HelpBot.framework "$FRAMEWORK_OUTPUT/"
        
        # 复制 XCFramework
        cp -R build/HelpBot.xcframework "$FRAMEWORK_OUTPUT/"
        
        # 打包 Framework
        cd "$FRAMEWORK_OUTPUT"
        zip -r HelpBot.framework.zip HelpBot.framework
        zip -r HelpBot.xcframework.zip HelpBot.xcframework
        
        echo "[OK] Framework 构建完成"
        ls -lh "$FRAMEWORK_OUTPUT"
        
        cd "$PROJECT_ROOT"
    else
        echo "[警告] iOS SDK 源码不存在: $IOS_SDK_PATH"
        echo "请确保 iOS Framework 已准备好"
        exit 1
    fi
fi

echo ""
echo "========================================"
echo "步骤 2: 编译 UE iOS 项目"
echo "========================================"
echo ""

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 设置 RunUAT 路径
RUNUAT="$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh"

# 执行编译
echo "执行 RunUAT BuildCookRun..."
echo "配置: $BUILD_CONFIG"
echo "输出: $OUTPUT_DIR"
echo ""

"$RUNUAT" BuildCookRun \
    -project="$PROJECT_FILE" \
    -platform=iOS \
    -clientconfig=$BUILD_CONFIG \
    -cook \
    -stage \
    -package \
    -build \
    -archive \
    -archivedirectory="$OUTPUT_DIR" \
    -utf8output

echo ""
echo "========================================"
echo "[成功] 编译完成!"
echo "========================================"
echo ""

# 查找生成的 IPA
echo "查找 IPA 文件..."
find "$OUTPUT_DIR" -name "*.ipa" -exec ls -lh {} \;

echo ""
echo "编译产物位置: $OUTPUT_DIR"
echo ""

# 询问是否安装到模拟器
read -p "是否安装到 iOS 模拟器? (y/n): " INSTALL
if [[ "$INSTALL" == "y" ]]; then
    echo ""
    echo "查找 .app 文件..."
    
    APP_FILE=$(find "$OUTPUT_DIR" -name "*.app" | head -n 1)
    
    if [ -n "$APP_FILE" ]; then
        echo "找到应用: $APP_FILE"
        
        # 列出可用的模拟器
        echo ""
        echo "可用的模拟器:"
        xcrun simctl list devices | grep "iPhone"
        
        echo ""
        read -p "请输入模拟器名称 (例如: iPhone 15): " SIMULATOR_NAME
        
        # 启动模拟器
        echo "启动模拟器..."
        xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || echo "模拟器已在运行"
        open -a Simulator
        
        # 安装应用
        echo "安装应用到模拟器..."
        xcrun simctl install booted "$APP_FILE"
        
        # 启动应用
        echo "启动应用..."
        xcrun simctl launch booted com.helpbot.ue.demo
        
        echo "[成功] 应用已安装并启动"
    else
        echo "[错误] 未找到 .app 文件"
    fi
fi

echo ""
echo "完成!"
