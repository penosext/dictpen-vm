# dictpen-vm Linux 使用说明

本文只讲 **Linux 宿主机**。Windows 的用法见根目录 `README.md`；两边共用同一套
`packs/`、`scripts/dpctl.py` 和 `vmgui/`，区别只在宿主工具的查找方式、音频后端和
启动脚本。

## 1. 适用环境

- Linux x86_64 桌面或服务器（Ubuntu / Debian / Fedora / Arch 均可）
- Python 3.11+（`tomllib` 需要）
- QEMU 的 `qemu-system-aarch64` 与 `qemu-img`
- 可选：PySide6（控制台和实时画面）、`openssh-client`、`adb`

客户机是 **aarch64**，x86_64 宿主上只能走 QEMU TCG 软件模拟，不能用 KVM；
起机慢、CPU 占用高是正常的。aarch64 宿主理论上可以接 KVM，但本框架没有做这条
加速路径。

## 2. 安装依赖

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install qemu-system-arm qemu-utils openssh-client python3 python3-venv
# 控制台 / 实时画面
python3 -m pip install PySide6
# PySide6 6.5+ 在部分 Ubuntu 上还需要：
# sudo apt install libgl1 libxcb-cursor0 libxkbcommon-x11-0
```

`qemu-system-arm` 提供 `/usr/bin/qemu-system-aarch64`，`qemu-utils` 提供
`/usr/bin/qemu-img`。

### Fedora

```bash
sudo dnf install qemu-system-aarch64 qemu-img openssh-clients python3
python3 -m pip install PySide6
```

### Arch

```bash
sudo pacman -S qemu-system-aarch64 qemu-img openssh python
python3 -m pip install PySide6
```

### 可选工具

| 工具 | 用途 | 包 |
|---|---|---|
| `sftp` | `dpctl put/get` 首选通道 | `openssh-client` / `openssh-clients` |
| `adb` | `dpctl adb` | Android platform-tools，或 PATH 上的 `adb` |
| `pactl` | 查看 Pulse/PipeWire 默认输出 | `pulseaudio-utils` / `pipewire-pulse` |
| `wpctl` | PipeWire 音量/静音 | `wireplumber` |
| `python3-tk` | `dpctl view` 的 Tk 窗口 | `python3-tk` / `python3-tkinter` |

## 3. 首次准备

```bash
git clone https://github.com/penosext/dictpen-vm.git
cd dictpen-vm

# 先看缺什么（不下载、不修改）
python3 scripts/bootstrap.py --check

# 补齐依赖、生成 SSH key/证书、构建 initramfs
python3 scripts/bootstrap.py
```

Linux 上的行为：

- **QEMU**：不下载 `tools/msys2` 里的 Windows 便携版，检查系统
  `qemu-system-aarch64` 与 `qemu-img`；缺了会直接给出 apt/dnf 安装命令。
- **zstd**：Windows 专用项，自动跳过。
- **busybox / arm64 内核**：需要 `downloads/busybox-static.deb`、`downloads/kernel.deb`、
  `downloads/kernel-generic.deb`（`.deb` 不进版本库）。仓库里已经有就直接用；
  没有时 `bootstrap` 会打印清华镜像的下载地址，下载后再跑一次。
- **arm64 资源包**：`scripts/deb-arm64-fetch.py` 从清华镜像获取 hostapd 等。
- **SSH key / mitm 证书**：本机生成；私钥自动 chmod `600`。
- **固件镜像**：按包下载（体积大），可以用 `--only` 只取一台：

```bash
python3 scripts/bootstrap.py --only firmware-s6pro
python3 scripts/bootstrap.py --only firmware-x5pro
```

`--check` 会把缺少的固件文件和出处一起打印。`x6pro`、`x7` 仍然需要手工从 OTA
提取，见 `docs/发布说明.md` 与对应包 README。

## 4. 启动与关闭

```bash
# 起机（默认 vmgui 画面窗口；--pack 选机型）
sh run-vm.sh --pack s6pro

# 看状态
python3 scripts/dpctl.py status

