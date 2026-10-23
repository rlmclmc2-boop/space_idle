# Stage 3 geometry authority candidate

Main base: b2d91c21c1ecfdbd056049edbeb654292abc9434. Continued WIP: 8bd4283009b0832b2d682bdf7037861f113d2826. Parent dot and existing Astra high review remain required; this is not merge approval.

## Boundary closed

- One persistent authority is prepared/bound before formal stepping. Capture startup's former pre-preparation ticks now use the external-time coordinator after binding.
- configured_hull supplies authored static_height, display multiplier, per-hull scale and HUD-limited anchor for preparation, initial presentation and later hull changes. Player queries no longer consult PNG tail pixels or stale stable_center when a slice is absent.
- Main enemy position, pose, width, frontline, appearance, component and recognition queries consume the published view or authority. Old scene geometry fallback bodies and redundant scene layout sync calls are removed. Launch/mount queries use the authority fleet pose; render-only charge effects still read the rendered ship for drawing.
- Slice attachment borrows the authority; detachment does not restore scene providers or return poses. Numerical events belong to the authority; display state is copied.
- Caption preparation includes raw/translated ordinary names, ordinary groups, independent hyperspace enemies/groups and existing slot labels. Missing captions assert instead of substituting slot dimensions. Font fitting, 17 px leader metrics, 12 px marker metrics and status rectangle equations preserve the preceding layout. Leader geometry uses the encounter leader flag before display synchronization.
- Explicit formation validation executes the existing seven times against the authority, bypassing published views and active read-model/draw caches, then restores time/flags. Frontline, screen-boundary and independent-yaw overlap checks and the existing reject/retreat caller remain.

## Verification

Engine: D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe. Existing test/run.py isolated project/user directories; --headless --timeout 180.

| Existing entry | Result | Evidence |
|---|---|---|
| probe_native_admission_stale_pose.gd | 36 checks, 0 failures | [lifecycle.txt](lifecycle.txt) |
| test_battle_coordinate_inverse.gd | 10,015 checks, 0 failures | [coordinate-final.txt](coordinate-final.txt) |
| test_player_mount_seating.gd | 90 samples, 0 failures; max error 0.00033880010596 | [seating-final.txt](seating-final.txt) |
| git diff --check | Passed | final command |

Lifecycle coverage: stale pose discard; capture initialization; unchanged authority/providers across ship round trip and display off/on; static_height equality with display; detached anchors; actual laser/missile/cannon/longLaser launch/beam and damage events; real drone launch; native admission/handoff; font metrics for both registries; live-invalid formation rejection despite an older published view. Drone fixture uses save_data/install_snapshot and the existing hyperspace runtime equipment command.

The first resumed probe failed on obsolete direct mutation of read-only inventory and nonexistent hyperspace.set_equipped; [failure evidence](lifecycle-resume-before.txt) is retained. Fixture corrected without weakening gameplay assertions. Earlier checkpoint/extraction evidence is historical, not final acceptance.

Successful runs emitted the pre-existing Windows certificate-store diagnostic. No parser/script error or assertion failure appeared in successful logs. These finite checks do not claim visual-quality/performance acceptance. No personal saves, original dirty checkout, assets, tables, native binary or Library changed. No new suite or audit layer.
