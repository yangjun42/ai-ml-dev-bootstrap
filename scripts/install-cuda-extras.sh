#!/usr/bin/env bash
set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found" >&2
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
  echo "No NVIDIA GPU visible; skipping cuda-extras."
  exit 0
fi

PROJECT="${1:-$HOME/projects/ai-ml-starter}"
if [ ! -d "$PROJECT" ]; then
  echo "Project not found: $PROJECT" >&2
  exit 1
fi

cd "$PROJECT"

# Keep this intentionally best-effort. These packages are ABI-sensitive.
uv pip install -r requirements/cuda-extras-linux.txt || true

echo "cuda-extras attempted. Verify with: uv run python scripts/check_env.py"
