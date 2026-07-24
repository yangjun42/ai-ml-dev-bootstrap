#!/usr/bin/env bash
set -euo pipefail

PROFILE="minimal"
DRY_RUN=0
UPGRADE=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-macos.sh [options]

Profiles:
  minimal      Default. Core personal Mac setup for AI/software development.
  core         Alias for minimal.
  developer    minimal + common CLI developer utilities.
  workstation  developer + native build and Docker-compatible tooling.
  restricted   Host-only setup without public AI apps or Ollama.

Compatibility aliases:
  personal     Alias for minimal.
  enterprise   Alias for restricted.

Options:
  --profile NAME  Select a profile. Default: minimal.
  --upgrade       Allow Homebrew Bundle to upgrade installed packages.
  --dry-run       Print the selected Brewfiles without installing anything.
  -h, --help      Show this help.

This host bootstrap intentionally does not install Python, PyTorch, MLX,
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
      echo "Use: bash scripts/bootstrap-macos-legacy-ai.sh $*" >&2
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
  echo "Complete the macOS installer dialog, then re-run this command." >&2
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
    echo "Follow the shellenv instructions printed by the Homebrew installer, then re-run." >&2
    exit 1
  fi
}

bundle_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Missing Brewfile: $file" >&2
    exit 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would apply $file"
    sed 's/^/  /' "$file"
    return
  fi

  local args=(bundle "--file=$file")
  if [[ "$UPGRADE" != "1" ]]; then
    args+=(--no-upgrade)
  fi

  log "applying $(basename "$file")"
  HOMEBREW_NO_AUTO_UPDATE=1 brew "${args[@]}"
}

ensure_command_line_tools
ensure_homebrew

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

cat <<'EOF'

Not performed by design:
  - no VS Code extensions
  - no account login or credential setup
  - no Ollama model downloads or background-service changes
  - no Python installation, virtual environment, or AI/ML project dependencies
  - no shell-framework or dotfile changes

Open ChatGPT to use ChatGPT/Codex, open Ollama once before using the CLI,
and let each project declare its own environment with uv when needed.
EOF
