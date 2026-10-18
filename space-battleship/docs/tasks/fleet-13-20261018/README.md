# Approved fleet 13 integration

Base: main `51a7e1b9bc5784927e7d5b232a112194d990a41c`. Reference: `art/approved-fleet-reference-20261018@96332dd117c7661a6439fb546af35b5d8dd668fe`. Only the thirteen source-file blobs were read from that commit. The transferred Base64 is absent from this production branch.

The production change is 13 new 887x1774 true-alpha battle hull PNGs, five new 768x768 UI preview PNGs, 13 `texture` path changes in `data/ship_weapon_visuals.json`, and five `texture` path changes in `assets/ui/ships/manifest.json`. The only coordinate changes are two **preview-only** `Heavy_Battleship` mount centers, from approximately `(192,322)` and `(576,322)` to `(300,280)` and `(468,280)`. This preserves the five existing slot IDs and puts both markers on the approved narrow hull. No gameplay configuration, battle logic, native source, DLL, UI layout, or size fallback art changed.

## Asset validation

`normalize_fleet.gd` reads thirteen separately generated source images from `FLEET_SOURCE_DIR`, uses their visible alpha bounds, and scales them uniformly into transparent canvases. `normalization.json` records source and output bounds. It asserts no distortion beyond pixel rounding, a nonempty body, alpha-zero corners, and safe output margins. `validate_fleet.gd` parsed both mappings, loaded all eighteen target PNGs, checked canvas dimensions and sampled every existing battle hardpoint and UI preview mount: **zero missed hulls** after the two preview marker changes. The original inspection, normalization, and validation logs are in `evidence/validation/`; the generation commit is the reproducible original source.

## Real scene evidence

The identical `capture_fleet.gd` script ran once on the unchanged base and once on this candidate with the same existing main51 DLL (SHA-256 `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`). It captured five real stage 1–3 encounters covering all eight archetype keys and the ship selection UI covering all five player hulls. Original 1398x900 PNGs and logs are in `evidence/before/` and `evidence/after/`. Both runs ended `FLEET_CAPTURE_DONE 6`, reported speed 1 and native presentation, and had no script error.

| Scene | Archetypes | Draw calls before → after |
| --- | --- | ---: |
| Stage 1 scout/sentry | scout, sentry | 150 → 150 |
| Stage 2 swarm/interceptor | swarm, interceptor | 235 → 235 |
| Stage 2 swarm/anchor | swarm, anchor | 273 → 273 |
| Stage 3 reactive/shielded | reactive, shielded | 172 → 172 |
| Stage 3 command/shielded | command, shielded | 162 → 162 |

The displayed GPU texture-memory reading was `375,340,808` bytes before and `375,340,936` bytes after (+128 bytes) in each sampled scene. The replacement textures keep their predecessor canvas sizes and rendering path. The thirteen mapped battle PNGs total 10,728,128 compressed bytes before and 10,077,232 after; the five UI PNGs total 358,163 before and 2,042,170 after. These are resource and draw-call checks, **not** a frame-time benchmark; the same one-frame capture does not establish FPS.

## Remaining review point

At the full battle viewport, enemy hulls remain small under the existing actor width and combat footprint, making fine art differences difficult to see. This batch does not change visual actor scale or combat geometry. The parent should review the unaltered before/after captures before any separate display-scale decision or main merge.
