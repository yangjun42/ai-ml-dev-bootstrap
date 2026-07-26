#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/configure-macos-shell.sh [options]

Options:
  --dry-run   Print intended changes without writing files.
  -h, --help  Show this help.

The repository owns ~/.zshrc and the primary Ghostty config. Existing files are
backed up once as *.original, then replaced. Put machine-specific additions in:
  ~/.config/zsh/local.zsh
  ~/.config/ghostty/local.ghostty
Existing Starship configuration and Ghostty appearance choices are preserved.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
  name="${name#.}"
  local destination="$BACKUP_ROOT/${name}.original"

  [[ -e "$source" || -L "$source" ]] || return 0

  if [[ -e "$destination" || -L "$destination" ]]; then
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

  [[ -f "$source" ]] || { echo "Missing template: $source" >&2; exit 1; }

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would manage: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -d "$target" && ! -L "$target" ]]; then
    echo "Expected a file but found a directory: $target" >&2
    exit 1
  fi

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    install -m "$mode" "$source" "$target"
    log "installed: $target"
    return
  fi

  if cmp -s "$source" "$target" 2>/dev/null; then
    log "already current: $target"
    return
  fi

  backup_once "$target" "$(basename "$target")"
  rm -f "$target"
  install -m "$mode" "$source" "$target"
  log "updated: $target"
}

install_if_missing() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"

  [[ -f "$source" ]] || { echo "Missing template: $source" >&2; exit 1; }

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install if absent: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    log "preserving existing choice: $target"
  else
    install -m "$mode" "$source" "$target"
    log "installed initial file: $target"
  fi
}

has_explicit_zsh_command() {
  local file="$1"
  [[ -f "$file" || -L "$file" ]] || return 1
  grep -Eq '^[[:space:]]*command[[:space:]]*=[[:space:]]*/bin/zsh[[:space:]]+-l[[:space:]]*$' "$file" 2>/dev/null
}

remove_duplicate_ghostty_config() {
  local duplicate="$1"

  [[ -e "$duplicate" || -L "$duplicate" ]] || return 0

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would back up once and remove duplicate Ghostty config: $duplicate"
    return
  fi

  if [[ -d "$duplicate" && ! -L "$duplicate" ]]; then
    echo "Expected a file but found a directory: $duplicate" >&2
    exit 1
  fi

  backup_once "$duplicate" "ghostty-macos-config"
  rm -f "$duplicate"
  log "removed duplicate Ghostty config path: $duplicate"
}

configure_ghostty() {
  local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
  local ghostty_dir="$config_root/ghostty"
  local target="$ghostty_dir/config.ghostty"
  local template="$REPO_ROOT/config/macos/ghostty/config.ghostty"
  local appearance="$ghostty_dir/appearance.ghostty"
  local duplicate="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  local rendered
  local preserve_explicit_zsh=0

  if has_explicit_zsh_command "$target" || has_explicit_zsh_command "$duplicate"; then
    preserve_explicit_zsh=1
  fi

  rendered="$(mktemp "${TMPDIR:-/tmp}/ai-ml-ghostty.XXXXXX")"
  if [[ "$preserve_explicit_zsh" == "1" ]]; then
    sed 's|^# command = /bin/zsh -l$|command = /bin/zsh -l|' "$template" > "$rendered"
  else
    cat "$template" > "$rendered"
  fi

  install_managed_file "$rendered" "$target"
  rm -f "$rendered"
  install_if_missing "$REPO_ROOT/config/macos/ghostty/appearance.ghostty" "$appearance"
  remove_duplicate_ghostty_config "$duplicate"

  if [[ "$preserve_explicit_zsh" == "1" ]]; then
    log "preserved existing opt-in Ghostty zsh command"
  fi
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

configure_ghostty
configure_starship
install_managed_file "$REPO_ROOT/config/macos/zsh/core.zsh" "$HOME/.zshrc"

if [[ "$DRY_RUN" != "1" ]]; then
  touch "$HOME/.zsh_history"
  chmod 600 "$HOME/.zsh_history"
  log "configuration complete"
  log "restart Ghostty, or press Cmd+Shift+, to reload reloadable settings"
fi
