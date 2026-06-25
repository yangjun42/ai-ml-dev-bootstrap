#!/usr/bin/env bash
set -euo pipefail

PROFILE="personal"
FEATURES="core,ai,conda"
REPO_ROOT=""
PYTHON_VERSION="3.12"
PYTORCH_CUDA_INDEX="https://download.pytorch.org/whl/cu130"
PYTORCH_CPU_INDEX="https://download.pytorch.org/whl/cpu"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --features) FEATURES="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --python) PYTHON_VERSION="$2"; shift 2 ;;
    --pytorch-cuda-index) PYTORCH_CUDA_INDEX="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

has_feature() {
  [[ ",$FEATURES," == *",$1,"* || ",$FEATURES," == *",all,"* ]]
}

if [[ "$PROFILE" != "personal" && "$PROFILE" != "enterprise" ]]; then
  echo "PROFILE must be personal or enterprise" >&2
  exit 1
fi

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

echo "[bootstrap-wsl] profile=${PROFILE} features=${FEATURES} repo=${REPO_ROOT}"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential git git-lfs curl wget ca-certificates gnupg unzip zip jq rsync \
  htop pkg-config cmake ninja-build python3-venv python3-dev \
  ffmpeg libgl1 libglib2.0-0

git lfs install || true

# uv
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

uv python install "$PYTHON_VERSION"

mkdir -p "$HOME/projects" "$HOME/data" "$HOME/models" "$HOME/mlruns"

# profile env
mkdir -p "$HOME/.config/ai-ml-dev-bootstrap"
cp "$REPO_ROOT/profiles/${PROFILE}.env" "$HOME/.config/ai-ml-dev-bootstrap/profile.env"
if ! grep -q 'ai-ml-dev-bootstrap/profile.env' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'EOF'

# ai-ml-dev-bootstrap profile
if [ -f "$HOME/.config/ai-ml-dev-bootstrap/profile.env" ]; then
  . "$HOME/.config/ai-ml-dev-bootstrap/profile.env"
fi
EOF
fi
# shellcheck disable=SC1090
source "$HOME/.config/ai-ml-dev-bootstrap/profile.env"

if has_feature conda; then
  bash "$REPO_ROOT/scripts/install-miniforge.sh" "$HOME/miniforge3"
  # shellcheck disable=SC1091
  source "$HOME/miniforge3/etc/profile.d/conda.sh"
  if [ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ]; then
    # shellcheck disable=SC1091
    source "$HOME/miniforge3/etc/profile.d/mamba.sh"
  fi
  if mamba env list | awk '{print $1}' | grep -qx 'ai-native'; then
    mamba env update -n ai-native -f "$REPO_ROOT/envs/ai-native.yml" --prune
  else
    mamba env create -f "$REPO_ROOT/envs/ai-native.yml"
  fi
fi

if has_feature ai; then
  TARGET="$HOME/projects/ai-ml-starter"
  mkdir -p "$TARGET"
  rsync -a --delete --exclude '.venv' "$REPO_ROOT/templates/ai-starter/" "$TARGET/"
  cd "$TARGET"
  uv venv --python "$PYTHON_VERSION"
  uv pip install -r requirements/base.txt -r requirements/llm.txt -r requirements/dev.txt

  if command -v nvidia-smi >/dev/null 2>&1 || [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
    echo "NVIDIA GPU visible; installing PyTorch from ${PYTORCH_CUDA_INDEX}"
    uv pip install torch torchvision torchaudio --index-url "$PYTORCH_CUDA_INDEX"
  else
    echo "No NVIDIA GPU visible; installing CPU PyTorch"
    uv pip install torch torchvision torchaudio --index-url "$PYTORCH_CPU_INDEX"
  fi

  if has_feature mlsys; then
    uv pip install -r requirements/mlsys.txt
  fi

  if [[ "$PROFILE" == "personal" ]]; then
    uv pip install -r requirements/personal.txt
  else
    uv pip install -r requirements/enterprise.txt
  fi

  uv run python scripts/check_env.py || true
fi

if has_feature cuda-extras; then
  bash "$REPO_ROOT/scripts/install-cuda-extras.sh" || true
fi

echo "[bootstrap-wsl] done"
echo "Next: cd ~/projects/ai-ml-starter && uv run jupyter lab"
