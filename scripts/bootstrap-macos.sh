#!/usr/bin/env bash
set -euo pipefail

FEATURES_CSV=""
DRY_RUN=0
UPGRADE=0
SKIP_CONFIG=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURES=()

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-macos.sh [options]

The core development host is always installed. Add only the host capabilities
that this Mac needs.

Optional features (comma-separated):
  ai          ChatGPT/Codex, Claude Code, and Ollama.
  mlsys       CMake, Ninja, pkgconf, and hyperfine for ML systems work.
  containers  Colima and Docker-compatible CLI tooling; does not start Colima.
  all         Enable ai, mlsys, and containers.

Options:
  --features LIST  Example: ai or ai,mlsys.
  --upgrade        Update Homebrew metadata and allow package upgrades.
  --skip-config    Install packages only; do not manage Ghostty/zsh files.
  --dry-run        Print package and configuration actions without changing them.
  -h, --help       Show this help.

Python versions, virtual environments, ML frameworks, notebooks, profiling
packages, and project dependencies are intentionally managed inside each
repository with uv.
EOF
}

log() {
  printf '[bootstrap-macos] %s\n' "$*"
}

append_feature() {
  local candidate="$1"
  local existing
  for existing in "${FEATURES[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  FEATURES+=("$candidate")
}

feature_enabled() {
  local needle="$1"
  local existing
  for existing in "${FEATURES[@]}"; do
    [[ "$existing" == "$needle" ]] && return 0
  done
  return 1
}

parse_feature_list() {
  local csv="$1"
  local old_ifs="$IFS"
  local item normalized

  IFS=','
  for item in $csv; do
    normalized="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$normalized" ]] || continue

    case "$normalized" in
      ai|mlsys|containers)
        append_feature "$normalized"
        ;;
      all)
        append_feature ai
        append_feature mlsys
        append_feature containers
        ;;
      *)
        echo "Unknown macOS feature: $normalized" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
  IFS="$old_ifs"
}

feature_summary() {
  if [[ "${#FEATURES[@]}" -eq 0 ]]; then
    printf 'none'
  else
    local old_ifs="$IFS"
    IFS=','
    printf '%s' "${FEATURES[*]}"
    IFS="$old_ifs"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --features)
      [[ $# -ge 2 ]] || { echo "--features requires a value" >&2; exit 2; }
      FEATURES_CSV="$2"
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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

parse_feature_list "$FEATURES_CSV"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This entrypoint is for macOS. Use the Windows/WSL scripts elsewhere." >&2
  exit 1
fi

ensure_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would request Apple Command Line Tools: xcode-select --install"
    return
  fi

  log "Apple Command Line Tools are required for system Git and SDKs."
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

  command -v brew >/dev/null 2>&1 || {
    echo "Homebrew was installed but is not available in this shell." >&2
    echo "Apply the shellenv instructions printed by Homebrew, then rerun." >&2
    exit 1
  }
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

  bundle_is_satisfied "$file" || {
    echo "Brewfile is still not fully satisfied: $file" >&2
    exit 1
  }
}

ensure_command_line_tools
ensure_homebrew

if [[ "$UPGRADE" == "1" && "$DRY_RUN" != "1" ]]; then
  brew update
fi

BREWFILES=("$REPO_ROOT/brewfiles/macos/core.Brewfile")
feature_enabled ai && BREWFILES+=("$REPO_ROOT/brewfiles/macos/ai.Brewfile")
feature_enabled mlsys && BREWFILES+=("$REPO_ROOT/brewfiles/macos/mlsys.Brewfile")
feature_enabled containers && BREWFILES+=("$REPO_ROOT/brewfiles/macos/containers.Brewfile")

log "features=$(feature_summary) repo=$REPO_ROOT"
for file in "${BREWFILES[@]}"; do
  bundle_file "$file"
done

if [[ "$SKIP_CONFIG" != "1" ]]; then
  CONFIG_ARGS=()
  [[ "$DRY_RUN" == "1" ]] && CONFIG_ARGS+=(--dry-run)
  bash "$REPO_ROOT/scripts/configure-macos-shell.sh" "${CONFIG_ARGS[@]}"
else
  log "skipping Ghostty/zsh configuration by request"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "dry run complete"
  exit 0
fi

if command -v git-lfs >/dev/null 2>&1; then
  git lfs install --skip-repo
fi

log "installed core features=$(feature_summary)"
printf '\nSystem-provided tools (not reinstalled):\n'
printf '  git: %s\n' "$(git --version 2>/dev/null || echo 'not found')"
printf '  ssh: %s\n' "$(ssh -V 2>&1 | head -n 1 || echo 'not found')"
printf '\nCore tools:\n'
for command_name in uv tmux gh git-lfs btop starship zoxide fzf; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '  %-10s %s\n' "$command_name:" "$($command_name --version 2>/dev/null | head -n 1 || echo installed)"
  else
    printf '  %-10s %s\n' "$command_name:" "not found"
  fi
done

cat <<'EOF'

Project ownership by design:
  - no Python installation or virtual environment
  - no PyTorch, MLX, Jupyter, profiling package, or other framework dependency
  - no Miniforge/conda environment
  - no VS Code extensions, account login, API key, SSH key, or model download
  - no Oh My Zsh

Use uv inside each repository, for example: uv sync
EOF

if feature_enabled ai; then
  cat <<'EOF'

AI applications are installed. Open Ollama once before using its CLI, sign in to
ChatGPT/Codex and Claude Code as needed, and restart Ghostty for shell settings.
EOF
else
  cat <<'EOF'

Core is ready. Add the AI applications later with:
  ./scripts/bootstrap-macos.sh --features ai
EOF
fi
