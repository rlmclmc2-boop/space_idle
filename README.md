# Approved individual-platform city — runtime candidate

Candidate branch: `art/cosmic-city-individual-runtime`.
Candidate SHA: `8f8d68422633d93d9caa2468d63eea41cabbbdf6`.
Based on approved direction `ededd13303cc6f4125d5ca2fc5e9540cdf65ef78`; main was fetched again as `10360c57f1057c51ba7106f84581fdd5b1383c62`. Not merged. The rejected shared-district implementation is not in this branch's ancestry.

## Final behavior

- Preserves the accepted 30 individual 16×16 platforms, mixed-type placement, original GLBs, separate headquarters, 32 service bridges and default camera (size 134 at the reference aspect). No shared functional district decks. Original slot IDs, types, blueprint rotation and construction prerequisites remain authoritative; view positions are not saved.
- Empty slots have separately selectable planned foundations. Model roofs and platform rims select their individual slot. Construction reveals the actual partial model; upgrading retains its current model and own progress/selection UI. Existing crew and effect behavior is retained.
- Decorative boats independently depart and arrive at actual DockSockets above the bridges; their count is not drawn. Construction vessels remain crew-dependent. Pause and hidden views stop visual updates; reopening restores the current state.
- The hub, 30 platforms and 32 bridges are 63 static structural meshes, baked on region selection. Upgrades reuse them and cached per-model mounts. No extra viewport/light or per-frame structure rebuild. Fixed framing avoids fitting the city again to every changing flight envelope.
- Exactly four visual configuration values change in the authoritative Excel and generated JSON (camera range and decorative fleet density/cap). No economy, unlock, exploration work/time, save schema, GLB, planet or Windows branch changes.

## Native evidence

- `galaxy-city-ui.png`: full 1372×883 game UI, 30 mixed-level buildings with the accepted composition. Visually inspected against the approved direction.
- `individual-city-runtime.mp4`: actual normal game framebuffer, game speed=1, 53 frames over 12.180 wall-clock seconds; no time acceleration/interpolation. Encoding pads one bottom row to 1372×884; duration 12.24 seconds includes final held frame. `recording.json` includes each frame's fleet positions and state.
- `individual-flight-1x.gif`: native 815×558 galaxy viewport, fixed inspection camera only (size 48), unchanged ships and flight routes. No count overlay. 23 frames over 10.264 seconds, with actual wall-time playback. First/last native frames were inspected and show ships crossing open space in front of the headquarters.
- `flight-positions.json` and `flight-per-second.csv`: six visible aircraft throughout, crew=0, running=true, paused=false; each moves about 20.58 world units. In this software-rendered capture the visual clock advances only 2.941 seconds, so this is not a full-speed hardware-performance claim.
- `galaxy-construction-detail-ui.png`, `galaxy-upgrade-ui.png`, `galaxy-paused-reopened-ui.png`, `galaxy-complete-ui.png`: actual construction selection, upgrade selection, paused reopen and all-Lv5 state.
- `library-deliverables.json`: confirmed native Library image/video/GIF IDs and versions.

## Verification and limits

- `ui.log`: 893 assertions, zero failures. Covers all six families/five levels/four orientations, 750 roof samples plus 150 existing roof samples, all platform/HQ pair clearances, 32 bridge endpoint/normal/width checks, static mesh identity across upgrades, saved blueprint immutability, camera fit, selected/hover states, popup and crew actions, repeated region switching, hidden/paused/reopened rendering. Paused/hidden visual tick delta: zero.
- After extending picking to the platform rim, `platform-pick-and-flight.log`: five focused checks, zero failures (startup plus four center/old-edge/new-rim/outside-boundary checks). No unrelated or broad rerun. `focused-capture.gd` makes the focused check and recording reproducible.
- `config.log`: two configuration validation/projection tests passed. `scope-audit.json`: exact four visual Excel/JSON differences and unchanged scope.
- During verification, an over-conservative camera fit shrank the accepted composition; it was replaced with the accepted fixed camera and aspect adaptation, then the related UI suite passed. A temporary close-up capture script's type-inference error was corrected; the successful log is included. No production parse errors or unresolved test failures remain.

All captures use an isolated synthetic fixture, never a user save. Godot 4.6.3 / Linux llvmpipe, not Windows. No hardware performance or before/after speed claim; no unrelated test matrix. Pending: independent parent visual/code review and explicit merge approval. Planet rotation and `codex/local-x1` remain separate and untouched.
