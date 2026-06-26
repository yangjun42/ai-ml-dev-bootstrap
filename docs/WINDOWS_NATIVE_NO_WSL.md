# Windows native AI/ML bootstrap without WSL

This document is for Windows 11 workstations where WSL2 is unavailable, broken, blocked by policy, or unnecessary.

The native Windows path is a first-class fallback. It is good for PyTorch, Hugging Face, scikit-learn, notebooks, inference demos, RAG prototypes, and many enterprise workstations. It is less ideal for Linux-first CUDA extensions, distributed training stacks, and packages that assume POSIX tooling.

## Design changes in the interactive/native template

The native Windows template is intentionally split into small feature groups. It no longer treats Git, editors, CMake, Ninja, Visual Studio Build Tools, or CUDA Toolkit as part of the default enterprise install.

Default features:

```text
enterprise -> minimal,ai
personal   -> minimal,ai,vcs,editor,build,conda
```

Backward compatibility:

```text
core -> minimal,desktop,vcs,editor,build
```

Use `core` only when you explicitly want the old broad desktop-developer bundle.

## Quick start

Run from PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

# Enterprise/local-first profile, minimal default
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise

# Personal profile, broader default
.\scripts\bootstrap-windows-native.ps1 -Profile personal

# Add Miniforge/mamba to enterprise
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features minimal,ai,conda

# Force CPU-only PyTorch
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -PytorchBackend cpu
```

## Interactive location prompts

By default, if a PowerShell host is interactive, the script asks you to confirm or override these paths:

```text
InstallRoot
ProjectDir
MiniforgeDir
ModelsDir
MlrunsDir
UvCacheDir
UvPythonInstallDir
UvToolDir
UvToolBinDir
UvInstallDir
WingetInstallLocation optional
```

To place most AI/ML state on a non-C drive while keeping the command short:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -InstallRoot D:\AI `
  -UseDefaults `
  -AssumeYes
```

This maps to:

```text
D:\AI\Projects\ai-ml-starter
D:\AI\miniforge3
D:\AI\Models\huggingface
D:\AI\mlruns
D:\AI\uv-cache
D:\AI\uv-python
D:\AI\uv-tools
D:\AI\uv-tools-bin
D:\AI\uv-bin
```

For fully explicit paths:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -ProjectDir D:\Projects\ai-ml-starter `
  -ModelsDir D:\Models\huggingface `
  -MlrunsDir D:\MLRuns `
  -UvCacheDir D:\Caches\uv `
  -UvPythonInstallDir D:\Tools\uv-python `
  -MiniforgeDir D:\Tools\miniforge3
```

To suppress all prompts:

```powershell
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -UseDefaults -AssumeYes
```



## Existing / non-empty target directories

The native bootstrap is designed to be re-runnable. Data/cache directories such as `ModelsDir`, `MlrunsDir`, and `UvCacheDir` may be non-empty and are reused.

Generated tool directories are handled more carefully. If `MiniforgeDir`, the uv standalone install directory, a `.venv`, or the conda environment prefix already exists but does not contain the expected marker files, the script no longer lets the installer fail blindly. It uses `ExistingInstallDirPolicy`:

```powershell
# Default: ask interactively; in non-interactive mode, move incomplete dirs aside.
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features minimal,ai,conda

# Always move incomplete generated/tool dirs aside and continue.
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -ExistingInstallDirPolicy backup

# Delete incomplete generated/tool dirs and reinstall.
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -ExistingInstallDirPolicy clean

# Fail fast instead of modifying anything.
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -ExistingInstallDirPolicy fail
```

For the starter project directory, the separate `ExistingProjectPolicy` controls what happens when `ProjectDir` is non-empty but has no `pyproject.toml`:

```powershell
# Default: ask interactively; non-interactive default is merge.
# merge copies only missing template files and never overwrites existing files.
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -ExistingProjectPolicy merge

# Create a new timestamped project directory instead.
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -ExistingProjectPolicy new
```

For a fully non-interactive enterprise install that avoids C drive state where possible and safely moves incomplete generated directories aside:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -InstallRoot D:\AI `
  -UseDefaults `
  -AssumeYes `
  -ExistingInstallDirPolicy backup `
  -ExistingProjectPolicy merge
```

## WinGet visibility modes

The default `WingetMode` is `progress`: the script does not pass `--silent --disable-interactivity`, so winget and installers can show normal progress where supported.

```powershell
# Default progress mode
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise

# Explicit installer UI
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -WingetMode interactive

# Old silent behavior
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -WingetMode silent -UseDefaults -AssumeYes
```

Per-package verbose logs are written to:

```text
%TEMP%\ai-ml-dev-bootstrap\winget-logs
```

The script also prints the exact `winget` command it is about to run.

## Optional WinGet install location

If you set `WingetInstallLocation`, the script passes `winget install --location <path>` only to package installs marked as location-capable in the template:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile personal `
  -Features minimal,ai,vcs,editor,build `
  -WingetInstallLocation D:\Apps `
  -WingetMode interactive
