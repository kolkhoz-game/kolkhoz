# Physical Deck Card Backs

The `art/` images are borderless, full-bleed 1644 x 2244 masters. The light
and dark files share one composition and use fresh 1930s color-lithograph
colorways rather than an artificially aged treatment.

Both masters reserve a quiet expendable perimeter of sky and repeating field
rows for bleed and cutting variance. Workers, buildings, the title, and the
four crop emblems sit inside the programmatic frame instead of running
through it. The crop emblems use the same simplified artwork language as the
card-front suit symbols. Flat green negative space isolates each emblem from
the surrounding rows. Four field workers echo the deck's Jack, Queen, King,
and Saboteur roles; the Saboteur is the dark-coated figure pocketing crops.

Run:

```bash
design/physical-deck/backs/render_card_backs.sh
```

The renderer owns the same double octagonal frame geometry used by the card
fronts. It writes full-resolution print files to `exports/` and 822 x 1122 app
assets to `app/assets/art/field_plan/cards/backs/`.

## Generation prompts

The light master used the previous Kolkhoz back as its composition reference
and `design/physical-deck/palette/references/canonical-poster-reference.png` as
its style and color reference. It requested a borderless, full-bleed collective
farm scene with converging fields, grain elevators, workers, the four
crop symbols, and the exact `KOLKHOZ` placard. Its title uses the canonical
poster red `#E13212`. The treatment specified fresh
vermilion, ochre, chartreuse, slate, black, and cream lithographic inks with
clean flat spot-color fills and only minimal ink tooth. It explicitly excluded
repeating ornamental paper texture, fading, stains, sepia, exterior frames,
and heavy distress. The field rows use crisp, repeated leaf and grain marks
with hard edges and clean perspective tapering, avoiding fuzzy fern-like
texture or soft haze.

The dark master was re-illustrated as a true nighttime companion rather than
darkened from the daytime art. It preserves the composition and exact title,
but adds a moon and sparse stars, lit windows, nocturnal field rows, and
intentional moonlit workers. The dark-coated Saboteur hides his crop bundle
among the working figures. Its dominant ground uses the card
front's `#171b1a`, with `#f5d19a` cream, vermilion, ochre, olive, and small
slate-blue accents. The title placard also uses `#171b1a` rather than the light
parchment field, retaining canonical poster red `#E13212` as a separate ink.
It explicitly
excludes all-over dark overlays,
desaturation, monochrome tinting, fading, and photographic day-for-night
treatment.
