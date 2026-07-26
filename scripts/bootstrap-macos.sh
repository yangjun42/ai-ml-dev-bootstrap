#!/usr/bin/env bash
set -euo pipefail

PROFILE="core"
FEATURES_CSV=""
PYTHON_VERSION="3.12"
PROJECT_DIR="$HOME/projects/ai-ml-starter"
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
  core        Default personal Mac: complete terminal/dev baseline plus
              ChatGPT/Codex, Claude Code, and Ollama.
  restricted  Same open-source terminal/dev baseline, without public AI apps
              or Ollama.

Optional features (comma-separated):
  ai          Create or reuse one uv-managed local AI/ML starter project.
  conda       Install Miniforge, including conda and mamba, for compatibility.
  mlsys       Add host benchmarking and Python profiling/runtime tools;
              automatically enables ai.
  build       Add CMake, Ninja, pkgconf, and FFmpeg.
  containers  Add Colima and Docker-compatible CLI tooling; does not start it.
  all         Enable ai, conda, mlsys, build, and containers.

Options:
  --profile NAME       core or restricted. Default: core.
  --features LIST      Example: ai,mlsys or conda,containers.
  --python VERSION     Python for the optional ai feature. Default: 3.12.
  --project-dir PATH   AI starter path. Default: ~/projects/ai-ml-starter.
  --upgrade            Update Homebrew metadata and allow package upgrades.
  --skip-config        Install packages only; do not manage Ghostty/zsh files.
  --force-config       Back up and replace an unmanaged Ghostty main config.
  --dry-run            Print all package, config, and feature actions.
  -h, --help           Show this help.

Compatibility aliases:
  minimal, developer, personal -> core
  workstation                  -> core + build,containers
  enterprise                   -> restricted

The host bootstrap does not install Python/ML dependencies unless the ai or
mlsys feature is selected.
EOF
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
      ai|conda|mlsys|build|containers) append_feature "$normalized" ;;
      all)
        append_feature ai
        append_feature conda
        append_feature mlsys
        append_feature build
        append_feature containers
        ;;
      *)
        echo "Unknown macOS feature: $normalized" >&2
        exit 2
        ;;
    esac
  done
  IFS="$old_ifs"
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
    --python)
      [[ $# -ge 2 ]] || { echo "--python requires a value" >&2; exit 2; }
      PYTHON_VERSION="$2"
      shift 2
      ;;
    --project-dir)
      [[ $# -ge 2 ]] || { echo "--project-dir requires a value" >&2; exit 2; }
      PROJECT_DIR="$2"
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
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

PROFILE="$(printf '%s' "$PROFILE" | tr '[:upper:]' '[:lower:]')"
case "$PROFILE" in
  core|restricted) ;;
  minimal|developer|personal) PROFILE="core" ;;
  workstation)
    PROFILE="core"
    COMPAT_FEATURES="build,containers"
    ;;
  enterprise) PROFILE="restricted" ;;
  *)
    echo "Unknown macOS profile: $PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

parse_feature_list "$COMPAT_FEATURES"
parse_feature_list "$FEATURES_CSV"

# ML systems tooling extends the local AI project rather than creating a second
# environment with overlapping dependencies.
if feature_enabled mlsys; then
  append_feature ai
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This entrypoint is for macOS. Use the Windows/WSL scripts elsewhere." >&2
  exit 1
fi

log() {
  printf '[bootstrap-macos] %s\n' "$*"
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

# Profile changes policy only. It does not create a second terminal tier.
if [[ "$PROFILE" == "core" ]]; then
  BREWFILES+=("$REPO_ROOT/brewfiles/macos/personal.Brewfile")
else
  export HOMEBREW_NO_ANALYTICS=1
fi

feature_enabled build && BREWFILES+=("$REPO_ROOT/brewfiles/macos/build.Brewfile")
feature_enabled containers && BREWFILES+=("$REPO_ROOT/brewfiles/macos/containers.Brewfile")
feature_enabled mlsys && BREWFILES+=("$REPO_ROOT/brewfiles/macos/mlsys.Brewfile")

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

if feature_enabled conda; then
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Miniforge at $HOME/miniforge3"
  else
    bash "$REPO_ROOT/scripts/install-miniforge.sh" "$HOME/miniforge3"
  fi
fi

if feature_enabled ai; then
  AI_ARGS=(--profile "$PROFILE" --python "$PYTHON_VERSION" --project-dir "$PROJECT_DIR")
  feature_enabled mlsys && AI_ARGS+=(--with-mlsys)
  [[ "$DRY_RUN" == "1" ]] && AI_ARGS+=(--dry-run)
  bash "$REPO_ROOT/scripts/setup-macos-ai.sh" "${AI_ARGS[@]}"
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

Not performed unless explicitly selected:
  - no Python/AI project without --features ai or mlsys
  - no Miniforge without --features conda
  - no local build or container stack without the matching feature
  - no VS Code extensions, account login, API key, SSH key, or model download
  - no Oh My Zsh and no replacement of unmarked personal dotfiles
EOF

if [[ "$PROFILE" == "restricted" ]]; then
  cat <<'EOF'

Restricted profile complete. ChatGPT, Claude Code, and Ollama were omitted.
Use organization-approved applications, mirrors, and runtimes as required.
EOF
else
  cat <<'EOF'

Core is ready: Ghostty TokyoNight Moon/Day, zsh, Starship Jetpack, zoxide,
fzf, autosuggestions, syntax highlighting, ChatGPT/Codex, Claude Code, and
Ollama. Restart Ghostty so all settings take effect.
EOF
fi
