#!/usr/bin/env bash
set -euo pipefail

PROFILE="core"
PYTHON_VERSION="3.12"
PROJECT_DIR="$HOME/projects/ai-ml-starter"
WITH_MLSYS=0
DRY_RUN=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-macos-ai.sh [options]

Options:
  --profile core|restricted
  --python VERSION       Default: 3.12
  --project-dir PATH     Default: ~/projects/ai-ml-starter
  --with-mlsys           Add profiling, benchmarking, ONNX, and runtime tools.
  --dry-run              Print intended actions without changing anything.
  -h, --help             Show this help.

This feature creates or reuses one uv project. It does not install global
Python packages and does not modify unrelated repositories.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --python)
      PYTHON_VERSION="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --with-mlsys)
      WITH_MLSYS=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$PROFILE" in
  core|restricted) ;;
  personal|minimal|developer|workstation) PROFILE="core" ;;
  enterprise) PROFILE="restricted" ;;
  *) echo "Unknown profile: $PROFILE" >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This feature is intended for macOS." >&2
  exit 1
fi

command -v uv >/dev/null 2>&1 || {
  echo "uv is required. Install the core profile first." >&2
  exit 1
}

TEMPLATE_DIR="$REPO_ROOT/templates/ai-starter"
[[ -f "$TEMPLATE_DIR/pyproject.toml" ]] || {
  echo "Missing AI starter template: $TEMPLATE_DIR" >&2
  exit 1
}

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[setup-macos-ai] would prepare project: $PROJECT_DIR"
  echo "[setup-macos-ai] would use Python: $PYTHON_VERSION"
  echo "[setup-macos-ai] would install base, LLM, development, PyTorch/MPS, and Apple Silicon packages"
  [[ "$WITH_MLSYS" == "1" ]] && echo "[setup-macos-ai] would add ML systems packages"
  exit 0
fi

if [[ -d "$PROJECT_DIR" && -n "$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" && ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
  echo "Refusing to populate a non-empty directory without pyproject.toml: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
if [[ ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
  rsync -a "$TEMPLATE_DIR/" "$PROJECT_DIR/"
  printf '%s\n' "$PYTHON_VERSION" > "$PROJECT_DIR/.python-version"
  echo "[setup-macos-ai] created starter project: $PROJECT_DIR"
else
  # Existing projects own their files. Add only template files that are absent.
  rsync -a --ignore-existing "$TEMPLATE_DIR/" "$PROJECT_DIR/"
  if [[ ! -f "$PROJECT_DIR/.python-version" ]]; then
    printf '%s\n' "$PYTHON_VERSION" > "$PROJECT_DIR/.python-version"
  fi
  echo "[setup-macos-ai] reusing project: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

if [[ ! -x .venv/bin/python ]]; then
  uv venv --python "$PYTHON_VERSION"
fi

uv pip install \
  -r requirements/base.txt \
  -r requirements/llm.txt \
  -r requirements/dev.txt

# macOS wheels use the Metal/MPS backend where supported; no CUDA index is used.
uv pip install torch torchvision torchaudio

if [[ "$(uname -m)" == "arm64" ]]; then
  uv pip install -r requirements/macos-apple-silicon.txt
fi

if [[ "$WITH_MLSYS" == "1" ]]; then
  uv pip install -r requirements/mlsys.txt
fi

if [[ "$PROFILE" == "restricted" ]]; then
  uv pip install -r requirements/enterprise.txt
else
  uv pip install -r requirements/personal.txt
fi

uv run python scripts/check_env.py || true

echo "[setup-macos-ai] ready: $PROJECT_DIR"
echo "Next: cd '$PROJECT_DIR' && uv run jupyter lab"
