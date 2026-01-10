#!/usr/bin/env bash
set -euo pipefail

# 用 Swift Package（SDK/iOS/HelpBotSDK）构建可分发的 HelpBotSDK.xcframework（带 Modules）。
# 约束：不修改 SDK/iOS 目录源码，只做编译产物。

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output_xcframework_path>"
  exit 1
fi

OUT_XCFRAMEWORK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PKG_DIR="${ROOT_DIR}/SDK/iOS/HelpBotSDK"
CONFIGURATION="${CONFIGURATION:-Release}"

TMP="${ROOT_DIR}/SDK/Unity/_tmp_helpbot_sdk_build"
rm -rf "${TMP}"
mkdir -p "${TMP}"

IOS_DEVICE_ARCHIVE="${TMP}/HelpBotSDK-iOS.xcarchive"
IOS_SIM_ARCHIVE="${TMP}/HelpBotSDK-iOS-sim.xcarchive"

set -x

echo "[HelpBotSDK] archive iOS (device)"
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS" \
  -archivePath "${IOS_DEVICE_ARCHIVE}" \
  -derivedDataPath "${TMP}/DerivedData" \
  -workspace "${TMP}/HelpBotSDK.xcworkspace" \
  -configuration "${CONFIGURATION}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
  -quiet || true

# Swift Package 默认没有 workspace，这里用 xcodebuild -scheme -package-path 方式构建 framework 更稳
echo "[HelpBotSDK] archive iOS (device) via pushd"
pushd "${PKG_DIR}"
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS" \
  -archivePath "${IOS_DEVICE_ARCHIVE}" \
  -derivedDataPath "${TMP}/DerivedData" \
  -configuration "${CONFIGURATION}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  DEFINES_MODULE=YES \
  SWIFT_EMIT_MODULE_INTERFACE=YES
popd

echo "[HelpBotSDK] archive iOS (simulator)"
pushd "${PKG_DIR}"
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${IOS_SIM_ARCHIVE}" \
  -derivedDataPath "${TMP}/DerivedData" \
  -configuration "${CONFIGURATION}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  DEFINES_MODULE=YES \
  SWIFT_EMIT_MODULE_INTERFACE=YES
popd

echo "[HelpBotSDK] Archive listing for debug:" >&2
find "${TMP}" -maxdepth 10 -not -path "*/.*" >&2

# 手动组装 Framework 结构
assemble_fw_manually() {
    local archive="$1"
    local arch_name="$2"
    local target_fw="${TMP}/staged/${arch_name}/HelpBotSDK.framework"
    mkdir -p "${target_fw}/Modules"
    mkdir -p "${target_fw}/Headers"

    echo "--- Assembling ${arch_name} ---" >&2
    
    # 1. 查找并复制二进制文件
    local lib=""
    # 优先找 framework 路径下的二进制，排除 DerivedData
    lib=$(find "$archive" -path "*/HelpBotSDK.framework/HelpBotSDK" -type f | grep -v "DerivedData" | head -n 1 || true)
    if [[ -z "$lib" ]]; then
        lib=$(find "$archive" -type f \( -name "libHelpBotSDK.a" -o -name "HelpBotSDK.a" -o -name "HelpBotSDK" \) | grep -v "DerivedData" | head -n 1 || true)
    fi

    if [[ -n "$lib" && -f "$lib" ]]; then
        cp -f "$lib" "${target_fw}/HelpBotSDK"
        echo "Found binary: $lib" >&2
    else
        echo "ERROR: Binary not found in $archive" >&2
        return 1
    fi

    # 2. 查找并复制 Swift Modules
    local module_dir=""
    # 在整个 TMP 目录下找，包括 DerivedData，因为 SP 编译有时会把模块界面放那
    module_dir=$(find "${archive}" "${TMP}/DerivedData" -type d -name "HelpBotSDK.swiftmodule" | grep -v "Index.noindex" | head -n 1 || true)
    if [[ -n "$module_dir" && -d "$module_dir" ]]; then
        cp -R "$module_dir" "${target_fw}/Modules/"
        echo "Found Swift Modules: $module_dir" >&2
    else
        echo "WARNING: Swift Modules not found in archive or DerivedData" >&2
        # 尝试找 .swiftinterface
        local interface
        interface=$(find "${archive}" "${TMP}/DerivedData" -name "HelpBotSDK.swiftinterface" | head -n 1 || true)
        if [[ -n "$interface" ]]; then
            cp "$interface" "${target_fw}/Modules/"
            echo "Found Swift Interface: $interface" >&2
        fi
    fi

    # 3. 复制 Headers
    find "$archive" -name "*.h" -not -path "*/DerivedData/*" -exec cp {} "${target_fw}/Headers/" \; 2>/dev/null || true

    # 4. 生成 Info.plist
    cat > "${target_fw}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>HelpBotSDK</string>
    <key>CFBundleIdentifier</key>
    <string>com.helpbot.HelpBotSDK</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HelpBotSDK</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
    echo "${target_fw}"
}

echo "[HelpBotSDK] Attempting manual assembly..."
STAGED_DEVICE_FW=$(assemble_fw_manually "${IOS_DEVICE_ARCHIVE}" "ios-arm64") || { echo "Device assembly failed"; exit 3; }
STAGED_SIM_FW=$(assemble_fw_manually "${IOS_SIM_ARCHIVE}" "ios-arm64_x86_64-simulator") || { echo "Sim assembly failed"; exit 3; }

echo "DEVICE_FW: ${STAGED_DEVICE_FW}"
echo "SIM_FW: ${STAGED_SIM_FW}"

if [[ ! -d "${STAGED_DEVICE_FW}" || ! -d "${STAGED_SIM_FW}" ]]; then
    echo "[HelpBotSDK] ERROR: Manual assembly failed - paths do not exist."
    exit 3
fi

rm -rf "${OUT_XCFRAMEWORK}"
echo "[HelpBotSDK] create-xcframework"
xcodebuild -create-xcframework \
  -framework "${STAGED_DEVICE_FW}" \
  -framework "${STAGED_SIM_FW}" \
  -output "${OUT_XCFRAMEWORK}"

echo "[HelpBotSDK] output=${OUT_XCFRAMEWORK}"

