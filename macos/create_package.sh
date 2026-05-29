#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${MIANOTES_BUILD_DIR:-$ROOT_DIR/.build/macos}"
DIST_DIR="$ROOT_DIR/dist"
PAYLOAD_DIR="$BUILD_DIR/payload"
SOURCE_DIR="$BUILD_DIR/source"
PACKAGE_VERSION="${MIANOTES_PACKAGE_VERSION:-${GITHUB_REF_NAME:-0.1.0}}"
PACKAGE_VERSION="${PACKAGE_VERSION#v}"
if [[ ! "$PACKAGE_VERSION" =~ ^[0-9][A-Za-z0-9.+_-]*$ ]]; then
  PACKAGE_VERSION="0.1.0"
fi
WEB_SERVICE_REPO="${MIANOTES_WEB_SERVICE_REPO:-https://github.com/Mianotes/mianotes-web-service.git}"
DASHBOARD_REPO="${MIANOTES_DASHBOARD_REPO:-https://github.com/Mianotes/mianotes-dashboard.git}"
WEB_SERVICE_REF="${MIANOTES_WEB_SERVICE_REF:-${MIANOTES_REF:-main}}"
DASHBOARD_REF="${MIANOTES_DASHBOARD_REF:-${MIANOTES_REF:-main}}"

find_npm() {
  if command -v npm >/dev/null 2>&1; then
    command -v npm
    return
  fi

  echo "npm is required to build the dashboard package payload." >&2
  exit 1
}

prepare_runtime() {
  if [[ "${MIANOTES_SKIP_MACOS_RUNTIME:-0}" == "1" ]]; then
    echo "Skipping bundled macOS runtime."
    return
  fi

  "$ROOT_DIR/macos/runtime/fetch_runtime.sh"
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

clean_payload_metadata() {
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$PAYLOAD_DIR" || true
  fi

  if command -v dot_clean >/dev/null 2>&1; then
    dot_clean -m "$PAYLOAD_DIR" || true
  fi

  find "$PAYLOAD_DIR" -name "._*" -type f -delete
}

sign_runtime_payload() {
  local identity="${CODESIGN_IDENTITY:-}"
  local keychain="${CODESIGN_KEYCHAIN:-}"

  if [[ -z "$identity" ]]; then
    echo "Skipping bundled runtime code signing; CODESIGN_IDENTITY is not set."
    return
  fi

  if ! command -v codesign >/dev/null 2>&1; then
    echo "codesign is required when CODESIGN_IDENTITY is set." >&2
    exit 1
  fi

  if [[ ! -d "$APP_ROOT/runtime" ]]; then
    return
  fi

  echo "Signing bundled runtime binaries..."
  while IFS= read -r path; do
    if file "$path" | grep -q "Mach-O"; then
      if [[ -n "$keychain" ]]; then
        codesign --force --timestamp --options runtime --keychain "$keychain" --sign "$identity" "$path"
      else
        codesign --force --timestamp --options runtime --sign "$identity" "$path"
      fi
    fi
  done < <(find "$APP_ROOT/runtime" -type f | sort -r)
}

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$PAYLOAD_DIR" "$DIST_DIR"

echo "Cloning source repositories..."
clone_repo "$WEB_SERVICE_REPO" "$WEB_SERVICE_REF" "$SOURCE_DIR/web-service"
clone_repo "$DASHBOARD_REPO" "$DASHBOARD_REF" "$SOURCE_DIR/dashboard"

echo "Building dashboard..."
NPM_BIN="$(find_npm)"
(
  cd "$SOURCE_DIR/dashboard"
  if [[ -f package-lock.json ]]; then
    "$NPM_BIN" ci
  else
    "$NPM_BIN" install
  fi
  "$NPM_BIN" run build
)

echo "Preparing bundled runtime..."
prepare_runtime

echo "Preparing package payload..."
APP_ROOT="$PAYLOAD_DIR/Library/Application Support/Mianotes"
mkdir -p "$APP_ROOT/bin" "$APP_ROOT/dashboard" "$PAYLOAD_DIR/Library/LaunchDaemons" "$PAYLOAD_DIR/usr/local/bin"

copy_tree "$SOURCE_DIR/web-service" "$APP_ROOT/web-service"
copy_tree "$SOURCE_DIR/dashboard/dist" "$APP_ROOT/dashboard/dist"
copy_tree "$ROOT_DIR/macos/bin" "$APP_ROOT/bin"
if [[ -d "$BUILD_DIR/runtime" ]]; then
  copy_tree "$BUILD_DIR/runtime" "$APP_ROOT/runtime"
fi
cp "$ROOT_DIR/common/bin/dashboard_server.py" "$APP_ROOT/bin/dashboard_server.py"
cp "$ROOT_DIR/macos/bin/mianotes" "$PAYLOAD_DIR/usr/local/bin/mianotes"
cp "$ROOT_DIR/macos/launchd/com.mianotes.web-service.plist" "$PAYLOAD_DIR/Library/LaunchDaemons/com.mianotes.web-service.plist"
cp "$ROOT_DIR/macos/launchd/com.mianotes.dashboard.plist" "$PAYLOAD_DIR/Library/LaunchDaemons/com.mianotes.dashboard.plist"

chmod 755 "$APP_ROOT/bin/start-web-service.sh" "$APP_ROOT/bin/start-dashboard.sh" "$APP_ROOT/bin/runtime-env.sh" "$APP_ROOT/bin/dashboard_server.py" "$PAYLOAD_DIR/usr/local/bin/mianotes"
chmod 644 "$PAYLOAD_DIR/Library/LaunchDaemons/com.mianotes.web-service.plist" "$PAYLOAD_DIR/Library/LaunchDaemons/com.mianotes.dashboard.plist"
sign_runtime_payload
clean_payload_metadata

echo "Building package..."
pkgbuild \
  --identifier "com.mianotes.installer" \
  --version "$PACKAGE_VERSION" \
  --root "$PAYLOAD_DIR" \
  --install-location "/" \
  --scripts "$ROOT_DIR/macos/scripts" \
  --filter '(^|/)\._[^/]+$' \
  --filter '(^|/)\.DS_Store$' \
  --filter '(^|/)\.svn($|/)' \
  --filter '(^|/)CVS($|/)' \
  "$DIST_DIR/mianotes.pkg"

echo "Package created:"
echo "  $DIST_DIR/mianotes.pkg"
