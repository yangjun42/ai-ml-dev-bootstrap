#!/usr/bin/env bash
set -euo pipefail

PROFILE="minimal"
DRY_RUN=0
FORCE_CONFIG=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/configure-macos-shell.sh [options]

Options:
  --profile minimal|developer|workstation|restricted
  --force-config  Back up and replace an unmanaged Ghostty main config.
  --dry-run       Print intended changes without writing files.
  -h, --help      Show this help.

The script merges marked blocks into ~/.zshrc, installs a managed Ghostty
baseline, preserves appearance/local overrides, and configures Starship only
for developer/workstation profiles.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { echo "--profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
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

case "$PROFILE" in
  core|personal) PROFILE="minimal" ;;
  enterprise) PROFILE="restricted" ;;
  minimal|developer|workstation|restricted) ;;
  *) echo "Unknown macOS profile: $PROFILE" >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != "Darwin" && "${AI_ML_BOOTSTRAP_TEST:-0}" != "1" ]]; then
  echo "This configurator is intended for macOS." >&2
  exit 1
fi

log() {
  printf '[configure-macos-shell] %s\n' "$*"
}

BACKUP_ROOT="$HOME/.config/ai-ml-dev-bootstrap/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  local source="$1"
  local name="$2"
  [[ -e "$source" || -L "$source" ]] || return 0
  mkdir -p "$BACKUP_ROOT"
  cp -p "$source" "$BACKUP_ROOT/${name}.${TIMESTAMP}"
  log "backup: $BACKUP_ROOT/${name}.${TIMESTAMP}"
}

install_managed_file() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"
  local candidate="${target}.ai-ml-dev-bootstrap-new"

  [[ -f "$source" ]] || { echo "Missing template: $source" >&2; exit 1; }

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install managed file: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    install -m "$mode" "$source" "$target"
    log "installed: $target"
    return
  fi

  if cmp -s "$source" "$target"; then
    log "already current: $target"
    return
  fi

  if [[ -L "$target" && "$FORCE_CONFIG" != "1" ]]; then
    install -m "$mode" "$source" "$candidate"
    log "preserved symlinked config: $target"
    log "review candidate: $candidate"
    return
  fi

  if grep -Fq 'Managed by ai-ml-dev-bootstrap' "$target" 2>/dev/null || [[ "$FORCE_CONFIG" == "1" ]]; then
    backup_file "$target" "$(basename "$target")"
    install -m "$mode" "$source" "$target"
    log "updated: $target"
    return
  fi

  install -m "$mode" "$source" "$candidate"
  log "preserved unmanaged config: $target"
  log "review candidate or rerun with --force-config: $candidate"
}

install_if_missing() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install if absent: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    log "preserving existing user choice: $target"
  else
    install -m "$mode" "$source" "$target"
    log "installed initial file: $target"
  fi
}

managed_marker_count() {
  local file="$1"
  local marker="$2"
  grep -Fc "$marker" "$file" 2>/dev/null || true
}

