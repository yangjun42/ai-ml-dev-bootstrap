# Architecture notes

## Design model

The repository uses three concepts:

```text
core     shared host baseline
feature  optional host capability
project  owns language and ML dependencies
```

There is no macOS profile hierarchy or compatibility layer. The public macOS
interface is intentionally limited to:

```text
features: ai, mlsys, containers
```

## Ownership boundaries

### Host bootstrap

The host bootstrap owns:

- operating-system package managers;
- general development applications and CLIs;
- terminal and shell configuration;
- explicitly selected AI applications, ML systems tools, and container CLIs.

On macOS, Homebrew Bundle manages packages while Apple Command Line Tools
provide Git, OpenSSH, compilers, and SDKs.

### Project

Each repository owns:

- Python version constraints;
- `.venv` and dependency lockfiles;
- PyTorch, MLX, JAX, TensorFlow, Jupyter, and other frameworks;
- profiling/runtime packages tied to that project;
- model and dataset choices.

uv is installed by core and is the default project tool, but the host never
creates an environment or starter project.

### User and organization

The bootstrap does not own:

- logins, API keys, SSH keys, or secrets;
- VS Code extensions;
- enterprise allowlists, mirrors, firewall rules, or license review;
- project dependencies.

## macOS modules

### Core

Core is always installed and contains the common terminal, editor, repository,
and shell experience:

```text
Ghostty
macOS zsh
Starship
zoxide
fzf
zsh-autosuggestions
zsh-syntax-highlighting
ripgrep / fd / jq / yq / bat / ShellCheck / just
```

Oh My Zsh, Powerlevel10k, and terminal file managers remain separate personal
choices.

### `ai`

The AI feature contains only end-user AI applications:

```text
ChatGPT / Codex
Claude Code
Ollama
```

It does not install models, Python packages, or a second inference engine.
Ollama is the convenient local runtime. `llama.cpp` is deliberately excluded
because its ordinary inference role overlaps with Ollama; it remains a manual
advanced choice for direct GGUF, quantization, server flags, or runtime work.

### `mlsys`

The ML systems feature contains host-side build and benchmark tools:

```text
CMake
Ninja
pkgconf
hyperfine
```

It remains separate from `ai`: one is for applications and local model access,
the other for systems engineering. Project-specific profilers and runtimes stay
inside project dependency files.

### `containers`

The containers feature installs Colima and Docker-compatible CLIs but does not
start a VM, service, or container.

## Configuration ownership

The macOS configurator uses one source of truth per concern.

### Managed files

```text
~/.zshrc
~/.config/ghostty/config.ghostty
~/.local/bin/devtheme
```

When an existing file is adopted, its original content is saved once under:

```text
~/.config/ai-ml-dev-bootstrap/backups/<name>.original
```

Fixed backup names prevent timestamped backup accumulation. Repeated runs simply
compare and update the managed file.

### User-owned overrides

```text
~/.config/zsh/local.zsh
~/.config/ghostty/local.ghostty
~/.config/ghostty/appearance.ghostty
~/.config/starship.toml
```

- `local.zsh` and `local.ghostty` are never created or overwritten.
- `appearance.ghostty` is installed only when absent.
- an existing Starship config is preserved;
- an explicit `devtheme` switch backs it up once as
  `starship.toml.original` before selecting a managed preset.

Ghostty's later macOS Application Support config path is removed after one-time
backup so it cannot silently override the XDG config.

The managed Ghostty config uses the macOS login shell by default. A commented
`command = /bin/zsh -l` recovery line is provided for directory-managed accounts
that still start Bash.

## Repeatability

- `brew bundle check` provides the fast path for satisfied manifests.
- Homebrew upgrades require explicit `--upgrade`.
- Git LFS initialization is idempotent.
- Optional features are independently selectable.
- No macOS feature writes into a project directory.
- Existing packages are not reinstalled and unrelated packages are not removed.
- Configuration adoption creates at most one original backup per managed file.
- CI runs configuration tests on both Linux and macOS runners.

## Windows model

Windows remains separate because its constraints differ:

- preferred: Windows host + WSL2 Ubuntu for Linux/CUDA-oriented development;
- fallback: native Windows when WSL is unavailable or blocked;
- CUDA Toolkit, native compilers, conda compatibility, containers, and MLsys
  tooling remain explicit where that platform workflow requires them.
