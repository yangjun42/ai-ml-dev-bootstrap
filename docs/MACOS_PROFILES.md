# macOS host profiles

The macOS bootstrap configures a development **host**, not a shared Python or
AI project environment. The default is intentionally small and suitable for a
personal Apple Silicon Mac that spends much of its time controlling remote
Linux/GPU servers.

## Default: `minimal` (`core` alias)

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

Git and OpenSSH are provided by macOS / Apple Command Line Tools and are
verified rather than reinstalled with Homebrew. Window tiling uses the native
macOS window-management features, so no third-party window manager is part of
the default profile.

The corresponding package manifest is
[`brewfiles/macos/minimal.Brewfile`](../brewfiles/macos/minimal.Brewfile).

```bash
./scripts/bootstrap-macos.sh
# equivalent aliases
./scripts/bootstrap-macos.sh --profile minimal
./scripts/bootstrap-macos.sh --profile core
```

## Profile hierarchy

| profile | composition | intended use |
|---|---|---|
| `minimal` | exact core list above | default personal Mac and remote-first AI/ML development |
| `developer` | `minimal` + ripgrep, fd, fzf, jq, yq, bat, ShellCheck, just | frequent local CLI and repository work |
| `workstation` | `developer` + CMake, Ninja, pkgconf, FFmpeg, Colima, Docker CLI/Compose | native builds or Docker-compatible local testing |
| `restricted` | host tools from `minimal`, but no ChatGPT, Claude Code, or Ollama | machines where public AI services/model runtimes need separate approval |

Compatibility aliases are retained:

```text
personal   -> minimal
enterprise -> restricted
```

Examples:

```bash
./scripts/bootstrap-macos.sh --profile developer
./scripts/bootstrap-macos.sh --profile workstation
./scripts/bootstrap-macos.sh --profile restricted
./scripts/bootstrap-macos.sh --profile minimal --dry-run
```

By default Homebrew Bundle uses `--no-upgrade`, so re-running the bootstrap
installs missing items without turning the operation into a machine-wide
upgrade. Use `--upgrade` explicitly when that is desired.

## Deliberate omissions

The host bootstrap does **not** install or configure:

- VS Code extensions;
- Python or a `.venv`;
- PyTorch, MLX, JAX, TensorFlow, Jupyter, or Hugging Face libraries;
- Miniforge, mamba, or Pixi;
- Ollama model weights;
- shell frameworks, prompts, aliases, or dotfiles;
- third-party window managers;
- application logins, API keys, SSH keys, or credentials;
- running Colima containers or background services.

Each repository should declare its own Python and AI/ML dependencies. For a
uv project, the normal entry point is simply:

```bash
cd project
uv sync
```

Install a Python version only when a project requires one:

```bash
uv python install 3.12
```

## Local models

The default installs **Ollama App**, not both the app and the Homebrew formula.
The app supplies the desktop experience and CLI while keeping one model store.
No model is downloaded automatically. Open Ollama once, then choose a model
according to the current task and available memory.

Installing Ollama does not add the `mlx` Python package to projects. Add MLX or
MLX-LM with uv only when writing MLX code directly.

## ChatGPT / Codex

The profile installs the current `chatgpt` Homebrew cask. Homebrew marks the old
`codex-app` cask as deprecated in favor of `chatgpt`, which is the maintained
OpenAI desktop entry point for ChatGPT/Codex.

## Legacy full AI bootstrap

The former macOS behavior that created a starter project, installed Python,
PyTorch/MLX, and optionally Miniforge is retained only for compatibility:

```bash
bash scripts/bootstrap-macos-legacy-ai.sh --profile personal --features core,ai,conda
```

It is not recommended for a new Mac. Prefer the host profile plus per-project
`pyproject.toml` and `uv.lock` files.

## Upstream references

- Homebrew Bundle: <https://docs.brew.sh/Brew-Bundle-and-Brewfile>
- Apple Command Line Tools: <https://developer.apple.com/documentation/xcode/installing-the-command-line-tools>
- uv: <https://docs.astral.sh/uv/>
- Ghostty: <https://ghostty.org/>
- VS Code Remote SSH: <https://code.visualstudio.com/docs/remote/ssh>
- Claude Code: <https://docs.anthropic.com/en/docs/claude-code/overview>
- Ollama: <https://ollama.com/>
