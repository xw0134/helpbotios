#!/usr/bin/env bash
#
# HelpBot iOS Demo 构建脚本（仅 Demo）
#
# 目标：
# - 只负责编译 Demo（不构建 SDK 源码）
# - Demo 必须通过 `../HelpBotSDK.xcframework`（二进制交付形态）集成
#
# 输出：
# - `SDK/iOS/build/HelpBotDemo.xcarchive`
# - `SDK/iOS/build/HelpBotDemo.xcarchive.zip`
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
CONFIGURATION="${CONFIGURATION:-Debug}" # Debug/Release

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { printf '%b\n' "${BLUE}========================================${NC}" >&2; printf '%b\n' "${BLUE}$1${NC}" >&2; printf '%b\n' "${BLUE}========================================${NC}" >&2; }
print_success() { printf '%b\n' "${GREEN} $1${NC}" >&2; }
print_error() { printf '%b\n' "${RED} $1${NC}" >&2; }

print_header "1. 环境检查"
if [[ "${OSTYPE:-}" != "darwin"* ]]; then
    print_error "此脚本只能在 macOS 上运行"
    exit 1
fi
if ! command -v xcodebuild &> /dev/null; then
    print_error "未检测到 xcodebuild（请安装 Xcode）"
    exit 1
fi
if [[ ! -d "${DEMO_DIR}" ]]; then
    print_error "未找到 Demo 目录：${DEMO_DIR}"
    exit 1
fi
if [[ ! -d "${SDK_XC}" ]]; then
    print_error "未找到 SDK xcframework：${SDK_XC}"
    print_error "说明：本脚本不会构建 SDK，请先把 HelpBotSDK.xcframework 放到 SDK/iOS/ 目录下"
    exit 1
fi
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
xcodebuild build \
  -project HelpBotDemo.xcodeproj \
  -scheme HelpBotDemo \
  -configuration "${CONFIGURATION}" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
print_success "模拟器编译通过"

print_header "5. Archive 真机（编译校验）"
cd "${SCRIPT_DIR}"
mkdir -p ./build

cd "${DEMO_DIR}"
xcodebuild archive \
  -project HelpBotDemo.xcodeproj \
  -scheme HelpBotDemo \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -archivePath ../build/HelpBotDemo.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
print_success "Archive 生成完成: SDK/iOS/build/HelpBotDemo.xcarchive"

print_header "6. 打包 Archive"
cd "${SCRIPT_DIR}/build"
rm -f HelpBotDemo.xcarchive.zip || true
zip -qr HelpBotDemo.xcarchive.zip HelpBotDemo.xcarchive
print_success "Archive 已打包: SDK/iOS/build/HelpBotDemo.xcarchive.zip"

