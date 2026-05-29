#!/usr/bin/env bash

mianotes_runtime_arch() {
  case "$(uname -m)" in
    arm64)
      echo "darwin-arm64"
      ;;
    x86_64)
      echo "darwin-x64"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

mianotes_runtime_dir() {
  local app_root="$1"
  local arch

  arch="$(mianotes_runtime_arch)"
  if [[ "$arch" == "unsupported" ]]; then
    return 1
  fi

  echo "$app_root/runtime/$arch"
}

mianotes_runtime_python() {
  local app_root="$1"
  local runtime_dir

  runtime_dir="$(mianotes_runtime_dir "$app_root")" || return 1
  echo "$runtime_dir/python/bin/python3"
}

mianotes_export_runtime() {
  local app_root="$1"
  local runtime_dir

  runtime_dir="$(mianotes_runtime_dir "$app_root")" || return 0

  if [[ -d "$runtime_dir/bin" ]]; then
    export PATH="$runtime_dir/bin:$PATH"
  fi

  if [[ -d "$runtime_dir/share/tessdata" ]]; then
    export TESSDATA_PREFIX="$runtime_dir/share/tessdata"
  fi
}
