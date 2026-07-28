#!/usr/bin/env python3
"""Extract centered runtime icons from the generated Field Plan source sheets."""

from __future__ import annotations

import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = REPO_ROOT / "design/field-plan-world/ui-icon-sheets"
OUTPUT_ROOT = REPO_ROOT / "app/assets/art/field_plan"
SOURCE_CELL_SIZE = 362
OUTPUT_SIZE = 256
UNDERLAY_MARGIN = 4
ALPHA_THRESHOLD = 8
EDGE_BLEED = 4


@dataclass(frozen=True)
class Icon:
    name: str
    bounds: tuple[int, int, int, int]
    tight_underlay: bool = False


@dataclass(frozen=True)
class Sheet:
    source: str
    destination: str
    icons: tuple[Icon, ...]
    source_cell_size: int = SOURCE_CELL_SIZE


# The generator did not place subjects on exact mathematical cell boundaries.
# These regions follow the visible gutters and only isolate each subject; the
# final crop is calculated from the subject's alpha bounds and recentered below.
SHEETS = (
    Sheet(
        source="navigation-years-v1-source.png",
        destination="game/ui/navigation",
        icons=(
            Icon("brigade", (0, 0, 380, 370)),
            Icon("jobs", (380, 0, 730, 370)),
            Icon("north", (730, 0, 1080, 370)),
            Icon("game-log", (1080, 0, 1448, 370)),
            Icon("menu", (0, 370, 380, 700)),
            Icon("year-1", (380, 370, 730, 700)),
            Icon("year-2", (730, 370, 1080, 700)),
            Icon("year-3", (1080, 370, 1448, 700)),
            Icon("year-4", (0, 700, 380, 1086)),
            Icon("year-5", (380, 700, 730, 1086)),
            Icon(
                "nav-frame-inactive",
                (730, 700, 1080, 1086),
                tight_underlay=True,
            ),
            Icon(
                "nav-frame-active",
                (1080, 700, 1448, 1086),
                tight_underlay=True,
            ),
        ),
    ),
    Sheet(
        source="resources-actions-v1-source.png",
        destination="game/ui/icons",
        icons=(
            Icon("cellar", (0, 0, 410, 375)),
            Icon("plot", (410, 0, 750, 375)),
            Icon("medal", (750, 0, 1070, 375)),
            Icon("wheat", (1070, 0, 1448, 375)),
            Icon("sunflower", (0, 375, 390, 710)),
            Icon("potato", (390, 375, 750, 710)),
            Icon("beet", (750, 375, 1060, 710)),
            Icon("toolbar-play", (1060, 375, 1448, 710)),
            Icon("toolbar-swap", (0, 710, 390, 1086)),
            Icon("toolbar-confirm", (390, 710, 720, 1086)),
            Icon("toolbar-undo", (720, 710, 1000, 1086)),
            Icon("toolbar-assign", (1000, 710, 1448, 1086)),
        ),
    ),
    Sheet(
        source="social-online-v1-source.png",
        destination="shared/pictograms",
        icons=(
            Icon("profile", (0, 0, 465, 422)),
            Icon("friends-list", (465, 0, 931, 422)),
            Icon("add-friend", (931, 0, 1396, 422)),
            Icon("comrade", (1396, 0, 1862, 422)),
            Icon("online", (0, 422, 465, 845)),
            Icon("status-connecting", (465, 422, 931, 845)),
            Icon("status-connected", (931, 422, 1396, 845)),
            Icon("human-seat", (1396, 422, 1862, 845)),
        ),
        source_cell_size=380,
    ),
    Sheet(
        source="player-controllers-v1-source.png",
        destination="shared/pictograms",
        icons=(
            Icon("controller-hotseat-player", (0, 0, 434, 724)),
            Icon("controller-online-player", (434, 0, 869, 724)),
            Icon("controller-easy-ai", (869, 0, 1303, 724)),
            Icon("controller-medium-ai", (1303, 0, 1738, 724)),
            Icon("controller-hard-ai", (1738, 0, 2172, 724)),
        ),
    ),
    Sheet(
        source="gameplay-status-v1-source.png",
        destination="shared/pictograms",
        icons=(
            Icon("status-current-turn", (0, 0, 537, 488)),
            Icon("status-ai-thinking", (537, 0, 1074, 488)),
            Icon("status-brigade-leader", (1074, 0, 1611, 488)),
            Icon("status-protected", (0, 488, 537, 976)),
            Icon("status-vulnerable", (537, 488, 1074, 976)),
            Icon("turn-timer-clock", (1074, 488, 1611, 976)),
        ),
        source_cell_size=410,
    ),
    Sheet(
        source="game-variants-v2-source.png",
        destination="ledger/variants",
        icons=(
            Icon("variant_nomenclature", (0, 0, 314, 314)),
            Icon("variant_swap_cards", (314, 0, 627, 314)),
            Icon("variant_northern_style", (627, 0, 941, 314)),
            Icon("variant_mice", (941, 0, 1254, 314)),
            Icon("variant_order_to_boss", (0, 314, 314, 627)),
            Icon("variant_medals", (314, 314, 627, 627)),
            Icon("variant_hero", (627, 314, 941, 627)),
            Icon("variant_stakhanovite", (941, 314, 1254, 627)),
            Icon("variant_saboteur", (0, 627, 314, 941)),
            Icon("variant_final_year_trump", (314, 627, 627, 941)),
            Icon("variant_pass_cards", (627, 627, 941, 941)),
            Icon(
                "variant_highest_cards_requisition",
                (941, 627, 1254, 941),
            ),
            Icon("variant_lotto_rewards", (0, 941, 314, 1254)),
        ),
        source_cell_size=310,
    ),
    Sheet(
        source="setup-presets-v2-source.png",
        destination="ledger/presets",
        icons=(
            Icon("preset_kolkhoz", (0, 0, 537, 488)),
            Icon("preset_little_kolkhoz", (537, 0, 1074, 488)),
            Icon("preset_camp_style", (1074, 0, 1612, 488)),
            Icon("preset_custom", (0, 488, 537, 976)),
        ),
        source_cell_size=480,
    ),
    Sheet(
        source="setup-presets-v2-source.png",
        destination="ledger/variants",
        icons=(
            Icon("variant_deck", (537, 488, 1074, 976)),
            Icon("variant_five_year_plan", (1074, 488, 1612, 976)),
        ),
        source_cell_size=480,
    ),
)


