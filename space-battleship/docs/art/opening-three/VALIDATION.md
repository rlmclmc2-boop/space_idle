# Review evidence and limits

## Delivered

- `first-review.png`: original enemy identity studies and cropped scenery; prototypes only, not runtime hull replacements.
- `ten-stage-composition.png/.svg`: continuous ten-stage composition, seven later stages reserved.
- `stage-1-ui.png` / `stage-2-ui.png` / `stage-3-ui.png`: actual Godot viewport captures, isolated in-memory first encounter of each real baseline stage. Capture script asserts stage entry and no enemy/distance/RNG mutation during drawing. All three passed.
- Runtime: stages 1–3 read existing stage/distance for background texture position. Armor corner plates and lower static shield opacity use the existing protection painter and retained invalidation; stages 4+ preserve prior appearance. No gameplay table, kernel, hit geometry, firing rate, projectile count, damage, save or unlock changes.

## Necessary checks

Godot 4.6.3 import completed with no parse/script errors in the final isolated run. Xorg dummy display + Mesa llvmpipe rendered the actual scene; no software installed. Initial editor-config path failure was resolved with isolated XDG_CONFIG_HOME. Audio disabled for final render fixtures. Render fixtures do not load player saves.

Pixel comparisons: stage01 top 960 rows exactly equal stage02 bottom 960 rows; same for stage02→03. 887×1774 hull studies have RGBA with transparent margins. `git diff --check` passed. Source SVGs and reproducible Inkscape generator are included.

## Performance boundary

No new simulation path or second authority. Background adds one texture lookup to the existing scenery quad; for these stages it skips the procedural fog calculation it replaces. Journey division/clamp and scalar comparison run only on existing star-layer redraw; texture binding changes at stage boundaries, progress upload only when distance changes. Three textures are resident (~20.1MiB RGBA equivalent, no requested mipmaps). No per-frame image upload, framebuffer copy, added viewport, new node, enemy scan, or new event array. Armor corner path uses one retained multiline command instead of one closed polyline, with a bounded 24-point buffer only when existing protection invalidation repaints it. No new invalidation loop.

This is a source-level risk audit, NOT a measured performance pass. The environment has no matching 4.7 Windows native extension (repository template only lists the DLL); `SpaceCombatPresentation` unavailable in all three render fixtures. Screenshots use the repository's existing available renderer and are layout evidence only, not single-kernel combat or timing acceptance. No old path was introduced, restored or altered. FPS displayed in software-rendered capture is not a comparative benchmark. Parent must run the affected frozen equal-load scene on the accepted native environment (1× / 60Hz logic, full picture, no cap/VSync, focus fixed, whole/busy/tail frame reporting) before accepting performance. No broad matrix or new optimization exploration was run.

## Remaining integration dependencies

Baseline has 5/5/5 encounters, whereas target is 5/6/7. Eighteen presentation intentions are reviewable in CONTRACT.md; the extra three actual points are not created here. Stable archetype mapping and authoritative attack-warning / mitigation fields need parent+Sol coordination. No invented warning timer, mitigation rule or recovery window is rendered. Existing weapon/impact/death pipeline remains authoritative; richer break/mitigation feedback and live identity binding remain pending. Existing baseline weapon interval visible in captures is not changed by this art work.
