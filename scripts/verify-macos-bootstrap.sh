#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

for script in \
  scripts/bootstrap-macos.sh \
  scripts/bootstrap-macos-legacy-ai.sh \
  scripts/configure-macos-shell.sh \
  scripts/setup-macos-ai.sh \
  scripts/test-macos-configure.sh \
  config/macos/bin/devtheme; do
  bash -n "$script"
done

for executable in \
  scripts/bootstrap-macos.sh \
  scripts/configure-macos-shell.sh \
  scripts/setup-macos-ai.sh \
  scripts/test-macos-configure.sh \
  config/macos/bin/devtheme; do
  test -x "$executable"
done

for file in \
  brewfiles/macos/core.Brewfile \
  brewfiles/macos/personal.Brewfile \
  brewfiles/macos/build.Brewfile \
  brewfiles/macos/containers.Brewfile \
  brewfiles/macos/mlsys.Brewfile \
  config/macos/ghostty/config.ghostty \
  config/macos/ghostty/appearance.ghostty \
  config/macos/zsh/core.zsh; do
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
  grep -Fqx "$entry" brewfiles/macos/personal.Brewfile
  if grep -Fqx "$entry" brewfiles/macos/core.Brewfile; then
    echo "personal-only app leaked into core.Brewfile: $entry" >&2
    exit 1
  fi
done

if grep -Eq '^brew "git"$' brewfiles/macos/core.Brewfile; then
  echo "core.Brewfile must use Apple Command Line Tools Git" >&2
  exit 1
fi

if grep -Eq '^(brew|cask) "(python(@[^"]*)?|miniforge|pixi|colima|docker|docker-compose|rectangle|yazi)"$' brewfiles/macos/core.Brewfile; then
  echo "core.Brewfile unexpectedly contains project, container, or optional tooling" >&2
  exit 1
fi

# The old tiered manifests/config must be removed after the core migration.
for obsolete in \
  brewfiles/macos/minimal.Brewfile \
  brewfiles/macos/developer-extra.Brewfile \
  brewfiles/macos/workstation-extra.Brewfile \
  brewfiles/macos/restricted.Brewfile \
  config/macos/zsh/minimal.zsh \
  config/macos/zsh/developer.zsh; do
  test ! -e "$obsolete"
done

# Ghostty and unified zsh invariants.
grep -Fq 'command = /bin/zsh -l' config/macos/ghostty/config.ghostty
grep -Fq 'shell-integration-features = ssh-env,ssh-terminfo' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update = check' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update-channel = stable' config/macos/ghostty/config.ghostty
grep -Fq 'config-file = ?appearance.ghostty' config/macos/ghostty/config.ghostty
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' config/macos/ghostty/appearance.ghostty
grep -Fq '# >>> ai-ml-dev-bootstrap:macos-core >>>' config/macos/zsh/core.zsh
grep -Fq '/opt/homebrew/bin/brew shellenv' config/macos/zsh/core.zsh
grep -Fq 'zoxide init zsh' config/macos/zsh/core.zsh
grep -Fq 'fzf --zsh' config/macos/zsh/core.zsh
grep -Fq 'starship init zsh' config/macos/zsh/core.zsh
grep -Fq 'zsh-syntax-highlighting.zsh' config/macos/zsh/core.zsh

# Bootstrap interface: two policy profiles and five orthogonal features.
grep -Fq 'PROFILE="core"' scripts/bootstrap-macos.sh
grep -Fq 'ai|conda|mlsys|build|containers' scripts/bootstrap-macos.sh
grep -Fq 'minimal|developer|personal' scripts/bootstrap-macos.sh
grep -Fq 'bundle_is_satisfied' scripts/bootstrap-macos.sh
grep -Fq 'setup-macos-ai.sh' scripts/bootstrap-macos.sh
grep -Fq 'install-miniforge.sh' scripts/bootstrap-macos.sh
grep -Fq 'config/macos/zsh/core.zsh' scripts/configure-macos-shell.sh

grep -Fq 'uv pip install' scripts/setup-macos-ai.sh
grep -Fq 'requirements/mlsys.txt' scripts/setup-macos-ai.sh

bash scripts/test-macos-configure.sh

echo "macOS core/feature static and integration checks passed"
