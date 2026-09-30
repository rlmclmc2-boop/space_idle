# Unified prototype checkpoint

Runnable integration milestone on `codex/unified-battle-prototype`, not a main-branch merge or final visual acceptance.

Integrated topics:
- Weapon mechanics/readability through local `193af0c`
- Equipment panel through local `5864dd4` (full topic range)
- Optional onboarding through local `11ac5a7` (full topic range)

Only localization insertions conflicted. Both equipment and onboarding entries were retained; the merged catalog/contract contains 1477 unique keys and passes `tools/ui_text_editor.py --check`. Main/game construction, projectile hooks, guide setup and onboarding profile fields coexist.

## Current acceptance boundary

The sustained beam's actual color ramp, distinct full state, one full-entry cue and instant shutdown are accepted and frozen. Accepted ship/orbit/pulse presentation is retained. Equipment and guide flows are integrated; the requested defense-icon/level-spacing follow-up is separate and not applied here.

Missile and rail mechanics are runnable, but their current visual identities need the newly approved redesign. This checkpoint does not call them final. Next weapon-only pass: two slower substantial rockets per pod with staged ejection/ignition/acceleration/curved seeking; electrically dominant rail charge/discharge with a very brief core instead of a gold laser-like line. Balance-related prototype parameters are authorized to change. Keep those changes in the dev combat implementation and document actual effects.

## Bounded integration verification

- Equipment interaction assertions pass: free equip, read-only picker preview, level-preserving swap, direct/batch upgrade affordability, live capacity and semantic anchors. Engine reports one retained resource at test shutdown; not claimed as a clean lifetime audit
- Beginner guide: 28 checks, 0 failures, including free-equip/upgrade anchors, dismissal/reopen and fresh/legacy profile boundaries
- Combined mixed prototype smoke passes both 450-frame renderer runs with all four weapon families; these runs use the current prototype mechanics, not the old game's timing
- Production projectile iteration: 8 checks, 0 failures. The separate old lifecycle test has a stale retarget assertion and fails identically on the unchanged base; it is not counted as passing

## Resume

From `space-battleship`:

`python dev/toon_ship/preview.py --godot /path/to/godot --fixture Heavy_Battleship --interactive`

This creates an isolated project/user directory and never writes a player save. See `dev/toon_ship/PROTOTYPE_CHECKPOINT.md` for sparse/mixed weapon review commands. Use Linux XDG directories under the isolated `test/work` area for test scripts; the legacy general runner only sets Windows app-data variables. Windows and real-time performance are untested.
