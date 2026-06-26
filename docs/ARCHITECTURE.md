# Architecture notes

## Tool ownership model

This repo uses a layered ownership model:

1. OS/package bootstrap:
   - Windows WSL backend: winget + WSL2 Ubuntu.
   - Windows native backend: uv-first, small feature groups, optional winget packages.
   - macOS: Homebrew for OS-level developer tools.
2. Python project dependencies:
   - uv is the default owner for Python virtual environments and PyPI packages.
3. Native/scientific binary dependencies:
   - Miniforge provides the conda-forge entrypoint.
   - mamba is used as the fast CLI for conda environments.
4. Containers:
   - Optional. Use for reproducibility, CI parity, or deployment validation.

## Why not Anaconda Distribution by default?

Anaconda Distribution is convenient for teaching and enterprise setups that already standardize on it, but it is large and defaults to Anaconda channels. For a fresh open-source-first setup, Miniforge is smaller and defaults to conda-forge.

## Why not uv-only everywhere?

uv is excellent for Python projects, but conda-forge remains strong when packages depend on non-Python native stacks: GDAL, HDF5, NetCDF, Qt, R, BioConductor, system BLAS variants, legacy scientific binaries, and cross-language toolchains.

## Windows design

When WSL2 is available, Windows is used as the desktop host and the AI/ML environment is created inside WSL2 Ubuntu. This avoids most Windows-native CUDA, compiler, and symlink/path issues.

When WSL2 is blocked or broken, the native Windows backend is the fallback. It defaults to `minimal,ai`, checks for existing commands before installing packages, shows WinGet progress by default, and allows project/cache/tool paths to be placed outside the default C:\Users tree.

## macOS design

macOS runs native. Apple Silicon machines get PyTorch MPS support through PyTorch and optional MLX packages.

## Enterprise profile design

The enterprise profile is not a legal guarantee. It is a safer default:

- no token setup;
- no automatic login to external services;
- W&B offline mode;
- MLflow local file tracking;
- Hugging Face telemetry disabled;
- conda-forge + nodefaults guidance;
- room for private PyPI/conda mirrors.
