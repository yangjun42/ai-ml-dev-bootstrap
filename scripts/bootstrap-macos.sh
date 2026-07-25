#!/usr/bin/env bash
set -euo pipefail

PROFILE="minimal"
DRY_RUN=0
UPGRADE=0
SKIP_CONFIG=0
FORCE_CONFIG=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-macos.sh [options]

Profiles:
  minimal      Default host, AI apps, Ghostty, and reliable zsh baseline.
  core         Alias for minimal.
  developer    minimal + Starship, zoxide, fuzzy search, and common CLI tools.
  workstation  developer + native build and Docker-compatible tooling.
  restricted   Host/shell setup without public AI apps or Ollama.

Compatibility aliases:
  personal     Alias for minimal.
  enterprise   Alias for restricted.

Options:
  --profile NAME  Select a profile. Default: minimal.
  --upgrade       Update Homebrew metadata and allow package upgrades.
  --skip-config   Install packages only; do not manage Ghostty/zsh files.
  --force-config  Back up and replace an unmanaged Ghostty main config.
  --dry-run       Print packages and configuration actions without changing them.
  -h, --help      Show this help.

The host bootstrap intentionally does not install Python, PyTorch, MLX,
Miniforge, VS Code extensions, model weights, or project environments.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { echo "--profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --upgrade)
      UPGRADE=1
      shift
      ;;
    --skip-config)
      SKIP_CONFIG=1
      shift
      ;;
    --force-config)
      FORCE_CONFIG=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --features|--python)
      echo "The old project-environment options moved out of the default Mac bootstrap." >&2
      echo "Use scripts/bootstrap-macos-legacy-ai.sh only when the former full setup is explicitly required." >&2
      exit 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$PROFILE" in
  core|personal) PROFILE="minimal" ;;
  enterprise) PROFILE="restricted" ;;
  minimal|developer|workstation|restricted) ;;
  *)
    echo "Unknown macOS profile: $PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This entrypoint is for macOS. Use the Windows/WSL scripts on other systems." >&2
  exit 1
fi

log() {
  printf '[bootstrap-macos] %s\n' "$*"
}

ensure_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would request Apple Command Line Tools: xcode-select --install"
    return
  fi

  log "Apple Command Line Tools are required for the system Git and developer SDKs."
  xcode-select --install >/dev/null 2>&1 || true
  echo "Complete the macOS installer dialog, then rerun this command." >&2
  exit 2
}

load_homebrew_into_path() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_homebrew() {
  load_homebrew_into_path
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Homebrew using the official installer"
    return
  fi

  log "Homebrew not found; running the official installer."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew_into_path

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew was installed but is not available in this shell." >&2
    echo "Follow the shellenv instructions printed by the Homebrew installer, then rerun." >&2
    exit 1
  fi
}

bundle_is_satisfied() {
  local file="$1"
  HOMEBREW_NO_AUTO_UPDATE=1 \
  HOMEBREW_BUNDLE_NO_UPGRADE=1 \
    brew bundle check --file="$file" >/dev/null 2>&1
}

bundle_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Missing Brewfile: $file" >&2; exit 1; }

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would apply $file"
    sed 's/^/  /' "$file"
    return
  fi

  if [[ "$UPGRADE" != "1" ]] && bundle_is_satisfied "$file"; then
    log "already satisfied: $(basename "$file")"
    return
  fi

  log "applying $(basename "$file")"
  if [[ "$UPGRADE" == "1" ]]; then
    brew bundle --file="$file"
  else
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_BUNDLE_NO_UPGRADE=1 \
      brew bundle --file="$file" --no-upgrade
  fi

  if ! bundle_is_satisfied "$file"; then
    echo "Brewfile is still not fully satisfied: $file" >&2
    exit 1
  fi
}

ensure_command_line_tools
ensure_homebrew

if [[ "$UPGRADE" == "1" && "$DRY_RUN" != "1" ]]; then
  brew update
