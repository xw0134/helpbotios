#!/usr/bin/env bash
#
# HelpBot iOS SDK 构建脚本（仅 SDK）
#
# 目标：
# - 从 `SDK/iOS/HelpBotSDK`（Swift Package）构建标准交付形态：`HelpBotSDK.xcframework`
# - 强校验：必须包含 Modules/Headers（可 `import HelpBotSDK`）
# - 输出：
#   - `SDK/iOS/build/HelpBotSDK.xcframework`
#   - `SDK/iOS/build/HelpBotSDK.xcframework.zip`
#   - `SDK/iOS/build/build-report.txt`
#
# 约束：
# - 只在 macOS + Xcode 环境运行
# - 作为 SDK 构建入口，供 GitHub Actions / 本地使用
#

set -euo pipefail

# ============================================
# 重要说明（兼容性/稳定性）
# - 推荐使用 bash 执行本脚本：./build_sdk.sh 或 bash build_sdk.sh
# - 若被 sh/posix 模式执行，可能触发 echo 行为差异导致路径变量污染
# ============================================
if [[ -z "${BASH_VERSION:-}" ]]; then
    exec /usr/bin/env bash "$0" "$@"
else
    if shopt -qo posix; then
        exec /usr/bin/env bash "$0" "$@"
    fi
fi

# ============================================
# 配置区域
# ============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="${SCRIPT_DIR}/HelpBotSDK"
SCHEME="HelpBotSDK"
CONFIGURATION="${CONFIGURATION:-Release}"  # Debug / Release
BUILD_DIR="build"
XCFRAMEWORK_NAME="${SCHEME}.xcframework"
PRIVACY_MANIFEST_SOURCE="${PKG_DIR}/PrivacyInfo.xcprivacy"

# 颜色输出（只输出到 stderr，避免污染命令替换）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { printf '%b\n' "${BLUE}========================================${NC}" >&2; printf '%b\n' "${BLUE}$1${NC}" >&2; printf '%b\n' "${BLUE}========================================${NC}" >&2; }
print_success() { printf '%b\n' "${GREEN} $1${NC}" >&2; }
print_error() { printf '%b\n' "${RED} $1${NC}" >&2; }
print_warning() { printf '%b\n' "${YELLOW} $1${NC}" >&2; }
print_info() { printf '%b\n' "${BLUE} $1${NC}" >&2; }

# ============================================
# xcodebuild wrapper（CI 兼容：可选 xcpretty）
# ============================================
run_xcodebuild_archive() {
    local destination="$1"
    local archive_path="$2"
    local configuration="$3"
    local derived_data_path="$4"

    if command -v xcpretty &> /dev/null; then
        xcodebuild archive \
            -packagePath "$PKG_DIR" \
            -scheme "$SCHEME" \
            -destination "$destination" \
            -archivePath "$archive_path" \
            -derivedDataPath "$derived_data_path" \
            -configuration "$configuration" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            ONLY_ACTIVE_ARCH=NO \
            DEFINES_MODULE=YES \
            SWIFT_EMIT_MODULE_INTERFACE=YES \
            SWIFT_INSTALL_OBJC_HEADER=YES \
            SWIFT_OBJC_INTERFACE_HEADER_NAME="${SCHEME}-Swift.h" \
            GENERATE_INFOPLIST_FILE=YES \
            | xcpretty
    else
        xcodebuild archive \
            -packagePath "$PKG_DIR" \
            -scheme "$SCHEME" \
            -destination "$destination" \
            -archivePath "$archive_path" \
            -derivedDataPath "$derived_data_path" \
            -configuration "$configuration" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            ONLY_ACTIVE_ARCH=NO \
            DEFINES_MODULE=YES \
            SWIFT_EMIT_MODULE_INTERFACE=YES \
            SWIFT_INSTALL_OBJC_HEADER=YES \
            SWIFT_OBJC_INTERFACE_HEADER_NAME="${SCHEME}-Swift.h" \
            GENERATE_INFOPLIST_FILE=YES
    fi
}

# ============================================
# 1. 环境检查
# ============================================
print_header "1. 环境检查"

if [[ "${OSTYPE:-}" != "darwin"* ]]; then
    print_error "此脚本只能在 macOS 上运行"
    exit 1
fi
print_success "运行环境: macOS"

if ! command -v xcodebuild &> /dev/null; then
    print_error "未检测到 Xcode,请先安装 Xcode"
    exit 1
fi
print_success "Xcode 已安装"

if [[ ! -f "${PKG_DIR}/Package.swift" ]]; then
    print_error "未找到 Swift Package：${PKG_DIR}/Package.swift"
    print_error "请确认仓库完整，且 build_sdk.sh 位于 SDK/iOS 目录下"
    exit 1
fi
print_success "Swift Package 已就绪: ${PKG_DIR}/Package.swift"

printf '\n' >&2
print_info "系统版本:"
sw_vers

printf '\n' >&2
print_info "Xcode 版本:"
xcodebuild -version

