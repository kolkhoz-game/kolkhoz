#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
back_dir="$repo_root/design/physical-deck/backs"
art_dir="$back_dir/art"
export_dir="$back_dir/exports"
app_dir="$repo_root/app/assets/art/field_plan/cards/backs"

mkdir -p "$export_dir" "$app_dir"

draw_back() {
  local source="$1"
  local stroke="$2"
  local export_path="$3"
  local app_path="$4"

  magick "$source" \
    -fill none -stroke "$stroke" -strokewidth 15 \
    -draw "path 'M176 88 H1460 L1520 148 V2096 L1460 2156 H184 L124 2096 V148 Z'" \
    -strokewidth 9 \
    -draw "path 'M204 116 H1440 L1492 168 V2076 L1440 2128 H204 L152 2076 V168 Z'" \
    -strip -depth 8 "$export_path"

  magick "$export_path" -resize 822x1122! -strip -depth 8 "$app_path"
}

draw_back \
  "$art_dir/card-back-kolkhoz-light-v2.png" \
  '#33434a' \
  "$export_dir/card-back-kolkhoz-light-v2-mpc.png" \
  "$app_dir/card-back-kolkhoz-light-v2.png"

draw_back \
  "$art_dir/card-back-kolkhoz-dark-v2.png" \
  '#f5d19a' \
  "$export_dir/card-back-kolkhoz-dark-v2-mpc.png" \
  "$app_dir/card-back-kolkhoz-dark-v2.png"