# 关机
sh stop-vm.sh
```

常用变体：

```bash
sh run-vm.sh --pack s6pro --fresh          # 清空该包状态盘后重建
sh run-vm.sh --pack s6pro --display none   # 不开前端，只留 QMP/串口/SSH
sh run-vm.sh --pack s6pro --display gtk    # 用 QEMU 自带的 GTK 窗口
sh run-vm.sh --pack s6pro --no-audio       # 宿主没有可用音频设备时
sh run-vm.sh --pack s6pro --no-scan        # 冷启动跳过扫描翻译预加载，起机更快
sh run-vm.sh --pack s6pro --fast           # 从首页快照恢复（更快，无声音）
```

首次冷启动要完成固件自己的首启初始化，可能几分钟；`--fast` 需要先用
`python3 scripts/dpctl.py fast save` 建快照（要先关机，且需要 `qemu-img`）。

所有端口只绑 `127.0.0.1`，一般不需要改防火墙：

| 端口 | 用途 |
|---|---|
| 2222 | SSH |
| 4444 | 串口控制台 |
| 4445 | QEMU HMP |
| 4446 | QMP（控制台/前端独占） |
| 4447 | 虚拟蓝牙 HCI |
| 4448 | `--display vnc` 的推流配置（实际端口以 `vm/qemu.log` 为准） |
| 15037 | ADB |

## 5. 控制台与画面

```bash
sh vm-console.sh                 # 可视化控制台：设备画面 + 状态栏 + 抽屉
sh vm-console.sh --pack s6pro
```

控制台会占住 QMP 4446，所以它开着时：

- `dpctl tap`、`dpctl screenshot` 等 QMP 操作会被拒绝；
- 需要注入手势时先关控制台，或用 `up --display none` 起机后再连。

`dpctl down` **不会**关控制台窗口；虚拟机停了，控制台会落到“虚拟机没在跑”
的空态。

没有 PySide6 时：

```bash
sh run-vm.sh --display gtk   # 需要桌面环境
sh run-vm.sh --display none  # 无窗口，用 SSH/串口/命令
```

`dpctl attach` 在 Linux 上不会把已有 vmgui 窗口抬到前台（Windows 才有
`SetForegroundWindow`），请用窗口管理器切换。

Linux 的触摸反馈环由 vmgui 自己画；`dpctl pointer` 的透明置顶浮层是 Windows
专用。

## 6. 声音

Linux 默认：

1. 有 `PULSE_SERVER` 或 `/run/user/<uid>/pulse/native` → `-audiodev pa`
2. 有 `/dev/snd` 或 `aplay` → `-audiodev alsa`
3. 都没有 → `-audiodev none`

手动指定：

```bash
DICTPEN_AUDIODEV=pa   sh run-vm.sh --pack s6pro
DICTPEN_AUDIODEV=alsa sh run-vm.sh --pack s6pro
DICTPEN_AUDIODEV=none sh run-vm.sh --pack s6pro
sh run-vm.sh --pack s6pro --no-audio      # 完全不挂音频设备
```

排查宿主输出：

```bash
pactl get-default-sink
pactl get-sink-mute @DEFAULT_SINK@
pactl get-sink-volume @DEFAULT_SINK@
# 或 PipeWire
wpctl status
wpctl get-volume @DEFAULT_AUDIO_SINK@
```

`dpctl audio-check` 的宿主端点检查目前是 Windows 专用；Linux 请用上面的
`pactl`/`wpctl` 看默认输出是否静音、音量是否为 0。

快速启动快照不含音频；要声音请冷启动。

## 7. SSH、ADB 与文件传输

```bash
sh ssh-vm.sh                       # root@127.0.0.1:2222
python3 scripts/dpctl.py shell     # 同一个入口
python3 scripts/dpctl.py sh -c "uname -a"

python3 scripts/dpctl.py put 本地文件 /userdata/文件
python3 scripts/dpctl.py get /userdata/applog/DictPen.log ./DictPen.log

