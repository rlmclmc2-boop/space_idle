# Approved fleet 13 integration

## Final battle display correction (2026-10-18)

The first capture exposed a separate live 3D player hull path. `presented_ship_view.gd` now keeps its imported assembly and weapon sockets, hides only the old hull meshes, and displays the approved player PNG on a textured plane in the existing ship viewport. A later inspection found that the retained enemy contact renderer has its own weapon-size floor, so the earlier change to the fallback weapon painter alone did not fix the visible turrets. The retained renderer now uses a one-screen-pixel floor while retaining the same muzzle anchor. The eight enemy PNGs and their normalization recipe were restored byte-for-byte to the approved `292c095a` batch: enlarging their alpha footprint also changed the texture-derived recognition geometry and failed the same-event performance gate. No combat, collision, native source or DLL change was made.

The final [review index](REVIEW_INDEX.md) links ten live battle screenshots: all five player hulls plus five enemy combinations. `evidence/final-review-capture.log` records `FLEET_CAPTURE_DONE 11`, five approved player texture paths, no same-hull rebuild, and retained weapon mouth agreement at every sampled mount. `validate_fleet.gd` reported 18 assets and zero hardpoint failures. `evidence/corrected/` is an earlier, superseded capture. The earlier description of opaque rectangular backgrounds in source art was mistaken: sampled corner and top-edge alpha is zero, and a single black pixel near the hull bow does not establish a background rectangle. No source-art background removal was done.

Base: main `51a7e1b9bc5784927e7d5b232a112194d990a41c`. Reference: `art/approved-fleet-reference-20261018@96332dd117c7661a6439fb546af35b5d8dd668fe`. Only the thirteen source-file blobs were read from that commit. The transferred Base64 is absent from this production branch.

The asset batch comprises 13 new 887x1774 true-alpha battle hull PNGs, five new 768x768 UI preview PNGs, 13 `texture` path changes in `data/ship_weapon_visuals.json`, and five `texture` path changes in `assets/ui/ships/manifest.json`. The only coordinate changes are two **preview-only** `Heavy_Battleship` mount centers, from approximately `(192,322)` and `(576,322)` to `(300,280)` and `(468,280)`. This preserves the five existing slot IDs and puts both markers on the approved narrow hull. The later battle display correction changes GDScript presentation only.

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

At the full battle viewport, enemy hulls remain small under the existing actor width and combat footprint, making fine art differences difficult to see. This batch does not change visual actor scale or combat geometry. The parent should review the final indexed captures before any separate display-scale decision or main merge.

## Final five-case full-picture performance replay

The existing `ai-tech-five-weapon-replay-20261017/perf_driver.gd`, mixed/combat fixtures and probes were copied into isolated checkouts. [measure_fleet.py](measure_fleet.py) ran each fixture once on `292c095a` and once on the final worktree, alternating before/after by case. Both loaded the same existing DLL (SHA-256 `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`). Godot 4.7.2, RTX 2060, OpenGL Compatibility, full window, 1× logic, 240 warmup plus 480 sampled steps, uncapped/VSync off, 15 held-health enemies, and the same named weapon fixture were used. All ten runs passed native admission, actual 1×, focus/sample validity and full frame-phase checks; each pair had identical combat event and stress counts. Raw 10 compressed frame traces, logs, full-picture PNGs and [summary.json](evidence/final-review/performance/summary.json) are in `evidence/final-review/performance/`.

| Fixture | Before frame mean / P95 ms | After frame mean / P95 ms | Mean delta ms | Draw calls mean before → after |
| --- | ---: | ---: | ---: | ---: |
| mixed | 7.859 / 11.271 | 7.693 / 11.425 | −0.166 | 774.1 → 739.1 |
| laser | 5.707 / 9.045 | 5.720 / 8.858 | +0.013 | 697.2 → 662.3 |
| cannon | 7.686 / 11.550 | 7.571 / 11.426 | −0.115 | 776.7 → 741.3 |
| missile | 7.332 / 10.120 | 7.192 / 9.995 | −0.140 | 757.0 → 722.1 |
| longLaser | 9.978 / 15.839 | 9.380 / 14.517 | −0.598 | 707.0 → 671.9 |

This single paired pass shows no clear full-frame mean regression; the mixed P95 rose 0.154 ms. An earlier exploratory mixed pair with enlarged enemy alpha footprints failed event equality and was discarded before the eight enemy PNGs were restored. Neither the invalid pair nor the older first-pass screenshot draw-call readings are performance acceptance for this final candidate. Parent visual review and merge decision remain open.
