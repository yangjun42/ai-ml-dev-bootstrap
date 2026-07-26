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

There are no profiles, tiered setup levels, or compatibility aliases.

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

Core deliberately excludes public AI applications, a local model runtime,
containers, ML systems build tools, Python, and project environments.

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

It does not sign in, write credentials, download an Ollama model, install
Python, or create a project.

#### Why Ollama, not llama.cpp by default?

Both can run local models, so installing both in a small host bootstrap is
mostly redundant. Ollama provides the intended higher-level workflow:

```text
model download and storage
simple CLI and desktop app
local HTTP API
coding-agent integrations
minimal runtime configuration
```

`llama.cpp` remains a manual advanced choice for direct GGUF handling,
conversion or quantization, detailed server flags, kernel/runtime experiments,
or its benchmark tools. FFmpeg is also omitted until a project has a concrete
multimedia requirement.

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

This feature supports native-extension builds, runtime/component compilation,
and repeatable command-level benchmarks. Framework-specific profilers and
runtimes remain project dependencies.

### `containers`

```bash
./scripts/bootstrap-macos.sh --features containers
```

Installs Colima, Docker CLI, and Docker Compose. It does not start Colima,
create a VM, change Docker context, pull an image, or run a container.

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

Add PyTorch, MLX, Jupyter, Transformers, serving packages, or profilers only
when that repository requires them.

## Terminal baseline

### Ghostty

The repository manages one primary file:

```text
~/.config/ghostty/config.ghostty
```

The first time an existing file is replaced, its original content is saved to:

```text
~/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original
```

Only that one fixed backup is created. Subsequent updates do not create backup
clutter.

Appearance and machine-local settings are separate:

```text
~/.config/ghostty/appearance.ghostty  preserved when already present
~/.config/ghostty/local.ghostty       never created or overwritten
```

Defaults:

```text
Dark theme   TokyoNight Moon
Light theme  TokyoNight Day
Shell        macOS login shell
Updates      check stable channel
```

The managed config does not force a shell. It contains this commented recovery
option:

```ini
# command = /bin/zsh -l
```

A fresh install keeps it commented. If migration detects that any existing
Ghostty config already enabled `command = /bin/zsh -l`, the generated managed
file keeps it enabled. This avoids breaking directory-managed accounts that
still launch Bash. Shell integration remains automatic:

```ini
shell-integration = detect
```

Ghostty supports both `config.ghostty` and the older filename `config`, in the
XDG and macOS Application Support locations. Later files override earlier ones,
so leaving more than one creates ambiguous precedence. The configurator keeps
only the primary XDG file and removes these alternatives after one-time backup:

| duplicate path | backup |
|---|---|
| `~/.config/ghostty/config` | `ghostty-xdg-legacy-config.original` |
| `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` | `ghostty-macos-config.original` |
| `~/Library/Application Support/com.mitchellh.ghostty/config` | `ghostty-macos-legacy-config.original` |

All backups live under:

```text
~/.config/ai-ml-dev-bootstrap/backups/
```

### zsh

The repository owns the complete:

```text
~/.zshrc
```

An existing file is saved once as:

```text
~/.config/ai-ml-dev-bootstrap/backups/zshrc.original
```

The managed file provides:

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

Put personal or machine-specific additions in:

```text
~/.config/zsh/local.zsh
```

That file is never created or overwritten by the bootstrap. It is loaded before
the final typing helpers so syntax highlighting remains the last line-editor
integration.

Oh My Zsh and Powerlevel10k are intentionally not installed.

### Starship

On a fresh machine, the configurator generates Jetpack and selects it through:

```text
~/.config/starship.toml
```

If that file already exists, it is preserved. This is important when rerunning
core after a manual Starship setup.

### Theme switching

```bash
devtheme current
devtheme list

devtheme tokyo
devtheme tokyo-night
devtheme catppuccin
devtheme gruvbox
```

An explicit switch may replace a custom Starship config. Its original content
is saved exactly once as:

```text
~/.config/ai-ml-dev-bootstrap/backups/starship.toml.original
```

Press `Cmd+Shift+,` in Ghostty after switching.

## Rerunning after the previous minimal setup

Run the new personal setup normally:

```bash
./scripts/bootstrap-macos.sh --features ai
```

The migration is deterministic:

1. Homebrew Bundle checks each manifest first.
2. Already installed packages and casks are skipped.
3. Only missing core or AI items are installed.
4. Existing versions are not upgraded unless `--upgrade` is supplied.
5. Ghostty and zsh are adopted once with fixed `.original` backups.
6. All legacy or later-priority Ghostty config paths are removed after one-time
   backup, leaving one active source.
7. An already enabled `/bin/zsh -l` Ghostty override is retained; a fresh setup
   leaves it commented.
8. Existing Ghostty appearance, local overrides, and Starship config remain.
9. Repeated runs produce no additional backups and no duplicate shell
   initialization.

The bootstrap does not uninstall unrelated software left from an older setup.
It only ensures the selected manifests are satisfied.

## Controls

```bash
# Preview packages and config operations.
./scripts/bootstrap-macos.sh --features ai --dry-run

# Allow package upgrades explicitly.
./scripts/bootstrap-macos.sh --features ai --upgrade

# Install packages only.
./scripts/bootstrap-macos.sh --features ai --skip-config

# Apply only terminal configuration.
./scripts/configure-macos-shell.sh
```

## Validation

```bash
make verify-macos
```

GitHub Actions runs static and integration checks on Linux and macOS. The suite
covers manifest boundaries, shell syntax, one-time adoption, all Ghostty config
precedence paths, repeated execution, theme switching, and preservation of
explicit local overrides.
