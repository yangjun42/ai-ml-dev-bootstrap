#!/usr/bin/env bash
set -euo pipefail

PROFILE="core"
FEATURES_CSV=""
DRY_RUN=0
UPGRADE=0
SKIP_CONFIG=0
FORCE_CONFIG=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURES=()
COMPAT_FEATURES=""

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-macos.sh [options]

Profiles:
  core        Default personal Mac: complete terminal/development baseline plus
              ChatGPT/Codex, Claude Code, and Ollama.
  enterprise  Same open-source terminal/development baseline, without public AI
              applications or the local Ollama runtime.

Optional features (comma-separated):
  ml          Model-facing local tools: llama.cpp and FFmpeg. Does not create a
              Python environment or install a framework.
  mlsys       Systems-facing build and benchmark tools: CMake, Ninja, pkgconf,
              and hyperfine. Does not create a Python environment.
  containers  Colima and Docker-compatible CLI tooling. Does not start Colima.
  all         Enable ml, mlsys, and containers.

Options:
  --profile NAME   core or enterprise. Default: core.
  --features LIST  Example: ml,mlsys or mlsys,containers.
  --upgrade        Update Homebrew metadata and allow package upgrades.
  --skip-config    Install packages only; do not manage Ghostty/zsh files.
  --force-config   Back up and replace an unmanaged Ghostty main config.
  --dry-run        Print package and configuration actions without changing them.
  -h, --help       Show this help.

Compatibility profile aliases:
  minimal, developer, personal -> core
  restricted                  -> enterprise
  workstation                 -> core + mlsys,containers

Python versions, virtual environments, ML frameworks, notebooks, and project
packages are intentionally project-owned and should be managed with uv.
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
      core|minimal|developer) ;;
      ml|mlsys|containers) append_feature "$normalized" ;;
      all)
        append_feature ml
        append_feature mlsys
        append_feature containers
        ;;
      ai|conda|build)
        echo "The macOS feature '$normalized' was removed." >&2
        echo "Use ml for model-facing tools, mlsys for systems/build tools, and uv inside each project." >&2
        exit 2
        ;;
      *)
        echo "Unknown macOS feature: $normalized" >&2
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
    --profile)
      [[ $# -ge 2 ]] || { echo "--profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
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
    --python|--project-dir)
      echo "$1 is no longer a host-bootstrap option." >&2
      echo "Create and configure Python/ML environments inside each project with uv." >&2
      exit 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

PROFILE="$(printf '%s' "$PROFILE" | tr '[:upper:]' '[:lower:]')"
case "$PROFILE" in
  core|enterprise) ;;
  minimal|developer|personal) PROFILE="core" ;;
  restricted) PROFILE="enterprise" ;;
  workstation)
    PROFILE="core"
    COMPAT_FEATURES="mlsys,containers"
    ;;
  *)
    echo "Unknown macOS profile: $PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

parse_feature_list "$COMPAT_FEATURES"
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

# Profiles express policy. The terminal/editor baseline stays identical.
if [[ "$PROFILE" == "core" ]]; then
  BREWFILES+=("$REPO_ROOT/brewfiles/macos/personal.Brewfile")
else
  export HOMEBREW_NO_ANALYTICS=1
fi

feature_enabled ml && BREWFILES+=("$REPO_ROOT/brewfiles/macos/ml.Brewfile")
feature_enabled mlsys && BREWFILES+=("$REPO_ROOT/brewfiles/macos/mlsys.Brewfile")
feature_enabled containers && BREWFILES+=("$REPO_ROOT/brewfiles/macos/containers.Brewfile")

log "profile=$PROFILE features=$(feature_summary) repo=$REPO_ROOT"
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

# Configure Git LFS filters globally, but do not modify any repository.
if command -v git-lfs >/dev/null 2>&1; then
  git lfs install --skip-repo
fi

log "installed profile=$PROFILE features=$(feature_summary)"
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
  - no PyTorch, MLX, Jupyter, or other framework packages
  - no Miniforge/conda environment
  - no VS Code extensions, account login, API key, SSH key, or model download
  - no Oh My Zsh and no replacement of unmarked personal dotfiles

Use uv inside each repository, for example: uv sync
EOF

if [[ "$PROFILE" == "enterprise" ]]; then
  cat <<'EOF'

Enterprise profile complete. ChatGPT, Claude Code, and Ollama were intentionally
omitted; use organization-approved applications and services.
EOF
else
  cat <<'EOF'

Core profile complete. Open Ollama once before using its CLI, sign in to the AI
applications you use, and restart Ghostty so the managed zsh command takes effect.
EOF
fi
