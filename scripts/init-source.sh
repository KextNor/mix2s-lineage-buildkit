#!/usr/bin/env bash
#
# 初始化 LineageOS 源码树并注入本仓库的 local manifest
#
# 用法:
#   bash scripts/init-source.sh [源码目录] [manifest 名称]
#
#   源码目录     默认 $HOME/android/lineage-23.2
#   manifest 名称 默认 lineage-23.2；回退官方稳定版用 lineage-22.2
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$HOME/android/lineage-23.2}"
BRANCH="${2:-lineage-23.2}"

if [[ ! -f "$ROOT/manifests/$BRANCH.xml" ]]; then
  echo "找不到 manifests/$BRANCH.xml，可选值：$(ls "$ROOT/manifests" | sed 's/\.xml$//' | tr '\n' ' ')" >&2
  exit 1
fi

if ! command -v repo >/dev/null 2>&1; then
  echo "repo 不在 PATH 中，请先运行 scripts/setup-ubuntu.sh 并重开终端。" >&2
  exit 1
fi

mkdir -p "$SRC"
cd "$SRC"

# repo init 是幂等的；每次都执行，方便在同一目录切换 23.2 / 22.2
echo "==> repo init ($BRANCH)"
repo init -u https://github.com/LineageOS/android.git -b "$BRANCH" --git-lfs --no-clone-bundle

echo "==> 写入 local manifest: $BRANCH.xml"
mkdir -p .repo/local_manifests
cp -f "$ROOT/manifests/$BRANCH.xml" .repo/local_manifests/polaris.xml

echo "==> repo sync（首次约 60-120 GB，视网络而定）"
repo sync -c -j"$(nproc)" --force-sync --no-clone-bundle --no-tags

cat <<EOF

完成。源码目录: $SRC
下一步（可选）：用仓库内自带的设备树覆盖同步结果
  bash "$ROOT/scripts/install-bundled-device-trees.sh" "$SRC"
然后开始编译
  bash "$ROOT/scripts/build.sh" "$SRC"
EOF
