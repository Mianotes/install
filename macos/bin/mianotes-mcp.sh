#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/Library/Application Support/Mianotes"
ENV_FILE="$APP_ROOT/env/mianotes.env"
RUNTIME_ENV="$APP_ROOT/bin/runtime-env.sh"

if [[ -f "$RUNTIME_ENV" ]]; then
  # shellcheck source=/dev/null
  . "$RUNTIME_ENV"
  mianotes_export_runtime "$APP_ROOT"
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

export MIANOTES_API_URL="${MIANOTES_API_URL:-http://127.0.0.1:8200}"
export MIANOTES_ENV_FILE="${MIANOTES_ENV_FILE:-$ENV_FILE}"
export MIANOTES_CLIENT_NAME="${MIANOTES_CLIENT_NAME:-MCP}"

exec "$APP_ROOT/.venv/bin/mianotes-mcp"
