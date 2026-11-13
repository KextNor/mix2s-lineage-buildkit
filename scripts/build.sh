#!/usr/bin/env bash
#
# 编译 LineageOS for polaris
#
# 用法:
#   bash scripts/build.sh [源码目录] [任务]
#
#   任务默认 brunch（完整 ROM zip），其它可用值：bacon / recoveryimage
#
set -euo pipefail

SRC="${1:-$HOME/android/lineage-23.2}"
TARGET="${2:-brunch}"

cd "$SRC"

if [[ ! -f build/envsetup.sh ]]; then
  echo "$SRC 不是有效的 Android 源码树（缺 build/envsetup.sh）。" >&2
  exit 1
fi

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export LC_ALL=C

# shellcheck disable=SC1091
source build/envsetup.sh

echo "==> breakfast polaris"
breakfast polaris

echo "==> $TARGET polaris"
case "$TARGET" in
  brunch) brunch polaris ;;
  bacon)  mka bacon ;;
  recoveryimage) mka recoveryimage ;;
  *) echo "未知任务: $TARGET" >&2; exit 1 ;;
esac

echo "==> 产物目录: $SRC/out/target/product/polaris"
ls -lh "$SRC/out/target/product/polaris"/*.zip 2>/dev/null || true
ls -lh "$SRC/out/target/product/polaris"/recovery.img 2>/dev/null || true
