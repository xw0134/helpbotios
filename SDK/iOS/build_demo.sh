#!/usr/bin/env bash
#
# HelpBot iOS Demo 构建脚本
#
# 目标：
# - 只负责编译 Demo
#
# 输出：
# - SDK/iOS/build/HelpBotDemo.xcarchive
# - SDK/iOS/build/HelpBotDemo.xcarchive.zip
# - SDK/iOS/build/HelpBotDemo-unsigned.ipa（未签名，用于交付/后续签名；不可直接安装）
#

set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec /usr/bin/env bash "$0" "$@"
else
    if shopt -qo posix; then
        exec /usr/bin/env bash "$0" "$@"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="${SCRIPT_DIR}/HelpBotDemo"
SDK_XC="${SCRIPT_DIR}/HelpBotSDK.xcframework"
BUILD_DIR="${SCRIPT_DIR}/build"
CONFIGURATION="${CONFIGURATION:-Debug}" # Debug/Release
SCHEME="${SCHEME:-HelpBotDemo}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { printf '%b\n' "${BLUE}========================================${NC}" >&2; printf '%b\n' "${BLUE}$1${NC}" >&2; printf '%b\n' "${BLUE}========================================${NC}" >&2; }
print_success() { printf '%b\n' "${GREEN} $1${NC}" >&2; }
print_error() { printf '%b\n' "${RED} $1${NC}" >&2; }
print_info() { printf '%b\n' "${BLUE} $1${NC}" >&2; }

require_cmd() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        print_error "缺少必要命令: ${name}"
        exit 1
    fi
}

verify_xcframework() {
    local xc="$1"
    test -f "${xc}/Info.plist"
    test -d "${xc}/ios-arm64/HelpBotSDK.framework"
    test -d "${xc}/ios-arm64_x86_64-simulator/HelpBotSDK.framework"
    test -d "${xc}/ios-arm64/HelpBotSDK.framework/Modules/HelpBotSDK.swiftmodule"
    test -d "${xc}/ios-arm64_x86_64-simulator/HelpBotSDK.framework/Modules/HelpBotSDK.swiftmodule"
    test -f "${xc}/ios-arm64/HelpBotSDK.framework/Modules/module.modulemap"
    test -f "${xc}/ios-arm64_x86_64-simulator/HelpBotSDK.framework/Modules/module.modulemap"
    test -f "${xc}/ios-arm64/HelpBotSDK.framework/Headers/HelpBotSDK.h"
    test -f "${xc}/ios-arm64_x86_64-simulator/HelpBotSDK.framework/Headers/HelpBotSDK.h"
}

print_header "1. 环境检查"
if [[ "${OSTYPE:-}" != "darwin"* ]]; then
    print_error "此脚本只能在 macOS 上运行"
    exit 1
fi
require_cmd "xcodebuild"
require_cmd "zip"
require_cmd "ditto"
require_cmd "rm"
require_cmd "mkdir"
require_cmd "cp"
require_cmd "test"
print_success "基础命令检查通过"

if [[ ! -d "${DEMO_DIR}" ]]; then
    print_error "未找到 Demo 目录：${DEMO_DIR}"
    exit 1
fi
if [[ ! -d "${SDK_XC}" ]]; then
    print_error "未找到 SDK xcframework：${SDK_XC}"
    print_error "说明：本脚本不会构建 SDK，请先把 HelpBotSDK.xcframework 放到 SDK/iOS/ 目录下"
    exit 1
fi
verify_xcframework "${SDK_XC}"
print_success "Demo/SDK 路径检查通过"

print_header "2. 安装 XcodeGen（如缺失）"
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
    else
        print_error "未找到 xcodegen，且系统无 brew，无法自动安装"
        exit 1
    fi
fi
xcodegen --version >&2
print_success "XcodeGen 已就绪"

print_header "3. 生成 Xcode 工程（XcodeGen）"
cd "${DEMO_DIR}"
xcodegen generate
test -d ./HelpBotDemo.xcodeproj
print_success "HelpBotDemo.xcodeproj 已生成"

print_header "4. 编译模拟器（编译校验）"
if ! xcodebuild build \
    -project HelpBotDemo.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "platform=iOS Simulator,name=iPhone 15" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""; then
    print_info "模拟器目的地 iPhone 15 不可用，降级为 generic iOS Simulator"
    xcodebuild build \
      -project HelpBotDemo.xcodeproj \
      -scheme "${SCHEME}" \
      -configuration "${CONFIGURATION}" \
      -destination "generic/platform=iOS Simulator" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGN_IDENTITY=""
fi
print_success "模拟器编译通过"

print_header "5. Archive 真机（编译校验）"
cd "${SCRIPT_DIR}"
mkdir -p "${BUILD_DIR}"

cd "${DEMO_DIR}"
xcodebuild archive \
  -project HelpBotDemo.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -archivePath "${BUILD_DIR}/HelpBotDemo.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
print_success "Archive 生成完成: SDK/iOS/build/HelpBotDemo.xcarchive"

print_header "6. 打包 Archive"
cd "${BUILD_DIR}"
rm -f HelpBotDemo.xcarchive.zip || true
zip -qr HelpBotDemo.xcarchive.zip HelpBotDemo.xcarchive
print_success "Archive 已打包: SDK/iOS/build/HelpBotDemo.xcarchive.zip"

print_header "7. 生成未签名 IPA（用于交付/后续签名）"
APP_PATH="${BUILD_DIR}/HelpBotDemo.xcarchive/Products/Applications/HelpBotDemo.app"
if [[ ! -d "${APP_PATH}" ]]; then
    print_error "未找到 .app：${APP_PATH}"
    exit 1
fi

rm -rf "${BUILD_DIR}/_ipa_payload" || true
mkdir -p "${BUILD_DIR}/_ipa_payload/Payload"
ditto "${APP_PATH}" "${BUILD_DIR}/_ipa_payload/Payload/HelpBotDemo.app"

rm -f "${BUILD_DIR}/HelpBotDemo-unsigned.ipa" || true
(cd "${BUILD_DIR}/_ipa_payload" && zip -qr "${BUILD_DIR}/HelpBotDemo-unsigned.ipa" Payload)
rm -rf "${BUILD_DIR}/_ipa_payload" || true
print_success "已生成未签名 IPA: SDK/iOS/build/HelpBotDemo-unsigned.ipa"

