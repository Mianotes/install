#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/mianotes"
DASHBOARD_DIR="$APP_ROOT/dashboard/dist"

exec "$APP_ROOT/.venv/bin/python" \
  -m http.server 8201 \
  --bind 0.0.0.0 \
  --directory "$DASHBOARD_DIR"
