# AI工厂：单个炼铁工位卡通原型

`iron-workstation-cartoon-v1.png` is one iterated OpenAI built-in imagegen sprite, matching the accepted cream/navy/teal equipment and friendly hull language while retaining an amber iron identity. No text, UI, drone, spark, floor or ground shadow is baked into it. Source/prompt provenance is beside the asset; discarded iterations stay outside the project.

The original `../orbital-atlas.png` is preserved. Only the iron profile selects this single sprite (grid 1×1, cell 0×0); the other three machines retain their old atlas and byte-identical source-derived assembly maps. The drawing footprint stays 296×296 logical pixels inside the existing bay, with the same top-left origin, clickable parent area, 23 assembly stages, shader progress, worker movement, pause/hide policy and identity-free locked placeholder.

The cream plating requires an iron-only `furnace_cartoon` mask recipe: component zones keep the existing furnace locations; final ignition accepts warm highlights rather than bright cream material. An opt-in `warm_energy_only` shader uniform likewise keeps cream plates out of energy pulses. Defaults preserve every other machine's rendering; unregistered art keeps its previous legacy furnace fallback. No research values, AI formulas, configuration, or save fields change.

## Cost and transparency

- Source: 1254×1254 RGBA PNG, 1,115,876 bytes; original generated alpha preserved
- Import: max dimension 640, no mipmaps; decoded RGBA 1,638,400 bytes (1.5625 MiB), measured imported texture file 307,508 bytes
- Existing 4-cell atlas remains resident for the other machines; these costs are additive, not savings
- One additional cached texture/readback at first setup; the existing four 192×192 order maps retain their size. An unregistered-art row lazily adds one bounded legacy-fallback map only when needed. No new runtime viewport or decorative animation
- Structural alpha>8 bounds: (140,123)–(1114,1171), leaving roughly 11% horizontal, 10% top and 6.6% bottom margins. All corner pixels are fully transparent; chamber gaps are transparent
- The generator left a few alpha≤8 stray pixels farther out (any-alpha bounds (23,21)–(1218,1214)). A requested strictly empty 7% outer strip was not fully achieved; no manual alpha cleanup is claimed

This is a review prototype. It does not replace the full machinery set or the photographic hall. Actual-size native comparison and mask-contract evidence belong in the isolated test workspace, not the shipped asset directory. Expand only after this one machine is reviewed.
