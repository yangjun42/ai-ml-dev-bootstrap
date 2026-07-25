# Architecture notes

## Tool ownership model

This repo uses a layered ownership model:

1. OS/package bootstrap:
   - Windows WSL backend: winget + WSL2 Ubuntu.
   - Windows native backend: uv-first, small feature groups, optional winget packages.
   - macOS: Homebrew Bundle for a small host profile; Apple Command Line Tools provide Git and OpenSSH.
2. Python project dependencies:
   - uv is the default owner for Python versions, virtual environments, PyPI packages, and lockfiles.
   - The default macOS host bootstrap installs the uv binary but does not create Python environments.
3. Native/scientific binary dependencies:
   - Miniforge provides the conda-forge entrypoint when a project needs it.
   - mamba is used as the fast CLI for conda environments.
4. Containers:
   - Optional. Use for reproducibility, CI parity, or deployment validation.
   - The macOS `workstation` profile provides Colima and Docker-compatible CLIs but does not start them.
5. Local model runtime:
   - The macOS `minimal` profile installs Ollama App without downloading models.
   - Direct MLX/MLX-LM development remains a project-level dependency managed with uv.

## Why not Anaconda Distribution by default?

Anaconda Distribution is convenient for teaching and enterprise setups that already standardize on it, but it is large and defaults to Anaconda channels. For a fresh open-source-first setup, Miniforge is smaller and defaults to conda-forge. Neither is part of the minimal Mac host profile.

## Why not uv-only everywhere?

uv is excellent for Python projects, but conda-forge remains strong when packages depend on non-Python native stacks: GDAL, HDF5, NetCDF, Qt, R, BioConductor, system BLAS variants, legacy scientific binaries, and cross-language toolchains.

## Windows design

When WSL2 is available, Windows is used as the desktop host and the AI/ML environment is created inside WSL2 Ubuntu. This avoids most Windows-native CUDA, compiler, and symlink/path issues.

When WSL2 is blocked or broken, the native Windows backend is the fallback. It defaults to `minimal,ai`, checks for existing commands before installing packages, shows WinGet progress by default, and allows project/cache/tool paths to be placed outside the default C:\Users tree.

## macOS design

macOS is treated as a lightweight developer host and remote-server control plane by default.

```text
minimal/core -> terminal, SSH/Git integration, editor, coding agents,
                Ollama, uv, and small desktop utilities

developer    -> minimal + common CLI repository tools

workstation  -> developer + local native-build and Docker-compatible tools

restricted   -> host-only variant without public AI apps or Ollama
```

The default profile does not install Python, PyTorch, MLX, Jupyter, conda, model weights, VS Code extensions, or shell frameworks. Each project owns those decisions through `pyproject.toml`, `uv.lock`, or a project-specific conda definition.

`personal` and `enterprise` remain compatibility aliases for `minimal` and `restricted` respectively. See [MACOS_PROFILES.md](MACOS_PROFILES.md).

## Enterprise/restricted design

The restricted profile is not a legal guarantee. It is a safer host default:

- no automatic installation of ChatGPT, Claude Code, or Ollama;
- no token setup or application login;
- no automatic model downloads;
- no Python project or public package-index configuration;
- room for organization-approved internal mirrors and applications.

The existing environment policy files remain available for Windows/WSL and legacy project bootstrap workflows:

- W&B offline mode;
- MLflow local file tracking;
- Hugging Face telemetry disabled;
- conda-forge + nodefaults guidance;
- private PyPI/conda mirror placeholders.
