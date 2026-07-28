# Field-plan gameplay icon sheets

These source sheets were generated with the built-in image-generation tool on
2026-07-27. Runtime icons are chroma-keyed, cropped from their actual painted
bounds, centered on a `362 x 362` transparent canvas, and resized to `256 x 256`
under `app/assets/art/field_plan/game/ui/`.

Regenerate them from the repository root with:

```bash
python3 app/tool/extract_field_plan_icon_sheets.py
```

Do not divide the `1448 x 1086` sheets into equal cells. The generated subjects
cross those mathematical boundaries even though they visually form a `4 x 3`
layout; equal-cell slicing clips and offsets several icons.

## Shared prompt

Create an exact `4 x 3` sprite sheet of isolated, centered production game UI
pictograms. Match the existing field-plan pictograms: restrained Soviet
agricultural print, flat hand-inked lithography, solid color blocks, slightly
imperfect registration, subtle paper texture inside subjects, and thick
charcoal outlines. Use charcoal `#20221d`, cream `#e2ce9a`, brick red
`#a33a28`, mustard `#c08a27`, faded blue `#496b73`, and muted olive
`#70805b`. Keep every icon legible at `28-48 px`. Use a perfectly flat
`#ff00ff` chroma-key background with equal cells and gutters. No labels,
captions, gradients, shadows outside subjects, pixels, photorealism, glossy
rendering, modern UI styling, watermarks, or extra objects.

Style references:

- `app/assets/art/field_plan/shared/pictograms/create-game.png`
- `app/assets/art/field_plan/shared/pictograms/how-to-play.png`
- `app/assets/art/field_plan/shared/pictograms/settings.png`
- `app/assets/art/field_plan/cards/suits/suit-wheat.png`

## `navigation-years-v1-source.png`

Reading order:

1. Brigade
2. Jobs
3. North
4. Game log
5. Menu
6. Year 1
7. Year 2
8. Year 3
9. Year 4
10. Year 5
11. Inactive navigation frame
12. Active navigation frame

The five year badges use the same five-point plan badge, changing only the
large numeral. The inactive and active frames are empty square-corner paper
plaques with matching rectangular geometry and double ink keylines. Their
regenerated paired source is `button-underlays-square-v1-source.png`; the
neutral and primary fills differ, but every border turns through the same true
90-degree corners so the frames remain registered when state changes or the
nine-slice painter stretches them. Unlike the pictograms, these two underlays
are cropped tightly to their painted bounds and centered with equal transparent
margins before their `32 px` nine-slice guides are applied.

## `resources-actions-v1-source.png`

Reading order:

1. Cellar
2. Plot
3. Medal
4. Wheat
5. Sunflower
6. Potato
7. Beet
8. Play
9. Swap
10. Confirm
11. Undo
12. Assign

The crop icons use distinct silhouettes. The action icons use cream cards,
brick-red direction arrows, and minimal compositions that remain readable at
phone toolbar size.

## `social-online-v1-source.png`

Reading order:

1. Profile
2. Friends list
3. Add friend
4. Comrade
5. Online
6. Connecting
7. Connected
8. Human seat

This `4 x 2` sheet replaces the shared multiplayer and social pixel-art
pictograms. The connecting state has an incomplete one-sided broadcast, while
the connected state has complete signals on both sides so they remain
distinguishable at toolbar size.

## `player-controllers-v1-source.png`

Reading order:

1. Hot-seat player
2. Online player
3. Easy AI
4. Medium AI
5. Hard AI

The human controller modes use cards and a broadcast globe. The three AI
difficulties use distinct farm-worker portraits and increasingly full wheat
sheaves, preserving the original controller chooser's quick visual progression.

## `gameplay-status-v1-source.png`

Reading order:

1. Current turn
2. AI thinking
3. Brigade leader
4. Protected
5. Vulnerable
6. Turn timer

These badges favor bold silhouettes at `20-40 px`. Protected and vulnerable
use intact and cracked shields; the timer uses a round stopwatch so it cannot
be confused with the old calendar-like pixel icon.

## `game-variants-v2-source.png`

Reading order:

1. Nomenklatura
2. Swap cards
3. Northern style
4. Mice
5. Order to the boss
6. Medals
7. Hero
8. Common pot
9. Saboteur
10. Final-year trump
11. Pass cards
12. Highest-card requisition
13. Lotto rewards

The remaining three cells in the `4 x 4` sheet are intentionally empty. This
sheet replaces both the older pixel icons and the first-generation ledger
illustrations so every variant row shares one line weight, palette, texture,
and visual scale.

## `setup-presets-v2-source.png`

Reading order:

1. Kolkhoz preset
2. Little Kolkhoz preset
3. Camp-style preset
4. Custom preset
5. Card deck
6. Year plan

These replace the older miniature ledger illustrations with the same bold,
flat field-art treatment as the complete variant family.
