#!/usr/bin/env bash
# Compatibility wrapper for the former macOS profile/feature interface.
set -euo pipefail

PROFILE="personal"
FEATURES="core,ai,conda"
PYTHON_VERSION="3.12"
PROJECT_DIR="$HOME/projects/ai-ml-starter"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --features) FEATURES="$2"; shift 2 ;;
    --python) PYTHON_VERSION="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Compatibility wrapper. Prefer scripts/bootstrap-macos.sh directly.

Legacy options:
  --profile personal|enterprise
  --features core,ai,conda,mlsys,containers
  --python VERSION
  --project-dir PATH
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$PROFILE" in
  personal) NEW_PROFILE="core" ;;
  enterprise) NEW_PROFILE="restricted" ;;
  *) echo "Legacy profile must be personal or enterprise" >&2; exit 2 ;;
esac

NEW_FEATURES=""
OLD_IFS="$IFS"
IFS=','
for feature in $FEATURES; do
  case "$feature" in
    core|minimal|developer) ;;
    ai|conda|mlsys|containers|build)
      NEW_FEATURES="${NEW_FEATURES:+$NEW_FEATURES,}$feature"
      ;;
    all)
      NEW_FEATURES="ai,conda,mlsys,build,containers"
      ;;
    *) echo "Unknown legacy feature: $feature" >&2; exit 2 ;;
  esac
done
IFS="$OLD_IFS"

echo "[bootstrap-macos-legacy-ai] forwarding to the modular macOS bootstrap" >&2

ARGS=(
  --profile "$NEW_PROFILE"
  --python "$PYTHON_VERSION"
  --project-dir "$PROJECT_DIR"
)
[[ -n "$NEW_FEATURES" ]] && ARGS+=(--features "$NEW_FEATURES")

exec bash "$REPO_ROOT/scripts/bootstrap-macos.sh" "${ARGS[@]}"
