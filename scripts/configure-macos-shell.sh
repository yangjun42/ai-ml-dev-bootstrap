#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
FORCE_CONFIG=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/configure-macos-shell.sh [options]

Options:
  --force-config  Replace a symlinked Ghostty main config after one-time backup.
  --dry-run       Print intended changes without writing files.
  -h, --help      Show this help.

Installs one reliable Ghostty, zsh, Starship, navigation, and interactive-shell
configuration. Existing regular Ghostty configs are adopted after one one-time
backup; symlinked configs remain externally owned unless --force-config is used.
Only repository-marked zsh blocks are replaced.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ "$(uname -s)" != "Darwin" && "${AI_ML_BOOTSTRAP_TEST:-0}" != "1" ]]; then
  echo "This configurator is intended for macOS." >&2
  exit 1
fi

log() {
  printf '[configure-macos-shell] %s\n' "$*"
}

BACKUP_ROOT="$HOME/.config/ai-ml-dev-bootstrap/backups"

backup_once() {
  local source="$1"
  local name="$2"
  local destination="$BACKUP_ROOT/${name}.original"

  [[ -e "$source" || -L "$source" ]] || return 0

  if [[ -e "$destination" || -L "$destination" ]]; then
    log "one-time backup already exists: $destination"
    return 0
  fi

  mkdir -p "$BACKUP_ROOT"
  if [[ -L "$source" && ! -e "$source" ]]; then
    printf 'broken symlink -> %s\n' "$(readlink "$source")" > "$destination"
  else
    cp -pL "$source" "$destination"
  fi
  log "one-time backup: $destination"
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
    rm -f "$candidate"
    log "installed: $target"
    return
  fi

  if cmp -s "$source" "$target" 2>/dev/null; then
    rm -f "$candidate"
    log "already current: $target"
    return
  fi

  if [[ -L "$target" && "$FORCE_CONFIG" != "1" ]]; then
    if ! cmp -s "$source" "$candidate" 2>/dev/null; then
      install -m "$mode" "$source" "$candidate"
    fi
    log "preserved externally managed symlink: $target"
    log "review candidate: $candidate"
    return
  fi

  backup_once "$target" "$(basename "$target")"
  [[ -L "$target" ]] && rm -f "$target"
  install -m "$mode" "$source" "$target"
  rm -f "$candidate"
  log "adopted managed file: $target"
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

marker_count() {
  grep -Fc "$2" "$1" 2>/dev/null || true
}

validate_managed_markers() {
  local file="$1"
  local name starts ends

  for name in macos-core macos-minimal macos-developer; do
    starts="$(marker_count "$file" "# >>> ai-ml-dev-bootstrap:${name} >>>")"
    ends="$(marker_count "$file" "# <<< ai-ml-dev-bootstrap:${name} <<<")"
    if [[ "$starts" != "$ends" ]]; then
      echo "Malformed ai-ml-dev-bootstrap block markers in $file: $name" >&2
      exit 1
    fi
  done
}

configure_zshrc() {
  local zshrc="$HOME/.zshrc"
  local template="$REPO_ROOT/config/macos/zsh/core.zsh"
  local had_content=0

  [[ -f "$template" ]] || { echo "Missing zsh template: $template" >&2; exit 1; }

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would merge one core zsh block into: $zshrc"
    return
  fi

  [[ -s "$zshrc" || -L "$zshrc" ]] && had_content=1
  touch "$zshrc"
  validate_managed_markers "$zshrc"

  local stripped tmp
  stripped="$(mktemp "${TMPDIR:-/tmp}/ai-ml-zshrc-stripped.XXXXXX")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/ai-ml-zshrc.XXXXXX")"

  # Remove the current block and the two repository-managed blocks from the
  # earlier minimal/developer design. Unmarked user content is never deleted.
  awk '
    $0 == "# >>> ai-ml-dev-bootstrap:macos-core >>>" { skip = 1; next }
    $0 == "# <<< ai-ml-dev-bootstrap:macos-core <<<" { skip = 0; next }
    $0 == "# >>> ai-ml-dev-bootstrap:macos-minimal >>>" { skip = 1; next }
    $0 == "# <<< ai-ml-dev-bootstrap:macos-minimal <<<" { skip = 0; next }
    $0 == "# >>> ai-ml-dev-bootstrap:macos-developer >>>" { skip = 1; next }
    $0 == "# <<< ai-ml-dev-bootstrap:macos-developer <<<" { skip = 0; next }
    !skip { print }
  ' "$zshrc" > "$stripped"

  # Trim only trailing blank lines from user-owned content.
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
  cat "$template" >> "$tmp"
  printf '\n' >> "$tmp"

  if cmp -s "$tmp" "$zshrc"; then
    rm -f "$tmp"
    log "already current: $zshrc"
  else
    [[ "$had_content" == "1" ]] && backup_once "$zshrc" "zshrc"
    cat "$tmp" > "$zshrc"
    rm -f "$tmp"
    log "updated managed block: $zshrc"
  fi

  touch "$HOME/.zsh_history"
  chmod 600 "$HOME/.zsh_history"
}

configure_starship() {
  local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
  local preset_root="$config_root/starship/presets"
  local jetpack="$preset_root/jetpack.toml"
  local active="${STARSHIP_CONFIG:-$config_root/starship.toml}"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would ensure Starship Jetpack and install ~/.local/bin/devtheme"
    return
  fi

  command -v starship >/dev/null 2>&1 || {
    echo "core requires starship, but it is not on PATH" >&2
    exit 1
  }

  mkdir -p "$preset_root" "$HOME/.local/bin" "$(dirname "$active")"
  if [[ ! -s "$jetpack" ]]; then
    starship preset jetpack -o "$jetpack"
    log "generated Starship preset: $jetpack"
  else
    log "preserving Starship preset: $jetpack"
  fi

  if [[ ! -e "$active" && ! -L "$active" ]]; then
    ln -s "$jetpack" "$active"
    log "selected default Starship preset: Jetpack"
  elif [[ -L "$active" && ! -e "$active" ]]; then
    ln -sfn "$jetpack" "$active"
    log "repaired dangling Starship config link"
  else
    log "preserving active Starship config: $active"
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

configure_starship
configure_zshrc

if [[ "$DRY_RUN" != "1" ]]; then
  log "configuration complete"
  log "restart Ghostty, or press Cmd+Shift+, to reload reloadable settings"
fi
