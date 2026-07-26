# Architecture notes

## Design goals

The repository favors a small number of concepts:

```text
profile  = policy
feature  = optional capability
project  = owns its language and ML dependencies
```

This avoids duplicated installation tiers and keeps modules composable,
idempotent, and independently testable.

## Tool ownership

1. **OS/package bootstrap**
   - macOS: Homebrew Bundle; Apple Command Line Tools provide Git/OpenSSH.
   - Windows host: WinGet, with WSL2 Ubuntu preferred for Linux-oriented AI work.
2. **Terminal and host configuration**
   - Ghostty and one marked zsh block are managed by the macOS configurator.
   - Unmarked dotfile content and machine-local overrides remain user-owned.
3. **Python projects**
   - uv owns Python versions, `.venv`, PyPI dependencies, and lockfiles.
   - The macOS host bootstrap installs uv but creates a project only when the
     `ai` or `mlsys` feature is selected.
4. **Conda/native compatibility**
   - Miniforge is installed only by the `conda` feature.
   - mamba is the preferred conda-compatible CLI.
5. **Containers and native build tools**
   - Explicit `build` and `containers` features; neither is a core prerequisite.
6. **Local model runtime**
   - The personal `core` profile installs Ollama App without downloading models.
   - Direct MLX/MLX-LM development remains project-scoped.

## macOS model

Only two policy profiles are exposed:

```text
core        complete personal developer host, including AI applications
restricted  same open-source host/terminal baseline, omitting public AI apps
```

Capabilities are orthogonal:

```text
ai          local uv AI/ML starter project
conda       Miniforge + mamba compatibility layer
mlsys       AI feature + profiling/benchmark/runtime tools
build       native build tools
containers  Colima + Docker-compatible CLI tools
```

`mlsys` implies `ai`, because profiling packages extend the same project rather
than creating a second overlapping Python environment.

The previous `minimal`, `developer`, and `workstation` names remain compatibility
aliases only. They are not separate architecture layers.

## Why core includes the polished terminal stack

For this repository's target user, Starship, zoxide, fzf, autosuggestions,
syntax highlighting, and basic repository CLIs are small, mainstream daily-use
tools. Splitting them into a second profile produced two nearly identical host
states and made onboarding less predictable. They now form one tested core.

The core terminal configuration is deliberately framework-free:

```text
Ghostty
macOS zsh
Starship
zoxide
fzf
zsh-autosuggestions
zsh-syntax-highlighting
```

Oh My Zsh, Powerlevel10k, and terminal file managers remain personal choices.

## Configuration ownership

The macOS configurator follows these rules:

- managed Ghostty main config: timestamped backup before update;
- unmanaged or symlinked Ghostty config: preserve and emit review candidate;
- `appearance.ghostty`: install only when absent;
- `local.ghostty`: never create or modify;
- `.zshrc`: replace only one marked `macos-core` block;
- previous managed blocks: migrate automatically;
- Starship config: generate Jetpack only when no active config exists;
- explicit `devtheme` switch: back up custom Starship config first.

## Repeatability

- `brew bundle check` provides the fast path for satisfied manifests.
- Homebrew upgrades require explicit `--upgrade`.
- Git LFS initialization is idempotent.
- AI project setup refuses to populate a non-empty unrelated directory.
- Optional features are independently selectable and may be composed.
- CI runs configuration tests on both Linux and macOS runners.

## Why not uv-only everywhere?

uv is the default for Python-first projects, but conda-forge remains useful for
non-Python native stacks such as GDAL, HDF5, NetCDF, R, Qt, compiler variants,
and legacy scientific binaries. This is why `conda` remains an optional feature
rather than a core dependency.

## Windows model

Windows remains separate because its platform constraints differ:

- preferred: Windows host + WSL2 Ubuntu for Linux/CUDA-oriented development;
- fallback: native Windows when WSL is unavailable or blocked;
- CUDA Toolkit, native compilers, containers, and MLsys tooling remain explicit
  features rather than universal defaults.

## Restricted profile

`restricted` changes the application policy, not the terminal quality. It omits
ChatGPT, Claude Code, and Ollama while retaining the open-source terminal/editor
baseline. It is not a legal or technical compliance guarantee; internal
mirrors, network controls, allowlists, and license review remain organizational
responsibilities.
