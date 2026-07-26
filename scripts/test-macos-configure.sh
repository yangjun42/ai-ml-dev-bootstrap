#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-ml-macos-config.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
unset XDG_CONFIG_HOME STARSHIP_CONFIG
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$HOME" "$FAKE_BIN"

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

CONFIGURE=(
  env AI_ML_BOOTSTRAP_TEST=1
  bash "$REPO_ROOT/scripts/configure-macos-shell.sh"
)

# Preserve pre-existing user content while installing the managed baseline.
printf 'export USER_SETTING=kept\n' > "$HOME/.zshrc"
"${CONFIGURE[@]}"
test -f "$HOME/.config/ghostty/config.ghostty"
test -f "$HOME/.config/ghostty/appearance.ghostty"
test -x "$HOME/.local/bin/devtheme"
test -L "$HOME/.config/starship.toml"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "jetpack.toml"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-core >>>' "$HOME/.zshrc")" -eq 1
grep -Fq 'export USER_SETTING=kept' "$HOME/.zshrc"
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' "$HOME/.config/ghostty/appearance.ghostty"

# Repeated configuration must not duplicate content or reset the selected theme.
"${CONFIGURE[@]}"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-core >>>' "$HOME/.zshrc")" -eq 1
"$HOME/.local/bin/devtheme" catppuccin
grep -Fq 'theme = dark:Catppuccin Mocha,light:Catppuccin Latte' "$HOME/.config/ghostty/appearance.ghostty"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
"${CONFIGURE[@]}"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"

# An explicit theme switch backs up a custom Starship configuration.
rm -f "$HOME/.config/starship.toml"
printf 'custom = true\n' > "$HOME/.config/starship.toml"
"$HOME/.local/bin/devtheme" tokyo
test -L "$HOME/.config/starship.toml"
find "$HOME/.config/ai-ml-dev-bootstrap/backups" -name 'starship.toml.*' -type f | grep -q .

# An unmanaged Ghostty main config is preserved and receives a review candidate.
SECOND_HOME="$TEST_ROOT/unmanaged-home"
mkdir -p "$SECOND_HOME/.config/ghostty"
printf 'theme = custom\n' > "$SECOND_HOME/.config/ghostty/config.ghostty"
HOME="$SECOND_HOME" "${CONFIGURE[@]}"
grep -Fq 'theme = custom' "$SECOND_HOME/.config/ghostty/config.ghostty"
test -f "$SECOND_HOME/.config/ghostty/config.ghostty.ai-ml-dev-bootstrap-new"

# Core load order: compinit before navigation; syntax highlighting last.
compinit_line="$(grep -n 'compinit' "$HOME/.zshrc" | head -n 1 | cut -d: -f1)"
zoxide_line="$(grep -n 'zoxide init zsh' "$HOME/.zshrc" | head -n 1 | cut -d: -f1)"
starship_line="$(grep -n 'starship init zsh' "$HOME/.zshrc" | head -n 1 | cut -d: -f1)"
syntax_line="$(grep -n 'zsh-syntax-highlighting.zsh' "$HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
test "$compinit_line" -lt "$zoxide_line"
test "$starship_line" -lt "$syntax_line"

echo "macOS core configuration integration tests passed"
