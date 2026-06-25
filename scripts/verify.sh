#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:-$HOME/projects/ai-ml-starter}"
cd "$PROJECT"
uv run python scripts/check_env.py
