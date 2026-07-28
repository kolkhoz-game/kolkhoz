# Field-Plan Gameplay Background

`brigade-plot-light.png` is the light-mode environmental plate for the combined brigade
and plot area. It is a 1672 x 941 RGB landscape asset because it must retain detail
across the full gameplay surface.

The plate contains four farmsteads around a central crossroads, connecting roads,
distant fields, farm infrastructure, equipment, and utilities. Flutter overlays cards,
player identity, cellar and plot state, controls, and all live text.

The composition targets the full 16:9 board. The central crossroads is reserved for
live trick cards. The fenced farmsteads carry each player's identity, cellar, and
revealed plot state.

Run `python3 tool/field_plan_calibration_overlay.py --serve` from `app/`, then choose
**Brigade / plots** to position each player's portrait, name, plot cards, and cellar
count; the four crop job signs; the crossroads cards; or the planning panel directly
on this plate. The editor retains changes in the browser and emits plate-pixel Dart
constants for `lib/src/board/brigade_panel.dart`.

`fields-light.png` is the working-fields layer directly above the farmstead view. A
vertical swipe up transitions to its four crop fields; swiping down returns to the
brigade and plots.

`north-light.png` is the North layer above the fields. A second upward swipe reveals
the barracks and the five-year exile archive; downward swipes retrace the route through
the fields to the brigade and plots.

## Static-hero day/night plates

The production game panels use registered 1920 x 800 static-hero plates:

- `static-hero-brigade-underlay-v1.png` and
  `static-hero-brigade-underlay-night-v1.png`
- `static-hero-fields-underlay-v1.png` and
  `static-hero-fields-underlay-night-v1.png`
- `static-hero-north-underlay-v1.png` and
  `static-hero-north-underlay-night-v1.png`

The night companions were produced with the built-in image editor on 2026-07-28 using
the matching day plate as strict composition authority. The edit changed only
time-of-day, illumination, and palette: moonlit indigo/blue-gray terrain, restrained
amber practical lights, and preserved aged-lithograph texture. Geometry, crop,
perspective, field boundaries, structures, route elements, and overlay-safe regions
remain registered to the day plates. The generated 1942 x 809 outputs were normalized
to the locked 1920 x 800 runtime registration.
