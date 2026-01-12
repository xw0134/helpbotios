#!/usr/bin/env bash

# HelpBot iOS SDK 本地编译脚本
# 用途: 在 macOS 上本地编译 iOS SDK (作为 GitHub Actions 的备用方案)
# 使用: chmod +x build_local.sh && ./build_local.sh

set -euo pipefail  # 遇到错误立即退出；未定义变量报错；管道失败可感知

# ============================================
# 重要说明（兼容性/稳定性）
# - 推荐使用 bash 执行本脚本：./build_local.sh 或 bash build_local.sh
# - 在 macOS 上，/bin/sh 通常是 bash 的 POSIX 模式；若用 `sh build_local.sh` 运行，
#   可能触发历史遗留的输出行为差异，导致命令替换输出被污染（典型表现：路径里出现 "/-e"）。
# - 这里做“自举”保护：只要不是 bash，或 bash 正处于 POSIX 模式，就强制 exec bash 重跑。
# ============================================
if [[ -z "${BASH_VERSION:-}" ]]; then
    exec /usr/bin/env bash "$0" "$@"
else
    # bash 以 `sh` 身份运行时通常处于 POSIX 模式；此时强制切回标准 bash 模式更稳
    if shopt -qo posix; then
        exec /usr/bin/env bash "$0" "$@"
    fi
fi

# ============================================
# 配置区域
# ============================================
SCHEME="HelpBotSDK"
CONFIGURATION="${CONFIGURATION:-Release}"  # 可选: Debug, Release（允许通过环境变量覆盖）
BUILD_DIR="build"
XCFRAMEWORK_NAME="${SCHEME}.xcframework"
PRIVACY_MANIFEST_SOURCE="$(cd "$(dirname "$0")" && pwd)/HelpBotSDK/PrivacyInfo.xcprivacy"

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
    # 统一用 printf，避免 echo 在不同 shell/模式下对 -e 等参数处理不一致
    # 统一输出到 stderr：避免被命令替换 $(...) 捕获，污染路径变量
    printf '%b\n' "${BLUE}========================================${NC}" >&2
    printf '%b\n' "${BLUE}$1${NC}" >&2
    printf '%b\n' "${BLUE}========================================${NC}" >&2
}

print_success() {
    printf '%b\n' "${GREEN} $1${NC}" >&2
}

print_error() {
    printf '%b\n' "${RED} $1${NC}" >&2
}

print_warning() {
    printf '%b\n' "${YELLOW} $1${NC}" >&2
}

print_info() {
    printf '%b\n' "${BLUE} $1${NC}" >&2
}

