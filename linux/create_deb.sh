#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${MIANOTES_BUILD_DIR:-$ROOT_DIR/.build/linux}"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$BUILD_DIR/package"
SOURCE_DIR="$BUILD_DIR/source"
PACKAGE_VERSION="${MIANOTES_PACKAGE_VERSION:-${GITHUB_REF_NAME:-0.1.0}}"
PACKAGE_VERSION="${PACKAGE_VERSION#v}"
if [[ ! "$PACKAGE_VERSION" =~ ^[0-9][A-Za-z0-9.+:~_-]*$ ]]; then
  SAFE_REF="$(echo "$PACKAGE_VERSION" | tr -cs 'A-Za-z0-9.+~-' '-' | sed 's/^-//; s/-$//')"
  PACKAGE_VERSION="0.1.0+${SAFE_REF:-local}"
fi
WEB_SERVICE_REPO="${MIANOTES_WEB_SERVICE_REPO:-https://github.com/Mianotes/mianotes-web-service.git}"
DASHBOARD_REPO="${MIANOTES_DASHBOARD_REPO:-https://github.com/Mianotes/mianotes-dashboard.git}"
WEB_SERVICE_REF="${MIANOTES_WEB_SERVICE_REF:-${MIANOTES_REF:-main}}"
DASHBOARD_REF="${MIANOTES_DASHBOARD_REF:-${MIANOTES_REF:-main}}"

require_command() {
  local name="$1"
  local message="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "$message" >&2
    exit 1
  fi
}

clone_repo() {
  local repo_url="$1"
  local ref="$2"
  local target_dir="$3"

  git clone "$repo_url" "$target_dir"
  git -C "$target_dir" checkout "$ref"
}

copy_tree() {
  local source_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir"
  rsync -a \
    --delete \
    --exclude ".git" \
    --exclude ".github" \
    --exclude ".DS_Store" \
    --exclude "._*" \
    --exclude ".venv" \
    --exclude "node_modules" \
    --exclude "__pycache__" \
    --exclude ".pytest_cache" \
    --exclude ".mypy_cache" \
    --exclude "tests" \
    "$source_dir/" "$target_dir/"
}

require_command git "git is required to build the package."
require_command npm "npm is required to build the dashboard package payload."
require_command rsync "rsync is required to prepare the package payload."
require_command dpkg-deb "dpkg-deb is required to build mianotes.deb."

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$PACKAGE_DIR" "$DIST_DIR"

echo "Cloning source repositories..."
clone_repo "$WEB_SERVICE_REPO" "$WEB_SERVICE_REF" "$SOURCE_DIR/web-service"
clone_repo "$DASHBOARD_REPO" "$DASHBOARD_REF" "$SOURCE_DIR/dashboard"

echo "Building dashboard..."
(
  cd "$SOURCE_DIR/dashboard"
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
  npm run build
)

echo "Preparing Debian package payload..."
APP_ROOT="$PACKAGE_DIR/opt/mianotes"
mkdir -p \
  "$APP_ROOT/bin" \
  "$APP_ROOT/dashboard" \
  "$PACKAGE_DIR/DEBIAN" \
  "$PACKAGE_DIR/etc/mianotes" \
  "$PACKAGE_DIR/lib/systemd/system" \
  "$PACKAGE_DIR/usr/bin" \
  "$PACKAGE_DIR/var/lib/mianotes/data" \
  "$PACKAGE_DIR/var/log/mianotes"

copy_tree "$SOURCE_DIR/web-service" "$APP_ROOT/web-service"
copy_tree "$SOURCE_DIR/dashboard/dist" "$APP_ROOT/dashboard/dist"
copy_tree "$ROOT_DIR/linux/bin" "$APP_ROOT/bin"
cp "$ROOT_DIR/common/bin/dashboard_server.py" "$APP_ROOT/bin/dashboard_server.py"
cp "$ROOT_DIR/linux/bin/mianotes" "$PACKAGE_DIR/usr/bin/mianotes"
cp "$ROOT_DIR/linux/systemd/mianotes-web-service.service" "$PACKAGE_DIR/lib/systemd/system/mianotes-web-service.service"
cp "$ROOT_DIR/linux/systemd/mianotes-dashboard.service" "$PACKAGE_DIR/lib/systemd/system/mianotes-dashboard.service"
cp "$ROOT_DIR/linux/scripts/preinst" "$PACKAGE_DIR/DEBIAN/preinst"
cp "$ROOT_DIR/linux/scripts/postinst" "$PACKAGE_DIR/DEBIAN/postinst"
cp "$ROOT_DIR/linux/scripts/prerm" "$PACKAGE_DIR/DEBIAN/prerm"
cp "$ROOT_DIR/linux/scripts/postrm" "$PACKAGE_DIR/DEBIAN/postrm"

chmod 755 \
  "$APP_ROOT/bin/start-web-service.sh" \
  "$APP_ROOT/bin/start-dashboard.sh" \
  "$APP_ROOT/bin/dashboard_server.py" \
  "$PACKAGE_DIR/usr/bin/mianotes" \
  "$PACKAGE_DIR/DEBIAN/preinst" \
  "$PACKAGE_DIR/DEBIAN/postinst" \
  "$PACKAGE_DIR/DEBIAN/prerm" \
  "$PACKAGE_DIR/DEBIAN/postrm"
chmod 644 "$PACKAGE_DIR/lib/systemd/system/mianotes-web-service.service" "$PACKAGE_DIR/lib/systemd/system/mianotes-dashboard.service"

INSTALLED_SIZE="$(du -sk "$PACKAGE_DIR" | awk '{print $1}')"
cat > "$PACKAGE_DIR/DEBIAN/control" <<CONTROL
Package: mianotes
Version: $PACKAGE_VERSION
Section: web
Priority: optional
Architecture: all
Maintainer: Mianotes <hello@mianotes.local>
Depends: python3 (>= 3.11), python3-venv, python3-pip, ca-certificates, systemd
Installed-Size: $INSTALLED_SIZE
Homepage: https://github.com/Mianotes
Description: Mianotes web service and dashboard
 Mianotes stores notes, links, files, and generated Markdown in a local workspace.
 This package installs the web service and dashboard as systemd services.
CONTROL

echo "Building Debian package..."
dpkg-deb --build --root-owner-group "$PACKAGE_DIR" "$DIST_DIR/mianotes.deb"

echo "Package created:"
echo "  $DIST_DIR/mianotes.deb"
