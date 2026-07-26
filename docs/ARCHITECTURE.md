# Architecture notes

## Design model

The repository uses three concepts:

```text
profile  = policy
feature  = optional host capability
project  = owns language and ML dependencies
```

This is intentionally smaller than a ladder of almost-identical machine tiers.
Modules stay composable, idempotent, and independently testable.

## Ownership boundaries

### Host bootstrap

The host bootstrap owns:

- operating-system package managers;
- general development applications and CLIs;
- terminal and shell configuration;
- explicitly selected model-facing, systems-facing, or container host tools.

On macOS, Homebrew Bundle manages packages while Apple Command Line Tools
provide Git, OpenSSH, compilers, and SDKs.

### Project

Each repository owns:

- Python version constraints;
- `.venv` and dependency lockfiles;
- PyTorch, MLX, JAX, TensorFlow, Jupyter, and other frameworks;
- framework-specific profiling/runtime packages;
- model and dataset choices.

uv is installed by the host and is the default project tool, but the host does
not create an environment or starter project.

### User and organization

The bootstrap does not own:

- logins, API keys, SSH keys, or secrets;
- VS Code extensions;
- enterprise allowlists, mirrors, firewall rules, or license review;
- unmarked personal dotfile content.

## macOS policy profiles

Only two policy profiles are exposed:

```text
core        complete personal developer host, including AI applications
enterprise  same open-source terminal/editor baseline without public AI apps
```

They share `core.Brewfile`. The `core` profile additionally applies
`personal.Brewfile`, which contains ChatGPT, Claude Code, and Ollama.

The policy difference is therefore small and explicit. Terminal quality does
not degrade on an enterprise-managed machine.

## macOS features

Three optional host capabilities remain:

```text
ml          model-facing local inference and media tools
mlsys       systems-facing build and benchmark tools
containers  Colima and Docker-compatible CLI tooling
```

Their boundaries are intentional:

- `ml` contains `llama.cpp` and FFmpeg. It is for direct local model runtime
  control and multimodal preprocessing beyond the default Ollama workflow.
- `mlsys` contains CMake, Ninja, pkgconf, and hyperfine. It is for native builds
  and repeatable systems/performance work.
- `containers` installs Docker-compatible tooling without starting a VM or
  service.

`ml` and `mlsys` are independent. Neither implies the other, and neither
installs Python or framework packages.

The previous Mac `ai` and `conda` features mixed host and project
responsibilities. They were removed rather than merged into another automatic
environment installer. The previous `build` name is superseded by `mlsys`.

## Why core includes the terminal productivity stack

For the target user, these are small mainstream daily-use tools rather than a
separate machine class:

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

Splitting them between minimal and developer profiles created two nearly
identical hosts and made onboarding less predictable. One tested core is easier
to understand and maintain.

Oh My Zsh, Powerlevel10k, and terminal file managers remain personal choices.

## Configuration ownership

The macOS configurator follows these rules:

- managed Ghostty main config: timestamped backup before update;
- unmanaged or symlinked Ghostty config: preserve and emit review candidate;
- `appearance.ghostty`: install only when absent;
- `local.ghostty`: never create or modify;
- `.zshrc`: replace only one marked `macos-core` block;
- previous repository-managed blocks: migrate automatically;
- Starship Jetpack: generate only when no active config exists;
- explicit `devtheme` switch: back up custom Starship config first.

## Repeatability

- `brew bundle check` provides the fast path for satisfied manifests.
- Homebrew upgrades require explicit `--upgrade`.
- Git LFS initialization is idempotent.
- Optional host features are independently selectable.
- No Mac feature writes into an arbitrary project directory.
- CI runs configuration tests on both Linux and macOS runners.

## Windows model

Windows remains separate because its constraints differ:

- preferred: Windows host + WSL2 Ubuntu for Linux/CUDA-oriented development;
- fallback: native Windows when WSL is unavailable or blocked;
- CUDA Toolkit, native compilers, conda compatibility, containers, and MLsys
  tooling remain explicit where that platform workflow requires them.
