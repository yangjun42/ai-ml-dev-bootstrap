#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bash -n scripts/bootstrap-macos.sh
bash -n scripts/bootstrap-macos-legacy-ai.sh
bash -n scripts/configure-macos-shell.sh
bash -n scripts/test-macos-configure.sh
bash -n config/macos/bin/devtheme

for executable in \
  scripts/bootstrap-macos.sh \
  scripts/configure-macos-shell.sh \
  scripts/test-macos-configure.sh \
  config/macos/bin/devtheme; do
  test -x "$executable"
done

for file in \
  brewfiles/macos/minimal.Brewfile \
  brewfiles/macos/developer-extra.Brewfile \
  brewfiles/macos/workstation-extra.Brewfile \
  brewfiles/macos/restricted.Brewfile \
  config/macos/ghostty/config.ghostty \
  config/macos/ghostty/appearance.ghostty \
  config/macos/zsh/minimal.zsh \
  config/macos/zsh/developer.zsh; do
  test -f "$file"
done

required_minimal=(
  'brew "tmux"'
  'brew "gh"'
  'brew "git-lfs"'
  'brew "uv"'
  'brew "btop"'
  'cask "ghostty"'
  'cask "visual-studio-code"'
  'cask "chatgpt"'
  'cask "claude-code"'
  'cask "ollama-app"'
)

for entry in "${required_minimal[@]}"; do
  grep -Fqx "$entry" brewfiles/macos/minimal.Brewfile
done

required_developer=(
  'brew "starship"'
  'brew "zoxide"'
  'brew "zsh-autosuggestions"'
  'brew "zsh-syntax-highlighting"'
  'brew "fzf"'
  'brew "ripgrep"'
)

for entry in "${required_developer[@]}"; do
  grep -Fqx "$entry" brewfiles/macos/developer-extra.Brewfile
done

if grep -Eq '^brew "git"$' brewfiles/macos/minimal.Brewfile; then
  echo "minimal.Brewfile must use the Apple Command Line Tools Git" >&2
  exit 1
fi

if grep -Eq '^(brew|cask) "(python(@[^"]*)?|miniforge|pixi|colima|docker|docker-compose|rectangle|starship|zoxide|yazi)"$' brewfiles/macos/minimal.Brewfile; then
  echo "minimal.Brewfile unexpectedly contains project, workstation, or developer-only dependencies" >&2
  exit 1
fi

if grep -Eq '^cask "rectangle"$' brewfiles/macos/restricted.Brewfile; then
  echo "restricted.Brewfile must use macOS native window tiling" >&2
  exit 1
fi

for disallowed in 'cask "chatgpt"' 'cask "claude-code"' 'cask "ollama-app"'; do
  if grep -Fqx "$disallowed" brewfiles/macos/restricted.Brewfile; then
    echo "restricted.Brewfile unexpectedly includes: $disallowed" >&2
    exit 1
  fi
done

# Ghostty and zsh baseline invariants.
grep -Fq 'command = /bin/zsh -l' config/macos/ghostty/config.ghostty
grep -Fq 'shell-integration-features = ssh-env,ssh-terminfo' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update = check' config/macos/ghostty/config.ghostty
grep -Fq 'auto-update-channel = stable' config/macos/ghostty/config.ghostty
grep -Fq 'config-file = ?appearance.ghostty' config/macos/ghostty/config.ghostty
grep -Fq 'theme = dark:TokyoNight Moon,light:TokyoNight Day' config/macos/ghostty/appearance.ghostty
grep -Fq '# >>> ai-ml-dev-bootstrap:macos-minimal >>>' config/macos/zsh/minimal.zsh
grep -Fq '# >>> ai-ml-dev-bootstrap:macos-developer >>>' config/macos/zsh/developer.zsh
grep -Fq '/opt/homebrew/bin/brew shellenv' config/macos/zsh/minimal.zsh
grep -Fq '! $+functions[compdef]' config/macos/zsh/minimal.zsh
grep -Fq 'typeset -U path PATH' config/macos/zsh/developer.zsh
if grep -Fq 'export STARSHIP_CONFIG=' config/macos/zsh/developer.zsh; then
  echo "developer.zsh must let existing and managed Starship init use the official default config path" >&2
  exit 1
fi
grep -Fq '! $+functions[__zoxide_z]' config/macos/zsh/developer.zsh
grep -Fq '! $+widgets[fzf-history-widget]' config/macos/zsh/developer.zsh
grep -Fq 'STARSHIP_SHELL' config/macos/zsh/developer.zsh
grep -Fq '! $+functions[_zsh_autosuggest_start]' config/macos/zsh/developer.zsh
grep -Fq '! $+functions[_zsh_highlight]' config/macos/zsh/developer.zsh
grep -Fq 'zsh-syntax-highlighting.zsh' config/macos/zsh/developer.zsh
grep -Fq 'local active="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"' scripts/configure-macos-shell.sh
grep -Fq 'STARSHIP_ACTIVE="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"' config/macos/bin/devtheme

# Bootstrap behaviour and profile aliases.
grep -Fq 'PROFILE="minimal"' scripts/bootstrap-macos.sh
grep -Fq 'core|personal) PROFILE="minimal"' scripts/bootstrap-macos.sh
grep -Fq 'enterprise) PROFILE="restricted"' scripts/bootstrap-macos.sh
grep -Fq 'bundle_is_satisfied' scripts/bootstrap-macos.sh
grep -Fq 'configure-macos-shell.sh' scripts/bootstrap-macos.sh
grep -Fq 'no Python installation' scripts/bootstrap-macos.sh

bash scripts/test-macos-configure.sh

echo "macOS bootstrap static and integration checks passed"