# ============================================
# xcodebuild wrapper（CI 兼容：可选 xcpretty，不重复编译）
# ============================================
run_xcodebuild_archive() {
    local destination="$1"
    local archive_path="$2"
    local configuration="$3"
    local derived_data_path="$4"

    if command -v xcpretty &> /dev/null; then
        xcodebuild archive \
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
printf '\n' >&2
print_info "系统版本:"
sw_vers

printf '\n' >&2
print_info "Xcode 版本:"
xcodebuild -version

printf '\n' >&2
print_info "Swift 版本:"
swift --version

# 检查 Swift 版本 (推荐 5.10+)
SWIFT_VERSION="$(swift --version | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -n 1 || true)"
REQUIRED_VERSION="5.10"
if [[ -z "$SWIFT_VERSION" ]]; then
    print_warning "未能解析 Swift 版本号，跳过版本校验（不影响编译）。"
elif command -v bc &> /dev/null; then
    if (( $(echo "$SWIFT_VERSION < $REQUIRED_VERSION" | bc -l) )); then
        print_warning "Swift 版本 $SWIFT_VERSION 低于推荐版本 $REQUIRED_VERSION"
        print_warning "可能会遇到编译问题,建议升级 Xcode"
    else
        print_success "Swift 版本符合要求: $SWIFT_VERSION"
    fi
else
    print_warning "bc 未安装，跳过 Swift 版本比较（不影响编译）。"
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
DERIVED_DATA_DEVICE="$BUILD_DIR/DerivedData-ios"
run_xcodebuild_archive "generic/platform=iOS" "$BUILD_DIR/ios.xcarchive" "$CONFIGURATION" "$DERIVED_DATA_DEVICE"

print_success "iOS 真机架构编译完成"

# ============================================
# 4. 编译 iOS 模拟器架构
# ============================================
print_header "4. 编译 iOS 模拟器架构 (x86_64, arm64)"

print_info "开始编译..."
DERIVED_DATA_SIM="$BUILD_DIR/DerivedData-sim"
run_xcodebuild_archive "generic/platform=iOS Simulator" "$BUILD_DIR/ios-simulator.xcarchive" "$CONFIGURATION" "$DERIVED_DATA_SIM"

print_success "iOS 模拟器架构编译完成"

# ============================================
# 5. 创建 XCFramework
# ============================================
print_header "5. 创建 XCFramework"

print_info "开始创建 XCFramework..."

DEVICE_ARCHIVE="$BUILD_DIR/ios.xcarchive"
SIM_ARCHIVE="$BUILD_DIR/ios-simulator.xcarchive"
OUTPUT_PATH="$BUILD_DIR/$XCFRAMEWORK_NAME"

resolve_framework() {
    local archive="$1"
    local expected="${archive}/Products/Library/Frameworks/${SCHEME}.framework"
    if [[ -d "$expected" && -f "${expected}/Info.plist" ]]; then
        print_info "找到 Framework (标准路径): $expected"
        echo "$expected"
        return 0
    fi
    local found
    found="$(find "$archive" -maxdepth 10 -type d -name "${SCHEME}.framework" 2>/dev/null | head -n 1 || true)"
    if [[ -n "${found}" && -f "${found}/Info.plist" ]]; then
        print_info "找到 Framework (搜索路径): $found"
        echo "$found"
        return 0
    fi
    print_error "未找到 ${SCHEME}.framework 在 archive: $archive"
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

    # 1. 查找并复制二进制文件
    local lib=""
    lib=$(find "$archive" -maxdepth 12 -type f \( -name "lib${SCHEME}.a" -o -name "${SCHEME}.a" \) 2>/dev/null | head -n 1 || true)
    if [[ -z "$lib" ]]; then
        # 尝试查找 framework 内的二进制
        lib=$(find "$archive" -maxdepth 12 -type f -path "*/${SCHEME}.framework/${SCHEME}" 2>/dev/null | head -n 1 || true)
    fi

    if [[ -n "$lib" && -f "$lib" ]]; then
        cp -f "$lib" "${fw_dir}/${SCHEME}"
        print_info "已准备二进制 ($arch_name): $(basename "$lib")"
    else
        print_error "未找到二进制文件 ($arch_name)"
        return 1
    fi

    # 2. 查找并复制 Swift Modules
    local module_dir=""
    # 说明：Swift Package / archive 产物的 swiftmodule 位置可能在 DerivedData 内。
    # 为保证 SDK 交付结构稳定，这里同时搜索 archive + 本次指定的 DerivedData。
    module_dir=$(find "$archive" "$derived_data_path" -maxdepth 14 -type d -name "${SCHEME}.swiftmodule" 2>/dev/null | head -n 1 || true)
    if [[ -n "$module_dir" && -d "$module_dir" ]]; then
        cp -R "$module_dir" "${fw_dir}/Modules/"
        print_info "已准备 Swift Modules ($arch_name)"
    else
        print_error "未找到 Swift Modules ($arch_name)；请检查 BUILD_LIBRARY_FOR_DISTRIBUTION/DEFINES_MODULE 设置及 DerivedData 输出"
        return 1
    fi

    # 3. 查找并复制 Headers (如果是 ObjC 混编或生成的 Bridge)
    find "$archive" -maxdepth 14 -type f -name "*.h" -exec cp {} "${fw_dir}/Headers/" \; 2>/dev/null || true

    # 3.1 生成稳定的 Umbrella Header（确保 ObjC 可用的头入口存在）
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

    # 3.2 生成 module.modulemap（使 @import / #import 更稳定）
    if [[ ! -f "${fw_dir}/Modules/module.modulemap" ]]; then
        cat > "${fw_dir}/Modules/module.modulemap" << EOF
framework module ${SCHEME} {
  umbrella header "${SCHEME}.h"
  export *
  module * { export * }
}
EOF
    fi

    # 4. 生成 Info.plist
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

    # 5. 复制隐私清单
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

# 兜底校验：避免任何 stdout 污染导致的非法路径
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
# 6. 验证 XCFramework
# ============================================
print_header "6. 验证 XCFramework"

printf '\n' >&2
print_info "XCFramework 结构:"
XCROOT="$BUILD_DIR/$XCFRAMEWORK_NAME"
ls -lR "$XCROOT"

printf '\n' >&2
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

printf '\n' >&2
print_info "iOS 模拟器架构:"
SIM_BIN="$(resolve_bin "$XCROOT/ios-arm64_x86_64-simulator")"
print_info "bin: $SIM_BIN"
lipo -info "$SIM_BIN" || true

printf '\n' >&2
print_header "验证 Modules 和 Headers"

# 验证 iOS 真机 Modules
DEVICE_MODULES="$XCROOT/ios-arm64/${SCHEME}.framework/Modules"
if [[ -d "$DEVICE_MODULES" ]]; then
    print_success "iOS 真机 Modules 目录存在"
    print_info "内容:"
    ls -la "$DEVICE_MODULES" || true
    
    # 检查 swiftmodule
    DEVICE_SWIFTMODULE="$DEVICE_MODULES/${SCHEME}.swiftmodule"
    if [[ -d "$DEVICE_SWIFTMODULE" ]]; then
        print_success "iOS 真机 swiftmodule 存在"
        print_info "swiftmodule 内容:"
        ls -la "$DEVICE_SWIFTMODULE" || true
    else
        print_warning "iOS 真机 swiftmodule 不存在,但可能不影响使用"
    fi
else
    print_error "iOS 真机 Modules 目录不存在: $DEVICE_MODULES"
    exit 1
fi

# 验证 iOS 模拟器 Modules
SIM_MODULES="$XCROOT/ios-arm64_x86_64-simulator/${SCHEME}.framework/Modules"
if [[ -d "$SIM_MODULES" ]]; then
    print_success "iOS 模拟器 Modules 目录存在"
    print_info "内容:"
    ls -la "$SIM_MODULES" || true
    
    # 检查 swiftmodule
    SIM_SWIFTMODULE="$SIM_MODULES/${SCHEME}.swiftmodule"
    if [[ -d "$SIM_SWIFTMODULE" ]]; then
        print_success "iOS 模拟器 swiftmodule 存在"
        print_info "swiftmodule 内容:"
        ls -la "$SIM_SWIFTMODULE" || true
    else
        print_warning "iOS 模拟器 swiftmodule 不存在,但可能不影响使用"
    fi
else
    print_error "iOS 模拟器 Modules 目录不存在: $SIM_MODULES"
    exit 1
fi

# 验证 Headers (可选,Swift framework 可能没有 Headers)
DEVICE_HEADERS="$XCROOT/ios-arm64/${SCHEME}.framework/Headers"
if [[ -d "$DEVICE_HEADERS" ]]; then
    print_success "iOS 真机 Headers 目录存在"
    HEADER_COUNT=$(find "$DEVICE_HEADERS" -name "*.h" 2>/dev/null | wc -l || echo "0")
    print_info "Headers 数量: $HEADER_COUNT"
else
    print_info "iOS 真机 Headers 目录不存在 (纯 Swift framework 正常)"
fi

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
print_header " 编译完成!"

printf '\n' >&2
print_success "编译产物位置:"
echo "   XCFramework: $BUILD_DIR/$XCFRAMEWORK_NAME"
echo "   压缩包: $BUILD_DIR/$XCFRAMEWORK_NAME.zip"
echo "   编译报告: $BUILD_DIR/build-report.txt"

printf '\n' >&2
print_info "下一步:"
echo "  1. 将 $XCFRAMEWORK_NAME 集成到您的项目"
echo "  2. 或分发 $XCFRAMEWORK_NAME.zip 给其他开发者"
echo "  3. 查看 GITHUB_ACTIONS_GUIDE.md 了解集成方式"

printf '\n' >&2
print_success "编译成功完成!"
