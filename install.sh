#!/usr/bin/env bash
set -euo pipefail

WEB_SERVICE_REPO="${MIANOTES_WEB_SERVICE_REPO:-https://github.com/Mianotes/mianotes-web-service.git}"
DASHBOARD_REPO="${MIANOTES_DASHBOARD_REPO:-https://github.com/Mianotes/mianotes-dashboard.git}"
INSTALL_DIR="${MIANOTES_INSTALL_DIR:-$(pwd)}"
REF="${MIANOTES_REF:-}"
INSTALL_DEV=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Installs Mianotes into the current directory by creating:
  mianotes-web-service/
  mianotes-dashboard/

Options:
  --dir PATH  Install into PATH instead of the current directory.
  --ref REF   Clone a specific branch, tag, or commit for both repos.
  --dev       Ask app installers to include development dependencies.
  -h, --help  Show this help.

Environment overrides:
  MIANOTES_WEB_SERVICE_REPO
  MIANOTES_DASHBOARD_REPO
  MIANOTES_INSTALL_DIR
  MIANOTES_REF
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      if [[ $# -lt 2 ]]; then
        echo "--dir requires a path." >&2
        exit 2
      fi
      INSTALL_DIR="$2"
      shift
      ;;
    --ref)
      if [[ $# -lt 2 ]]; then
        echo "--ref requires a branch, tag, or commit." >&2
        exit 2
      fi
      REF="$2"
      shift
      ;;
    --dev)
      INSTALL_DEV=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_command() {
  local name="$1"
  local message="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "$message" >&2
    exit 1
  fi
}

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"
  local label="$3"

  if [[ -d "$target_dir/.git" ]]; then
    echo "Updating $label..."
    git -C "$target_dir" fetch --tags origin
    if [[ -n "$REF" ]]; then
      git -C "$target_dir" checkout "$REF"
      git -C "$target_dir" pull --ff-only origin "$REF" || true
    else
      git -C "$target_dir" pull --ff-only
    fi
    return
  fi

  if [[ -e "$target_dir" ]]; then
    echo "$target_dir already exists but is not a Git checkout. Move it or choose another --dir." >&2
    exit 1
  fi

  echo "Cloning $label..."
  git clone "$repo_url" "$target_dir"
  if [[ -n "$REF" ]]; then
    git -C "$target_dir" checkout "$REF"
  fi
}

run_app_installer() {
  local app_dir="$1"
  local app_name="$2"
  local script_path="$app_dir/install.sh"

  if [[ ! -f "$script_path" ]]; then
    echo "$app_name does not provide install.sh at $script_path" >&2
    exit 1
  fi

  echo "Installing $app_name..."
  if [[ "$INSTALL_DEV" -eq 1 ]]; then
    bash "$script_path" --dev
  else
    bash "$script_path"
  fi
}

require_command git "Git is required. Install Git, then run the installer again."
require_command bash "Bash is required."

mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"

WEB_SERVICE_DIR="$INSTALL_DIR/mianotes-web-service"
DASHBOARD_DIR="$INSTALL_DIR/mianotes-dashboard"

cat <<START
Installing Mianotes into:
  $INSTALL_DIR

START

clone_or_update "$WEB_SERVICE_REPO" "$WEB_SERVICE_DIR" "Mianotes web service"
clone_or_update "$DASHBOARD_REPO" "$DASHBOARD_DIR" "Mianotes dashboard"

run_app_installer "$WEB_SERVICE_DIR" "Mianotes web service"
run_app_installer "$DASHBOARD_DIR" "Mianotes dashboard"

cat <<NEXT

Mianotes installed.

Installed folders:
  $WEB_SERVICE_DIR
  $DASHBOARD_DIR

Start the web service:
  cd "$WEB_SERVICE_DIR"
  mianotes-web-service init-db
  mianotes-web-service --host 0.0.0.0 --port 8200

Run the dashboard during development:
  cd "$DASHBOARD_DIR"
  npm run dev

Then open:
  http://127.0.0.1:8201
NEXT
