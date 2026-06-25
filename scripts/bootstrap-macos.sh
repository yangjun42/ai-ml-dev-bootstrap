#!/usr/bin/env bash
set -euo pipefail

PROFILE="personal"
FEATURES="core,ai,conda"
PYTHON_VERSION="3.12"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTORCH_CPU_INDEX="https://download.pytorch.org/whl/cpu"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --features) FEATURES="$2"; shift 2 ;;
    --python) PYTHON_VERSION="$2"; shift 2 ;;
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

echo "[bootstrap-macos] profile=${PROFILE} features=${FEATURES} repo=${REPO_ROOT}"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required for macOS system packages. Install from https://brew.sh and re-run." >&2
  exit 1
fi

if has_feature core; then
  brew update
  brew install git git-lfs uv jq wget cmake ninja pkg-config ffmpeg htop || true
  brew install --cask vscodium || true
  git lfs install || true
fi

uv python install "$PYTHON_VERSION"
mkdir -p "$HOME/projects" "$HOME/data" "$HOME/models" "$HOME/mlruns"

mkdir -p "$HOME/.config/ai-ml-dev-bootstrap"
cp "$REPO_ROOT/profiles/${PROFILE}.env" "$HOME/.config/ai-ml-dev-bootstrap/profile.env"
if ! grep -q 'ai-ml-dev-bootstrap/profile.env' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" <<'EOF'

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

  # macOS PyTorch wheels do not use CUDA; Apple Silicon uses MPS through PyTorch.
  uv pip install torch torchvision torchaudio

  if [[ "$(uname -m)" == "arm64" ]]; then
    uv pip install -r requirements/macos-apple-silicon.txt || true
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

if has_feature containers; then
  brew install podman docker docker-compose || true
  brew install --cask podman-desktop rancher || true
fi

echo "[bootstrap-macos] done"
echo "Next: cd ~/projects/ai-ml-starter && uv run jupyter lab"
