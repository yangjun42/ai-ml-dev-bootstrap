# Architecture notes

## Tool ownership model

This repo uses a layered ownership model:

1. OS/package bootstrap:
   - Windows WSL backend: winget + WSL2 Ubuntu.
   - Windows native backend: uv-first, small feature groups, optional winget packages.
   - macOS: Homebrew Bundle for host applications and CLI tools; Apple Command Line Tools provide Git and OpenSSH.
2. macOS terminal configuration:
   - `minimal` owns a small Ghostty baseline and marked zsh history/completion block.
   - `developer` adds a second marked zsh block plus Starship/zoxide/fzf integrations.
   - user-owned Ghostty appearance/local overrides and unmarked `.zshrc` content are preserved.
3. Python project dependencies:
   - uv is the default owner for Python versions, virtual environments, PyPI packages, and lockfiles.
   - the default macOS host bootstrap installs the uv binary but does not create Python environments.
4. Native/scientific binary dependencies:
   - Miniforge provides the conda-forge entrypoint when a project needs it.
   - mamba is used as the fast CLI for conda environments.
5. Containers:
   - optional; use for reproducibility, CI parity, or deployment validation.
   - the macOS `workstation` profile provides Colima and Docker-compatible CLIs but does not start them.
6. Local model runtime:
   - the macOS `minimal` profile installs Ollama App without downloading models.
   - direct MLX/MLX-LM development remains a project-level dependency managed with uv.

## Configuration ownership and repeatability

Host package state is declarative through Brewfiles. `brew bundle check` provides
a fast no-op path and installation is followed by a satisfaction check. The
default uses `--no-upgrade`.

Terminal files use narrower ownership boundaries:

```text
repository-owned and refreshable
  ~/.config/ghostty/config.ghostty
  marked blocks inside ~/.zshrc
  ~/.local/bin/devtheme

created once, then user-owned
  ~/.config/ghostty/appearance.ghostty

never created or modified
  ~/.config/ghostty/local.ghostty
  unmarked ~/.zshrc content
```

An unmanaged or symlinked Ghostty main config is not silently replaced. The
configurator writes a review candidate unless the user explicitly supplies
`--force-config`. Managed-file and zsh backups are kept under
`~/.config/ai-ml-dev-bootstrap/backups/`.

## Why not Anaconda Distribution by default?

Anaconda Distribution is convenient for teaching and enterprise setups that
already standardize on it, but it is large and defaults to Anaconda channels.
For a fresh open-source-first setup, Miniforge is smaller and defaults to
conda-forge. Neither is part of the minimal Mac host profile.

## Why not uv-only everywhere?

uv is excellent for Python projects, but conda-forge remains strong when
packages depend on non-Python native stacks: GDAL, HDF5, NetCDF, Qt, R,
BioConductor, system BLAS variants, legacy scientific binaries, and
cross-language toolchains.

## Windows design

When WSL2 is available, Windows is used as the desktop host and the AI/ML
environment is created inside WSL2 Ubuntu. This avoids most Windows-native
CUDA, compiler, and symlink/path issues.

When WSL2 is blocked or broken, the native Windows backend is the fallback. It
defaults to `minimal,ai`, checks for existing commands before installing
packages, shows WinGet progress by default, and allows project/cache/tool paths
to be placed outside the default `C:\Users` tree.

## macOS design

macOS is treated as a lightweight developer host and remote-server control
plane by default.

```text
minimal/core -> host apps, SSH/Git, editor, coding agents, Ollama, uv,
                Ghostty TokyoNight baseline, zsh history/completion

developer    -> minimal + Starship Jetpack, zoxide, fzf, typing helpers,
                common repository CLI tools

workstation  -> developer + local native-build and Docker-compatible tools

restricted   -> conservative host/Ghostty/zsh variant without public AI apps
                or Ollama
```

Ghostty explicitly launches `/bin/zsh -l`. This gives the profile deterministic
shell behaviour even when an enterprise directory account still advertises
`/bin/bash`, without changing the account-wide login shell.

The default visual pairing is TokyoNight Moon/Day with Starship Jetpack. The
optional `devtheme` helper coordinates a small set of alternative Ghostty and
Starship presets, but the bootstrap preserves the active selection on reruns.

The profiles do not install Python, PyTorch, MLX, Jupyter, conda, model weights,
VS Code extensions, Oh My Zsh, or Powerlevel10k. Each project owns language and
ML dependencies through `pyproject.toml`, `uv.lock`, or a project-specific
conda definition.

`personal` and `enterprise` remain compatibility aliases for `minimal` and
`restricted`. See [MACOS_PROFILES.md](MACOS_PROFILES.md) and
[MACOS_TERMINAL.md](MACOS_TERMINAL.md).

## Enterprise/restricted design

The restricted profile is not a legal guarantee. It is a safer host default:

- no automatic installation of ChatGPT, Claude Code, or Ollama;
- no token setup or application login;
- no automatic model downloads;
- no Python project or public package-index configuration;
- room for organization-approved internal mirrors and applications.

The existing environment policy files remain available for Windows/WSL and
legacy project bootstrap workflows:

- W&B offline mode;
- MLflow local file tracking;
- Hugging Face telemetry disabled;
- conda-forge + nodefaults guidance;
- private PyPI/conda mirror placeholders.