python3 scripts/dpctl.py adb shell # 需要 PATH 或 tools/platform-tools 里的 adb
```

`put/get` 优先走 sftp，失败回落 `ssh cat`。私钥在 `tools/ssh/id_devvm`，
Linux 上必须是 `600`；`dpctl` 启动时会自动收紧，`bootstrap` 也会处理。

如果出现：

- `Permission denied (publickey)`：确认跑过 `python3 scripts/bootstrap.py`；
- `REMOTE HOST IDENTIFICATION HAS CHANGED`：`dpctl up` 会重置
  `vm/known_hosts_devvm`；
- `PTY allocation request failed`：固件 guest 没有 devpts，用
  `python3 scripts/build-initramfs.py` 重建 initramfs 后 `down`/`up`。

## 8. 持久化与状态盘

每个包一份状态盘：`vm/state-<包名>.img`，默认整盘 ext4，不是分区镜像。

- `/userdata`、`/userdisk` 由 `/state/...` bind mount，重启不丢；
- overlay 的 upper 在 `/state/upper`；
- 首次开机由 guest 自带 `mke2fs` 格式化；
- `--fresh` 删除当前包状态盘，下次开机重建；
- 扩容：控制台“配置”页或 `dpctl` 相关入口用 `qemu-img resize`，之后还要在
  guest 里 `resize2fs /dev/vdb`。

需要 `qemu-img` 的操作（首次建盘、扩容、`fast save`）在缺工具时会直接报错并
提示安装 `qemu-utils`。

## 9. 环境变量

| 变量 | 作用 |
|---|---|
| `DICTPEN_QEMU` | 指定 `qemu-system-aarch64` 路径 |
| `DICTPEN_QEMU_IMG` | 指定 `qemu-img` 路径 |
| `DICTPEN_SFTP` | 指定 `sftp` 路径 |
| `DICTPEN_PYTHON` | `.sh` 启动脚本用哪个 Python（默认 `python3`） |
| `DICTPEN_VMGUI_PYTHON` | 控制台/实时画面用哪个能 `import PySide6` 的 Python |
| `DICTPEN_AUDIODEV` | `pa` / `alsa` / `none` / `sdl` / `wav` |
| `DICTPEN_TCG` | TCG 参数，默认 `thread=multi` |
| `DICTPEN_DL_THREADS` | bootstrap 下载线程数（默认 32） |
| `DICTPEN_TRACE` | QEMU trace 事件，例如 `virtio_gpu*` |
| `QT_QPA_PLATFORM` | Qt 平台插件；Wayland 有问题时可试 `xcb` |

## 10. 与 Windows 的差异

| 项目 | Windows | Linux |
|---|---|---|
| QEMU | `tools/msys2/ucrt64/bin/*.exe` | 发行版 `qemu-system-aarch64` / `qemu-img` |
| 音频后端 | `dsound` | `pa` / `alsa` / `none` |
| 启动脚本 | `*.cmd` | `*.sh` |
| 收进程 | `taskkill` | `os.kill` |
| 进程枚举 | Toolhelp32 | `/proc`（无 `/proc` 时 `pgrep`） |
| 触摸浮层 | `dpctl pointer` | vmgui 自带反馈环 |
| 宿主端点音频检查 | `dpctl audio-check` | 用 `pactl` / `wpctl` |
| 窗口抬到前台 | `dpctl attach` | 用窗口管理器 |

Windows 行为保持不变；Linux 分支通过 `os.name` / 工具查找选择。

## 11. 排障

### 找不到 QEMU

```text
dpctl: 找不到 qemu-system-aarch64
```

```bash
sudo apt install qemu-system-arm qemu-utils
# 或
DICTPEN_QEMU=/opt/qemu/bin/qemu-system-aarch64 sh run-vm.sh --pack s6pro
```

### 找不到 qemu-img

首次建状态盘、扩容、`fast save` 会用到：

```bash
sudo apt install qemu-utils
# 或
DICTPEN_QEMU_IMG=/usr/bin/qemu-img sh run-vm.sh
```

### 没有窗口 / 画面起不来

- 服务器无桌面：用 `--display none`，通过 SSH/串口操作；
- PySide6 导入报 `libGL.so.1` / `libxcb-cursor.so.0`：
  `sudo apt install libgl1 libxcb-cursor0`；
- Wayland 下窗口异常：`QT_QPA_PLATFORM=xcb sh vm-console.sh`；
- QEMU GTK 起不来：改用 `--display none` 或 `--display vnc`。

### 没声音

先关掉音频确认 VM 能起：

```bash
sh run-vm.sh --no-audio
```

能起但没声音，再看 `pactl`/`wpctl` 的默认输出是否静音/音量为 0，或换
`DICTPEN_AUDIODEV=alsa`。

### 起机很慢

x86_64 宿主跑 aarch64 客户机只能 TCG。可以：

- 用 `--fast` 首页快照；
- 调低 `vm/machine.toml` 里该包的 `smp` / `memory`；
- 冷启动时加 `--no-scan`（跳过扫描翻译预加载）。

### 端口被占

```bash
ss -ltnp | grep -E '2222|444[4-8]|15037'
```

先 `sh stop-vm.sh`，再确认没有残留的 `qemu-system-aarch64` 进程。

### 看日志

| 文件 | 内容 |
|---|---|
| `vm/qemu.log` | QEMU 启动/错误 |
| `vm/serial.log` | 串口输出 |
| `vm/console.out` | 控制台进程日志 |
| `vm/vmgui.out` | 实时画面进程日志 |
| `vm/fast-save.log` | 快照保存过程 |
| `vm/console-dpctl.log` | 控制台里执行过的 dpctl 命令与输出 |

## 12. 自检

```bash
python3 scripts/dpctl.py packs          # 包与镜像状态
python3 scripts/dpctl.py status         # VM/端口状态
QT_QPA_PLATFORM=offscreen python3 -m unittest discover -s vmgui/tests -t . -p "test_*.py"
```

测试需要 PySide6；会跳过两项平台相关的用例。

## 13. 清理

只删某一台的持久数据：

```bash
rm vm/state-<包名>.img
rm -f vm/fast-<包名>.qcow2 vm/fast-<包名>.json
```

彻底重来：

```bash
sh stop-vm.sh
rm -rf vm/
python3 scripts/bootstrap.py --force
```

`vm/` 里是状态盘、快照、日志、前端记账文件，删掉不会影响 `packs/` 里的固件。
