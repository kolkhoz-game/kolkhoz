import base64
import json
from pathlib import Path
import tempfile
import unittest

import optimize_web_demo


class OptimizeWebDemoTest(unittest.TestCase):
    def test_standard_message_codec_round_trip(self) -> None:
        manifest = {
            "assets/example.png": {
                "asset": "assets/example.png",
                "variants": ["assets/2.0x/example.png"],
            }
        }

        encoded = optimize_web_demo._encode_manifest(manifest)

        self.assertEqual(optimize_web_demo._decode_manifest(encoded), manifest)

    def test_rewrites_and_prunes_asset_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            asset_dir = Path(temporary_directory)
            manifest = {
                "assets/example.png": {"asset": "assets/example.png"},
                "assets/policies/model.json": {
                    "asset": "assets/policies/model.json"
                },
                "assets/art/field_plan/menu-village-day-underlay-v1.png": {
                    "asset": (
                        "assets/art/field_plan/"
                        "menu-village-day-underlay-v1.png"
                    )
                },
            }
            encoded = optimize_web_demo._encode_manifest(manifest)
            (asset_dir / "AssetManifest.bin").write_bytes(encoded)

            rewritten = optimize_web_demo._rewrite_asset_manifest(asset_dir)

            self.assertEqual(
                rewritten,
                {"assets/example.webp": {"asset": "assets/example.webp"}},
            )
            json_encoded = json.loads(
                (asset_dir / "AssetManifest.bin.json").read_text()
            )
            self.assertEqual(
                base64.b64decode(json_encoded),
                (asset_dir / "AssetManifest.bin").read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
