#!/usr/bin/env python3
"""Shrink a generated Flutter web demo without changing native app assets."""

from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
from typing import Any


_STRING = 7
_LIST = 12
_MAP = 13

_OBSOLETE_ASSETS = {
    "assets/art/field_plan/menu-village-day-underlay-v1.png",
    "assets/art/field_plan/menu-village-day-underlay-v2.png",
    "assets/art/field_plan/game/backgrounds/fields-light-v2.png",
    "assets/art/field_plan/game/backgrounds/north-year-1-light.png",
    "assets/art/field_plan/game/backgrounds/north-year-2-light.png",
    "assets/art/field_plan/game/backgrounds/north-year-3-light.png",
    "assets/art/field_plan/game/backgrounds/trick-field-light.png",
    *{
        f"assets/art/field_plan/game/backgrounds/brigade-plot-light-v{version}.png"
        for version in range(2, 11)
    },
}
_REMOVED_PREFIXES = ("assets/policies/",)


class _StandardMessageReader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def read(self) -> Any:
        value_type = self._read_byte()
        if value_type == _STRING:
            size = self._read_size()
            value = self.data[self.offset : self.offset + size].decode("utf-8")
            self.offset += size
            return value
        if value_type == _LIST:
            return [self.read() for _ in range(self._read_size())]
        if value_type == _MAP:
            return {self.read(): self.read() for _ in range(self._read_size())}
        raise ValueError(f"Unsupported manifest value type {value_type}")

    def _read_byte(self) -> int:
        value = self.data[self.offset]
        self.offset += 1
        return value

    def _read_size(self) -> int:
        value = self._read_byte()
        if value == 254:
            size = struct.unpack_from("=H", self.data, self.offset)[0]
            self.offset += 2
            return size
        if value == 255:
            size = struct.unpack_from("=I", self.data, self.offset)[0]
            self.offset += 4
            return size
        return value


def _write_size(output: bytearray, size: int) -> None:
    if size < 254:
        output.append(size)
    elif size <= 0xFFFF:
        output.append(254)
        output.extend(struct.pack("=H", size))
    else:
        output.append(255)
        output.extend(struct.pack("=I", size))


def _write_standard_message(output: bytearray, value: Any) -> None:
    if isinstance(value, str):
        encoded = value.encode("utf-8")
        output.append(_STRING)
        _write_size(output, len(encoded))
        output.extend(encoded)
        return
    if isinstance(value, list):
        output.append(_LIST)
        _write_size(output, len(value))
        for item in value:
            _write_standard_message(output, item)
        return
    if isinstance(value, dict):
        output.append(_MAP)
        _write_size(output, len(value))
        for key, item in value.items():
            _write_standard_message(output, key)
            _write_standard_message(output, item)
        return
    raise TypeError(f"Unsupported manifest value {value!r}")


def _decode_manifest(data: bytes) -> dict[str, Any]:
    reader = _StandardMessageReader(data)
    result = reader.read()
    if reader.offset != len(data):
        raise ValueError("Asset manifest has trailing data")
    if not isinstance(result, dict):
        raise ValueError("Asset manifest root is not a map")
    return result


def _encode_manifest(manifest: dict[str, Any]) -> bytes:
    output = bytearray()
    _write_standard_message(output, manifest)
    return bytes(output)


def _is_removed(asset: str) -> bool:
    return asset in _OBSOLETE_ASSETS or asset.startswith(_REMOVED_PREFIXES)


def _rewrite_manifest_value(value: Any) -> Any:
    if isinstance(value, str):
        return value.removesuffix(".png") + ".webp" if value.endswith(".png") else value
    if isinstance(value, list):
        return [_rewrite_manifest_value(item) for item in value]
    if isinstance(value, dict):
        return {
            _rewrite_manifest_value(key): _rewrite_manifest_value(item)
            for key, item in value.items()
        }
    return value


