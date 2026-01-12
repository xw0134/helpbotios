#!/usr/bin/env bash
#
# 兼容入口（请使用 build_sdk.sh）
#
# 历史原因：
# - 早期仓库用 `build_local.sh` 作为 iOS SDK 构建脚本入口
# - 现在已拆分为更清晰的入口：`build_sdk.sh`（仅 SDK）+ `build_demo.sh`（仅 Demo）
#
# 说明：
# - 本文件保留仅用于兼容旧文档/旧 CI；内部直接转调 `build_sdk.sh`
# - 请不要在新脚本/新工作流中继续引用本文件
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_SCRIPT="${SCRIPT_DIR}/build_sdk.sh"

if [[ ! -f "${SDK_SCRIPT}" ]]; then
  echo "[build_local.sh] 未找到 ${SDK_SCRIPT}，请检查仓库是否完整" >&2
  exit 1
fi

exec /usr/bin/env bash "${SDK_SCRIPT}" "$@"
