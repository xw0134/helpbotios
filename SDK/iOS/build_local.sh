#!/bin/bash

# HelpBot iOS SDK 本地编译脚本
# 用途: 在 macOS 上本地编译 iOS SDK (作为 GitHub Actions 的备用方案)
# 使用: chmod +x build_local.sh && ./build_local.sh

set -e  # 遇到错误立即退出

# ============================================
# 配置区域
# ============================================
SCHEME="HelpBotSDK"
CONFIGURATION="Release"  # 可选: Debug, Release
BUILD_DIR="build"
XCFRAMEWORK_NAME="${SCHEME}.xcframework"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 辅助函数
# ============================================
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============================================
# 1. 环境检查
# ============================================
print_header "1. 环境检查"

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "此脚本只能在 macOS 上运行"
    exit 1
fi
print_success "运行环境: macOS"

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    print_error "未检测到 Xcode,请先安装 Xcode"
    exit 1
fi
print_success "Xcode 已安装"

# 显示版本信息
echo ""
print_info "系统版本:"
sw_vers

echo ""
print_info "Xcode 版本:"
xcodebuild -version

echo ""
print_info "Swift 版本:"
swift --version

# 检查 Swift 版本 (需要 5.7+)
SWIFT_VERSION=$(swift --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
REQUIRED_VERSION="5.7"
if (( $(echo "$SWIFT_VERSION < $REQUIRED_VERSION" | bc -l) )); then
    print_warning "Swift 版本 $SWIFT_VERSION 低于推荐版本 $REQUIRED_VERSION"
    print_warning "可能会遇到编译问题,建议升级 Xcode"
else
    print_success "Swift 版本符合要求: $SWIFT_VERSION"
fi

# ============================================
# 2. 清理旧的编译产物
# ============================================
print_header "2. 清理旧的编译产物"

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
    print_success "已删除旧的 $BUILD_DIR 目录"
fi

if [ -d ".build" ]; then
    rm -rf ".build"
    print_success "已删除 Swift Package 缓存"
fi

mkdir -p "$BUILD_DIR"
print_success "创建新的 $BUILD_DIR 目录"

# ============================================
# 3. 编译 iOS 真机架构
# ============================================
print_header "3. 编译 iOS 真机架构 (arm64)"

print_info "开始编译..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD_DIR/ios.xcarchive" \
    -configuration "$CONFIGURATION" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    | xcpretty || xcodebuild archive \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS" \
        -archivePath "$BUILD_DIR/ios.xcarchive" \
        -configuration "$CONFIGURATION" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO

print_success "iOS 真机架构编译完成"

# ============================================
# 4. 编译 iOS 模拟器架构
# ============================================
print_header "4. 编译 iOS 模拟器架构 (x86_64, arm64)"

print_info "开始编译..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$BUILD_DIR/ios-simulator.xcarchive" \
    -configuration "$CONFIGURATION" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    | xcpretty || xcodebuild archive \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$BUILD_DIR/ios-simulator.xcarchive" \
        -configuration "$CONFIGURATION" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO

print_success "iOS 模拟器架构编译完成"

# ============================================
# 5. 创建 XCFramework
# ============================================
print_header "5. 创建 XCFramework"

print_info "开始创建 XCFramework..."
set -euo pipefail

DEVICE_ARCHIVE="$BUILD_DIR/ios.xcarchive"
SIM_ARCHIVE="$BUILD_DIR/ios-simulator.xcarchive"
OUTPUT_PATH="$BUILD_DIR/$XCFRAMEWORK_NAME"

resolve_framework() {
    local archive="$1"
    local expected="${archive}/Products/Library/Frameworks/${SCHEME}.framework"
    if [[ -d "$expected" && -f "${expected}/Info.plist" ]]; then
        echo "$expected"
        return 0
    fi
    local found
    found="$(find "$archive" -maxdepth 8 -type d -name "${SCHEME}.framework" 2>/dev/null | head -n 1 || true)"
    if [[ -n "${found}" && -f "${found}/Info.plist" ]]; then
        echo "$found"
        return 0
    fi
    return 1
}

resolve_library_with_modules() {
    local archive="$1"
    local out_dir="$2"
    mkdir -p "$out_dir"

    local lib=""
    lib="$(find "$archive" -maxdepth 12 -type f \( -name "lib${SCHEME}.a" -o -name "${SCHEME}.a" \) 2>/dev/null | head -n 1 || true)"
    if [[ -z "$lib" ]]; then
        lib="$(find "$archive" -maxdepth 12 -type f \( -name "lib${SCHEME}.dylib" -o -name "${SCHEME}.dylib" \) 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -z "$lib" ]]; then
        local obj=""
        obj="$(find "$archive" -maxdepth 12 -type f \( -name "${SCHEME}.o" -o -name "lib${SCHEME}.o" \) 2>/dev/null | head -n 1 || true)"
        if [[ -n "$obj" ]]; then
            lib="${out_dir}/lib${SCHEME}.a"
            /usr/bin/libtool -static -o "$lib" "$obj"
        fi
    fi

    if [[ -z "$lib" || ! -f "$lib" ]]; then
        return 1
    fi

    local staged_lib="${out_dir}/$(basename "$lib")"
    if [[ "$lib" != "$staged_lib" ]]; then
        cp -f "$lib" "$staged_lib"
    fi

    local module_dir=""
    module_dir="$(find "$archive" -maxdepth 14 -type d -name "${SCHEME}.swiftmodule" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$module_dir" && -d "$module_dir" ]]; then
        cp -R "$module_dir" "${out_dir}/"
    fi

    echo "$staged_lib"
    return 0
}

