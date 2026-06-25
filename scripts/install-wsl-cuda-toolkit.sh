#!/usr/bin/env bash
set -euo pipefail

CUDA_TOOLKIT_VERSION="${1:-13-3}"
CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/"
KEYRING="/usr/share/keyrings/cuda-wsl-archive-keyring.gpg"
LIST_FILE="/etc/apt/sources.list.d/cuda-wsl-ubuntu.list"

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "This script is intended for WSL2. Refusing to install the WSL-Ubuntu CUDA toolkit repo." >&2
  exit 1
fi

if [[ ! "$CUDA_TOOLKIT_VERSION" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
  echo "CUDA toolkit version must look like 12-9, 13-3, 12, or 13. Got: $CUDA_TOOLKIT_VERSION" >&2
  exit 1
fi

nvidia_smi() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi "$@"
  elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
    /usr/lib/wsl/lib/nvidia-smi "$@"
  else
    return 127
  fi
}

if ! nvidia_smi -L >/dev/null 2>&1; then
  echo "No NVIDIA GPU is visible inside WSL2. Install/update the Windows NVIDIA driver, run 'wsl --update', then 'wsl --shutdown' from PowerShell." >&2
  exit 1
fi

cat <<'MSG'
Installing CUDA Toolkit for WSL-Ubuntu.
This installs the Linux CUDA toolchain/runtime packages for compiling native CUDA code.
It does NOT install a Linux NVIDIA display driver. Do not install cuda, cuda-12-x, cuda-13-x, cuda-drivers, or nvidia-driver packages inside WSL2.
MSG

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg

sudo rm -f "$KEYRING.tmp"
curl -fsSL "${CUDA_REPO_URL}3bf863cc.pub" | sudo gpg --dearmor --yes -o "$KEYRING.tmp"
sudo mv "$KEYRING.tmp" "$KEYRING"
echo "deb [signed-by=${KEYRING}] ${CUDA_REPO_URL} /" | sudo tee "$LIST_FILE" >/dev/null

sudo apt-get update
PACKAGE="cuda-toolkit-${CUDA_TOOLKIT_VERSION}"
if ! apt-cache show "$PACKAGE" >/dev/null 2>&1; then
  echo "Package $PACKAGE not found in the WSL-Ubuntu CUDA repo. Check available packages with: apt-cache search '^cuda-toolkit-'" >&2
  exit 1
fi

sudo apt-get install -y "$PACKAGE"

BASHRC_LINE='\n# CUDA Toolkit for WSL2: toolchain only; NVIDIA driver is mapped from Windows\nif [ -d /usr/local/cuda/bin ]; then export PATH="/usr/local/cuda/bin:$PATH"; fi\nif [ -d /usr/local/cuda/lib64 ]; then export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"; fi'
if ! grep -q 'CUDA Toolkit for WSL2' "$HOME/.bashrc" 2>/dev/null; then
  printf "%b\n" "$BASHRC_LINE" >> "$HOME/.bashrc"
fi

export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

if command -v nvcc >/dev/null 2>&1; then
  nvcc --version
else
  echo "CUDA toolkit installed, but nvcc is not on PATH. Open a new shell or source ~/.bashrc."
fi
