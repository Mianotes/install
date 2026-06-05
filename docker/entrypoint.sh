#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

APP_ROOT="${MIANOTES_APP_ROOT:-/opt/mianotes}"
DASHBOARD_DIR="${MIANOTES_DASHBOARD_DIR:-$APP_ROOT/dashboard/dist}"
DASHBOARD_SERVER="$APP_ROOT/bin/dashboard_server.py"
PYTHON="$APP_ROOT/.venv/bin/python"
WEB_SERVICE="$APP_ROOT/.venv/bin/mianotes-web-service"

export MIANOTES_HOST="${MIANOTES_HOST:-0.0.0.0}"
export MIANOTES_PORT="${MIANOTES_PORT:-8200}"
export MIANOTES_DASHBOARD_HOST="${MIANOTES_DASHBOARD_HOST:-0.0.0.0}"
export MIANOTES_DASHBOARD_PORT="${MIANOTES_DASHBOARD_PORT:-8201}"
export MIANOTES_DATA_DIR="${MIANOTES_DATA_DIR:-/data}"
export MIANOTES_STORAGE_CONFIG_PATH="${MIANOTES_STORAGE_CONFIG_PATH:-$MIANOTES_DATA_DIR/workspaces.json}"
export MIANOTES_ENV_FILE="${MIANOTES_ENV_FILE:-$MIANOTES_DATA_DIR/mianotes.env}"

mkdir -p "$MIANOTES_DATA_DIR"

if [ -f "$MIANOTES_ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$MIANOTES_ENV_FILE"
  set +a
fi

mkdir -p \
  "$MIANOTES_DATA_DIR" \
  "$MIANOTES_DATA_DIR/workspaces" \
  "$MIANOTES_DATA_DIR/markdown" \
  "$MIANOTES_DATA_DIR/html"

"$WEB_SERVICE" init-db

"$WEB_SERVICE" --host "$MIANOTES_HOST" --port "$MIANOTES_PORT" &
api_pid=$!

"$PYTHON" "$DASHBOARD_SERVER" \
  --directory "$DASHBOARD_DIR" \
  --backend "http://127.0.0.1:$MIANOTES_PORT" \
  --host "$MIANOTES_DASHBOARD_HOST" \
  --port "$MIANOTES_DASHBOARD_PORT" &
dashboard_pid=$!

terminate() {
  kill "$api_pid" "$dashboard_pid" 2>/dev/null || true
  wait "$api_pid" "$dashboard_pid" 2>/dev/null || true
}

trap terminate INT TERM

set +e
wait -n "$api_pid" "$dashboard_pid"
exit_code=$?
set -e

terminate
exit "$exit_code"
