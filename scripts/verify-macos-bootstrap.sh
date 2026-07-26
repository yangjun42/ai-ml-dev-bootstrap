#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

for script in \
  scripts/bootstrap-macos.sh \
  scripts/configure-macos-shell.sh \
  scripts/test-macos-configure.sh \
  config/macos/bin/devtheme; do
  bash -n "$script"
done

for executable in \
  scripts/bootstrap-macos.sh \
  scripts/configure-macos-shell.sh \
  scripts/test-macos-configure.sh \
  config/macos/bin/devtheme; do
  test -x "$executable"
done

for file in \
  brewfiles/macos/core.Brewfile \
  brewfiles/macos/ai.Brewfile \
  brewfiles/macos/mlsys.Brewfile \
  brewfiles/macos/containers.Brewfile \
  config/macos/ghostty/config.ghostty \
  config/macos/ghostty/appearance.ghostty \
  config/macos/zsh/core.zsh \
  docs/MACOS.md; do
  test -f "$file"
done

required_core=(
  'brew "tmux"'
  'brew "gh"'
  'brew "git-lfs"'
  'brew "uv"'
  'brew "btop"'
  'brew "starship"'
  'brew "zoxide"'
  'brew "fzf"'
  'brew "ripgrep"'
  'brew "fd"'
  'brew "zsh-autosuggestions"'
  'brew "zsh-syntax-highlighting"'
  'cask "ghostty"'
  'cask "visual-studio-code"'
)

for entry in "${required_core[@]}"; do
  grep -Fqx "$entry" brewfiles/macos/core.Brewfile
done

for entry in 'cask "chatgpt"' 'cask "claude-code"' 'cask "ollama-app"'; do
  grep -Fqx "$entry" brewfiles/macos/ai.Brewfile
  if grep -Fqx "$entry" brewfiles/macos/core.Brewfile; then
    echo "AI application leaked into core.Brewfile: $entry" >&2
    exit 1
  fi
done

for entry in \
  'brew "cmake"' \
  'brew "ninja"' \
  'brew "pkgconf"' \
  'brew "hyperfine"'; do
  grep -Fqx "$entry" brewfiles/macos/mlsys.Brewfile
done

for entry in 'brew "colima"' 'brew "docker"' 'brew "docker-compose"'; do
  grep -Fqx "$entry" brewfiles/macos/containers.Brewfile
done

if grep -Eq '^brew "git"$' brewfiles/macos/core.Brewfile; then
  echo "core.Brewfile must use Apple Command Line Tools Git" >&2
  exit 1
fi

if grep -Eq '^(brew|cask) "(python(@[^"]*)?|miniforge|pixi|colima|docker|docker-compose|rectangle|yazi|llama.cpp|ffmpeg|cmake|ninja|hyperfine|chatgpt|claude-code|ollama-app)"$' brewfiles/macos/core.Brewfile; then
  echo "core.Brewfile unexpectedly contains project or optional feature tooling" >&2
  exit 1
fi

# Removed tier/profile manifests and environment installers must stay gone.
for obsolete in \
  brewfiles/macos/minimal.Brewfile \
  brewfiles/macos/developer-extra.Brewfile \
  brewfiles/macos/workstation-extra.Brewfile \
  brewfiles/macos/restricted.Brewfile \
  brewfiles/macos/personal.Brewfile \
  brewfiles/macos/ml.Brewfile \
  brewfiles/macos/build.Brewfile \
  config/macos/zsh/minimal.zsh \
  config/macos/zsh/developer.zsh \
  scripts/setup-macos-ai.sh \
  scripts/bootstrap-macos-legacy-ai.sh; do
  test ! -e "$obsolete"
done

if grep -Eq '^(brew|cask) "(llama\.cpp|ffmpeg)"$' brewfiles/macos/ai.Brewfile; then
  echo "AI feature must remain the three application bundle only" >&2
  exit 1
fi

# Ghostty uses the normal login shell and documents the opt-in Bash workaround.
grep -Fq '# command = /bin/zsh -l' config/macos/ghostty/config.ghostty
grep -Fq 'shell-integration = detect' config/macos/ghostty/config.ghostty
if grep -Eq '^[[:space:]]*command[[:space:]]*=' config/macos/ghostty/config.ghostty; then
  echo "Ghostty must not force an explicit shell by default" >&2
  exit 1
fi
grep -Fq 'shell-integration-features = ssh-env,ssh-terminfo' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update = check' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update-channel = stable' config/macos/ghostty/config.ghostty
grep -Fq 'config-file = ?appearance.ghostty' config/macos/ghostty/config.ghostty
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' config/macos/ghostty/appearance.ghostty

# One complete zsh source of truth plus an explicit user override file.
grep -Fq 'Managed by ai-ml-dev-bootstrap' config/macos/zsh/core.zsh
grep -Fq '/opt/homebrew/bin/brew shellenv' config/macos/zsh/core.zsh
grep -Fq 'zoxide init zsh' config/macos/zsh/core.zsh
grep -Fq 'fzf --zsh' config/macos/zsh/core.zsh
grep -Fq 'starship init zsh' config/macos/zsh/core.zsh
grep -Fq '.config}/zsh/local.zsh' config/macos/zsh/core.zsh
grep -Fq 'zsh-syntax-highlighting.zsh' config/macos/zsh/core.zsh
if grep -Fq 'ai-ml-dev-bootstrap:macos-' config/macos/zsh/core.zsh; then
  echo "core zsh config must not retain marker-based tier blocks" >&2
  exit 1
