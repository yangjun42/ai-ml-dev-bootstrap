# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发主机 bootstrap 模板。

核心原则：

- **macOS host-first**：默认安装通用开发主机软件、本地模型运行器、uv，以及可安全重复执行的 Ghostty/zsh 基线，不自动创建 Python/AI 环境。
- **uv-first**：具体项目通过 `pyproject.toml` / `uv.lock` 管理 Python、PyTorch、Hugging Face、scikit-learn 等依赖。
- **Miniforge + mamba 作为 fallback**：仅用于 conda-forge native 二进制依赖、团队 `environment.yml`、GDAL/HDF5/R/Qt 等复杂依赖。
- **Windows 优先 WSL2**；被企业策略或系统问题阻断时使用 native Windows fallback。
- **容器、CUDA Toolkit、Visual Studio Build Tools 和 MLsys profiling 均为可选项**。

> 本仓库不替代公司的安全、合规和许可证审查。`restricted` / `enterprise` 只是保守默认值模板。

---

## macOS：分层的最优主机方案

### `minimal` / `core`：默认基线

适合个人 Apple Silicon Mac、远程服务器为主、本地进行轻量开发与开源模型推理：

```text
Homebrew + Brewfile
Ghostty + macOS OpenSSH + tmux
Apple Command Line Tools Git + gh + Git LFS
VS Code
ChatGPT desktop / Codex
Claude Code CLI
Ollama App
uv
btop
```

Git 和 OpenSSH 由 macOS / Apple Command Line Tools 提供，脚本只验证，不通过 Homebrew 重复安装。窗口平铺使用 macOS 原生功能。

minimal 还会安全配置：

```text
Ghostty TokyoNight Moon/Day
Ghostty stable-channel update checks
Ghostty zsh + SSH/terminfo integration
zsh 持久化共享历史和原生补全
```

Ghostty 显式启动 `/bin/zsh -l`，因此即使企业目录账户仍把登录 shell 记录为 `/bin/bash`，新终端也会正确读取 `~/.zshrc`。这不会修改账户级默认 shell。

### `developer`：推荐的日常终端体验

在 minimal 上增加：

```text
Starship Jetpack
zoxide
fzf
zsh-autosuggestions
zsh-syntax-highlighting
ripgrep / fd / jq / yq / bat / ShellCheck / just
```

默认组合：

```text
Ghostty  : TokyoNight Moon / Day
Starship : Jetpack
```

可选的一条命令同步切换 Ghostty 与 Starship：

```bash
devtheme list
devtheme current
devtheme tokyo
devtheme tokyo-night
devtheme catppuccin
devtheme gruvbox
```

### `workstation`

在 developer 上增加本地 native build 和 Docker-compatible 工具：

```text
CMake / Ninja / pkgconf / FFmpeg
Colima
Docker CLI / Docker Compose
```

只安装工具，不会自动启动 Colima 或创建容器。

### `restricted`

保留主机、Ghostty、zsh、编辑器和 uv 基线，但不自动安装：

```text
ChatGPT
Claude Code
Ollama
```

### 安装

```bash
git clone https://github.com/yangjun42/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap

# 最小主机基线
./scripts/bootstrap-macos.sh

# 推荐的个人开发体验
./scripts/bootstrap-macos.sh --profile developer

# 本地 build/container 工作站
./scripts/bootstrap-macos.sh --profile workstation

# 受限环境
./scripts/bootstrap-macos.sh --profile restricted
```

全新 Mac 如果尚未安装 Apple Command Line Tools，脚本会请求安装；也可以先执行：

```bash
xcode-select --install
```

兼容别名：

```text
core       -> minimal
personal   -> minimal
enterprise -> restricted
```

### 安全重复执行

脚本会先使用 `brew bundle check` 判断每个 Brewfile 是否已经满足。默认 `--no-upgrade`，只补齐缺失软件；显式升级：

```bash
./scripts/bootstrap-macos.sh --profile developer --upgrade
```

配置策略：

- managed Ghostty 主配置更新前备份；
- 未托管或 symlink 的 Ghostty 主配置不覆盖，而是写出 review candidate；
- `appearance.ghostty` 只在不存在时创建，因此主题选择不会在重跑时被重置；
- `.zshrc` 只更新带 marker 的 managed blocks；
- 备份存于 `~/.config/ai-ml-dev-bootstrap/backups/`。

常用控制：

