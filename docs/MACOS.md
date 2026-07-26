# macOS setup

The macOS design has one complete daily baseline and a small set of orthogonal
features:

```text
profile:  core | restricted
features: ai, conda, mlsys, build, containers
```

This mirrors common developer-bootstrap practice: the profile expresses policy,
while features express capabilities. It avoids several almost-identical setup
levels and keeps each module independently understandable.

## Recommended setup

For a personal Apple Silicon Mac used for local lightweight work and remote
Linux/GPU development:

```bash
./scripts/bootstrap-macos.sh
```

This selects the `core` profile.

For a machine where public AI applications or a local model runtime require
separate approval:

```bash
./scripts/bootstrap-macos.sh --profile restricted
```

## Profiles

### `core`

The default personal profile installs:

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

Git and OpenSSH come from macOS / Apple Command Line Tools and are not
reinstalled through Homebrew.

### `restricted`

Uses the same open-source terminal, editor, repository, and shell baseline, but
omits:

```text
ChatGPT
Claude Code
Ollama
```

It is a conservative package policy, not a compliance guarantee. Internal
mirrors, application allowlists, credentials, network controls, and model/data
licenses remain organization responsibilities.

## Features

Features are comma-separated and may be combined:

| feature | behavior |
|---|---|
| `ai` | creates or reuses one uv-managed local AI/ML starter project |
| `conda` | installs Miniforge, including conda and mamba |
| `mlsys` | adds `hyperfine` and Python profiling/runtime tools; implies `ai` |
| `build` | installs CMake, Ninja, pkgconf, and FFmpeg |
| `containers` | installs Colima and Docker-compatible CLI tooling without starting it |
| `all` | enables every feature above |

Examples:

```bash
./scripts/bootstrap-macos.sh --features ai
./scripts/bootstrap-macos.sh --features conda
./scripts/bootstrap-macos.sh --features ai,mlsys
./scripts/bootstrap-macos.sh --features build,containers
./scripts/bootstrap-macos.sh --features all
```

The optional AI project location and Python version are configurable:

```bash
./scripts/bootstrap-macos.sh \
  --features ai,mlsys \
  --python 3.12 \
  --project-dir "$HOME/projects/ai-ml-starter"
```

## Terminal baseline

Both profiles install the same ready-to-use terminal configuration.

### Ghostty

Managed files:

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/appearance.ghostty
```

Defaults:

```text
Ghostty dark theme  : TokyoNight Moon
Ghostty light theme : TokyoNight Day
Starship preset     : Jetpack
Shell               : /bin/zsh -l
```

The explicit zsh command is useful on directory-managed Macs whose account
record still advertises `/bin/bash`; Ghostty reads `.zshrc` without requiring an
account-wide `chsh` change.

The Ghostty baseline also enables:

- zsh and SSH/terminfo integration;
- stable-channel update checks;
- working-directory inheritance for tabs, windows, and splits;
- bounded scrollback for build and agent output;
- conservative clipboard/paste behavior;
- left Option as terminal Alt;
- close confirmation for active processes.

Put machine-local overrides in:

```text
~/.config/ghostty/local.ghostty
```

For example:

```ini
font-size = 15
```

The bootstrap never creates or modifies that file.

### zsh

The bootstrap owns only one marked block in `~/.zshrc`:

```text
# >>> ai-ml-dev-bootstrap:macos-core >>>
...
# <<< ai-ml-dev-bootstrap:macos-core <<<
```

The block provides:

- Homebrew PATH recovery on a fresh Apple Silicon Mac;
- persistent/shared history in `~/.zsh_history`;
- native completion;
- zoxide and fzf integration;
- Starship;
- autosuggestions and syntax highlighting.

Unmarked personal content is preserved. Previous `macos-minimal` and
`macos-developer` blocks are migrated into this single block.

No Oh My Zsh or Powerlevel10k framework is installed.

## Theme switching

The core profile installs `~/.local/bin/devtheme`:

```bash
devtheme list
devtheme current

devtheme tokyo        # TokyoNight Moon/Day + Jetpack
devtheme tokyo-night  # TokyoNight Moon/Day + Tokyo Night preset
devtheme catppuccin   # Mocha/Latte + Catppuccin Powerline
devtheme gruvbox      # Gruvbox Dark/Light Hard + Gruvbox Rainbow
```

An explicit switch backs up a custom `starship.toml` before replacing it with a
managed preset symlink. After switching, press `Cmd+Shift+,` in Ghostty.

## AI feature

The `ai` feature is deliberately project-scoped. It does not install global
Python packages. It prepares:

```text
~/projects/ai-ml-starter
```

with a uv virtual environment containing the scientific Python stack, PyTorch
with macOS MPS support, Hugging Face tooling, Jupyter, and Apple Silicon MLX
packages. Existing projects with a `pyproject.toml` are reused; a non-empty
unrelated directory is rejected.

The `mlsys` feature adds profiling, benchmarking, ONNX, and runtime packages to
that same environment instead of creating a second overlapping environment.

## Conda feature

```bash
./scripts/bootstrap-macos.sh --features conda
```

installs Miniforge under:

```text
~/miniforge3
```

Miniforge is used only as the conda-forge compatibility/native-dependency layer.
Normal Python-first projects remain uv-managed.

## Repeatability and safety

The bootstrap is designed to be rerun:

- `brew bundle check` skips satisfied manifests;
- `--no-upgrade` is the default;
- managed Ghostty files are backed up before replacement;
- unmanaged or symlinked Ghostty configs are preserved and receive a review
  candidate instead;
- `appearance.ghostty` is created only when absent;
- only the marked `.zshrc` block is replaced;
- Starship/theme choices survive reruns;
- Git LFS initialization is idempotent.

Useful controls:

```bash
./scripts/bootstrap-macos.sh --dry-run
./scripts/bootstrap-macos.sh --upgrade
./scripts/bootstrap-macos.sh --skip-config
./scripts/bootstrap-macos.sh --force-config
./scripts/configure-macos-shell.sh --profile core
```

## Compatibility aliases

The old names remain accepted but are not part of the new conceptual model:

```text
minimal, developer, personal -> core
workstation                  -> core + build,containers
enterprise                   -> restricted
```

The old macOS entrypoint is now only a wrapper around the modular bootstrap.

## Deliberate omissions

The default `core` run does not install:

- Python or an AI project environment;
- Miniforge;
- CMake/containers;
- model weights;
- VS Code extensions;
- Yazi or another terminal file manager;
- account credentials, API keys, or SSH keys.

Those are either explicit features or user/project responsibilities.

## Validation

```bash
make verify-macos
```

The CI suite runs syntax, manifest, migration, idempotence, theme-switching, and
config-preservation tests on both Linux and macOS runners.
