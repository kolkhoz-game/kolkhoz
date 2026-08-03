#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_dir="$(cd "${app_dir}/.." && pwd)"
base_href="${BASE_HREF:-/}"

for command_name in cwebp emcc flutter python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

cd "${app_dir}"
dart run tool/sync_policy_assets.dart

emcc \
  "${repo_dir}/engine/KolkhozCEngine/KolkhozCEngine.c" \
  "${repo_dir}/engine/KolkhozCEngine/KolkhozCEngineAI.c" \
  "${repo_dir}/engine/KolkhozCEngine/KolkhozCEngineManagedEconomyAI.c" \
  "${repo_dir}/engine/KolkhozCEngine/KolkhozCEngineWeb.c" \
  -std=c11 \
  -O3 \
  "-I${repo_dir}/engine/KolkhozCEngine/include" \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=createKolkhozEngine \
  -sENVIRONMENT=web \
  -sALLOW_MEMORY_GROWTH=1 \
  -sFILESYSTEM=0 \
  -sEXPORTED_RUNTIME_METHODS='["ccall"]' \
  -sEXPORTED_FUNCTIONS='["_kc_web_engine_new","_kc_web_engine_clone","_kc_web_engine_free","_kc_web_engine_step_automatic","_kc_web_engine_apply","_kc_web_engine_heuristic_action","_kc_web_selected_action_get","_kc_web_engine_get"]' \
  -o web/kolkhoz_engine.js

flutter pub get
flutter build web \
  --release \
  --no-wasm-dry-run \
  --dart-define=KOLKHOZ_WEB_DEMO=true \
  "--base-href=${base_href}"

python3 tool/optimize_web_demo.py build/web

echo "Web demo ready at ${app_dir}/build/web"
