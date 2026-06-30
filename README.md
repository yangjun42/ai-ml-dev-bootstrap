# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发环境 bootstrap 模板。

核心原则：

- **uv-first**：大多数 Python / PyTorch / Hugging Face / scikit-learn 项目由 uv 管理。
- **Miniforge + mamba 作为 fallback**：用于 conda-forge native 二进制依赖、团队 `environment.yml` 复现、GDAL/HDF5/R/Qt 等复杂依赖。
- **Windows 优先 WSL2；WSL 被企业策略或系统问题阻断时，使用 native Windows fallback**。
- **容器、CUDA Toolkit、Visual Studio Build Tools、MLsys profiling 都是可选项，不再默认安装**。
- **personal / enterprise 两套 profile**：personal 更自由；enterprise 更保守、本地优先、关闭常见遥测默认项。

> 本仓库不替代公司的安全、合规和许可证审查。`enterprise` profile 只是保守默认值模板。

---

## Miniforge + mamba 是否重复？

不完全重复。

```text
Miniforge = conda-forge 生态的安装入口 / 发行版
mamba     = 管理 conda 环境和包的快速 CLI / 求解器
uv        = Python/PyPI/项目环境的主包管理器
```

本仓库默认不用 conda 处理常规 Python 项目；只有当你启用 `conda` feature 时才安装 Miniforge/mamba。

---

## Windows 11：native / 无 WSL fallback

当 `wsl --update`、`wsl --install` 或企业策略阻止 WSL 时，用 native Windows 路线。

### 最小企业版，默认会交互询问目录并显示安装进度

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend native -Profile enterprise
```

等价直接入口：

```powershell
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise
```

native Windows 默认 feature 现在是：

```text
enterprise 默认: minimal,ai
personal 默认:   minimal,ai,vcs,editor,build,conda
```

其中 `minimal,ai` 只做 uv、项目 `.venv`、PyTorch/Hugging Face/scientific Python 依赖和本地 profile 环境变量。不会默认装 Git、GitHub CLI、VSCodium、CMake、Ninja、Visual Studio Build Tools 或 CUDA Toolkit。

### 指定非 C 盘安装/缓存根目录

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -InstallRoot D:\AI `
  -UseDefaults `
  -AssumeYes
```

这会把默认目录集中到：

```text
D:\AI\Projects\ai-ml-starter
D:\AI\miniforge3
D:\AI\Models\huggingface
D:\AI\mlruns
D:\AI\uv-cache
D:\AI\uv-python
D:\AI\uv-tools
```

也可以逐项指定：

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -ProjectDir D:\Projects\ai-ml-starter `
  -ModelsDir D:\Models\huggingface `
  -UvCacheDir D:\Caches\uv `
  -UvPythonInstallDir D:\Tools\uv-python `
  -MiniforgeDir D:\Tools\miniforge3
```


### 已存在 / 非空目录处理

native Windows 脚本现在是可重复运行的。模型目录、MLflow 目录、uv cache 这类数据/缓存目录可以非空，会直接复用。

对于 Miniforge、uv standalone、`.venv`、conda env 这类“生成目录”，如果目标目录非空但不完整，脚本不会再让 installer 直接失败；默认在交互式 PowerShell 里询问，非交互模式下自动移动到 `.incomplete-时间戳` 后继续。

```powershell
# 推荐：非交互时把不完整生成目录移到旁边，不误删数据
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -InstallRoot D:\AI `
  -UseDefaults `
  -AssumeYes `
  -ExistingInstallDirPolicy backup `
  -ExistingProjectPolicy merge

# 想清理半成品并重装工具目录
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -ExistingInstallDirPolicy clean

# 项目目录非空但不是 starter project 时，新建时间戳目录
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -ExistingProjectPolicy new
```

`ExistingProjectPolicy merge` 只复制缺失的模板文件，不覆盖已有文件。

### WinGet 进度 / 交互 / 日志

默认 `WingetMode` 是 `progress`，不再使用 `--silent --disable-interactivity`，会尽量显示 winget 的安装进度并写 per-package verbose log。

```powershell
# 默认：显示 winget 进度
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise

# 显示安装器 UI，适合人工装机排查
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -WingetMode interactive

# 旧行为：静默安装，适合 CI 或全自动镜像
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -WingetMode silent -UseDefaults -AssumeYes
```

WinGet 日志：

```text
%TEMP%\ai-ml-dev-bootstrap\winget-logs
%TEMP%\ai-ml-dev-bootstrap\winget-checks
```

企业机器上如果 WinGet 下载或安装长时间不返回，脚本现在有安装超时；超时后会报出更明确的网络、代理、App Installer 或策略问题，而不是无限等待。

```powershell
# 缩短安装/下载超时，0 表示不设置超时
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -WingetInstallTimeoutSec 600

