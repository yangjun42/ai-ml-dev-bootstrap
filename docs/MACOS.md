# macOS setup

The macOS bootstrap has three concepts:

```text
profile  = application policy
feature  = optional host capability
project  = owns Python and ML dependencies
```

The public interface is intentionally small:

```text
profiles: core, enterprise
features: ml, containers
```

## Recommended commands

Personal Apple Silicon Mac:

```bash
./scripts/bootstrap-macos.sh
```

Enterprise-managed machine:

```bash
./scripts/bootstrap-macos.sh --profile enterprise
```

Optional host tooling:

```bash
./scripts/bootstrap-macos.sh --features ml
./scripts/bootstrap-macos.sh --features containers
./scripts/bootstrap-macos.sh --features ml,containers
```

## Profiles

### `core`

The daily personal baseline:

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

Git and OpenSSH are supplied by macOS / Apple Command Line Tools and are not
reinstalled through Homebrew.

Internally, the profile composes two manifests:

```text
core.Brewfile      shared terminal/editor/repository baseline
personal.Brewfile  ChatGPT, Claude Code, and Ollama
```

### `enterprise`

Uses `core.Brewfile` but omits `personal.Brewfile`. The terminal, editor, uv,
and open-source CLI experience remains the same; only these applications are
excluded:

```text
ChatGPT
Claude Code
Ollama
```

This is a conservative default, not a compliance guarantee. Organization-owned
allowlists, mirrors, credentials, network controls, and model/data license
review remain separate responsibilities.

## Features

### `ml`

Installs generic host-side tools useful for ML engineering:

```text
CMake
Ninja
pkgconf
FFmpeg
hyperfine
```

It deliberately does **not** install:

```text
Python
PyTorch / MLX / JAX / TensorFlow
Jupyter
Miniforge / conda / mamba
an ai-ml-starter project
```

The feature exists for native-extension builds, media/data preprocessing, and
repeatable command benchmarks. Framework and environment choices remain inside
each repository.

### `containers`

Installs:

```text
Colima
Docker CLI
Docker Compose
```

It does not start Colima, create a VM, change Docker context, pull an image, or
start a container.

### `all`

Equivalent to:

```bash
./scripts/bootstrap-macos.sh --features ml,containers
```

## Project environments

The host installs uv, but it does not create a Python environment.

For an existing project:

```bash
cd project
uv sync
```

For a new project:

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy pandas scikit-learn
```

Add PyTorch, MLX, Jupyter, or other packages only when that project's purpose
requires them. This keeps the Mac host small and makes local, remote, and CI
environments reproducible from project files rather than machine state.

## Terminal baseline

Both profiles receive the same ready-to-use configuration.

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

An explicit switch backs up a custom active Starship config before replacing it.
After switching, press `Cmd+Shift+,` in Ghostty.

## Repeatability and ownership

The bootstrap is safe to rerun:

- `brew bundle check` skips satisfied manifests;
- upgrades require `--upgrade`;
- managed Ghostty files are backed up before replacement;
- unmanaged or symlinked Ghostty files are preserved and receive a review candidate;
- `appearance.ghostty` is installed only when missing;
- `local.ghostty` is never managed;
- only repository-marked zsh blocks are replaced;
- old minimal/developer blocks migrate to the single core block;
- active Ghostty/Starship theme choices survive reruns.

Useful controls:

```bash
./scripts/bootstrap-macos.sh --dry-run
./scripts/bootstrap-macos.sh --upgrade
./scripts/bootstrap-macos.sh --skip-config
./scripts/bootstrap-macos.sh --force-config
./scripts/configure-macos-shell.sh --profile core
```

## Compatibility names

The implementation accepts these previous profile names during migration:

```text
minimal, developer, personal -> core
restricted                  -> enterprise
workstation                 -> core + ml,containers
```

The old Mac features `ai`, `conda`, `mlsys`, and `build` intentionally fail with
a migration message. They no longer represent host responsibilities.

## Validation

```bash
make verify-macos
```

The GitHub Actions workflow runs static and integration checks on both Linux and
macOS, including repeatability, old-block migration, theme switching, and user
configuration preservation.