fi

# The configurator adopts each managed file once and removes duplicate Ghostty
# config precedence instead of generating candidates or timestamped backups.
grep -Fq 'backup_once()' scripts/configure-macos-shell.sh
grep -Fq '.original' scripts/configure-macos-shell.sh
grep -Fq 'remove_duplicate_ghostty_config' scripts/configure-macos-shell.sh
grep -Fq 'install_managed_file "$REPO_ROOT/config/macos/zsh/core.zsh" "$HOME/.zshrc"' scripts/configure-macos-shell.sh
if grep -Eq -- '--force-config|ai-ml-dev-bootstrap-new|TIMESTAMP=|macos-minimal|macos-developer' scripts/configure-macos-shell.sh; then
  echo "macOS configurator contains obsolete migration or repeated-backup logic" >&2
  exit 1
fi

# Public interface: one core plus three orthogonal features.
grep -Fq 'ai|mlsys|containers' scripts/bootstrap-macos.sh
grep -Fq 'feature_enabled ai' scripts/bootstrap-macos.sh
grep -Fq 'feature_enabled mlsys' scripts/bootstrap-macos.sh
grep -Fq 'feature_enabled containers' scripts/bootstrap-macos.sh
grep -Fq 'brewfiles/macos/ai.Brewfile' scripts/bootstrap-macos.sh
grep -Fq 'bundle_is_satisfied' scripts/bootstrap-macos.sh
grep -Fq 'configure-macos-shell.sh' scripts/bootstrap-macos.sh
grep -Fq 'no Python installation or virtual environment' scripts/bootstrap-macos.sh

if grep -Fq 'FEATURES[@]' scripts/bootstrap-macos.sh; then
  echo "macOS feature parsing must not expand an empty Bash array under set -u" >&2
  exit 1
fi

if grep -Eq -- '--profile|PROFILE=|--force-config|setup-macos-ai|install-miniforge|uv python install|uv pip install|llama\.cpp|ffmpeg' scripts/bootstrap-macos.sh; then
  echo "macOS bootstrap contains a removed profile, force, or environment/runtime path" >&2
  exit 1
fi

grep -Fq 'features: ai, mlsys, containers' docs/MACOS.md
grep -Fq '# command = /bin/zsh -l' docs/MACOS.md
grep -Fq 'zshrc.original' docs/MACOS.md
grep -Fq 'ghostty-macos-config.original' docs/MACOS.md

# Starter metadata remains generic and does not embed a machine-wide ML stack.
python3 - <<'PY'
import pathlib
import tomllib

path = pathlib.Path("templates/ai-starter/pyproject.toml")
with path.open("rb") as handle:
    data = tomllib.load(handle)

assert data["project"]["dependencies"] == []
assert data["tool"]["uv"]["package"] is False
PY

# Exercise the public CLI with features under `set -u`. On the macOS runner this
# uses Apple's Bash 3.2 and catches empty-array expansion regressions.
CLI_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-ml-macos-cli.XXXXXX")"
trap 'rm -rf "$CLI_TEST_ROOT"' EXIT
CLI_FAKE_BIN="$CLI_TEST_ROOT/bin"
CLI_HOME="$CLI_TEST_ROOT/home"
mkdir -p "$CLI_FAKE_BIN" "$CLI_HOME"

cat > "$CLI_FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" ]]; then
  echo Darwin
else
  /usr/bin/uname "$@"
fi
EOF

cat > "$CLI_FAKE_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$CLI_FAKE_BIN/brew" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--prefix" ]]; then
  echo /opt/homebrew
fi
exit 0
EOF

chmod +x "$CLI_FAKE_BIN/uname" "$CLI_FAKE_BIN/xcode-select" "$CLI_FAKE_BIN/brew"

cli_ai_output="$(HOME="$CLI_HOME" PATH="$CLI_FAKE_BIN:$PATH" \
  bash scripts/bootstrap-macos.sh --features ai --dry-run)"
printf '%s\n' "$cli_ai_output" | grep -Fq 'features=ai'
printf '%s\n' "$cli_ai_output" | grep -Fq 'ai.Brewfile'

cli_all_output="$(HOME="$CLI_HOME" PATH="$CLI_FAKE_BIN:$PATH" \
  bash scripts/bootstrap-macos.sh --features all --dry-run)"
printf '%s\n' "$cli_all_output" | grep -Fq 'features=ai,mlsys,containers'
printf '%s\n' "$cli_all_output" | grep -Fq 'mlsys.Brewfile'
printf '%s\n' "$cli_all_output" | grep -Fq 'containers.Brewfile'

bash scripts/test-macos-configure.sh

echo "macOS core/AI/MLsys static and integration checks passed"