def chroma_helper() -> Path:
    codex_root = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    helper = (
        codex_root
        / "skills/.system/imagegen/scripts/remove_chroma_key.py"
    )
    if not helper.is_file():
        raise FileNotFoundError(f"Chroma-removal helper not found: {helper}")
    return helper


def remove_chroma(source: Path, destination: Path) -> None:
    subprocess.run(
        (
            "python3",
            str(chroma_helper()),
            "--input",
            str(source),
            "--out",
            str(destination),
            "--auto-key",
            "border",
            "--soft-matte",
            "--transparent-threshold",
            "12",
            "--opaque-threshold",
            "220",
            "--despill",
        ),
        check=True,
    )


def extract_icon(
    sheet: Image.Image,
    icon: Icon,
    source_cell_size: int,
) -> Image.Image:
    region = sheet.crop(icon.bounds)
    alpha = region.getchannel("A")
    subject = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    subject_bounds = subject.getbbox()
    if subject_bounds is None:
        raise ValueError(f"No painted pixels found for {icon.name}")

    left, top, right, bottom = subject_bounds
    left = max(0, left - EDGE_BLEED)
    top = max(0, top - EDGE_BLEED)
    right = min(region.width, right + EDGE_BLEED)
    bottom = min(region.height, bottom + EDGE_BLEED)
    crop = region.crop((left, top, right, bottom))

    if icon.tight_underlay:
        available = OUTPUT_SIZE - UNDERLAY_MARGIN * 2
        scale = min(available / crop.width, available / crop.height)
        fitted = crop.resize(
            (
                max(1, round(crop.width * scale)),
                max(1, round(crop.height * scale)),
            ),
            Image.Resampling.LANCZOS,
        )
        centered = Image.new(
            "RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0)
        )
        centered.alpha_composite(
            fitted,
            (
                (OUTPUT_SIZE - fitted.width) // 2,
                (OUTPUT_SIZE - fitted.height) // 2,
            ),
        )
        return centered

    if crop.width > source_cell_size or crop.height > source_cell_size:
        raise ValueError(
            f"{icon.name} is {crop.width}x{crop.height}, larger than "
            f"the {source_cell_size}px source canvas"
        )

    centered = Image.new(
        "RGBA", (source_cell_size, source_cell_size), (0, 0, 0, 0)
    )
    offset = (
        (source_cell_size - crop.width) // 2,
        (source_cell_size - crop.height) // 2,
    )
    centered.alpha_composite(crop, offset)
    return centered.resize(
        (OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS
    )


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="kolkhoz-icon-extraction-") as temp:
        temp_root = Path(temp)
        for spec in SHEETS:
            alpha_sheet = temp_root / spec.source
            if not alpha_sheet.exists():
                remove_chroma(SOURCE_ROOT / spec.source, alpha_sheet)
            sheet = Image.open(alpha_sheet).convert("RGBA")
            destination = OUTPUT_ROOT / spec.destination
            destination.mkdir(parents=True, exist_ok=True)

            for icon in spec.icons:
                output = extract_icon(
                    sheet,
                    icon,
                    spec.source_cell_size,
                )
                path = destination / f"{icon.name}.png"
                output.save(path, optimize=True)
                print(path.relative_to(REPO_ROOT))


if __name__ == "__main__":
    main()
