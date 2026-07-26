# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发主机 bootstrap 模板。

设计原则：

- **主机与项目分离**：装机脚本只管理通用软件和主机配置。
- **uv-first**：Python、虚拟环境、框架和依赖由各项目自行声明。
- **少量正交概念**：macOS 只有两个 profile 和两个可选 feature。
- **安全重复执行**：已满足的软件跳过，个人未托管配置不静默覆盖。

> 本仓库不替代组织的安全、合规和许可证审查。

---

## macOS

### 最简单的用法

个人 Apple Silicon Mac：

```bash
git clone https://github.com/yangjun42/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap
./scripts/bootstrap-macos.sh
```

企业或受限设备：

```bash
./scripts/bootstrap-macos.sh --profile enterprise
```

需要额外主机能力时：

```bash
./scripts/bootstrap-macos.sh --features ml
./scripts/bootstrap-macos.sh --features containers
./scripts/bootstrap-macos.sh --features ml,containers
```

全新 Mac 尚未安装 Apple Command Line Tools 时，脚本会请求安装；也可以预先执行：

```bash
xcode-select --install
```

### 模型

```text
profile  = 应用策略
feature  = 可选主机能力
project  = 自己管理 Python/ML 环境
```

正式 profile 只有：

| profile | 用途 |
|---|---|
| `core` | 默认个人开发主机，包含 ChatGPT/Codex、Claude Code 和 Ollama |
| `enterprise` | 相同的开源终端/编辑器基线，但不安装上述公共 AI 应用和本地模型运行时 |

正式 feature 只有：

| feature | 内容 |
|---|---|
| `ml` | CMake、Ninja、pkgconf、FFmpeg、hyperfine；不创建 Python 环境 |
| `containers` | Colima、Docker CLI、Docker Compose；不自动启动 Colima |
| `all` | `ml,containers` |

旧 profile 名称仅作为迁移别名：

```text
minimal, developer, personal -> core
restricted                  -> enterprise
workstation                 -> core + ml,containers
```

旧 `ai`、`conda`、`mlsys`、`build` feature 已移除。Mac 主机 bootstrap 不再创建 starter project，也不安装 Miniforge。

### `core` 包含什么

```text
Homebrew + Brewfile
Ghostty + macOS OpenSSH + tmux
Apple Command Line Tools Git + gh + Git LFS
VS Code
ChatGPT desktop / Codex
Claude Code CLI
Ollama App
uv + btop
Starship + zoxide + fzf
ripgrep + fd + jq + yq + bat + ShellCheck + just
zsh-autosuggestions + zsh-syntax-highlighting
```

Git 与 OpenSSH 使用 macOS / Apple Command Line Tools 提供的版本，不通过 Homebrew 重复安装。

默认终端体验：

```text
Ghostty dark  : TokyoNight Moon
Ghostty light : TokyoNight Day
Starship      : Jetpack
Shell         : /bin/zsh -l
```

Ghostty 显式启动 zsh，因此目录服务账户即使仍记录 `/bin/bash`，也能正确读取 `~/.zshrc`。

### 主题切换

```bash
devtheme list
devtheme current

devtheme tokyo        # TokyoNight Moon/Day + Jetpack
devtheme tokyo-night  # TokyoNight Moon/Day + Tokyo Night preset
devtheme catppuccin   # Mocha/Latte + Catppuccin Powerline
devtheme gruvbox      # Gruvbox Dark/Light Hard + Gruvbox Rainbow
```

切换后在 Ghostty 中按 `Cmd+Shift+,` 重新加载。

### Python / ML 项目

装机脚本不会自动执行以下操作：

```text
安装 Python
创建 .venv 或 starter project
安装 PyTorch、MLX、Jupyter、Transformers
安装 Miniforge / conda / mamba
下载 Ollama 模型
安装 VS Code 插件
```

项目自己管理环境：

```bash
cd project
uv sync
```

没有现成项目时：

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy pandas scikit-learn
```

需要 PyTorch、MLX 或其他框架时，仅在该项目中添加。

### 安全与幂等

```bash
# 查看计划
./scripts/bootstrap-macos.sh --dry-run

# 显式允许升级 Homebrew 软件
./scripts/bootstrap-macos.sh --upgrade

# 只装软件，不修改 Ghostty/zsh
./scripts/bootstrap-macos.sh --skip-config

# 备份并采用仓库的 Ghostty 主配置
./scripts/bootstrap-macos.sh --force-config

# 只更新终端配置
./scripts/configure-macos-shell.sh --profile core
```

脚本会：

- 先运行 `brew bundle check`，已满足的 manifest 整体跳过；
- 默认使用 `--no-upgrade`；
- 只维护 `.zshrc` 中带 marker 的 `macos-core` block；
- 自动迁移旧的 `macos-minimal` / `macos-developer` blocks；
- 保留未标记的个人配置；
- 不覆盖未托管或 symlink 的 Ghostty 配置，而是生成 review candidate；
- 不在重复执行时重置主题或 Starship 选择。

详细说明见 [`docs/MACOS.md`](docs/MACOS.md)。

---

## Windows 11

推荐 WSL2 Ubuntu：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend wsl -Profile personal
```

Windows 安装 NVIDIA driver 后，WSL2 可通过 Windows driver bridge 暴露 GPU。普通 PyTorch/Hugging Face 使用通常不需要在 WSL 内安装 Linux CUDA Toolkit；只有需要 `nvcc`、CUDA headers、samples 或编译 CUDA extension 时再启用。

文档：

- [`docs/WINDOWS_WSL_NVIDIA.md`](docs/WINDOWS_WSL_NVIDIA.md)
- [`docs/WSL_UPDATE_TRIAGE.md`](docs/WSL_UPDATE_TRIAGE.md)

WSL 被企业策略或系统问题阻断时：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend native -Profile enterprise
```

详细参数见 [`docs/WINDOWS_NATIVE_NO_WSL.md`](docs/WINDOWS_NATIVE_NO_WSL.md)。

---

## 验证

```bash
make verify-macos
```

macOS CI 在 Linux 与 macOS runner 上验证 shell 语法、manifest 边界、旧配置迁移、重复执行、主题切换和用户配置保留。

## 目录结构

```text
brewfiles/macos/
  core.Brewfile
  personal.Brewfile
  ml.Brewfile
  containers.Brewfile

config/macos/
  ghostty/config.ghostty
  ghostty/appearance.ghostty
  zsh/core.zsh
  bin/devtheme

scripts/
  bootstrap-macos.sh
  configure-macos-shell.sh
  bootstrap.ps1
  bootstrap-windows-native.ps1
  bootstrap-wsl.sh

docs/
  MACOS.md
  ARCHITECTURE.md
  WINDOWS_NATIVE_NO_WSL.md
  WINDOWS_WSL_NVIDIA.md
  WSL_UPDATE_TRIAGE.md
```

## License

MIT.
