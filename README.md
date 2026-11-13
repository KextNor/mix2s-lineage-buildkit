# Mi MIX 2S (polaris) — LineageOS 23.2 编译套件

小米 MIX 2S（代号 **polaris**）的 LineageOS 23.2 编译仓库：设备树快照、固定版本的 manifest、Ubuntu 环境准备和编译脚本。

目标只有一个：**把「源码找不齐、同步到一半报错、编译一半炸掉」变成几条可以重复执行的命令。**

---

## 一、先说清楚现状（很重要）

| 项目 | 情况 |
|------|------|
| LineageOS 23.2 | **Android 16**（AOSP `android-16.0.0_r4`） |
| polaris 官方支持 | 官方发布到 **22.2（Android 15）**，23.2 没有官方包 |
| polaris 23.2 设备树 | 存在，但和 `lineage-22.2` 是**同一个提交**（`1b46255`），并不是为 Android 16 重做的 |
| 内核 | `LineageOS/android_kernel_xiaomi_sdm845` **没有 lineage-23.2 分支**，最后可用是 22.2 |
| Vendor blobs | `TheMuppets` 的 polaris / sdm845-common 仓库**没有 lineage-23.2 分支**，最后可用是 22.2 |
| `hardware/xiaomi` | 有真正的 23.2 分支 |

所以本仓库的 23.2 方案 = **Android 16 系统 + 22.2 的设备树/内核/vendor**。

这意味着：

- 它可以作为「23.2 移植的起点」，但**属于实验性组合**；
- 编译可能失败，即使编译成功也**不保证能开机**；
- 任何「编译成功」都不能当成实机可用，必须刷机验证。

仓库同时提供 `manifests/lineage-22.2.xml` 作为**官方稳定回退方案**，用同一条命令切换。

---

## 二、仓库结构

```
manifests/
  lineage-23.2.xml          # 23.2 实验组合，全部按 commit SHA 固定
  lineage-22.2.xml          # 22.2 官方稳定组合，回退用
device/xiaomi/
  polaris/                  # polaris 设备树快照（lineage-23.2 分支）
  sdm845-common/            # sdm845 公共设备树快照（lineage-23.2 分支）
scripts/
  setup-ubuntu.sh           # 安装依赖、repo、配置 ccache
  init-source.sh            # repo init + 注入 local manifest + repo sync
  install-bundled-device-trees.sh  # 用仓库内设备树覆盖同步结果（可选）
  build.sh                  # breakfast + brunch
```

`device/` 里的文件是上游快照，用于**离线备份和固定版本**；正常编译以 `repo sync` 拉下来的为准，两者当前内容一致。

---

## 三、硬件和系统要求

| 项目 | 最低 | 建议 |
|------|------|------|
| 系统 | Ubuntu 22.04 LTS | **Ubuntu 24.04 LTS**（全新安装，别用 WSL） |
| CPU | 4 核 | 8 核以上 |
| 内存 | 16 GB | 32 GB |
| Swap | 16 GB | 32 GB（16 GB 内存必须加，否则容易 `cc1plus killed`） |
| 磁盘 | 400 GB 空闲 | 500 GB NVMe SSD |
| 网络 | 能稳定访问 github.com | 配置代理，`repo sync` 首次约 60–120 GB |

> 磁盘按官方要求：lineage-21 及以上建议 400 GB 起，开启 ccache 还要更多。

---

## 四、编译步骤

### 1. 安装 Ubuntu 依赖

```bash
git clone https://github.com/KextNor/mix2s-lineage-buildkit.git
cd mix2s-lineage-buildkit
bash scripts/setup-ubuntu.sh
```

脚本会安装官方依赖列表、把 `repo` 放到 `~/bin`、配置 50 GB ccache。

装完后**重开终端**，确认：

```bash
repo --version
ccache -s
```

> 如果 `storage.googleapis.com` 下载 repo 失败，用清华镜像：
> `curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o ~/bin/repo && chmod a+x ~/bin/repo`

### 2. 准备 swap（16 GB 内存的机器必做）

