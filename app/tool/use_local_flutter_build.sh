#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
build_link="$app_dir/build"
local_root="${KOLKHOZ_FLUTTER_BUILD_DIR:-${HOME}/Library/Caches/kolkhoz/flutter-build}"

case "$local_root" in
  *"/Library/CloudStorage/Dropbox/"*)
    echo "Refusing Dropbox build output path: $local_root" >&2
    exit 1
    ;;
esac

mkdir -p "$local_root"

if [ -L "$build_link" ]; then
  current_target=$(readlink "$build_link")
  if [ "$current_target" = "$local_root" ]; then
    echo "Flutter build output is already local: $local_root"
    exit 0
  fi
  unlink "$build_link"
elif [ -e "$build_link" ]; then
  timestamp=$(date +%Y%m%d-%H%M%S)
  quarantine_path="$app_dir/build.dropbox-stale-$timestamp"
  mv "$build_link" "$quarantine_path"
  echo "Moved Dropbox build output aside: $quarantine_path"
fi

ln -s "$local_root" "$build_link"
echo "Flutter build output linked to: $local_root"
