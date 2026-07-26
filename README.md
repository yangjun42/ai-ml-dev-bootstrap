# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发主机 bootstrap 模板。

核心原则：

- **主机与项目分离**：装机脚本管理通用软件；Python/AI 依赖默认属于项目。
- **uv-first**：Python 版本、虚拟环境、依赖和锁文件优先交给 uv。
- **conda 按需**：Miniforge + mamba 只作为 conda-forge/native/旧环境兼容层。
- **功能正交**：macOS 只有 `core` / `restricted` 两种策略，能力通过 feature 组合。
- **安全重复执行**：已满足的安装项跳过，用户未托管配置不静默覆盖。

> 本仓库不替代公司的安全、合规和许可证审查。

---

## macOS：一个 `core`，按需加 feature

### 默认 `core`

适合个人 Apple Silicon Mac、远程服务器为主、本地轻量开发和开源模型运行：

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

Git 与 OpenSSH 使用 macOS / Apple Command Line Tools 版本，不通过 Homebrew 重复安装。

默认终端体验：

```text
Ghostty dark  : TokyoNight Moon
Ghostty light : TokyoNight Day
Starship      : Jetpack
Shell         : /bin/zsh -l
```

安装：

```bash
git clone https://github.com/yangjun42/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap
./scripts/bootstrap-macos.sh
```

全新 Mac 尚未安装 Apple Command Line Tools 时，脚本会请求安装；也可以先执行：

```bash
xcode-select --install
```

### `restricted`

使用相同的开源终端、编辑器、仓库和 shell 基线，但不自动安装：

```text
ChatGPT
Claude Code
Ollama
```

```bash
./scripts/bootstrap-macos.sh --profile restricted
```

### 可选 features

```text
ai          创建/复用一个 uv 管理的本地 AI/ML starter project
conda       安装 Miniforge（含 conda 与 mamba）
mlsys       加入 profiling/benchmark/runtime 工具；自动启用 ai
build       CMake、Ninja、pkgconf、FFmpeg
containers  Colima、Docker CLI、Docker Compose；不会自动启动
all         启用全部 feature
```

示例：

```bash
./scripts/bootstrap-macos.sh --features ai
./scripts/bootstrap-macos.sh --features conda
./scripts/bootstrap-macos.sh --features ai,mlsys
./scripts/bootstrap-macos.sh --features build,containers
./scripts/bootstrap-macos.sh --features all
```

AI project 可指定路径与 Python：

```bash
./scripts/bootstrap-macos.sh \
  --features ai,mlsys \
  --python 3.12 \
  --project-dir "$HOME/projects/ai-ml-starter"
```

### 主题切换

`core` 会安装：

```bash
devtheme list
devtheme current

devtheme tokyo        # TokyoNight Moon/Day + Jetpack
devtheme tokyo-night  # TokyoNight Moon/Day + Tokyo Night preset
devtheme catppuccin   # Mocha/Latte + Catppuccin Powerline
devtheme gruvbox      # Gruvbox Dark/Light Hard + Gruvbox Rainbow
```

切换后在 Ghostty 中按 `Cmd+Shift+,` 重新加载。

### 安全与幂等

```bash
# 只查看计划
./scripts/bootstrap-macos.sh --dry-run

# 允许升级已有 Homebrew 软件
./scripts/bootstrap-macos.sh --upgrade

# 只安装软件，不修改 Ghostty/zsh
./scripts/bootstrap-macos.sh --skip-config

# 备份并采用仓库的 Ghostty 主配置
./scripts/bootstrap-macos.sh --force-config

# 只更新终端配置
./scripts/configure-macos-shell.sh --profile core
```

脚本会：

- 先运行 `brew bundle check`，已满足的 Brewfile 整体跳过；
- 默认使用 `--no-upgrade`；
- 只维护 `.zshrc` 中带 marker 的一个 `macos-core` block；
- 迁移旧的 `macos-minimal` / `macos-developer` blocks；
- 保留未标记的个人配置；
- 对托管配置先备份；
- 不覆盖未托管或 symlink 的 Ghostty 配置，而是生成 review candidate；
- 不在重复执行时重置主题或 Starship 选择。

详细说明见 [`docs/MACOS.md`](docs/MACOS.md)。

### 旧名称兼容

旧名称仍可运行，但新设计只使用 `core` / `restricted`：

```text
minimal, developer, personal -> core
workstation                  -> core + build,containers
enterprise                   -> restricted
```

---

## uv 与 Miniforge/mamba

```text
uv        = Python 版本、项目环境、PyPI 依赖和锁文件的默认工具
Miniforge = conda-forge 发行版/安装入口
mamba     = conda-compatible 的快速环境与包管理 CLI
```

普通 Python/AI 项目优先：

```bash
cd project
uv sync
```

需要 conda-forge native 依赖或兼容同事的 `environment.yml` 时：

```bash
./scripts/bootstrap-macos.sh --features conda
source ~/miniforge3/etc/profile.d/conda.sh
mamba env create -f environment.yml
```

---

## Windows 11：推荐 WSL2 Ubuntu

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

macOS CI 会在 Linux 与 macOS runner 上验证：

```text
shell syntax
Brewfile/module invariants
配置迁移
重复执行幂等性
主题切换
用户配置保留
```

已有 starter project：

```bash
make verify-project
```

---

## 目录结构

```text
brewfiles/macos/
  core.Brewfile
  personal.Brewfile
  build.Brewfile
  containers.Brewfile
  mlsys.Brewfile

config/macos/
  ghostty/config.ghostty
  ghostty/appearance.ghostty
  zsh/core.zsh
  bin/devtheme

scripts/
  bootstrap-macos.sh
  configure-macos-shell.sh
  setup-macos-ai.sh
  install-miniforge.sh
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
