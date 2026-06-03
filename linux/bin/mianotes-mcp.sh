#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/mianotes"
ENV_FILE="/etc/mianotes/mianotes.env"

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
