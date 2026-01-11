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
pushd "${PKG_DIR}"
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS" \
  -archivePath "${IOS_DEVICE_ARCHIVE}" \
  -derivedDataPath "${TMP}/DerivedData-ios" \
  -configuration "${CONFIGURATION}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  DEFINES_MODULE=YES \
  SWIFT_EMIT_MODULE_INTERFACE=YES \
  SWIFT_INSTALL_OBJC_HEADER=YES \
  SWIFT_OBJC_INTERFACE_HEADER_NAME="HelpBotSDK-Swift.h"
popd

echo "[HelpBotSDK] archive iOS (simulator)"
pushd "${PKG_DIR}"
xcodebuild archive \
  -scheme HelpBotSDK \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${IOS_SIM_ARCHIVE}" \
  -derivedDataPath "${TMP}/DerivedData-sim" \
  -configuration "${CONFIGURATION}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  DEFINES_MODULE=YES \
  SWIFT_EMIT_MODULE_INTERFACE=YES \
  SWIFT_INSTALL_OBJC_HEADER=YES \
  SWIFT_OBJC_INTERFACE_HEADER_NAME="HelpBotSDK-Swift.h"
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
    local target_file="arm64-apple-ios.swiftinterface"
    local arch_tag="iphoneos"
    if [[ "$arch_name" == *"simulator"* ]]; then
        target_file="arm64-apple-ios-simulator.swiftinterface"
        arch_tag="iphonesimulator"
    fi

    echo "Searching modules for ${arch_name} (looking for ${target_file} with tag ${arch_tag})..." >&2
    
    # 优先在各自的 DerivedData 目录下找，确保不串号
    local dd_dir="${TMP}/DerivedData-ios"
    if [[ "$arch_tag" == "iphonesimulator" ]]; then
        dd_dir="${TMP}/DerivedData-sim"
    fi

    local candidates
    candidates=$(find "${archive}" "${dd_dir}" -type d -name "HelpBotSDK.swiftmodule" | grep -v "Index.noindex" || true)
    
    for cand in $candidates; do
        if [[ -f "${cand}/${target_file}" || -f "${cand}/arm64.swiftinterface" ]]; then
            module_dir="$cand"
            break
        fi
    done
    
    if [[ -n "$module_dir" && -d "$module_dir" ]]; then
        cp -R "$module_dir" "${target_fw}/Modules/"
        echo "Found Swift Modules: $module_dir" >&2
    else
        echo "WARNING: Swift Modules not found for ${arch_name} in archive or ${dd_dir}" >&2
        # 兜底：尝试找任何符合的文件
        local interface
        interface=$(find "${archive}" "${dd_dir}" -name "${target_file}" | head -n 1 || true)
        if [[ -n "$interface" ]]; then
            cp "$interface" "${target_fw}/Modules/"
            echo "Found Swift Interface file: $interface" >&2
        fi
    fi

    # 3. 复制 Headers
    echo "Searching headers for ${arch_name} (including ${dd_dir})..." >&2
    # 寻找生成的 Swift Header 或公共头文件
    find "${archive}" "${dd_dir}" -name "*.h" -not -path "*/Index.noindex/*" -exec cp -f {} "${target_fw}/Headers/" \; 2>/dev/null || true

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

validate_framework_structure() {
    local fw_dir="$1"
    local label="$2"

    local modules_dir="${fw_dir}/Modules"
    local swiftmodule_dir="${modules_dir}/HelpBotSDK.swiftmodule"
    local headers_dir="${fw_dir}/Headers"

    if [[ ! -d "${modules_dir}" ]]; then
        echo "[HelpBotSDK] ERROR: missing Modules (${label}): ${modules_dir}" >&2
        return 1
    fi
    if [[ ! -d "${swiftmodule_dir}" ]]; then
        echo "[HelpBotSDK] ERROR: missing swiftmodule (${label}): ${swiftmodule_dir}" >&2
        return 1
    fi
    if [[ ! -d "${headers_dir}" ]]; then
        echo "[HelpBotSDK] ERROR: missing Headers (${label}): ${headers_dir}" >&2
        return 1
    fi
    if ! find "${headers_dir}" -maxdepth 1 -type f -name "*.h" | grep -q .; then
        echo "[HelpBotSDK] WARNING: Headers is empty (${label}): ${headers_dir} (Normal for pure Swift)" >&2
    fi

    echo "[HelpBotSDK] OK: ${label} framework structure valid" >&2
    return 0
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

validate_framework_structure "${STAGED_DEVICE_FW}" "ios-device" || exit 3
validate_framework_structure "${STAGED_SIM_FW}" "ios-simulator" || exit 3

rm -rf "${OUT_XCFRAMEWORK}"
echo "[HelpBotSDK] create-xcframework"
xcodebuild -create-xcframework \
  -framework "${STAGED_DEVICE_FW}" \
  -framework "${STAGED_SIM_FW}" \
  -output "${OUT_XCFRAMEWORK}"

echo "[HelpBotSDK] output=${OUT_XCFRAMEWORK}"