printf '\n' >&2
print_info "Swift 版本:"
swift --version

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
DERIVED_DATA_DEVICE="$BUILD_DIR/DerivedData-ios"
run_xcodebuild_archive "generic/platform=iOS" "$BUILD_DIR/ios.xcarchive" "$CONFIGURATION" "$DERIVED_DATA_DEVICE"
print_success "iOS 真机架构编译完成"

# ============================================
# 4. 编译 iOS 模拟器架构（arm64 + x86_64）
# ============================================
print_header "4. 编译 iOS 模拟器架构 (x86_64, arm64)"
print_info "开始编译..."
DERIVED_DATA_SIM="$BUILD_DIR/DerivedData-sim"
run_xcodebuild_archive "generic/platform=iOS Simulator" "$BUILD_DIR/ios-simulator.xcarchive" "$CONFIGURATION" "$DERIVED_DATA_SIM"
print_success "iOS 模拟器架构编译完成"

# ============================================
# 5. 组装标准 Framework（确保 Modules/Headers 稳定存在）并创建 XCFramework
# ============================================
print_header "5. 创建 XCFramework"
print_info "开始创建 XCFramework..."

DEVICE_ARCHIVE="$BUILD_DIR/ios.xcarchive"
SIM_ARCHIVE="$BUILD_DIR/ios-simulator.xcarchive"
OUTPUT_PATH="$BUILD_DIR/$XCFRAMEWORK_NAME"

rm -rf "$OUTPUT_PATH"

STAGING_DIR="${BUILD_DIR}/_xcframework_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

assemble_framework() {
    local archive="$1"
    local arch_name="$2"
    local derived_data_path="$3"
    local target_dir="${STAGING_DIR}/${arch_name}"
    local fw_dir="${target_dir}/${SCHEME}.framework"
    mkdir -p "${fw_dir}/Modules"
    mkdir -p "${fw_dir}/Headers"

    # 1) 复制二进制
    local bin_path=""
    bin_path=$(find "$archive" -maxdepth 12 -type f -path "*/${SCHEME}.framework/${SCHEME}" 2>/dev/null | head -n 1 || true)
    if [[ -z "$bin_path" ]]; then
        bin_path=$(find "$archive" -maxdepth 12 -type f \( -name "lib${SCHEME}.a" -o -name "${SCHEME}.a" \) 2>/dev/null | head -n 1 || true)
    fi
    if [[ -z "$bin_path" || ! -f "$bin_path" ]]; then
        print_error "未找到二进制文件 ($arch_name)"
        return 1
    fi
    cp -f "$bin_path" "${fw_dir}/${SCHEME}"
    print_info "已准备二进制 ($arch_name)"

    # 2) 复制 Swift Modules（优先从 archive，其次从 DerivedData）
    local module_dir=""
    module_dir=$(find "$archive" "$derived_data_path" -maxdepth 14 -type d -name "${SCHEME}.swiftmodule" 2>/dev/null | head -n 1 || true)
    if [[ -z "$module_dir" || ! -d "$module_dir" ]]; then
        print_error "未找到 Swift Modules ($arch_name)；请检查 BUILD_LIBRARY_FOR_DISTRIBUTION/DEFINES_MODULE 设置及 DerivedData 输出"
        return 1
    fi
    cp -R "$module_dir" "${fw_dir}/Modules/"
    print_info "已准备 Swift Modules ($arch_name)"

    # 3) Headers：复制生成的 .h（若没有则生成 Umbrella Header，保证 ObjC 入口稳定）
    find "$archive" -maxdepth 14 -type f -name "*.h" -exec cp {} "${fw_dir}/Headers/" \; 2>/dev/null || true
    if [[ ! -f "${fw_dir}/Headers/${SCHEME}.h" ]]; then
        cat > "${fw_dir}/Headers/${SCHEME}.h" << EOF
/**
 * ${SCHEME} Umbrella Header
 *
 * 说明：
 * - 同时支持 Swift / Objective-C 接入。
 * - Swift 对外暴露的 @objc API 由 Xcode 生成的 "${SCHEME}-Swift.h" 提供（若存在）。
 */
#import <Foundation/Foundation.h>

#if __has_include("${SCHEME}-Swift.h")
#import "${SCHEME}-Swift.h"
#endif
EOF
    fi

    # 4) module.modulemap：让 @import / #import 更稳
    if [[ ! -f "${fw_dir}/Modules/module.modulemap" ]]; then
        cat > "${fw_dir}/Modules/module.modulemap" << EOF
framework module ${SCHEME} {
  umbrella header "${SCHEME}.h"
  export *
  module * { export * }
}
EOF
    fi

    # 5) Info.plist（必须）
    cat > "${fw_dir}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${SCHEME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.helpbot.${SCHEME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${SCHEME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

    # 6) 隐私清单（建议）
    if [[ -f "${PRIVACY_MANIFEST_SOURCE}" ]]; then
        cp -f "${PRIVACY_MANIFEST_SOURCE}" "${fw_dir}/PrivacyInfo.xcprivacy"
    else
        print_warning "未找到 PrivacyInfo.xcprivacy（建议补齐）：${PRIVACY_MANIFEST_SOURCE}"
    fi

    echo "${fw_dir}"
    return 0
}