def _rewrite_asset_manifest(asset_dir: Path) -> dict[str, Any]:
    binary_path = asset_dir / "AssetManifest.bin"
    manifest = _decode_manifest(binary_path.read_bytes())
    rewritten = {
        _rewrite_manifest_value(key): _rewrite_manifest_value(value)
        for key, value in manifest.items()
        if not _is_removed(key)
    }
    encoded = _encode_manifest(rewritten)
    binary_path.write_bytes(encoded)
    (asset_dir / "AssetManifest.bin.json").write_text(
        json.dumps(base64.b64encode(encoded).decode("ascii")) + "\n",
        encoding="utf-8",
    )
    return rewritten


def _convert_png(source: Path) -> tuple[int, int]:
    destination = source.with_suffix(".webp")
    before = source.stat().st_size
    subprocess.run(
        [
            "cwebp",
            "-quiet",
            "-q",
            "82",
            "-alpha_q",
            "100",
            "-m",
            "6",
            "-sharp_yuv",
            str(source),
            "-o",
            str(destination),
        ],
        check=True,
    )
    after = destination.stat().st_size
    source.unlink()
    return before, after


def _rewrite_text_references(path: Path) -> None:
    content = path.read_text(encoding="utf-8")
    rewritten = content.replace(".png", ".webp")
    if rewritten != content:
        path.write_text(rewritten, encoding="utf-8")


def _tree_size(path: Path) -> int:
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def _manifest_asset_paths(value: Any) -> set[str]:
    if isinstance(value, str):
        return {value} if value.startswith("assets/") else set()
    if isinstance(value, list):
        return set().union(*(_manifest_asset_paths(item) for item in value))
    if isinstance(value, dict):
        paths = _manifest_asset_paths(list(value))
        paths.update(_manifest_asset_paths(list(value.values())))
        return paths
    return set()


def _validate_manifest(asset_dir: Path, manifest: dict[str, Any]) -> None:
    missing = [
        asset
        for asset in sorted(_manifest_asset_paths(manifest))
        if not (asset_dir / asset).is_file()
    ]
    if missing:
        preview = "\n".join(f"  {asset}" for asset in missing[:20])
        raise ValueError(f"Optimized manifest references missing assets:\n{preview}")


def optimize_web_demo(web_dir: Path) -> tuple[int, int, int]:
    web_dir = web_dir.resolve()
    asset_dir = web_dir / "assets"
    app_asset_dir = asset_dir / "assets"
    if not (web_dir / "main.dart.js").is_file() or not app_asset_dir.is_dir():
        raise ValueError(f"{web_dir} is not a Flutter web build")

    before = _tree_size(web_dir)

    shutil.rmtree(web_dir / "canvaskit", ignore_errors=True)
    shutil.rmtree(app_asset_dir / "policies", ignore_errors=True)
    for asset in _OBSOLETE_ASSETS:
        (asset_dir / asset).unlink(missing_ok=True)

    png_files = sorted(app_asset_dir.rglob("*.png"))
    workers = min(8, os.cpu_count() or 1)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        converted = list(pool.map(_convert_png, png_files))

    _rewrite_text_references(web_dir / "main.dart.js")
    for path in app_asset_dir.rglob("*.json"):
        _rewrite_text_references(path)

    manifest = _rewrite_asset_manifest(asset_dir)
    _validate_manifest(asset_dir, manifest)

    stale_pngs = list(app_asset_dir.rglob("*.png"))
    if stale_pngs:
        raise ValueError(f"PNG conversion left {len(stale_pngs)} files behind")
    if ".png" in (web_dir / "main.dart.js").read_text(encoding="utf-8"):
        raise ValueError("Compiled application still contains PNG asset references")

    after = _tree_size(web_dir)
    png_before = sum(item[0] for item in converted)
    webp_after = sum(item[1] for item in converted)
    print(
        f"Optimized {len(converted)} PNG assets: "
        f"{png_before / 1048576:.1f} MiB -> {webp_after / 1048576:.1f} MiB"
    )
    print(f"Web demo: {before / 1048576:.1f} MiB -> {after / 1048576:.1f} MiB")
    return before, after, len(converted)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("web_dir", type=Path)
    args = parser.parse_args()
    try:
        optimize_web_demo(args.web_dir)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"Web demo optimization failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