```bash
# 预览
./scripts/bootstrap-macos.sh --profile developer --dry-run

# 只安装软件，不修改配置
./scripts/bootstrap-macos.sh --profile developer --skip-config

# 备份并替换已有的未托管 Ghostty 主配置
./scripts/bootstrap-macos.sh --profile developer --force-config

# 只更新 Ghostty/zsh/Starship 配置
./scripts/configure-macos-shell.sh --profile developer
```

详细设计见：

- [`docs/MACOS_PROFILES.md`](docs/MACOS_PROFILES.md)
- [`docs/MACOS_TERMINAL.md`](docs/MACOS_TERMINAL.md)

### 默认不会做什么

macOS host bootstrap 不会自动：

```text
安装 VS Code 插件
安装 Python 或创建 .venv
安装 PyTorch、MLX、Jupyter、Transformers
安装 Miniforge/mamba/Pixi
下载 Ollama 模型
启动 Colima 或创建容器
安装 Oh My Zsh
登录 ChatGPT、Claude、GitHub 或写入 API key/SSH key
覆盖未标记的个人 dotfiles
```

项目真正需要 Python 时再执行：

```bash
cd project
uv sync
# 项目明确需要某个 Python 版本时
uv python install 3.12
```

旧版“自动创建完整 AI starter 环境”的逻辑保留为兼容入口，但不推荐用于新 Mac：

```bash
bash scripts/bootstrap-macos-legacy-ai.sh --profile personal --features core,ai,conda
```

---

## Miniforge + mamba 是否重复？

不完全重复：

```text
Miniforge = conda-forge 生态的安装入口 / 发行版
mamba     = 管理 conda 环境和包的快速 CLI / 求解器
uv        = Python/PyPI/项目环境的默认包管理器
```

本仓库不会在 macOS minimal profile 中安装 Miniforge。只有项目确实需要 conda-forge native 依赖或兼容同事的 `environment.yml` 时再启用。

---

## Windows 11：推荐 WSL2 Ubuntu

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend wsl -Profile personal
```

Windows 已安装 NVIDIA driver 时，WSL2 会通过 Windows driver bridge 暴露 GPU。普通 PyTorch/Hugging Face 使用通常不需要在 WSL 内安装 Linux CUDA Toolkit；只有需要 `nvcc`、CUDA headers、samples 或编译 CUDA extension 时才启用对应 feature。

详细说明：

- [`docs/WINDOWS_WSL_NVIDIA.md`](docs/WINDOWS_WSL_NVIDIA.md)
- [`docs/WSL_UPDATE_TRIAGE.md`](docs/WSL_UPDATE_TRIAGE.md)

WSL 更新失败时：

```powershell
.\scripts\triage-wsl-update.ps1
```

---

## Windows 11：native / 无 WSL fallback

当 WSL 被企业策略或系统问题阻断时：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend native -Profile enterprise
```

等价直接入口：

```powershell
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise
```

native Windows 默认仍采用小 feature 组合，并支持把项目、模型、uv cache、Python 和 Miniforge 放到非 C 盘目录。

详细参数和目录策略见 [`docs/WINDOWS_NATIVE_NO_WSL.md`](docs/WINDOWS_NATIVE_NO_WSL.md)。

---

## 验证

macOS bootstrap 静态检查和临时 HOME 幂等性测试：

```bash
make verify-macos
```

已有 starter project 的运行环境检查：

```bash
make verify-project
```

---

## 目录结构

```text
brewfiles/macos/
  minimal.Brewfile
  developer-extra.Brewfile
  workstation-extra.Brewfile
  restricted.Brewfile

config/macos/
  ghostty/config.ghostty
  ghostty/appearance.ghostty
  zsh/minimal.zsh
  zsh/developer.zsh
  bin/devtheme

scripts/
  bootstrap-macos.sh             # 默认 Mac host bootstrap
  configure-macos-shell.sh       # Ghostty/zsh/Starship 安全配置
  test-macos-configure.sh        # 临时 HOME 集成测试
  bootstrap-macos-legacy-ai.sh   # 旧完整 AI 环境兼容入口
  bootstrap.ps1                  # Windows unified entrypoint
  bootstrap-windows-native.ps1   # native Windows/no-WSL backend
  bootstrap-wsl.sh               # WSL Ubuntu backend
  verify-macos-bootstrap.sh

docs/
  MACOS_PROFILES.md
  MACOS_TERMINAL.md
  WINDOWS_NATIVE_NO_WSL.md
  WINDOWS_WSL_NVIDIA.md
  WSL_UPDATE_TRIAGE.md
  ARCHITECTURE.md
```

## License

MIT.
