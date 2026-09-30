# Unified equipment cards — review checkpoint

Base: `5fd7473d81f7340dc7e075c6c51d62e1c8478b4a`.
Implementation: `a3f879a257c3632e97fe89387b7002f87bc07616`.

One persistent equipment component now serves weapons and defence: minimum 310×176 logical size, 64×64 icon, grouped name/level, complete primary value and a centered 246×56 upgrade button. Both categories use the same responsive grid (four columns at 1373×883; two at 960×540). Existing selection, free equip, upgrade, refit, gem, detail and semantic anchors are retained.

The bundled Noto Sans SC variable font is reused: name 23/weight650, level and action 21/weight500, primary value 30/weight650, complete cost including resource 24/weight650. The quantity suffix is part of the same string and shares its size, weight and color. Defence SVGs are original vectors matching the existing cream/navy/cyan weapon palette. No font assets or dependencies were added.

Shared `NumberFormat.compact`, `damage` and large/dictionary `rate` displays use K/M/B/T/Qa/Qi/Sx/Sp/Oc/No, then scientific notation from 1e33, at most three significant digits. Carry occurs before suffix selection. Example: 9.9e19 → 99Qi. This affects all UI callers of those shared display functions, including resource balances and damage text; internal values, purchases, saves, `plain`, `precise` and `GrowthNumber.text` are unchanged.

## Actual Godot evidence

Godot 4.6.3, X11 dummy display, OpenGL Mesa llvmpipe. PNGs are native window captures, without resizing or composite mockups.

- [Initial empty slots, 1373×883](01-initial-slots.png): starter frigate, free equip entry.
- [Heavy hull, ordinary values, 1373×883](02-heavy-normal.png): 8 weapons + 4 defence; 65 iron and 1K armour; first weapon level2 from real upgrade check.
- [Heavy hull, extreme values, 1373×883](03-heavy-large.png): all module levels10000000, displayed stats/costs and resource balances9.9e19 → 99Qi.
- [Narrow window, 960×540](05-narrow-bottom.png): two columns, scroll264 logical units, fourth defence slot selected by pointer input.

49 formatter cases plus dictionary preservation/damage/rate assertions passed. Focused panel fixture: 681 checks, zero failures; includes all five hull capacities, persistent card identities, dormant state rows, bounds/full text, actual pointer free equip/upgrade/refit/x1/x10/MAX/gem/details, scroll access and zero property writes on unchanged refresh. Details: [results](unified-results.json). No broad matrix was run. Test-only injected stats and costs never reach production or player saves.

Reproduce with an isolated copy of `space-battleship` under `test/work`, placing `test/defence_card_layout_check.gd` and `test/test_quantity_format.gd` one directory above it. Import that copy with Godot; set DISPLAY and isolated XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME. Run `godot --audio-driver Dummy --path <copy> --script ../defence_card_layout_check.gd`; formatter runs headless with `../test_quantity_format.gd`. The GUI fixture freezes simulation and disables persistence.

Limits: narrow-window text still inherits the existing whole-game downscale; this change only adapts equipment columns. Godot reported unsupported VSync and one resource/ObjectDB cleanup warning at fixture exit, with exit status0 and no runtime script errors. Library saving failed before upload because its connection was unavailable; these selected files are provided on the independent review branch instead. No main/unified-branch update or battle-code changes.
