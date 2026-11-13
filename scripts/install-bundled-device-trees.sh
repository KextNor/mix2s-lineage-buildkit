#!/usr/bin/env bash
#
# 使用本仓库自带的设备树快照覆盖源码树中的 device/xiaomi/*
# 适用场景：上游分支被删/被改、或想完全使用本仓库固定版本。
# 注意：会覆盖目标目录中的同名文件（--delete）。
#
# 用法: bash scripts/install-bundled-device-trees.sh [源码目录]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$HOME/android/lineage-23.2}"

if [[ ! -d "$SRC/device/xiaomi" ]]; then
  echo "$SRC/device/xiaomi 不存在，请先完成 repo sync。" >&2
  exit 1
fi

command -v rsync >/dev/null 2>&1 || { echo "缺少 rsync" >&2; exit 1; }

for d in polaris sdm845-common; do
  echo "==> device/xiaomi/$d"
  mkdir -p "$SRC/device/xiaomi/$d"
  # 排除 .git：repo sync 的项目目录里自带 .git，删掉会让 repo 认为项目损坏
  rsync -a --delete --exclude=.git "$ROOT/device/xiaomi/$d/" "$SRC/device/xiaomi/$d/"
done

echo "完成。"