# 如果 winget list 检测不可靠，跳过检测，直接尝试 winget install
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -SkipWingetInstalledCheck
```

如果看到 `A package version is already installed. Installation cancelled.` 但随后 `uv` 找不到，新版会刷新 PATH、查找 WinGet link 目录，并在必要时尝试 `winget install ... --force` 修复；enterprise 模式仍不会自动运行远程 `irm ... | iex` 安装脚本。

可选地给支持安装位置的 winget 包传 `--location`：

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile personal `
  -Features minimal,ai,vcs,editor,build `
  -WingetInstallLocation D:\Apps `
  -WingetMode interactive
```

注意：`--location` 只有部分 installer 支持。脚本会先带 `--location` 尝试；如果失败，会自动重试一次不带 `--location`。

### 可选 feature 示例

```powershell
# 仅 uv + AI 项目
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features minimal,ai

# 加 Miniforge/mamba fallback
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features minimal,ai,conda

# 加 Git/GitHub CLI
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features minimal,ai,vcs

# 加编辑器和 CMake/Ninja，但不装 VS Build Tools
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features minimal,ai,vcs,editor,build

# 需要编译 C++/CUDA extension 时才启用
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features minimal,ai,native-build,cuda-toolkit-windows

# 加 MLsys profiling / benchmark 工具
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features minimal,ai,mlsys

# 跳过某些包
.\scripts\bootstrap-windows-native.ps1 `
  -Profile personal `
  -Features minimal,ai,vcs,editor,build `
  -SkipPackages Git.Git,VSCodium.VSCodium
```

---

## Windows 11：推荐 WSL2 Ubuntu 路线

WSL 正常时，仍推荐 WSL2 Ubuntu 作为主线：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\bootstrap.ps1 -Backend wsl -Profile personal
```

Windows 已安装 NVIDIA driver / CUDA 时，WSL2 会通过 Windows driver bridge 暴露 GPU。普通 PyTorch/Hugging Face 使用通常不需要在 WSL 里安装 Linux CUDA Toolkit；只有需要 `nvcc`、CUDA headers、CUDA samples 或编译 CUDA extension 时才启用：

```powershell
.\scripts\bootstrap.ps1 -Backend wsl -Profile personal -Features core,ai,conda,cuda-toolkit -CudaToolkitVersion 13-3
```

WSL 更新失败时可先收集诊断：

```powershell
.\scripts\triage-wsl-update.ps1
```

---

## macOS

```bash
./scripts/bootstrap-macos.sh --profile personal
./scripts/bootstrap-macos.sh --profile enterprise
./scripts/bootstrap-macos.sh --profile personal --features core,ai,conda,mlsys
```

Apple Silicon 机器会额外尝试安装 MLX 相关包。

---

## Feature 表

| feature | native Windows 默认 | 说明 |
|---|---:|---|
| `minimal` | ✅ | uv + profile 环境变量；不安装桌面/构建工具 |
| `ai` | ✅ | 创建 starter 项目和 `.venv`，安装 PyTorch/HF/scikit-learn/Jupyter |
| `conda` | personal ✅ / enterprise ❌ | 安装 Miniforge/mamba 和 conda fallback env |
| `vcs` | personal ✅ / enterprise ❌ | Git、GitHub CLI |
| `editor` | personal ✅ / enterprise ❌ | VSCodium；如果检测到 `codium` 或 `code` 会跳过 |
| `desktop` | ❌ | PowerShell、Windows Terminal、7-Zip |
| `build` | personal ✅ / enterprise ❌ | CMake、Ninja；用于 native build helpers，不是 VS Build Tools |
| `native-build` | ❌ | Visual Studio Build Tools / MSVC；仅编译 C++/CUDA 扩展时启用 |
| `cuda-toolkit-windows` | ❌ | NVIDIA CUDA Toolkit for Windows；仅需要 `nvcc` 时启用 |
| `windows-cuda-extras` | ❌ | Windows CUDA 相关 Python extras |
| `mlsys` | ❌ | profiling / benchmark 工具 |
| `containers` | ❌ | Podman Desktop / Rancher Desktop |
| `core` | 兼容别名 | 展开为 `minimal,desktop,vcs,editor,build`，不再建议作为企业默认 |

---

## 目录结构

```text
scripts/
  bootstrap.ps1                  # Windows unified entrypoint
  bootstrap-windows-native.ps1   # native Windows/no-WSL backend
  bootstrap-wsl.sh               # WSL Ubuntu backend
  bootstrap-macos.sh             # macOS backend
  install-miniforge-windows.ps1  # Windows Miniforge installer
  preflight-windows-native.ps1   # Windows native GPU/toolchain check
  triage-wsl-update.ps1          # WSL update/install diagnostics

tools/
  test-powershell-syntax.ps1     # maintainer-only syntax parser, not a user bootstrap entrypoint

docs/
  WINDOWS_NATIVE_NO_WSL.md
  WINDOWS_WSL_NVIDIA.md
  WSL_UPDATE_TRIAGE.md
```