configure_zshrc() {
  local zshrc="$HOME/.zshrc"
  local minimal_template="$REPO_ROOT/config/macos/zsh/minimal.zsh"
  local developer_template="$REPO_ROOT/config/macos/zsh/developer.zsh"
  local include_developer=0
  local zshrc_had_content=0

  [[ -f "$minimal_template" && -f "$developer_template" ]] || {
    echo "Missing zsh templates under config/macos/zsh" >&2
    exit 1
  }

  if [[ "$PROFILE" == "developer" || "$PROFILE" == "workstation" ]]; then
    include_developer=1
  elif [[ -f "$zshrc" ]] && grep -Fq '# >>> ai-ml-dev-bootstrap:macos-developer >>>' "$zshrc"; then
    # Profiles are additive: do not silently remove an existing developer block.
    include_developer=1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would merge minimal zsh block into: $zshrc"
    [[ "$include_developer" == "1" ]] && log "would merge developer zsh block into: $zshrc"
    return
  fi

  [[ -s "$zshrc" || -L "$zshrc" ]] && zshrc_had_content=1
  touch "$zshrc"

  local minimal_starts minimal_ends developer_starts developer_ends
  minimal_starts="$(managed_marker_count "$zshrc" '# >>> ai-ml-dev-bootstrap:macos-minimal >>>')"
  minimal_ends="$(managed_marker_count "$zshrc" '# <<< ai-ml-dev-bootstrap:macos-minimal <<<')"
  developer_starts="$(managed_marker_count "$zshrc" '# >>> ai-ml-dev-bootstrap:macos-developer >>>')"
  developer_ends="$(managed_marker_count "$zshrc" '# <<< ai-ml-dev-bootstrap:macos-developer <<<')"

  if [[ "$minimal_starts" != "$minimal_ends" || "$developer_starts" != "$developer_ends" ]]; then
    echo "Malformed ai-ml-dev-bootstrap block markers in $zshrc; refusing to edit." >&2
    exit 1
  fi

  local stripped tmp
  stripped="$(mktemp "${TMPDIR:-/tmp}/ai-ml-zshrc-stripped.XXXXXX")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/ai-ml-zshrc.XXXXXX")"

  awk '
    $0 == "# >>> ai-ml-dev-bootstrap:macos-minimal >>>" { skip = 1; next }
    $0 == "# <<< ai-ml-dev-bootstrap:macos-minimal <<<" { skip = 0; next }
    $0 == "# >>> ai-ml-dev-bootstrap:macos-developer >>>" { skip = 1; next }
    $0 == "# <<< ai-ml-dev-bootstrap:macos-developer <<<" { skip = 0; next }
    !skip { print }
  ' "$zshrc" > "$stripped"

  # Remove only trailing blank lines from unowned user content so repeated runs
  # do not accumulate whitespace before the managed blocks.
  awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] == "") last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' "$stripped" > "$tmp"
  rm -f "$stripped"

  [[ -s "$tmp" ]] && printf '\n\n' >> "$tmp"
  cat "$minimal_template" >> "$tmp"
  if [[ "$include_developer" == "1" ]]; then
    printf '\n' >> "$tmp"
    cat "$developer_template" >> "$tmp"
  fi
  printf '\n' >> "$tmp"

  if cmp -s "$tmp" "$zshrc"; then
    rm -f "$tmp"
    log "already current: $zshrc"
  else
    [[ "$zshrc_had_content" == "1" ]] && backup_file "$zshrc" "zshrc"
    cat "$tmp" > "$zshrc"
    rm -f "$tmp"
    log "updated managed blocks: $zshrc"
  fi

  touch "$HOME/.zsh_history"
  chmod 600 "$HOME/.zsh_history"
}

configure_starship() {
  local starship_root="${XDG_CONFIG_HOME:-$HOME/.config}/starship"
  local preset_root="$starship_root/presets"
  local jetpack="$preset_root/jetpack.toml"
  local current="$starship_root/current.toml"
  local legacy_default="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would ensure Starship Jetpack preset and current.toml"
    log "would install ~/.local/bin/devtheme"
    return
  fi

  if ! command -v starship >/dev/null 2>&1; then
    echo "developer profile requires starship, but it is not on PATH" >&2
    exit 1
  fi

  mkdir -p "$preset_root" "$HOME/.local/bin"
  if [[ ! -s "$jetpack" ]]; then
    starship preset jetpack -o "$jetpack"
    log "generated Starship preset: $jetpack"
  else
    log "preserving Starship preset: $jetpack"
  fi

  if [[ ! -e "$current" && ! -L "$current" ]]; then
    if [[ -s "$legacy_default" ]]; then
      ln -s "$legacy_default" "$current"
      log "preserved existing Starship config through: $current"
    else
      ln -s "$jetpack" "$current"
      log "selected default Starship preset: Jetpack"
    fi
  elif [[ -L "$current" && ! -e "$current" ]]; then
    ln -sfn "$jetpack" "$current"
    log "repaired dangling Starship preset link"
  else
    log "preserving active Starship config: $current"
  fi

  install_managed_file "$REPO_ROOT/config/macos/bin/devtheme" "$HOME/.local/bin/devtheme" 0755
}

GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
install_managed_file "$REPO_ROOT/config/macos/ghostty/config.ghostty" "$GHOSTTY_DIR/config.ghostty"
install_if_missing "$REPO_ROOT/config/macos/ghostty/appearance.ghostty" "$GHOSTTY_DIR/appearance.ghostty"

MACOS_GHOSTTY_CONFIG="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
if [[ -f "$MACOS_GHOSTTY_CONFIG" ]]; then
  log "warning: macOS-specific Ghostty config loads after the managed XDG config:"
  log "         $MACOS_GHOSTTY_CONFIG"
fi

if [[ "$PROFILE" == "developer" || "$PROFILE" == "workstation" ]]; then
  configure_starship
fi
configure_zshrc

if [[ "$DRY_RUN" != "1" ]]; then
  log "configuration complete for profile=$PROFILE"
  log "restart Ghostty, or press Cmd+Shift+, to reload reloadable settings"
fi
