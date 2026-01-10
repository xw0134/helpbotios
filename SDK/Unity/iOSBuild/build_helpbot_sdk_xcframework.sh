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
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
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
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
popd

# 寻找 Framework 产物（Discovery-based）
resolve_fw() {
    local archive="$1"
    local expected="${archive}/Products/Library/Frameworks/HelpBotSDK.framework"
    if [[ -d "${expected}" ]]; then
        echo "${expected}"
        return 0
    fi
    # 尝试搜索
    local found
    found=$(find "${archive}" -name "HelpBotSDK.framework" -type d | head -n 1 || true)
    if [[ -n "${found}" ]]; then
        echo "${found}"
        return 0
    fi
    return 1
}

DEVICE_FRAMEWORK=$(resolve_fw "${IOS_DEVICE_ARCHIVE}" || true)
SIM_FRAMEWORK=$(resolve_fw "${IOS_SIM_ARCHIVE}" || true)

if [[ -z "${DEVICE_FRAMEWORK}" || -z "${SIM_FRAMEWORK}" ]]; then
    echo "[HelpBotSDK] ERROR: framework not found in archives. Trying manual assembly..."
    # 调用之前的手动组装逻辑作为兜底
    # 这里为了简便，如果上面那个不行，我们就不在脚本里套娃了，直接增加搜寻结果
    echo "Archives contents (Products):"
    ls -R "${TMP}"/*/Products || true
    exit 2
fi

rm -rf "${OUT_XCFRAMEWORK}"
echo "[HelpBotSDK] create-xcframework"
echo "DEVICE_FRAMEWORK: ${DEVICE_FRAMEWORK}"
echo "SIM_FRAMEWORK: ${SIM_FRAMEWORK}"
echo "OUT_XCFRAMEWORK: ${OUT_XCFRAMEWORK}"

xcodebuild -create-xcframework \
  -framework "${DEVICE_FRAMEWORK}" \
  -framework "${SIM_FRAMEWORK}" \
  -output "${OUT_XCFRAMEWORK}"

echo "[HelpBotSDK] output=${OUT_XCFRAMEWORK}"