FW_DEVICE="$(assemble_framework "$DEVICE_ARCHIVE" "ios-arm64" "$DERIVED_DATA_DEVICE" | tail -n 1)" || { print_error "组装 iOS 真机 Framework 失败"; exit 1; }
FW_SIM="$(assemble_framework "$SIM_ARCHIVE" "ios-arm64_x86_64-simulator" "$DERIVED_DATA_SIM" | tail -n 1)" || { print_error "组装 iOS 模拟器 Framework 失败"; exit 1; }

if [[ -d "$FW_DEVICE" && -f "$FW_DEVICE/Info.plist" && -d "$FW_SIM" && -f "$FW_SIM/Info.plist" ]]; then
    print_success "Framework 结构组装完成"
    xcodebuild -create-xcframework \
        -framework "$FW_DEVICE" \
        -framework "$FW_SIM" \
        -output "$OUTPUT_PATH"
else
    print_error "组装 Framework 失败"
    exit 1
fi
print_success "XCFramework 创建完成"

# ============================================
# 6. 验证 XCFramework（必须包含 Modules / Headers）
# ============================================
print_header "6. 验证 XCFramework"
XCROOT="$BUILD_DIR/$XCFRAMEWORK_NAME"

DEVICE_MODULES="$XCROOT/ios-arm64/${SCHEME}.framework/Modules"
SIM_MODULES="$XCROOT/ios-arm64_x86_64-simulator/${SCHEME}.framework/Modules"

if [[ ! -d "$DEVICE_MODULES/${SCHEME}.swiftmodule" ]]; then
    print_error "iOS 真机 swiftmodule 缺失: $DEVICE_MODULES/${SCHEME}.swiftmodule"
    exit 1
fi
if [[ ! -d "$SIM_MODULES/${SCHEME}.swiftmodule" ]]; then
    print_error "iOS 模拟器 swiftmodule 缺失: $SIM_MODULES/${SCHEME}.swiftmodule"
    exit 1
fi
if [[ ! -f "$DEVICE_MODULES/module.modulemap" ]]; then
    print_error "iOS 真机 modulemap 缺失: $DEVICE_MODULES/module.modulemap"
    exit 1
fi
if [[ ! -f "$SIM_MODULES/module.modulemap" ]]; then
    print_error "iOS 模拟器 modulemap 缺失: $SIM_MODULES/module.modulemap"
    exit 1
fi

DEVICE_HEADERS="$XCROOT/ios-arm64/${SCHEME}.framework/Headers"
SIM_HEADERS="$XCROOT/ios-arm64_x86_64-simulator/${SCHEME}.framework/Headers"
if [[ ! -d "$DEVICE_HEADERS" || ! -f "$DEVICE_HEADERS/${SCHEME}.h" ]]; then
    print_error "iOS 真机 Headers 缺失/不完整: $DEVICE_HEADERS"
    exit 1
fi
if [[ ! -d "$SIM_HEADERS" || ! -f "$SIM_HEADERS/${SCHEME}.h" ]]; then
    print_error "iOS 模拟器 Headers 缺失/不完整: $SIM_HEADERS"
    exit 1
fi

print_success "XCFramework 验证通过（Modules/Headers 完整）"

# ============================================
# 7. 生成编译报告
# ============================================
print_header "7. 生成编译报告"
REPORT_FILE="$BUILD_DIR/build-report.txt"

cat > "$REPORT_FILE" << EOF
=== HelpBot iOS SDK Build Report ===
time: $(date)
configuration: ${CONFIGURATION}
host: $(hostname)
git_commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
git_branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")

=== environment ===
$(sw_vers)
$(xcodebuild -version)
$(swift --version)

=== output ===
xcframework: ${BUILD_DIR}/${XCFRAMEWORK_NAME}
EOF

print_success "编译报告已生成: $REPORT_FILE"

# ============================================
# 8. 打包 XCFramework
# ============================================
print_header "8. 打包 XCFramework"
(
  cd "$BUILD_DIR"
  rm -f "$XCFRAMEWORK_NAME.zip" || true
  zip -qr "$XCFRAMEWORK_NAME.zip" "$XCFRAMEWORK_NAME"
)
print_success "XCFramework 已打包: $BUILD_DIR/$XCFRAMEWORK_NAME.zip"

# ============================================
# 9. 完成
# ============================================
print_header "编译完成!"
printf '\n' >&2
print_success "产物位置:"
printf '%b\n' "   XCFramework: $BUILD_DIR/$XCFRAMEWORK_NAME" >&2
printf '%b\n' "   压缩包:     $BUILD_DIR/$XCFRAMEWORK_NAME.zip" >&2
printf '%b\n' "   报告:       $BUILD_DIR/build-report.txt" >&2