```bash
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

确认生效：

```bash
free -h
swapon --show
```

### 3. 配置 ccache（可写进 `~/.bashrc`）

```bash
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 50G
ccache -o compression=true
```

### 4. 初始化源码并同步

```bash
bash scripts/init-source.sh ~/android/lineage-23.2 lineage-23.2
```

这条命令做三件事：

1. `repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle`
2. 把 `manifests/lineage-23.2.xml` 复制到 `.repo/local_manifests/polaris.xml`
3. `repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags`

> 想先用官方稳定版练手：把最后的 `lineage-23.2` 换成 `lineage-22.2`。

同步中断是常态，直接重新执行同一条命令即可；`--force-sync` 会修正半途而废的仓库。

### 5. （可选）使用仓库内固定设备树

```bash
bash scripts/install-bundled-device-trees.sh ~/android/lineage-23.2
```

上游分支将来被改或被删时，这一步能保证设备树回到本仓库记录的版本。

### 6. 开始编译

```bash
bash scripts/build.sh ~/android/lineage-23.2
```

等价的手动命令：

```bash
cd ~/android/lineage-23.2
source build/envsetup.sh
breakfast polaris
brunch polaris
```

首次完整编译 8 核大约 1–3 小时，具体看 CPU 和网络（ccache 命中后第二次会快很多）。

### 7. 产物位置

```
out/target/product/polaris/
  lineage-23.2-<日期>-UNOFFICIAL-polaris.zip   # 卡刷包
  recovery.img                                 # Recovery
  boot.img
```

---

## 五、刷机前必须知道的事

1. **固件版本**：polaris 必须先刷到指定 MIUI 固件，否则装不上或装完崩溃。
   - 国行：`V12.0.3.0.QDGCNXM`
   - 国际版：`V12.0.3.0.QDGMIXM`
2. **解锁 Bootloader**：小米账号解锁，会清空数据。
3. **Recovery**：用本机型的 TWRP / OrangeFox / Lineage Recovery，用 `fastboot flash recovery recovery.img` 刷入。
4. **刷入 ROM**：Recovery 里 `adb sideload lineage-23.2-*.zip`，或先格式化 data（首次从 MIUI 过来必须格式化）。
5. 回到官方或换 ROM 前，先确认底包固件版本一致。

> 23.2 是实验组合，如果刷完卡开机动画或直接回 Recovery，这不是刷机步骤的问题，而是套件本身还没验证通过。

---

## 六、常见报错对照表

| 报错 | 原因 | 处理 |
|------|------|------|
| `vendor/xiaomi/polaris/BoardConfigVendor.mk: No such file` | vendor 仓库没同步下来 / local manifest 没生效 | 检查 `.repo/local_manifests/polaris.xml` 是否存在；重新 `repo sync --force-sync` |
| `fatal: could not read Username for 'https://github.com'` | 仓库地址错或私有仓库 | 本套件全部用公开仓库；检查 manifest 里的 `name/path` |
| `error.GitError: Cannot remove project` | 上次 sync 被强杀 | `repo sync --force-sync` |
| `ninja: build stopped: subcommand failed` | 真正的错误在**上面第一条** `error:` | 不要看最后一行，往上翻找第一个 error |
| `cc1plus: killed (program cc1plus)` / exit 137 | 内存不足 | 加 swap、关掉其它程序、`mka -j4` 降并行 |
| `No space left on device` | 磁盘不够 | 至少 400 GB；清 `out/` 重来 |
| `repo sync` 卡住或 `Connection reset` | 网络问题 | 换代理/换时段；`-j4` 降并发；不要中途 Ctrl+C |
| `lunch` 报 `Missing config` | 用了旧的 lunch 写法 | 用 `breakfast polaris` + `brunch polaris` |
| 编译到 90% 突然整机失去响应 | 内存 + swap 不足 | 同上，优先加 swap |
| 刷完无法开机 | 23.2 实验组合未通过实机验证 | 回退 `lineage-22.2` 套件；抓 `adb logcat` / `dmesg` 再分析 |

---

## 七、回退到官方稳定版

```bash
bash scripts/init-source.sh ~/android/lineage-22.2 lineage-22.2
bash scripts/build.sh ~/android/lineage-22.2
```

两个源码目录互不影响，建议 23.2 和 22.2 各留一份，方便对比。

---

## 八、许可与来源

- `device/xiaomi/polaris`、`device/xiaomi/sdm845-common`：来自 LineageOS 官方仓库，Apache-2.0。
- `manifests/`：仅记录上游仓库与提交 SHA。
- `scripts/`：本仓库原创，MIT。

本仓库不包含内核源码和 vendor blobs（体积太大），由 manifest 从上游按固定 SHA 拉取。