```

Caveat: `--location` is only honored by installers that support custom install paths. Some packages ignore it or fail. The template retries once without `--location` if the first attempt fails.

## Command-level skip logic

Before calling winget, the script checks both:

1. Whether an equivalent command already exists on PATH.
2. Whether `winget list -e --id <package>` already sees the package.

Examples:

```text
Git.Git               -> skips if git exists
GitHub.cli            -> skips if gh exists
VSCodium.VSCodium     -> skips if codium or code exists
Kitware.CMake         -> skips if cmake exists
Ninja-build.Ninja     -> skips if ninja exists
astral-sh.uv          -> skips if uv exists
Nvidia.CUDA           -> skips if nvcc exists
```

You can also manually skip packages:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile personal `
  -Features minimal,ai,vcs,editor,build `
  -SkipPackages Git.Git,VSCodium.VSCodium
```

Or restrict package installation to only specific IDs:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile personal `
  -Features vcs,editor `
  -OnlyPackages VSCodium.VSCodium
```

## Feature reference

| feature | Purpose |
|---|---|
| `minimal` | uv + local environment variables. No Git/editor/build tools. |
| `ai` | Starter project and `.venv`, PyTorch, Hugging Face, scikit-learn, Jupyter. |
| `conda` | Miniforge/mamba fallback environment. |
| `vcs` | Git and GitHub CLI. |
| `editor` | VSCodium; skipped if `codium` or `code` already exists. |
| `desktop` | PowerShell, Windows Terminal, 7-Zip. |
| `build` | CMake and Ninja only. |
| `native-build` | Visual Studio Build Tools / MSVC, optional and heavy. |
| `cuda-toolkit-windows` | NVIDIA CUDA Toolkit for Windows, optional; only needed for `nvcc`. |
| `windows-cuda-extras` | Windows CUDA-oriented Python extras. |
| `mlsys` | Profiling and benchmark Python tools. |
| `containers` | Podman Desktop and Rancher Desktop. |
| `core` | Backward-compatible alias for `minimal,desktop,vcs,editor,build`. |

## NVIDIA / CUDA on native Windows

For normal PyTorch wheel usage, you usually need only:

- Windows NVIDIA display driver.
- A PyTorch CUDA wheel selected by `uv pip install --torch-backend=auto` or an explicit backend.

You do **not** need the full CUDA Toolkit just to run normal PyTorch CUDA wheels. Install CUDA Toolkit and Visual Studio Build Tools only when you compile native CUDA code, custom PyTorch extensions, or build libraries from source.

Useful checks:

```powershell
nvidia-smi
nvcc --version       # only expected if CUDA Toolkit is installed
where cl             # only expected if MSVC shell/path is configured
```

## Restricted / offline-friendly enterprise mode

In `enterprise` profile, the native script avoids the uv internet installer fallback. Install `uv` through an approved source first, or allow winget to install `astral-sh.uv` if your organization permits it.

For Miniforge in environments where direct GitHub downloads are blocked, download and approve `Miniforge3-Windows-x86_64.exe` internally, then run:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
  -Features minimal,ai,conda `
  -NoRemoteScripts `
  -MiniforgeInstallerPath C:\Path\To\Miniforge3-Windows-x86_64.exe
```

## Enterprise profile behavior

The enterprise profile is conservative. It sets user environment defaults such as:

```text
AI_DEV_PROFILE=enterprise
HF_HUB_DISABLE_TELEMETRY=1
DO_NOT_TRACK=1
WANDB_MODE=offline
MLFLOW_TRACKING_URI=file:///<chosen-mlruns-dir>
HF_HOME=<chosen-model-cache-dir>
UV_CACHE_DIR=<chosen-uv-cache-dir>
UV_PYTHON_INSTALL_DIR=<chosen-uv-python-dir>
```

It does not log in to external services, does not write tokens, and does not require container engines.

## Known limitations compared with WSL2/Linux

- Some CUDA extension packages are Linux-first and may not provide Windows wheels.
- Build failures are more likely when packages require `nvcc`, MSVC, CMake, Ninja, or custom C++/CUDA compilation.
- Linux deployment parity is weaker than WSL2 or containers.
- `bitsandbytes`, `xformers`, `flash-attn`, Triton-based kernels, and similar packages require case-by-case compatibility checks on Windows.

## Debugging

PowerShell syntax checks for maintainers:

```powershell
pwsh .\tools\test-powershell-syntax.ps1
```

WinGet logs:

```powershell
Get-ChildItem $env:TEMP\ai-ml-dev-bootstrap\winget-logs | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

Tail latest log:

```powershell
$latest = Get-ChildItem $env:TEMP\ai-ml-dev-bootstrap\winget-logs -Filter *.log |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
Get-Content $latest.FullName -Tail 100 -Wait
```
