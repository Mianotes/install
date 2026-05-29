#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_FILE="${MIANOTES_RUNTIME_LOCK_FILE:-$ROOT_DIR/macos/runtime/dependencies.lock}"
BUILD_DIR="${MIANOTES_BUILD_DIR:-$ROOT_DIR/.build/macos}"
DOWNLOAD_DIR="$BUILD_DIR/runtime-downloads"
RUNTIME_DIR="$BUILD_DIR/runtime"

require_command() {
  local name="$1"
  local message="$2"

  if ! command -v "$name" >/dev/null 2>&1; then
    echo "$message" >&2
    exit 1
  fi
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "shasum or sha256sum is required to verify runtime downloads." >&2
    exit 1
  fi
}

download_asset() {
  local url="$1"
  local sha256="$2"
  local output="$3"
  local actual

  if [[ ! -f "$output" ]]; then
    curl -fL "$url" -o "$output"
  fi

  actual="$(sha256_file "$output")"
  if [[ "$actual" != "$sha256" ]]; then
    echo "Checksum mismatch for $output" >&2
    echo "Expected: $sha256" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

copy_python_runtime() {
  local archive="$1"
  local destination="$2"
  local temp_dir="$3"
  local python_root

  mkdir -p "$temp_dir" "$destination"
  tar -xzf "$archive" -C "$temp_dir"

  if [[ -e "$temp_dir/python/bin/python3" ]]; then
    python_root="$temp_dir/python"
  else
    python_root="$(find "$temp_dir" -path "*/bin/python3" -print -quit)"
    if [[ -n "$python_root" ]]; then
      python_root="$(cd "$(dirname "$python_root")/.." && pwd -P)"
    fi
  fi

  if [[ -z "${python_root:-}" ]]; then
    echo "Could not find python3 in $archive" >&2
    exit 1
  fi

  rsync -a --delete "$python_root/" "$destination/"
}

copy_tar_binary() {
  local archive="$1"
  local binary_name="$2"
  local destination="$3"
  local temp_dir="$4"
  local binary_path

  mkdir -p "$temp_dir" "$destination"
  tar -xzf "$archive" -C "$temp_dir"

  binary_path="$(find "$temp_dir" -type f -name "$binary_name" -perm -111 -print -quit)"
  if [[ -z "$binary_path" ]]; then
    echo "Could not find $binary_name in $archive" >&2
    exit 1
  fi

  cp "$binary_path" "$destination/$binary_name"
  chmod 755 "$destination/$binary_name"
}

copy_zip_binary() {
  local archive="$1"
  local binary_name="$2"
  local destination="$3"
  local temp_dir="$4"
  local binary_path

  mkdir -p "$temp_dir" "$destination"
  unzip -q "$archive" -d "$temp_dir"

  binary_path="$(find "$temp_dir" -type f -name "$binary_name" -print -quit)"
  if [[ -z "$binary_path" ]]; then
    echo "Could not find $binary_name in $archive" >&2
    exit 1
  fi

  cp "$binary_path" "$destination/$binary_name"
  chmod 755 "$destination/$binary_name"
}

copy_tesseract_wheel() {
  local archive="$1"
  local destination="$2"
  local temp_dir="$3"
  local data_dir

  mkdir -p "$temp_dir" "$destination/bin" "$destination/share"
  unzip -q "$archive" -d "$temp_dir"

  data_dir="$temp_dir/tesseract_bin/data"
  if [[ ! -x "$data_dir/bin/tesseract" ]]; then
    echo "Could not find tesseract binary in $archive" >&2
    exit 1
  fi

  rsync -a "$data_dir/bin/" "$destination/bin/"
  rsync -a "$data_dir/share/" "$destination/share/"
  chmod 755 "$destination/bin/tesseract"
}

require_command curl "curl is required to download macOS runtime dependencies."
require_command rsync "rsync is required to prepare macOS runtime dependencies."
require_command tar "tar is required to extract macOS runtime dependencies."
require_command unzip "unzip is required to extract macOS runtime dependencies."

rm -rf "$RUNTIME_DIR"
mkdir -p "$DOWNLOAD_DIR" "$RUNTIME_DIR"

while IFS='|' read -r type arch name url sha256 license source; do
  if [[ -z "${type:-}" || "$type" == \#* ]]; then
    continue
  fi

  asset_name="${url##*/}"
  asset_path="$DOWNLOAD_DIR/$arch-$name-${asset_name//%2B/+}"
  temp_dir="$BUILD_DIR/runtime-extract/$arch/$name"
  arch_dir="$RUNTIME_DIR/$arch"

  echo "Fetching $name for $arch..."
  rm -rf "$temp_dir"
  download_asset "$url" "$sha256" "$asset_path"

  case "$type" in
    python)
      copy_python_runtime "$asset_path" "$arch_dir/python" "$temp_dir"
      ;;
    tool-tar-bin)
      copy_tar_binary "$asset_path" "$name" "$arch_dir/bin" "$temp_dir"
      ;;
    tool-zip-bin)
      copy_zip_binary "$asset_path" "$name" "$arch_dir/bin" "$temp_dir"
      ;;
    tool-wheel-tesseract)
      copy_tesseract_wheel "$asset_path" "$arch_dir" "$temp_dir"
      ;;
    *)
      echo "Unknown runtime dependency type: $type" >&2
      exit 1
      ;;
  esac

  mkdir -p "$arch_dir/licenses"
  cat > "$arch_dir/licenses/$name.txt" <<LICENSE
Name: $name
Architecture: $arch
License: $license
Source: $source
URL: $url
SHA256: $sha256
LICENSE
done < "$LOCK_FILE"

find "$RUNTIME_DIR" -type f -perm -111 -print0 | xargs -0 chmod 755

echo "Runtime prepared at:"
echo "  $RUNTIME_DIR"
