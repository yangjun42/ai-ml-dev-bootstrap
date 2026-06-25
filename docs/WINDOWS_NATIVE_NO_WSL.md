# Windows native AI/ML bootstrap without WSL

This document is for Windows 11 workstations where WSL2 is unavailable, broken, blocked by policy, or unnecessary.

The native Windows path is a first-class fallback, not a full replacement for the WSL2/Linux path. It is good for PyTorch, Hugging Face, scikit-learn, notebooks, inference demos, RAG prototypes, and many internal enterprise workstations. It is less ideal for Linux-first CUDA extensions, distributed training stacks, and packages that assume a POSIX toolchain.

## When to use this path

Use `scripts/bootstrap-windows-native.ps1` when:

- `wsl --update` or `wsl --install` fails and the root cause is Windows/MSIX/MSI/Store/enterprise-policy related.
- Your company disables Hyper-V, VirtualMachinePlatform, Microsoft Store, or WSL distribution installation.
- You already have a working Windows NVIDIA driver and want PyTorch CUDA wheels directly on Windows.
- You need a conservative enterprise setup that avoids WSL image management.

Prefer the WSL2 path when:

- You develop Linux-first ML systems code.
- You need Linux CUDA extension compatibility, Linux containers, or deployment parity with Linux servers.
- You use packages that are only tested on Linux.

## Quick start

Run from an elevated PowerShell when possible:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

# Personal profile, default features: core, ai, conda
.\scripts\bootstrap-windows-native.ps1 -Profile personal

# Enterprise/local-first profile
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise

# Add MLsys profiling tools
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features core,ai,conda,mlsys

# Force CPU-only PyTorch
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise -PytorchBackend cpu

# Let uv select the appropriate PyTorch backend from installed GPU/driver state
.\scripts\bootstrap-windows-native.ps1 -Profile personal -PytorchBackend auto
```

The default project path is:

```text
%USERPROFILE%\Projects\ai-ml-starter
```

After installation:

```powershell
cd $env:USERPROFILE\Projects\ai-ml-starter
uv run python scripts\check_env.py
uv run jupyter lab
```

## What gets installed

Default `core,ai,conda` installs:

- Windows Terminal, PowerShell, Git, GitHub CLI, 7-Zip, VSCodium via winget.
- `uv` using Astral's official PowerShell installer.
- CPython using `uv python install`.
- A project-local `.venv` with scientific Python, PyTorch, Hugging Face, Jupyter, and dev tools.
- Optional Miniforge/mamba as the conda-forge native dependency fallback.

## NVIDIA / CUDA on native Windows

For PyTorch wheel usage, you usually need only:

- Windows NVIDIA display driver.
- A PyTorch CUDA wheel selected by the PyTorch install index or by `uv pip install --torch-backend=auto`.

You do **not** need the full CUDA Toolkit just to run normal PyTorch CUDA wheels. Install CUDA Toolkit and Visual Studio Build Tools only when you compile native CUDA code, custom PyTorch extensions, or build libraries from source.

Preflight:

```powershell
.\scripts\preflight-windows-native.ps1
```

Useful checks:

```powershell
nvidia-smi
nvcc --version       # only expected if CUDA Toolkit is installed
where cl             # only expected if MSVC shell/path is configured
```

Install Visual Studio Build Tools only when needed:

```powershell
.\scripts\bootstrap-windows-native.ps1 -Profile personal -Features core,ai,native-build
```


## Restricted / offline-friendly enterprise mode

In `enterprise` profile, the native script avoids the uv internet installer fallback. Install `uv` through an approved source first, or let `winget` install `astral-sh.uv` if your organization allows it.

For Miniforge in environments where direct GitHub downloads are blocked, download and approve `Miniforge3-Windows-x86_64.exe` internally, then run:

```powershell
.\scripts\bootstrap-windows-native.ps1 `
  -Profile enterprise `
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
MLFLOW_TRACKING_URI=file:///%USERPROFILE%/mlruns
```

It does not log in to external services, does not write tokens, and does not require container engines.

## Known limitations compared with WSL2/Linux

- Some CUDA extension packages are Linux-first and may not provide Windows wheels.
- Build failures are more likely when packages require `nvcc`, MSVC, CMake, Ninja, or custom C++/CUDA compilation.
- Linux deployment parity is weaker than WSL2 or containers.
- `bitsandbytes`, `xformers`, `flash-attn`, Triton-based kernels, and similar packages require case-by-case compatibility checks on Windows.

## Recommended fallback ladder

1. Native Windows uv project: fastest path when WSL is blocked.
2. Native Windows + Miniforge/mamba: use for conda-forge binary dependencies.
3. Native Windows + optional containers: use when Podman/Rancher Desktop is allowed.
4. WSL2 Ubuntu: return to this when Windows WSL/MSIX issues are repaired.
5. Remote Linux dev box or GPU server: use when you need Linux-first MLsys/CUDA parity.
