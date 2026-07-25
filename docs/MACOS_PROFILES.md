# macOS host profiles

The macOS bootstrap configures a development **host**, not a shared Python or
AI project environment. It is optimized for a personal Apple Silicon Mac that
spends much of its time controlling remote Linux/GPU servers while retaining a
high-quality local terminal and open-model runtime.

## Profile hierarchy

```text
minimal/core
  └─ developer
       └─ workstation

restricted is a conservative sibling of minimal.
```

| profile | composition | intended use |
|---|---|---|
| `minimal` / `core` | core host apps + Ghostty/zsh baseline | default small personal Mac setup |
| `developer` | `minimal` + polished prompt, navigation, fuzzy search, typing helpers, repository CLI tools | recommended daily software/AI development profile |
| `workstation` | `developer` + native build and Docker-compatible tools | local builds or deployment-like testing |
| `restricted` | host/editor/Ghostty/zsh baseline, but no ChatGPT, Claude Code, or Ollama | machines where public AI services or model runtimes need approval |

Compatibility aliases:

```text
personal   -> minimal
enterprise -> restricted
```

## `minimal` / `core`

Packages and applications:

```text
Homebrew + Brewfile
Ghostty + macOS OpenSSH + tmux
Apple Command Line Tools Git + gh + Git LFS
VS Code
ChatGPT desktop (ChatGPT/Codex entry point)
Claude Code CLI
Ollama App
uv
btop
```

Git and OpenSSH are supplied by macOS / Apple Command Line Tools and are
verified rather than reinstalled with Homebrew. Native macOS window tiling is
used instead of a third-party window manager.

Configuration installed safely by the profile:

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/appearance.ghostty   # only when absent
~/.zshrc                               # marked managed block only
~/.zsh_history                         # mode 0600
```

The default appearance is TokyoNight Moon/Day. Ghostty explicitly starts
`/bin/zsh -l`, which avoids the common failure mode where a directory-managed
account still launches `/bin/bash` and therefore never reads `.zshrc`.

The minimal zsh block handles only persistent/shared history and native zsh
completion. It does not install a prompt framework or aliases.

Install:

```bash
./scripts/bootstrap-macos.sh
./scripts/bootstrap-macos.sh --profile minimal
./scripts/bootstrap-macos.sh --profile core
```

## `developer`

Adds these Homebrew formulae:

```text
starship
zoxide
zsh-autosuggestions
zsh-syntax-highlighting
ripgrep
fd
fzf
jq
yq
bat
shellcheck
just
```

It configures an intentionally small interactive stack:

```text
Starship Jetpack        prompt
zoxide                  ranked directory navigation
fzf                     fuzzy history/file selection
zsh-autosuggestions     history-based inline suggestions
zsh-syntax-highlighting pre-execution command highlighting
```

No Oh My Zsh or Powerlevel10k framework is installed. The tools remain
independent, understandable, and easy to reproduce selectively on servers.

The active Starship config is referenced through:

```text
~/.config/starship/current.toml
```

On a fresh machine it points to the generated Jetpack preset. An existing
`~/.config/starship.toml` or existing `current.toml` is preserved.

Install:

```bash
./scripts/bootstrap-macos.sh --profile developer
```

Optional coordinated theme command:

```bash
devtheme list
devtheme current
devtheme tokyo
devtheme tokyo-night
devtheme catppuccin
devtheme gruvbox
```

See [`MACOS_TERMINAL.md`](MACOS_TERMINAL.md) for exact file ownership, load
order, theme pairings, and troubleshooting.

## `workstation`

Adds:

```text
CMake
Ninja
pkgconf
FFmpeg
Colima
Docker CLI
Docker Compose
```

It installs tooling only. It does not start Colima, create containers, or
change the active Docker context.

```bash
./scripts/bootstrap-macos.sh --profile workstation
```

## `restricted`

Uses a separate conservative Brewfile:

```text
tmux
gh
Git LFS
uv
btop
Ghostty
VS Code
```

It receives the same Ghostty and minimal zsh reliability baseline, but omits:

```text
ChatGPT
Claude Code
Ollama
```

```bash
./scripts/bootstrap-macos.sh --profile restricted
```

This is not a compliance guarantee. Internal mirrors, application allowlists,
network controls, secrets policies, and model/data licenses remain an
organization responsibility.

## Repeatability and config ownership

By default Homebrew Bundle uses `--no-upgrade`. The script first runs
`brew bundle check`; a fully satisfied Brewfile is skipped. Use `--upgrade`
when a machine-wide upgrade is intended.

The configurator follows these rules:

- managed Ghostty main config: update with timestamped backup;
- unmanaged/symlinked Ghostty main config: preserve and emit a review candidate;
- `appearance.ghostty`: install only when absent;
- `local.ghostty`: never create or modify;
- `.zshrc`: replace only the two marked repository-owned blocks;
- existing Starship selection: preserve;
- repeated runs: do not duplicate zsh blocks or reset theme selection.

Commands:

```bash
./scripts/bootstrap-macos.sh --profile developer --dry-run
./scripts/bootstrap-macos.sh --profile developer --skip-config
./scripts/bootstrap-macos.sh --profile developer --force-config
./scripts/configure-macos-shell.sh --profile developer
```

## Deliberate omissions

The host bootstrap does **not** install or configure:

- VS Code extensions;
- Python or a `.venv`;
- PyTorch, MLX, JAX, TensorFlow, Jupyter, or Hugging Face libraries;
- Miniforge, mamba, or Pixi;
- Ollama model weights;
- Oh My Zsh or Powerlevel10k;
- Yazi or another terminal file manager;
- application logins, API keys, SSH keys, or credentials;
- running Colima containers or background services.

Each repository should declare its own Python and AI/ML dependencies:

```bash
cd project
uv sync
```

Install a Python version only when a project requires one:

```bash
uv python install 3.12
```

## Local models

The default installs **Ollama App**, not both the app and Homebrew formula. No
model is downloaded automatically. Open Ollama once, then choose a model based
on the current task and available memory.

Installing Ollama does not add the `mlx` Python package to projects. Add MLX or
MLX-LM with uv only when writing MLX code directly.

## Legacy full AI bootstrap

The former macOS behaviour that created a starter project, installed Python,
PyTorch/MLX, and optionally Miniforge remains available only for compatibility:

```bash
bash scripts/bootstrap-macos-legacy-ai.sh --profile personal --features core,ai,conda
```

It is not recommended for a new Mac. Prefer the host profile plus per-project
`pyproject.toml` and `uv.lock` files.

## Upstream references

- Homebrew Bundle: <https://docs.brew.sh/Brew-Bundle-and-Brewfile>
- Apple Command Line Tools: <https://developer.apple.com/documentation/xcode/installing-the-command-line-tools>
- Ghostty: <https://ghostty.org/>
- Starship: <https://starship.rs/>
- zoxide: <https://github.com/ajeetdsouza/zoxide>
- VS Code Remote SSH: <https://code.visualstudio.com/docs/remote/ssh>
- Claude Code: <https://docs.anthropic.com/en/docs/claude-code/overview>
- Ollama: <https://ollama.com/>
