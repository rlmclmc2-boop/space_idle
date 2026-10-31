# Individual-platform city direction

`direction.gd` and `modules.gd` retain the approved static composition: separate 16×16 functional platforms, mixed-level GLBs, headquarters and socket-matched service bridges. Families are interleaved and the outer branches vary in spacing. The shared module implementation retains hull, flange and mount geometry with static mesh baking.

The old `preview.gd`, 30-slot fixture, UI test and isolated preview instructions were removed. This directory has no runnable preview or test entry.

Retained presentation uses `scripts/galaxy_city_layout.gd`, `scripts/galaxy_city_structure.gd` and `scripts/galaxy_city_modules.gd`. It reads current domain nodes and is not connected to the current `src/main.tscn` entry. This document records the visual direction; it does not claim current gameplay, save or performance validation.