fi

BREWFILES=("$REPO_ROOT/brewfiles/macos/minimal.Brewfile")
case "$PROFILE" in
  minimal)
    ;;
  developer)
    BREWFILES+=("$REPO_ROOT/brewfiles/macos/developer-extra.Brewfile")
    ;;
  workstation)
    BREWFILES+=(
      "$REPO_ROOT/brewfiles/macos/developer-extra.Brewfile"
      "$REPO_ROOT/brewfiles/macos/workstation-extra.Brewfile"
    )
    ;;
  restricted)
    BREWFILES=("$REPO_ROOT/brewfiles/macos/restricted.Brewfile")
    export HOMEBREW_NO_ANALYTICS=1
    ;;
esac

log "profile=$PROFILE repo=$REPO_ROOT"
for file in "${BREWFILES[@]}"; do
  bundle_file "$file"
done

if [[ "$SKIP_CONFIG" != "1" ]]; then
  CONFIG_ARGS=(--profile "$PROFILE")
  [[ "$DRY_RUN" == "1" ]] && CONFIG_ARGS+=(--dry-run)
  [[ "$FORCE_CONFIG" == "1" ]] && CONFIG_ARGS+=(--force-config)
  bash "$REPO_ROOT/scripts/configure-macos-shell.sh" "${CONFIG_ARGS[@]}"
else
  log "skipping Ghostty/zsh configuration by request"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "dry run complete"
  exit 0
fi

# Configure Git LFS filters globally, but do not change any repository.
if command -v git-lfs >/dev/null 2>&1; then
  git lfs install --skip-repo
fi

log "installed profile: $PROFILE"
printf '\nSystem-provided tools (not reinstalled):\n'
printf '  git: %s\n' "$(git --version 2>/dev/null || echo 'not found')"
printf '  ssh: %s\n' "$(ssh -V 2>&1 | head -n 1 || echo 'not found')"
printf '\nBootstrap-managed core tools:\n'
printf '  uv: %s\n' "$(uv --version 2>/dev/null || echo 'not found')"
printf '  tmux: %s\n' "$(tmux -V 2>/dev/null || echo 'not found')"
printf '  gh: %s\n' "$(gh --version 2>/dev/null | head -n 1 || echo 'not found')"
printf '  git-lfs: %s\n' "$(git-lfs --version 2>/dev/null || echo 'not found')"
printf '  btop: %s\n' "$(btop --version 2>/dev/null | head -n 1 || echo 'not found')"
if command -v starship >/dev/null 2>&1; then
  printf '  starship: %s\n' "$(starship --version 2>/dev/null | head -n 1)"
  printf '  zoxide: %s\n' "$(zoxide --version 2>/dev/null || echo 'not found')"
fi

cat <<'EOF'

Not performed by design:
  - no VS Code extensions
  - no account login, API key, or SSH key setup
  - no Ollama model downloads or background-service changes
  - no Python installation, virtual environment, or AI/ML project dependencies
  - no Oh My Zsh or replacement of unmarked personal dotfiles
EOF

if [[ "$PROFILE" == "restricted" ]]; then
  cat <<'EOF'

Restricted profile complete. Public AI apps and Ollama were intentionally not installed.
Use organization-approved applications, mirrors, and model runtimes as required.
EOF
elif [[ "$PROFILE" == "developer" || "$PROFILE" == "workstation" ]]; then
  cat <<'EOF'

The developer terminal experience is ready:
  - Ghostty TokyoNight Moon/Day
  - Starship Jetpack
  - zoxide, fzf, autosuggestions, and syntax highlighting
  - optional coordinated switching with: devtheme list

Restart Ghostty so its explicit zsh login command and all settings take effect.
EOF
else
  cat <<'EOF'

Open ChatGPT to use ChatGPT/Codex, open Ollama once before using the CLI,
and restart Ghostty to load the managed zsh baseline.
EOF
fi
