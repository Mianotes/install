#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/Library/Application Support/Mianotes"
DASHBOARD_DIR="$APP_ROOT/dashboard/dist"
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

API_PORT="${MIANOTES_PORT:-8200}"
DASHBOARD_PORT="${MIANOTES_DASHBOARD_PORT:-8201}"

exec "$APP_ROOT/.venv/bin/python" "$APP_ROOT/bin/dashboard_server.py" \
  --host 0.0.0.0 \
  --port "$DASHBOARD_PORT" \
  --backend "http://127.0.0.1:$API_PORT" \
  --directory "$DASHBOARD_DIR"
