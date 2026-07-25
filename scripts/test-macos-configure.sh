#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-ml-macos-config.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
# The test owns a temporary HOME. Do not let a runner-level XDG_CONFIG_HOME
# redirect Ghostty files outside that isolated tree.
unset XDG_CONFIG_HOME
unset STARSHIP_CONFIG
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
      -o|--output)
        output="$2"
        shift 2
        ;;
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

# Minimal: install the Ghostty baseline and exactly one zsh history/completion block.
"${CONFIGURE[@]}" --profile minimal
test -f "$HOME/.config/ghostty/config.ghostty"
test -f "$HOME/.config/ghostty/appearance.ghostty"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-minimal >>>' "$HOME/.zshrc")" -eq 1
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-developer >>>' "$HOME/.zshrc" || true)" -eq 0
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' "$HOME/.config/ghostty/appearance.ghostty"

# A second run must not duplicate managed blocks.
"${CONFIGURE[@]}" --profile minimal
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-minimal >>>' "$HOME/.zshrc")" -eq 1

# Developer: add prompt/navigation helpers and choose Jetpack at Starship's
# official default config path on a fresh setup.
"${CONFIGURE[@]}" --profile developer
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-minimal >>>' "$HOME/.zshrc")" -eq 1
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-developer >>>' "$HOME/.zshrc")" -eq 1
test -x "$HOME/.local/bin/devtheme"
test -L "$HOME/.config/starship.toml"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "jetpack.toml"

# Theme switching is coordinated, and rerunning bootstrap preserves that choice.
"$HOME/.local/bin/devtheme" catppuccin
grep -Fq 'theme = dark:Catppuccin Mocha,light:Catppuccin Latte' "$HOME/.config/ghostty/appearance.ghostty"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
"${CONFIGURE[@]}" --profile developer
grep -Fq 'theme = dark:Catppuccin Mocha,light:Catppuccin Latte' "$HOME/.config/ghostty/appearance.ghostty"
test "$(basename "$(readlink "$HOME/.config/starship.toml")")" = "catppuccin-powerline.toml"
test "$(grep -Fc '# >>> ai-ml-dev-bootstrap:macos-developer >>>' "$HOME/.zshrc")" -eq 1

# An existing manual Starship config is preserved by bootstrap. Explicitly
# running devtheme backs it up before switching the official active path.
CUSTOM_HOME="$TEST_ROOT/custom-starship-home"
mkdir -p "$CUSTOM_HOME/.config"
printf '# user-owned Starship config\n' > "$CUSTOM_HOME/.config/starship.toml"
HOME="$CUSTOM_HOME" "${CONFIGURE[@]}" --profile developer
grep -Fq '# user-owned Starship config' "$CUSTOM_HOME/.config/starship.toml"
HOME="$CUSTOM_HOME" "$CUSTOM_HOME/.local/bin/devtheme" tokyo
test -L "$CUSTOM_HOME/.config/starship.toml"
test "$(basename "$(readlink "$CUSTOM_HOME/.config/starship.toml")")" = "jetpack.toml"
compgen -G "$CUSTOM_HOME/.config/ai-ml-dev-bootstrap/backups/starship.toml.*" >/dev/null

# An unmanaged Ghostty config is preserved and a review candidate is produced.
SECOND_HOME="$TEST_ROOT/unmanaged-home"
mkdir -p "$SECOND_HOME/.config/ghostty"
printf 'theme = custom\n' > "$SECOND_HOME/.config/ghostty/config.ghostty"
HOME="$SECOND_HOME" "${CONFIGURE[@]}" --profile minimal
grep -Fq 'theme = custom' "$SECOND_HOME/.config/ghostty/config.ghostty"
test -f "$SECOND_HOME/.config/ghostty/config.ghostty.ai-ml-dev-bootstrap-new"

# Managed blocks must retain their order; syntax highlighting remains the final
# interactive integration in the managed developer block.
minimal_line="$(grep -n '# >>> ai-ml-dev-bootstrap:macos-minimal >>>' "$HOME/.zshrc" | cut -d: -f1)"
developer_line="$(grep -n '# >>> ai-ml-dev-bootstrap:macos-developer >>>' "$HOME/.zshrc" | cut -d: -f1)"
syntax_line="$(grep -n 'zsh-syntax-highlighting.zsh' "$HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
starship_line="$(grep -n 'starship init zsh' "$HOME/.zshrc" | tail -n 1 | cut -d: -f1)"
test "$minimal_line" -lt "$developer_line"
test "$starship_line" -lt "$syntax_line"

echo "macOS configuration integration tests passed"
