#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-ml-macos-config.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

unset XDG_CONFIG_HOME STARSHIP_CONFIG
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "preset" ]]; then
  preset="${2:-}"
  shift 2
  output=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$output" ]] || { echo "fake starship requires -o" >&2; exit 2; }
  mkdir -p "$(dirname "$output")"
  printf '# generated preset: %s\n' "$preset" > "$output"
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then
  echo "starship test-double"
  exit 0
fi
echo "unsupported fake starship command" >&2
exit 2
EOF
chmod +x "$FAKE_BIN/starship"
export PATH="$FAKE_BIN:$PATH"

configure() {
  local home="$1"
  shift
  HOME="$home" AI_ML_BOOTSTRAP_TEST=1 \
    bash "$REPO_ROOT/scripts/configure-macos-shell.sh" "$@"
}

count_backups() {
  local home="$1"
  if [[ -d "$home/.config/ai-ml-dev-bootstrap/backups" ]]; then
    find "$home/.config/ai-ml-dev-bootstrap/backups" -type f | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

# Fresh setup: one source of truth and no unnecessary backups.
FRESH_HOME="$TEST_ROOT/fresh-home"
mkdir -p "$FRESH_HOME"
configure "$FRESH_HOME"

test -f "$FRESH_HOME/.config/ghostty/config.ghostty"
test -f "$FRESH_HOME/.config/ghostty/appearance.ghostty"
test -x "$FRESH_HOME/.local/bin/devtheme"
test -L "$FRESH_HOME/.config/starship.toml"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "jetpack.toml"
cmp -s "$REPO_ROOT/config/macos/zsh/core.zsh" "$FRESH_HOME/.zshrc"
grep -Fq '# command = /bin/zsh -l' "$FRESH_HOME/.config/ghostty/config.ghostty"
grep -Fq 'shell-integration = detect' "$FRESH_HOME/.config/ghostty/config.ghostty"
if grep -Eq '^[[:space:]]*command[[:space:]]*=' "$FRESH_HOME/.config/ghostty/config.ghostty"; then
  echo "Ghostty must not force an explicit shell by default" >&2
  exit 1
fi
test "$(count_backups "$FRESH_HOME")" = "0"

# Repeated configuration is a no-op and keeps an explicitly selected theme.
configure "$FRESH_HOME"
test "$(count_backups "$FRESH_HOME")" = "0"
HOME="$FRESH_HOME" "$FRESH_HOME/.local/bin/devtheme" catppuccin
grep -Fq 'theme = dark:Catppuccin Mocha,light:Catppuccin Latte' "$FRESH_HOME/.config/ghostty/appearance.ghostty"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
configure "$FRESH_HOME"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
test "$(count_backups "$FRESH_HOME")" = "0"

# Migrate an existing machine: adopt Ghostty and zsh once, preserve appearance,
# local overrides, and an existing Starship configuration.
MIGRATION_HOME="$TEST_ROOT/migration-home"
mkdir -p \
  "$MIGRATION_HOME/.config/ghostty" \
  "$MIGRATION_HOME/.config/zsh" \
  "$MIGRATION_HOME/.config" \
  "$MIGRATION_HOME/Library/Application Support/com.mitchellh.ghostty"

cat > "$MIGRATION_HOME/.config/ghostty/config.ghostty" <<'EOF'
theme = manual-old-theme
font-size = 16
EOF
cat > "$MIGRATION_HOME/.config/ghostty/appearance.ghostty" <<'EOF'
theme = dark:TokyoNight Moon,light:TokyoNight Day
EOF
printf 'font-size = 15\n' > "$MIGRATION_HOME/.config/ghostty/local.ghostty"
printf 'alias local-only="echo local"\n' > "$MIGRATION_HOME/.config/zsh/local.zsh"
printf 'theme = duplicate-late-config\n' > "$MIGRATION_HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
printf 'custom = true\n' > "$MIGRATION_HOME/.config/starship.toml"
cat > "$MIGRATION_HOME/.zshrc" <<'EOF'
export USER_SETTING=kept
eval "$(starship init zsh)"
# >>> ai-ml-dev-bootstrap:macos-minimal >>>
old minimal content
# <<< ai-ml-dev-bootstrap:macos-minimal <<<
# >>> ai-ml-dev-bootstrap:macos-developer >>>
old developer content
# <<< ai-ml-dev-bootstrap:macos-developer <<<
EOF

configure "$MIGRATION_HOME"
cmp -s "$REPO_ROOT/config/macos/zsh/core.zsh" "$MIGRATION_HOME/.zshrc"
grep -Fq 'theme = manual-old-theme' "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original"
grep -Fq 'export USER_SETTING=kept' "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/zshrc.original"
grep -Fq 'duplicate-late-config' "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/ghostty-macos-config.original"
test ! -e "$MIGRATION_HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
grep -Fq 'custom = true' "$MIGRATION_HOME/.config/starship.toml"
grep -Fq 'TokyoNight Moon' "$MIGRATION_HOME/.config/ghostty/appearance.ghostty"
grep -Fq 'font-size = 15' "$MIGRATION_HOME/.config/ghostty/local.ghostty"
grep -Fq 'alias local-only' "$MIGRATION_HOME/.config/zsh/local.zsh"

backup_count_before="$(count_backups "$MIGRATION_HOME")"
configure "$MIGRATION_HOME"
backup_count_after="$(count_backups "$MIGRATION_HOME")"
test "$backup_count_before" = "$backup_count_after"

# An explicit theme switch backs up a custom Starship file exactly once.
HOME="$MIGRATION_HOME" "$MIGRATION_HOME/.local/bin/devtheme" tokyo
grep -Fq 'custom = true' "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/starship.toml.original"
starship_backup_count_before="$(count_backups "$MIGRATION_HOME")"
HOME="$MIGRATION_HOME" "$MIGRATION_HOME/.local/bin/devtheme" gruvbox
starship_backup_count_after="$(count_backups "$MIGRATION_HOME")"
test "$starship_backup_count_before" = "$starship_backup_count_after"

# A symlinked Ghostty config is also adopted once, preventing two competing
# configuration sources while retaining the original target content.
SYMLINK_HOME="$TEST_ROOT/symlink-home"
mkdir -p "$SYMLINK_HOME/.config/ghostty" "$SYMLINK_HOME/dotfiles"
printf 'theme = external\n' > "$SYMLINK_HOME/dotfiles/ghostty"
ln -s "$SYMLINK_HOME/dotfiles/ghostty" "$SYMLINK_HOME/.config/ghostty/config.ghostty"
configure "$SYMLINK_HOME"
test ! -L "$SYMLINK_HOME/.config/ghostty/config.ghostty"
grep -Fq 'Managed by ai-ml-dev-bootstrap' "$SYMLINK_HOME/.config/ghostty/config.ghostty"
grep -Fq 'theme = external' "$SYMLINK_HOME/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original"
symlink_backup_count="$(count_backups "$SYMLINK_HOME")"
configure "$SYMLINK_HOME"
test "$symlink_backup_count" = "$(count_backups "$SYMLINK_HOME")"

# Core load order: compinit before navigation, local overrides before the final
# syntax-highlighting integration.
compinit_line="$(grep -n 'compinit' "$FRESH_HOME/.zshrc" | head -n 1 | cut -d: -f1)"
zoxide_line="$(grep -n 'zoxide init zsh' "$FRESH_HOME/.zshrc" | head -n 1 | cut -d: -f1)"
local_line="$(grep -n 'local.zsh' "$FRESH_HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
syntax_line="$(grep -n 'zsh-syntax-highlighting.zsh' "$FRESH_HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
test "$compinit_line" -lt "$zoxide_line"
test "$local_line" -lt "$syntax_line"

echo "macOS core configuration integration tests passed"
