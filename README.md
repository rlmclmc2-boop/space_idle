# Galaxy city districts — review candidate

Candidate: `art/cosmic-city-districts` / `d6c944105d7c44ba67e3021d6d06c9c75797c85e`.
Base main: `10360c57f1057c51ba7106f84581fdd5b1383c62`, fetched again before delivery. Not merged.
The candidate includes the previously approved three-building prototype (`8f19a7487ff8516499fbdd735d8241edff80f767`) plus formal runtime integration.

## Changes

- Six compact shared platform districts surround the headquarters; eight service bridges meet equal-height, opposing sockets. Thick hollow hulls, restrained panels, flange shoulders and building mounts retain the approved sample direction.
- All existing six-family / five-level GLBs remain unchanged. First-galaxy fixture counts remain 6/6/6/6/5/1 (30 buildings), not five of each. Headquarters receives an audited bottom/center offset.
- View positions are deterministic mappings of existing slot IDs and families. Saved blueprint coordinates, construction prerequisites, economic values, unlocks, exploration time/rewards and save format are unchanged.
- Full panel canvas remains available. Camera centers the actual visible city and reserves space for flights. Decorative boats travel between actual docks independently of bridges; their numeric counter is hidden. Individual selection, construction and upgrade displays remain.
- Structure geometry is baked into 17 static meshes per selected region; upgrades reuse shared platform/bridge meshes and cached level-specific mounts. Existing single viewport and lights remain. No new per-frame structure generation.

## Evidence

- `galaxy-city-ui.png`: native 1372×883 game framebuffer, 30 buildings with mixed levels, full application UI.
- `galaxy-city.mp4`: same running game, 66 native frames over 12.046 seconds of real wall time at game speed 1. Encoding pads one bottom row to 1372×884; no visual redesign, time acceleration or interpolated motion. H.264 duration 12.08 seconds includes final held frame.
- `galaxy-complete-ui.png`: all 30 buildings at Lv5.
- `galaxy-construction-detail-ui.png`, `galaxy-upgrade-ui.png`, `galaxy-paused-reopened-ui.png`: real selected construction, upgrade and hidden/reopened flows.
- `library-deliverables.json`: confirmed Library IDs, file IDs and versions for the full screenshot and recording.

All captures use an isolated synthetic test fixture, not user saves. This branch contains only game captures and verification logs/metadata, not reference artwork or private images.

## Verification

- `city.log`: 323 UI assertions, zero failures. Includes six families at all five levels/four orientations, 750 model roof pick samples plus 150 existing roof samples; per-building model/cache behavior; socket endpoints and HQ alignment; normal selection/zoom/pan; crew popup; construction/upgrade; repeated region switching; paused and hidden rendering lifecycle. Hidden/paused visual tick delta is zero.
- `clearance.log`: 23 additional focused assertions, zero failures (15 district-pair separations and eight sampled bridge-width clearance checks). This is a separate run; do not describe it as a rerun of the whole 346-assertion UI suite.
- `config.log`: two configuration projection/validation tests passed. `scope-audit.json`: exactly four visual JSON values and four corresponding Excel cells changed; all GLBs, gameplay/save and planet code unchanged.
- `record.log` and `recording.json`: actual framebuffer timing/source metadata. Captures were visually inspected at native size.

Environment: Godot 4.6.3, Linux llvmpipe software rendering. Recorded cadence is approximately 5.5 rendered frames/s with the normal game scene active. There is no before/after hardware performance claim and no Windows performance validation. No unrelated full test matrix was run.

Pending: independent parent/user visual review, then an explicit merge decision. The accepted planet rotation branch and Windows `codex/local-x1` work are separate and untouched.
