#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/mianotes"
ENV_FILE="/etc/mianotes/mianotes.env"
WORKSPACES_CONFIG="/var/lib/mianotes/workspaces.json"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

export MIANOTES_DATA_DIR="${MIANOTES_DATA_DIR:-/var/lib/mianotes/data}"
export MIANOTES_STORAGE_CONFIG_PATH="${MIANOTES_STORAGE_CONFIG_PATH:-$WORKSPACES_CONFIG}"
export MIANOTES_ENV_FILE="${MIANOTES_ENV_FILE:-$ENV_FILE}"
export MIANOTES_HOST="${MIANOTES_HOST:-0.0.0.0}"
export MIANOTES_PORT="${MIANOTES_PORT:-8200}"

exec "$APP_ROOT/.venv/bin/mianotes-web-service" \
  --host "$MIANOTES_HOST" \
  --port "$MIANOTES_PORT"
