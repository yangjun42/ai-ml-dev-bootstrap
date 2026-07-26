# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发主机 bootstrap 模板。

设计原则：

- **主机与项目分离**：装机脚本只管理通用软件和主机配置。
- **uv-first**：Python、虚拟环境、框架和依赖由各项目自行声明。
- **少量正交模块**：macOS 只有一个 `core`，另有三个可选 feature。
- **单一配置来源**：Ghostty 主配置和 `~/.zshrc` 由 repo 管理，首次接管只备份一次。
- **安全重复执行**：已满足的软件跳过，后续运行不会重复生成备份或初始化区块。

> 本仓库不替代组织的安全、合规和许可证审查。

---

## macOS

### 推荐安装

个人 Apple Silicon Mac：

```bash
git clone https://github.com/yangjun42/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap
./scripts/bootstrap-macos.sh --features ai
```

企业管理设备或暂时不安装公共 AI 应用的 Mac：

```bash
./scripts/bootstrap-macos.sh
```

额外需要 ML systems 或容器工具时：

```bash
./scripts/bootstrap-macos.sh --features ai,mlsys
./scripts/bootstrap-macos.sh --features containers
./scripts/bootstrap-macos.sh --features all
```

全新 Mac 尚未安装 Apple Command Line Tools 时，脚本会请求安装；也可以预先执行：

```bash
xcode-select --install
```

### 设计模型

```text
core     = 所有开发机器共享的主机与终端基线
feature  = 可选主机能力
project  = 自己管理 Python、框架、环境和锁文件
```

正式 feature 只有：

| feature | 内容 |
|---|---|
| `ai` | ChatGPT/Codex、Claude Code、Ollama App |
| `mlsys` | CMake、Ninja、pkgconf、hyperfine |
| `containers` | Colima、Docker CLI、Docker Compose；不自动启动 |
| `all` | `ai,mlsys,containers` |

没有 profile、level 或旧接口兼容层。

### `core` 包含什么

```text
Homebrew + Brewfile
Ghostty + macOS OpenSSH + tmux
Apple Command Line Tools Git + gh + Git LFS
VS Code
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
Shell         : macOS 登录 shell（现代 Mac 通常为 zsh）
```

Ghostty 配置中保留了这行提示，但新安装默认注释：

```ini
# command = /bin/zsh -l
```

只有在目录服务或企业账户仍启动 Bash、导致 `~/.zshrc` 不加载时才需要启用。迁移时如果旧 Ghostty 配置已经启用了这一行，新配置会自动保留该选择。

### `ai`

```bash
./scripts/bootstrap-macos.sh --features ai
```

只安装：

```text
ChatGPT desktop / Codex
Claude Code CLI
Ollama App
```

不会自动登录账户、写入 API key、下载模型、创建 Python 环境或安装框架。

Ollama 是本仓库唯一管理的本地模型运行器。`llama.cpp` 与日常本地推理职责高度重叠，只在需要直接操作 GGUF、量化、底层 server 参数或专项 benchmark 时手动安装。FFmpeg 也不进入默认模块。

### `mlsys`

```bash
./scripts/bootstrap-macos.sh --features mlsys
```

安装：

```text
CMake
Ninja
pkgconf
hyperfine
```

用于 native extension 构建、底层组件编译和可重复命令 benchmark。Python profiling、PyTorch Profiler、ONNX Runtime 等仍由具体项目管理。

### `containers`

```bash
./scripts/bootstrap-macos.sh --features containers
```

安装 Colima、Docker CLI 和 Docker Compose，但不会启动虚拟机、修改 Docker context、拉取镜像或创建容器。

### 主题切换

```bash
devtheme list
devtheme current

devtheme tokyo        # TokyoNight Moon/Day + Jetpack
devtheme tokyo-night  # TokyoNight Moon/Day + Tokyo Night preset
devtheme catppuccin   # Mocha/Latte + Catppuccin Powerline
devtheme gruvbox      # Gruvbox Dark/Light Hard + Gruvbox Rainbow
```

切换后在 Ghostty 中按 `Cmd+Shift+,` 重新加载。首次替换自定义 Starship 配置时只创建一个：

```text
~/.config/ai-ml-dev-bootstrap/backups/starship.toml.original
```

后续切换不会重复备份。

### 从旧 minimal 或手工配置迁移

在旧版本安装过 minimal，并手工配置过 Ghostty / Starship 时，直接运行：

```bash
./scripts/bootstrap-macos.sh --features ai
```

行为如下：

1. `brew bundle check` 跳过已经安装的内容，只补齐 core 和 AI feature 缺少的软件。
2. 默认不升级已安装软件；只有 `--upgrade` 才升级。
3. Ghostty 主配置首次被 core 接管时备份为：

   ```text
   ~/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original
   ```

4. 旧 `~/.zshrc` 首次被接管时备份为：

   ```text
   ~/.config/ai-ml-dev-bootstrap/backups/zshrc.original
   ```

5. Ghostty 其余三个可能覆盖主配置的旧路径会分别一次性备份后移除：

   ```text
   ~/.config/ghostty/config
     -> ghostty-xdg-legacy-config.original

   ~/Library/Application Support/com.mitchellh.ghostty/config.ghostty
     -> ghostty-macos-config.original

   ~/Library/Application Support/com.mitchellh.ghostty/config
     -> ghostty-macos-legacy-config.original
   ```

6. 旧配置若已启用 `command = /bin/zsh -l`，迁移后继续启用；全新安装仍默认注释。
7. 现有 `~/.config/starship.toml` 保留，不会被 bootstrap 覆盖。
8. 现有 `appearance.ghostty` 保留，因此当前 TokyoNight 选择不会被重置。
9. 第二次及以后运行不会再创建同类备份，也不会叠加 zsh 初始化区块。

Repo 完整管理：

```text
~/.zshrc
~/.config/ghostty/config.ghostty
~/.local/bin/devtheme
```

机器专属内容放在以下文件，bootstrap 永不覆盖：

```text
~/.config/zsh/local.zsh
~/.config/ghostty/local.ghostty
```

### Python / ML 项目

装机脚本不会安装 Python、创建 `.venv` 或 starter project。项目自己管理环境：

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

需要 PyTorch、MLX、Jupyter、profiling 或 serving 工具时，仅在对应项目中添加。

### 安全与幂等

```bash
# 查看计划
./scripts/bootstrap-macos.sh --features ai --dry-run

# 显式允许升级 Homebrew 软件
./scripts/bootstrap-macos.sh --features ai --upgrade

# 只安装软件，不修改 Ghostty/zsh
./scripts/bootstrap-macos.sh --features ai --skip-config

# 只更新终端配置
./scripts/configure-macos-shell.sh
```

脚本会：

- 先运行 `brew bundle check`，已满足的 manifest 整体跳过；
- 默认使用 `--no-upgrade`；
- 对已有主配置只保留固定名称的一次性 `.original` 备份；
- 使用一个 repo 管理的 `.zshrc`，避免新旧初始化逻辑同时存在；
- 清理 Ghostty 的其他加载路径，避免后加载文件暗中覆盖；
- 保留 Starship 活动配置、Ghostty appearance 以及两个 `local.*` override；
- 重复执行时不产生额外备份、不重置主题、不创建 Python 环境。

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

macOS CI 在 Linux 与 macOS runner 上验证 shell 语法、manifest 边界、一次性迁移、全部 Ghostty 配置路径、重复执行、主题切换和配置来源唯一性。

## 目录结构

```text
brewfiles/macos/
  core.Brewfile
  ai.Brewfile
  mlsys.Brewfile
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
