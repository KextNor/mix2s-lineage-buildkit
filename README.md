# Mi MIX 2S (polaris) — LineageOS 23.2 / 24.0 编译套件

小米 MIX 2S（代号 **polaris**）的 LineageOS 编译仓库：设备树快照、固定版本的 manifest、Ubuntu 环境准备和编译脚本。

目标：把「源码找不齐、同步到一半报错、编译一半炸掉」变成几条可以重复执行的命令。

---

## 一、先看清现实（很重要）

LineageOS 官方对 polaris 的支持只到 **22.2（Android 15）**。官方仓库里的 `lineage-23.2` 设备树分支和 `lineage-22.2` 是**同一个提交**，内核和 vendor 也**没有** 23.2 / 24.0 分支。

所以本仓库不再使用官方那套老树，而是改用 **Evolution-X 社区仓库**（仍在维护 polaris 的 A16/A17 分支）作为设备树、内核和 vendor 来源，再配 LineageOS 源码编译。设备树本身继承的是 `vendor/lineage`，所以可以直接放进 LineageOS 源码树。

| 方案 | Android | 组合 | 状态 |
|------|---------|------|------|
| `lineage-22.2.xml` | 15 | LineageOS 官方 + TheMuppets vendor | 官方支持，最稳，但最老 |
| `lineage-23.2.xml` | **16** | Evolution-X `bka` 分支全套 | **推荐先试这个**：内核 2026-11 仍在更新，最能指望日用 |
| `lineage-24.0.xml` | **17** | Evolution-X `cnb` 分支全套 | 最新，社区早期适配；polaris 专用部分仍是 A16 内容，需自己修 |

各分支核对时间：`bka` 内核 2026-11-11、`hardware/xiaomi` 2026-11-01；`cnb` 内核 2026-02-17、`hardware/xiaomi` 2026-11-12；`cnb` 的公共设备树与 `bka` 是同一提交。

⚠️ **没有任何一组经过实机验证。** 编译成功只代表代码能过编译，不代表能开机、能日用。想日用必须先刷 `lineage-23.2` 产物并实际使用一段时间。

另外，我核对过 **Evolution-X 官方 OTA（`bka`，A16）的 88 台设备列表，里面没有 polaris**；LMODroid 也没有官方 polaris 构建。也就是说：Android 16/17 上，polaris 只有社区树，没有「维护者持续出包」的保证。这是现状，不是本仓库能改变的。

---

## 二、仓库结构

```
manifests/
  lineage-22.2.xml          # 官方稳定回退（Android 15）
  lineage-23.2.xml          # A16 组合，Evolution-X bka，全部 SHA 固定
  lineage-24.0.xml          # A17 组合，Evolution-X cnb，全部 SHA 固定
device/xiaomi/
  polaris/                  # 设备树快照（Evolution-X，A16/A17 共用）
  sdm845-common/            # sdm845 公共设备树快照
scripts/
  setup-ubuntu.sh           # 依赖、repo、ccache
  init-source.sh            # repo init + local manifest + repo sync
  install-bundled-device-trees.sh  # 用仓库内设备树覆盖同步结果（保留 .git）
  preflight.sh              # 编译前自检（依赖、磁盘、SHA、关键文件）
  build.sh                  # breakfast + brunch
```

`device/` 是上游快照，用于固定版本和离线备份；正常编译以 `repo sync` 拉下来的为准，内容与快照一致。

---

## 三、硬件和系统要求

| 项目 | 最低 | 建议 |
|------|------|------|
| 系统 | Ubuntu 22.04 LTS | **Ubuntu 24.04 LTS**（全新安装，不要 WSL） |
| CPU | 4 核 | 8 核以上 |
| 内存 | 16 GB | 32 GB |
| Swap | 16 GB | 32 GB（16 GB 内存必加，否则 `cc1plus killed`） |
| 磁盘 | 400 GB 空闲 | 500 GB NVMe SSD |
| 网络 | 稳定访问 github.com | 配代理；首次 `repo sync` 约 60–120 GB |

---

## 四、编译步骤

### 1. 安装依赖

```bash
git clone https://github.com/KextNor/mix2s-lineage-buildkit.git
cd mix2s-lineage-buildkit
bash scripts/setup-ubuntu.sh
```

装完重开终端，确认 `repo --version` 和 `ccache -s` 可用。

> 下载 repo 失败（storage.googleapis.com 不通）时用清华镜像：
> `curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o ~/bin/repo && chmod a+x ~/bin/repo`

### 2. 加 swap（16 GB 内存必做）

```bash
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
free -h && swapon --show
```

### 3. 配置 ccache

```bash
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 50G
ccache -o compression=true
```

### 4. 同步源码（二选一）

