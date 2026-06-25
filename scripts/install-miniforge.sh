#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:-$HOME/miniforge3}"
OS="$(uname)"
ARCH="$(uname -m)"

case "$OS" in
  Linux) INSTALLER="Miniforge3-Linux-${ARCH}.sh" ;;
  Darwin) INSTALLER="Miniforge3-MacOSX-${ARCH}.sh" ;;
  *) echo "Unsupported OS for this script: $OS" >&2; exit 1 ;;
esac

URL="https://github.com/conda-forge/miniforge/releases/latest/download/${INSTALLER}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -x "${PREFIX}/bin/conda" ]; then
  echo "Miniforge already installed at ${PREFIX}"
else
  echo "Downloading ${URL}"
  curl -fsSL "$URL" -o "$TMP/miniforge.sh"
  bash "$TMP/miniforge.sh" -b -p "$PREFIX"
fi

# shellcheck disable=SC1091
source "${PREFIX}/etc/profile.d/conda.sh"
if [ -f "${PREFIX}/etc/profile.d/mamba.sh" ]; then
  # shellcheck disable=SC1091
  source "${PREFIX}/etc/profile.d/mamba.sh"
fi

conda config --set auto_activate_base false
conda config --set channel_priority strict
conda config --remove-key channels >/dev/null 2>&1 || true
conda config --add channels conda-forge

if ! command -v mamba >/dev/null 2>&1; then
  conda install -y -n base -c conda-forge mamba
fi

echo "Miniforge ready: ${PREFIX}"
echo "Use: source ${PREFIX}/etc/profile.d/conda.sh && conda activate <env>"
