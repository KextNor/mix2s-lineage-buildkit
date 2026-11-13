#!/usr/bin/env bash
#
# Ubuntu 22.04 / 24.04 编译环境一键准备
# 用法: bash scripts/setup-ubuntu.sh
#
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "请不要用 root 运行，用你的普通用户（脚本内部会调用 sudo）。" >&2
  exit 1
fi

echo "==> 安装编译依赖"
sudo apt update
sudo apt install -y \
  bc bison build-essential ccache curl erofs-utils flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick kmod protobuf-compiler python3-protobuf \
  lib32readline-dev lib32z1-dev libdw-dev libelf-dev libgnutls28-dev lz4 \
  libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc xxd zip zlib1g-dev python3 unzip

echo "==> 安装 repo 工具到 ~/bin"
mkdir -p "$HOME/bin"
if [[ ! -x "$HOME/bin/repo" ]]; then
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
  chmod a+x "$HOME/bin/repo"
fi
# 如果 storage.googleapis.com 无法访问，可改用清华镜像：
#   curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o "$HOME/bin/repo"

if ! grep -qs 'HOME/bin' "$HOME/.profile"; then
  echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.profile"
fi

echo "==> 配置 ccache（50 GB，开启压缩）"
ccache -M 50G
ccache -o compression=true

echo "==> 检查 git 身份"
if ! git config --global user.name >/dev/null || ! git config --global user.email >/dev/null; then
  echo "尚未配置 git 身份，请执行（换成你自己的信息）："
  echo '  git config --global user.name  "Your Name"'
  echo '  git config --global user.email "you@example.com"'
fi

echo "==> 检查磁盘（建议剩余 400 GB 以上）"
df -h "$HOME" || true

cat <<'EOF'

完成。接下来请先打开一个新终端（或执行 source ~/.profile）让 PATH 生效，
然后按 README 的「初始化源码」步骤继续。
EOF
