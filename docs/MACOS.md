# macOS setup

The macOS bootstrap has only three concepts:

```text
core     shared development host baseline
feature  optional host capability
project  owns Python, frameworks, environments, and lockfiles
```

The public interface is intentionally small:

```text
features: ai, mlsys, containers
```

There are no profiles or tiered setup levels.

## Recommended commands

Personal Apple Silicon Mac:

```bash
./scripts/bootstrap-macos.sh --features ai
```

Enterprise-managed or public-AI-restricted machine:

```bash
./scripts/bootstrap-macos.sh
```

Optional host tooling:

```bash
./scripts/bootstrap-macos.sh --features mlsys
./scripts/bootstrap-macos.sh --features containers
./scripts/bootstrap-macos.sh --features ai,mlsys
./scripts/bootstrap-macos.sh --features all
```

## Core

Core is installed by every invocation:

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

Git and OpenSSH are supplied by macOS / Apple Command Line Tools and are not
reinstalled through Homebrew.

Core deliberately excludes:

```text
public AI applications
local model runtimes
containers
native ML systems build tools
Python and project environments
```

## Features

### `ai`

```bash
./scripts/bootstrap-macos.sh --features ai
```

Installs exactly:

```text
ChatGPT desktop / Codex
Claude Code CLI
Ollama App
```

This is the recommended personal setup. It installs applications only and does
not sign in, write credentials, download an Ollama model, or create a project.

#### Why Ollama, not llama.cpp by default?

Both can run local models, so installing both in a simple host bootstrap is
mostly redundant.

Ollama is selected because it provides the higher-level workflow needed here:

```text
model download and storage
simple CLI and desktop app
local HTTP API
coding-agent integrations
minimal runtime configuration
```

`llama.cpp` is a lower-level inference toolkit. Install it separately only when
you need direct GGUF file handling, conversion or quantization, detailed server
flags, kernel/runtime experiments, or its benchmark tools.

FFmpeg is not part of `ai`; multimedia preprocessing belongs to a project or a
future narrowly scoped feature when a real need appears.

### `mlsys`

```bash
./scripts/bootstrap-macos.sh --features mlsys
```

Installs:

```text
CMake
Ninja
pkgconf
hyperfine
```

This feature is systems-facing rather than model-facing. It supports native
extension builds, runtime/component compilation, and repeatable command-level
benchmarks.

It does not install Python, PyTorch, MLX, Jupyter, ONNX Runtime, TensorBoard, or
profiling packages. Those versions must remain aligned with the repository that
uses them.

### `containers`

```bash
./scripts/bootstrap-macos.sh --features containers
```

Installs:

```text
Colima
Docker CLI
Docker Compose
```

It does not start Colima, create a VM, change Docker context, pull an image, or
run a container.

### `all`

Equivalent to:

```bash
./scripts/bootstrap-macos.sh --features ai,mlsys,containers
```

## Project environments

The host installs uv but never creates a Python environment.

Existing project:

```bash
cd project
uv sync
```

New project:

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy pandas scikit-learn
```

Add PyTorch, MLX, Jupyter, Transformers, serving packages, or profilers only when
that repository requires them. This keeps the Mac host small and lets local,
remote, and CI environments reproduce from project files instead of machine
history.

## Terminal baseline

### Ghostty

Managed files:

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/appearance.ghostty
```

Defaults:

```text
Dark theme   TokyoNight Moon
Light theme  TokyoNight Day
Shell        /bin/zsh -l
Updates      check stable channel
```

The explicit zsh command handles directory-managed accounts that still advertise
`/bin/bash`, without changing the account-wide login shell.

The baseline also configures SSH/terminfo integration, working-directory
inheritance, bounded scrollback, secure input, clipboard protection, and an
optional `local.ghostty` override.

### zsh

The configurator maintains exactly one marked block in `~/.zshrc`:

```zsh
# >>> ai-ml-dev-bootstrap:macos-core >>>
...
# <<< ai-ml-dev-bootstrap:macos-core <<<
```

It provides:

```text
Homebrew PATH recovery
shared persistent history
native completion
Starship Jetpack
zoxide
fzf shell integration
zsh-autosuggestions
zsh-syntax-highlighting
```

Oh My Zsh and Powerlevel10k are intentionally not installed.

### Theme switching

```bash
devtheme current
devtheme list

devtheme tokyo
devtheme tokyo-night
devtheme catppuccin
devtheme gruvbox
```

An explicit switch backs up a custom active Starship configuration before
replacing it. Press `Cmd+Shift+,` in Ghostty after switching.

## Repeatability and ownership

The bootstrap is safe to rerun:

- `brew bundle check` skips satisfied manifests;
- upgrades require `--upgrade`;
- managed Ghostty files are backed up before replacement;
- unmanaged or symlinked Ghostty files are preserved and receive a review candidate;
- `appearance.ghostty` is installed only when missing;
- `local.ghostty` is never managed;
- only the repository-marked zsh block is replaced;
- active Ghostty and Starship theme choices survive reruns.

Useful controls:

```bash
./scripts/bootstrap-macos.sh --features ai --dry-run
./scripts/bootstrap-macos.sh --features ai --upgrade
./scripts/bootstrap-macos.sh --features ai --skip-config
./scripts/bootstrap-macos.sh --features ai --force-config
./scripts/configure-macos-shell.sh
```

## Validation

```bash
make verify-macos
```

GitHub Actions runs static and integration checks on Linux and macOS, including
manifest boundaries, repeatability, theme switching, and user configuration
preservation.
