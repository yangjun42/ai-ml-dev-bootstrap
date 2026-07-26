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

This feature creates or reuses the repository's uv starter project. It does not
install global Python packages and refuses unrelated non-empty directories.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --python) PYTHON_VERSION="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --with-mlsys) WITH_MLSYS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$PROFILE" in
  core|restricted) ;;
  personal|minimal|developer|workstation) PROFILE="core" ;;
  enterprise) PROFILE="restricted" ;;
  *) echo "Unknown profile: $PROFILE" >&2; exit 2 ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "This feature is intended for macOS." >&2
  exit 1
}

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
  echo "[setup-macos-ai] would prepare: $PROJECT_DIR"
  echo "[setup-macos-ai] would use Python: $PYTHON_VERSION"
  echo "[setup-macos-ai] would run uv sync with ai and $PROFILE extras"
  [[ "$WITH_MLSYS" == "1" ]] && echo "[setup-macos-ai] would include the mlsys extra"
  exit 0
fi

# BSD find on macOS does not provide GNU -mindepth/-maxdepth flags. `ls -A`
# is sufficient because the path is quoted and only emptiness matters.
if [[ -d "$PROJECT_DIR" && -n "$(ls -A "$PROJECT_DIR" 2>/dev/null)" && ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
  echo "Refusing to populate a non-empty directory without pyproject.toml: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
if [[ ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
  rsync -a "$TEMPLATE_DIR/" "$PROJECT_DIR/"
  printf '%s\n' "$PYTHON_VERSION" > "$PROJECT_DIR/.python-version"
  echo "[setup-macos-ai] created starter project: $PROJECT_DIR"
else
  if ! grep -Eq '^name[[:space:]]*=[[:space:]]*"ai-ml-starter"' "$PROJECT_DIR/pyproject.toml"; then
    echo "Refusing to manage an unrelated Python project: $PROJECT_DIR" >&2
    exit 1
  fi
  rsync -a --ignore-existing "$TEMPLATE_DIR/" "$PROJECT_DIR/"
  [[ -f "$PROJECT_DIR/.python-version" ]] || printf '%s\n' "$PYTHON_VERSION" > "$PROJECT_DIR/.python-version"
  echo "[setup-macos-ai] reusing starter project: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

if grep -Eq '^ai[[:space:]]*=[[:space:]]*\[' pyproject.toml; then
  SYNC_ARGS=(--extra ai)
  if [[ "$PROFILE" == "restricted" ]]; then
    SYNC_ARGS+=(--extra restricted)
  else
    SYNC_ARGS+=(--extra personal)
  fi
  [[ "$WITH_MLSYS" == "1" ]] && SYNC_ARGS+=(--extra mlsys)

  # uv creates .venv, resolves dependencies, and records the exact solution in
  # uv.lock. Re-running sync keeps the environment aligned with project metadata.
  uv sync "${SYNC_ARGS[@]}"
else
  # Compatibility path for starter projects created before pyproject extras were
  # introduced. Their files remain user-owned; no pyproject rewrite is forced.
  echo "[setup-macos-ai] legacy starter detected; using requirements compatibility path" >&2
  [[ -x .venv/bin/python ]] || uv venv --python "$PYTHON_VERSION"
  uv pip install -r requirements/base.txt -r requirements/llm.txt -r requirements/dev.txt
  uv pip install torch torchvision torchaudio
  [[ "$(uname -m)" == "arm64" ]] && uv pip install -r requirements/macos-apple-silicon.txt
  [[ "$WITH_MLSYS" == "1" ]] && uv pip install -r requirements/mlsys.txt
  if [[ "$PROFILE" == "restricted" ]]; then
    uv pip install -r requirements/enterprise.txt
  else
    uv pip install -r requirements/personal.txt
  fi
fi

uv run python scripts/check_env.py || true

echo "[setup-macos-ai] ready: $PROJECT_DIR"
echo "Next: cd '$PROJECT_DIR' && uv run jupyter lab"
