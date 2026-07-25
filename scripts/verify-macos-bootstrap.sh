#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bash -n scripts/bootstrap-macos.sh
bash -n scripts/bootstrap-macos-legacy-ai.sh

for file in \
  brewfiles/macos/minimal.Brewfile \
  brewfiles/macos/developer-extra.Brewfile \
  brewfiles/macos/workstation-extra.Brewfile \
  brewfiles/macos/restricted.Brewfile; do
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

if grep -Eq '^brew "git"$' brewfiles/macos/minimal.Brewfile; then
  echo "minimal.Brewfile must use the Apple Command Line Tools Git" >&2
  exit 1
fi

if grep -Eq '^(brew|cask) "(python(@[^\"]*)?|miniforge|pixi|colima|docker|docker-compose|rectangle)"$' brewfiles/macos/minimal.Brewfile; then
  echo "minimal.Brewfile unexpectedly contains project/runtime, workstation, or window-manager dependencies" >&2
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

grep -Fq 'PROFILE="minimal"' scripts/bootstrap-macos.sh
grep -Fq 'core|personal) PROFILE="minimal"' scripts/bootstrap-macos.sh
grep -Fq 'enterprise) PROFILE="restricted"' scripts/bootstrap-macos.sh
grep -Fq 'no Python installation' scripts/bootstrap-macos.sh

echo "macOS bootstrap static checks passed"