rm -rf "$OUTPUT_PATH"

if FW_DEVICE="$(resolve_framework "$DEVICE_ARCHIVE")" && FW_SIM="$(resolve_framework "$SIM_ARCHIVE")"; then
    print_success "检测到 Framework 产物:"
    print_info "device: $FW_DEVICE"
    print_info "sim:    $FW_SIM"
    xcodebuild -create-xcframework \
        -framework "$FW_DEVICE" \
        -framework "$FW_SIM" \
        -output "$OUTPUT_PATH"
else
    print_warning "未检测到有效 Framework，回退使用 -library 方式创建 XCFramework..."
    STAGING_DIR="${BUILD_DIR}/_xcframework_staging"
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"

    LIB_DEVICE="$(resolve_library_with_modules "$DEVICE_ARCHIVE" "${STAGING_DIR}/device")"
    LIB_SIM="$(resolve_library_with_modules "$SIM_ARCHIVE" "${STAGING_DIR}/simulator")"
    print_info "device lib: $LIB_DEVICE"
    print_info "sim lib:    $LIB_SIM"

    HDR_DIR="${STAGING_DIR}/headers"
    mkdir -p "$HDR_DIR"
    xcodebuild -create-xcframework \
        -library "$LIB_DEVICE" -headers "$HDR_DIR" \
        -library "$LIB_SIM" -headers "$HDR_DIR" \
        -output "$OUTPUT_PATH"
fi

print_success "XCFramework 创建完成"

# ============================================
# 6. 验证 XCFramework
# ============================================
print_header "6. 验证 XCFramework"

echo ""
print_info "XCFramework 结构:"
XCROOT="$BUILD_DIR/$XCFRAMEWORK_NAME"
ls -lR "$XCROOT"

echo ""
print_info "iOS 真机架构:"
resolve_bin() {
    local platform_dir="$1"
    local fw_bin="${platform_dir}/${SCHEME}.framework/${SCHEME}"
    if [[ -f "$fw_bin" ]]; then
        echo "$fw_bin"
        return 0
    fi
    local lib
    lib="$(find "$platform_dir" -maxdepth 3 -type f \( -name "lib${SCHEME}.a" -o -name "${SCHEME}.a" -o -name "lib${SCHEME}.dylib" -o -name "${SCHEME}.dylib" \) 2>/dev/null | head -1 || true)"
    if [[ -n "$lib" ]]; then
        echo "$lib"
        return 0
    fi
    return 1
}
DEVICE_BIN="$(resolve_bin "$XCROOT/ios-arm64")"
print_info "bin: $DEVICE_BIN"
lipo -info "$DEVICE_BIN" || true

echo ""
print_info "iOS 模拟器架构:"
SIM_BIN="$(resolve_bin "$XCROOT/ios-arm64_x86_64-simulator")"
print_info "bin: $SIM_BIN"
lipo -info "$SIM_BIN" || true

print_success "XCFramework 验证通过"

# ============================================
# 7. 生成编译报告
# ============================================
print_header "7. 生成编译报告"

REPORT_FILE="$BUILD_DIR/build-report.txt"

cat > "$REPORT_FILE" << EOF
=== HelpBot iOS SDK 本地编译报告 ===

编译时间: $(date)
编译配置: $CONFIGURATION
编译主机: $(hostname)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")

=== 环境信息 ===
$(sw_vers)

$(xcodebuild -version)

$(swift --version)

=== XCFramework 信息 ===
$(ls -lh "$XCROOT")

=== 架构信息 ===
iOS 真机:
bin: $DEVICE_BIN
$(lipo -info "$DEVICE_BIN" 2>&1 || true)

iOS 模拟器:
bin: $SIM_BIN
$(lipo -info "$SIM_BIN" 2>&1 || true)

=== 文件大小 ===
$(du -sh "$BUILD_DIR/$XCFRAMEWORK_NAME")

EOF

print_success "编译报告已生成: $REPORT_FILE"
cat "$REPORT_FILE"

# ============================================
# 8. 打包 XCFramework
# ============================================
print_header "8. 打包 XCFramework"

cd "$BUILD_DIR"
zip -r "$XCFRAMEWORK_NAME.zip" "$XCFRAMEWORK_NAME" > /dev/null
cd ..

print_success "XCFramework 已打包: $BUILD_DIR/$XCFRAMEWORK_NAME.zip"
ls -lh "$BUILD_DIR/$XCFRAMEWORK_NAME.zip"

# ============================================
# 9. 完成
# ============================================
print_header "🎉 编译完成!"

echo ""
print_success "编译产物位置:"
echo "  📦 XCFramework: $BUILD_DIR/$XCFRAMEWORK_NAME"
echo "  📦 压缩包: $BUILD_DIR/$XCFRAMEWORK_NAME.zip"
echo "  📄 编译报告: $BUILD_DIR/build-report.txt"

echo ""
print_info "下一步:"
echo "  1. 将 $XCFRAMEWORK_NAME 集成到您的项目"
echo "  2. 或分发 $XCFRAMEWORK_NAME.zip 给其他开发者"
echo "  3. 查看 GITHUB_ACTIONS_GUIDE.md 了解集成方式"

echo ""
print_success "✨ 编译成功完成!"
