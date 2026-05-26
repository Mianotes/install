#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/Library/Application Support/Mianotes"
ENV_FILE="$APP_ROOT/env/mianotes.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

export MIANOTES_DATA_DIR="${MIANOTES_DATA_DIR:-$APP_ROOT/data}"
export MIANOTES_HOST="${MIANOTES_HOST:-0.0.0.0}"
export MIANOTES_PORT="${MIANOTES_PORT:-8200}"

exec "$APP_ROOT/.venv/bin/mianotes-web-service" \
  --host "$MIANOTES_HOST" \
  --port "$MIANOTES_PORT"
