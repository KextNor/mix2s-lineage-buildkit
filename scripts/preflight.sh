#!/usr/bin/env bash
#
# 编译前置检查：在花 1-3 小时编译之前，先把常见的「必炸」问题找出来。
#
# 用法:
#   bash scripts/preflight.sh [源码目录] [分支]
#
#   源码目录  默认 $HOME/android/lineage-23.2
#   分支      默认 lineage-23.2（用于挑选期望的 manifest）
#
set -uo pipefail

SRC="${1:-$HOME/android/lineage-23.2}"
BRANCH="${2:-lineage-23.2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/manifests/$BRANCH.xml"

FAIL=0
WARN=0
ok()   { printf '  [ OK ] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  [WARN] %s\n' "$1"; WARN=$((WARN+1)); }

echo "== 1. 主机环境 =="
for c in repo git ccache python3; do
  command -v "$c" >/dev/null 2>&1 && ok "$c 可用" || bad "$c 不在 PATH（先跑 scripts/setup-ubuntu.sh 并重开终端）"
done

if [[ -d "$SRC" ]]; then
  FREE_GB=$(df -Pk "$SRC" | awk 'NR==2 {printf "%d", $4/1024/1024}')
  if [[ "$FREE_GB" -ge 300 ]]; then
    ok "磁盘剩余 ${FREE_GB} GB"
  else
    bad "磁盘剩余仅 ${FREE_GB} GB，建议 >= 400 GB"
  fi
else
  bad "源码目录不存在: $SRC"
fi

MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
SWAP_MB=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
TOTAL_MB=$((MEM_MB + SWAP_MB))
if [[ "$TOTAL_MB" -ge 24000 ]]; then
  ok "内存 + swap = $((TOTAL_MB / 1024)) GB"
else
  warn "内存 + swap 只有 $((TOTAL_MB / 1024)) GB，16 GB 内存请务必加 32 GB swap"
fi

echo
echo "== 2. 源码树 =="
if [[ -f "$SRC/build/envsetup.sh" ]]; then ok "build/envsetup.sh 存在"; else bad "源码树不完整（缺 build/envsetup.sh），repo sync 未完成"; fi
if [[ -d "$SRC/.repo" ]]; then ok ".repo 存在"; else bad "缺 .repo，未执行 repo init"; fi
if [[ -f "$SRC/vendor/lineage/config/common_full_phone.mk" ]]; then
  ok "vendor/lineage 已同步"
else
  bad "vendor/lineage 缺失，repo sync 未完成"
fi
if [[ -f "$SRC/.repo/local_manifests/polaris.xml" ]]; then
  ok "local manifest 已注入"
else
  bad ".repo/local_manifests/polaris.xml 不存在（用 scripts/init-source.sh 初始化）"
fi

echo
echo "== 3. 设备树 / 内核 / vendor（按 $BRANCH 期望检查）=="
if [[ ! -f "$MANIFEST" ]]; then
  bad "找不到 manifest: $MANIFEST"
else
  # manifest -> "path sha" 列表
  EXPECTED=$(python3 - "$MANIFEST" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in ET.parse(sys.argv[1]).getroot().findall('project'):
    print(p.get('path'), p.get('revision'))
PY
)
  if [[ -z "$EXPECTED" ]]; then
    bad "manifest 解析失败或没有 project 条目"
  else
    while read -r path sha; do
      [[ -z "${path:-}" ]] && continue
      if [[ ! -d "$SRC/$path" ]]; then
        bad "$path 缺失"
        continue
      fi
      actual=$(git -C "$SRC/$path" rev-parse HEAD 2>/dev/null || echo none)
      if [[ "$actual" == "$sha" ]]; then
        ok "$path @ ${sha:0:7}"
      else
        bad "$path 提交不符（期望 ${sha:0:7}，实际 ${actual:0:7}）"
      fi
    done <<< "$EXPECTED"
  fi
fi

echo
echo "== 4. 关键编译输入 =="
for f in \
  device/xiaomi/polaris/lineage_polaris.mk \
  device/xiaomi/polaris/BoardConfig.mk \
  device/xiaomi/polaris/device.mk \
  device/xiaomi/sdm845-common/BoardConfigCommon.mk \
  device/xiaomi/sdm845-common/sdm845.mk \
  kernel/xiaomi/sdm845/Makefile \
  kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/mi845_defconfig \
  vendor/xiaomi/polaris/polaris-vendor.mk \
  vendor/xiaomi/sdm845-common/sdm845-common-vendor.mk \
  hardware/xiaomi/Android.bp
do
  [[ -e "$SRC/$f" ]] && ok "$f" || bad "$f 缺失"
done

echo
echo "== 5. ccache =="
if command -v ccache >/dev/null 2>&1; then
  ccache -s 2>/dev/null | grep -E 'Max cache size|Cache size' | sed 's/^/  /'
  if [[ -z "${USE_CCACHE:-}" ]]; then
    warn "当前 shell 未设置 USE_CCACHE=1（build.sh 会自动设置）"
  else
    ok "USE_CCACHE=$USE_CCACHE"
  fi
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "结论：$FAIL 个错误，$WARN 个警告 —— 可以开始编译。"
  echo "  bash \"$ROOT/scripts/build.sh\" \"$SRC\""
  exit 0
else
  echo "结论：$FAIL 个错误，$WARN 个警告 —— 先修上面的 [FAIL]，别急着编译。"
  exit 1
fi
