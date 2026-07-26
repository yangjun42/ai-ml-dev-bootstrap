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

# Fresh core setup.
FRESH_HOME="$TEST_ROOT/fresh-home"
mkdir -p "$FRESH_HOME"
configure "$FRESH_HOME"

test -f "$FRESH_HOME/.config/ghostty/config.ghostty"
test -f "$FRESH_HOME/.config/ghostty/appearance.ghostty"
test -x "$FRESH_HOME/.local/bin/devtheme"
test -L "$FRESH_HOME/.config/starship.toml"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "jetpack.toml"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-core >>>' "$FRESH_HOME/.zshrc")" -eq 1
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' "$FRESH_HOME/.config/ghostty/appearance.ghostty"
grep -Fq '# command = /bin/zsh -l' "$FRESH_HOME/.config/ghostty/config.ghostty"
grep -Fq 'shell-integration = detect' "$FRESH_HOME/.config/ghostty/config.ghostty"
if grep -Eq '^[[:space:]]*command[[:space:]]*=' "$FRESH_HOME/.config/ghostty/config.ghostty"; then
  echo "Ghostty must not force an explicit shell by default" >&2
  exit 1
fi

# Repeated configuration must not duplicate content or reset the selected theme.
configure "$FRESH_HOME"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-core >>>' "$FRESH_HOME/.zshrc")" -eq 1
HOME="$FRESH_HOME" "$FRESH_HOME/.local/bin/devtheme" catppuccin
grep -Fq 'theme = dark:Catppuccin Mocha,light:Catppuccin Latte' "$FRESH_HOME/.config/ghostty/appearance.ghostty"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
configure "$FRESH_HOME"
test "$(basename "$(readlink "$FRESH_HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"

# Adopt an older regular Ghostty config, preserve manual Starship config and
# unmarked zsh content, and migrate the former minimal/developer blocks.
MIGRATION_HOME="$TEST_ROOT/migration-home"
mkdir -p "$MIGRATION_HOME/.config/ghostty" "$MIGRATION_HOME/.config"
cat > "$MIGRATION_HOME/.config/ghostty/config.ghostty" <<'EOF'
theme = manual-old-theme
font-size = 16
EOF
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
grep -Fq 'Managed by ai-ml-dev-bootstrap' "$MIGRATION_HOME/.config/ghostty/config.ghostty"
grep -Fq 'theme = manual-old-theme' "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original"
grep -Fq 'custom = true' "$MIGRATION_HOME/.config/starship.toml"
grep -Fq 'export USER_SETTING=kept' "$MIGRATION_HOME/.zshrc"
grep -Fq 'eval "$(starship init zsh)"' "$MIGRATION_HOME/.zshrc"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-core >>>' "$MIGRATION_HOME/.zshrc")" -eq 1
test "$(grep -Fc 'macos-minimal' "$MIGRATION_HOME/.zshrc" || true)" -eq 0
test "$(grep -Fc 'macos-developer' "$MIGRATION_HOME/.zshrc" || true)" -eq 0
test -f "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups/zshrc.original"

backup_count_before="$(find "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups" -type f | wc -l | tr -d ' ')"
configure "$MIGRATION_HOME"
backup_count_after="$(find "$MIGRATION_HOME/.config/ai-ml-dev-bootstrap/backups" -type f | wc -l | tr -d ' ')"
test "$backup_count_before" = "$backup_count_after"

# Symlinked Ghostty configs remain externally owned unless force is explicit.
SYMLINK_HOME="$TEST_ROOT/symlink-home"
mkdir -p "$SYMLINK_HOME/.config/ghostty" "$SYMLINK_HOME/dotfiles"
printf 'theme = external\n' > "$SYMLINK_HOME/dotfiles/ghostty"
ln -s "$SYMLINK_HOME/dotfiles/ghostty" "$SYMLINK_HOME/.config/ghostty/config.ghostty"
configure "$SYMLINK_HOME"
test -L "$SYMLINK_HOME/.config/ghostty/config.ghostty"
grep -Fq 'theme = external' "$SYMLINK_HOME/.config/ghostty/config.ghostty"
test -f "$SYMLINK_HOME/.config/ghostty/config.ghostty.ai-ml-dev-bootstrap-new"

configure "$SYMLINK_HOME" --force-config
test ! -L "$SYMLINK_HOME/.config/ghostty/config.ghostty"
grep -Fq 'Managed by ai-ml-dev-bootstrap' "$SYMLINK_HOME/.config/ghostty/config.ghostty"
grep -Fq 'theme = external' "$SYMLINK_HOME/.config/ai-ml-dev-bootstrap/backups/config.ghostty.original"

# Core load order: compinit before navigation; syntax highlighting last.
compinit_line="$(grep -n 'compinit' "$FRESH_HOME/.zshrc" | head -n 1 | cut -d: -f1)"
zoxide_line="$(grep -n 'zoxide init zsh' "$FRESH_HOME/.zshrc" | head -n 1 | cut -d: -f1)"
starship_line="$(grep -n 'starship init zsh' "$FRESH_HOME/.zshrc" | head -n 1 | cut -d: -f1)"
syntax_line="$(grep -n 'zsh-syntax-highlighting.zsh' "$FRESH_HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
test "$compinit_line" -lt "$zoxide_line"
test "$starship_line" -lt "$syntax_line"

echo "macOS core configuration integration tests passed"
