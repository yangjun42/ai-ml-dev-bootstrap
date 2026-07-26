# Architecture notes

## Design model

The repository uses three concepts:

```text
core     shared host baseline
feature  optional host capability
project  owns language and ML dependencies
```

There is no macOS profile hierarchy. Enterprise use is represented by installing
core without the optional `ai` feature, rather than by maintaining a second
nearly identical machine definition.

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
- unmarked personal dotfile content.

## macOS modules

### Core

Core is always installed and contains the common terminal, editor, repository,
and shell experience. Keeping this complete baseline in one module avoids the
former minimal/developer split, where one state was only a slightly less usable
version of the other.

The terminal stack is deliberately framework-free:

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

Oh My Zsh, Powerlevel10k, and terminal file managers remain personal choices.

### `ai`

The AI feature contains only end-user AI applications:

```text
ChatGPT / Codex
Claude Code
Ollama
```

It does not install models, Python packages, or a second inference engine.
Ollama is the default convenient local runtime. `llama.cpp` is deliberately not
installed because its normal local-inference role overlaps with Ollama; it is a
manual advanced choice for direct GGUF, quantization, server-flag, or benchmark
workflows.

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

The macOS configurator follows these rules:

- managed Ghostty main config: timestamped backup before update;
- unmanaged or symlinked Ghostty config: preserve and emit review candidate;
- `appearance.ghostty`: install only when absent;
- `local.ghostty`: never create or modify;
- `.zshrc`: replace only one marked `macos-core` block;
- Starship Jetpack: generate only when no active config exists;
- explicit `devtheme` switch: back up custom Starship config first.

## Repeatability

- `brew bundle check` provides the fast path for satisfied manifests.
- Homebrew upgrades require explicit `--upgrade`.
- Git LFS initialization is idempotent.
- Optional features are independently selectable.
- No macOS feature writes into a project directory.
- CI runs configuration tests on both Linux and macOS runners.

## Windows model

Windows remains separate because its constraints differ:

- preferred: Windows host + WSL2 Ubuntu for Linux/CUDA-oriented development;
- fallback: native Windows when WSL is unavailable or blocked;
- CUDA Toolkit, native compilers, conda compatibility, containers, and MLsys
  tooling remain explicit where that platform workflow requires them.