```bash
# 推荐：Android 16
bash scripts/init-source.sh ~/android/lineage-23.2 lineage-23.2

# 最新：Android 17（实验性更强）
bash scripts/init-source.sh ~/android/lineage-24.0 lineage-24.0

# 回退：官方 Android 15
bash scripts/init-source.sh ~/android/lineage-22.2 lineage-22.2
```

脚本会执行 `repo init -b <分支>`、把对应 manifest 放进 `.repo/local_manifests/polaris.xml`、再 `repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags`。

同步中断是常态，重复执行同一条命令即可。

### 5. 编译前自检（强烈建议）

```bash
bash scripts/preflight.sh ~/android/lineage-23.2 lineage-23.2
```

它会检查：主机依赖、磁盘、内存 + swap、源码树完整性、local manifest、**6 个仓库的 HEAD 是否等于 manifest 固定的 SHA**、设备树/内核/vendor 关键文件、ccache。全部 `[ OK ]` 再开始编译；出现 `[FAIL]` 就先修，不要硬编。

### 6. （可选）用仓库内固定设备树

```bash
bash scripts/install-bundled-device-trees.sh ~/android/lineage-23.2
```

上游仓库将来有变动或被删除时，这一步能回到本仓库记录的版本。

### 7. 编译

```bash
bash scripts/build.sh ~/android/lineage-23.2
```

等价手动命令：

```bash
cd ~/android/lineage-23.2
source build/envsetup.sh
breakfast polaris
brunch polaris
```

8 核首次完整编译约 1–3 小时，ccache 命中后第二次明显更快。

### 8. 产物

```
out/target/product/polaris/
  lineage-23.2-<日期>-UNOFFICIAL-polaris.zip
  recovery.img
  boot.img
```

---

## 五、刷机前必须知道的事

1. **底包固件**：先刷到指定 MIUI 版本，否则装不上或开机崩溃。
   - 国行：`V12.0.3.0.QDGCNXM`
   - 国际版：`V12.0.3.0.QDGMIXM`
2. **解锁 Bootloader**（会清空数据）。
3. **Recovery**：`fastboot flash recovery recovery.img`（TWRP / OrangeFox / Lineage Recovery 均可）。
4. **刷 ROM**：Recovery 里 `adb sideload lineage-*.zip`；从 MIUI 首次过来要先格式化 data。
5. 换 ROM 或回官方前，确认底包版本一致。

---

## 六、常见报错对照表

| 报错 | 原因 | 处理 |
|------|------|------|
| `vendor/xiaomi/polaris/BoardConfigVendor.mk: No such file` | vendor 仓库没同步 / manifest 没生效 | 检查 `.repo/local_manifests/polaris.xml`，重新 `repo sync --force-sync` |
| `error: Cannot find module ...` / `PRODUCT_PACKAGES` 缺包 | 设备树引用了 ROM 专有模块 | 属 24.0 实验组合的已知风险；先回 23.2 组合 |
| `resource ... not found`（overlay 相关） | 设备树带了 `overlay-evolution` | 一般只是警告；若中断编译，删除 `device.mk` / `sdm845.mk` 里的 `overlay-evolution` 行 |
| `repo sync` 卡住 / `Connection reset` | 网络 | 换代理/换时段；`-j4` 降并发；别中途 Ctrl+C |
| `error.GitError: Cannot remove project` | 上次 sync 被强杀 | `repo sync --force-sync` |
| `ninja: build stopped: subcommand failed` | 真正错误在**上面第一条** `error:` | 往上翻，不要只看最后一行 |
| `cc1plus: killed` / exit 137 | 内存不足 | 加 swap、关其它程序、`mka -j4` |
| `No space left on device` | 磁盘不足 | 至少 400 GB，清 `out/` 重来 |
| `lunch` 报 `Missing config` | 用了旧 lunch 写法 | 用 `breakfast polaris` + `brunch polaris` |
| 编译成功但刷完不开机 | 组合未经实机验证 | 抓 `adb logcat` / `dmesg`；先用 22.2 官方组合作对照 |

---

## 七、切换方案

```bash
bash scripts/init-source.sh ~/android/lineage-23.2 lineage-23.2
bash scripts/build.sh ~/android/lineage-23.2

bash scripts/init-source.sh ~/android/lineage-24.0 lineage-24.0
bash scripts/build.sh ~/android/lineage-24.0
```

同一目录重复 `init-source.sh` 可以直接切换分支；建议 23.2 / 24.0 各留一份源码目录，互不干扰。

---

## 八、许可与来源

- `device/xiaomi/polaris`、`device/xiaomi/sdm845-common`：来自 Evolution-X 设备仓库（Apache-2.0），其中 `overlay-evolution` 仅含少量 Evolution 专有字符串。
- `manifests/`：记录上游仓库与提交 SHA。
- `scripts/`：本仓库原创，MIT。
- 内核源码和 vendor blobs 体积过大，不放进本仓库，由 manifest 按固定 SHA 拉取。
