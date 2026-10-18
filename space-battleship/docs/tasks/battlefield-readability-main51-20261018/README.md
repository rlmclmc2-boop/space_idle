# Battlefield readability on main 51a7e1b9

Production base: `51a7e1b9bc5784927e7d5b232a112194d990a41c`. The `before` worktree is that commit. The `after` worktree has only the four visual source edits listed below. This branch is not a merge of the older `d2f5db1a` art branch.

The eight `assets/ships/enemy/opening_v2` silhouettes and their one-to-one mapping in `scripts/enemy_visual_identity.gd` were already present at the production base. No ship asset, mapping, combat rule, spawn, timing, player UI, or right-side layout change is included here.

## Production diff

- `scripts/battlefield.gd`: warmer enemy hull modulation, six-pixel health/shield meters, and a short border on the actual meter struck.
- `scripts/enemy_recognition_visual.gd`: distinct physical bolt and energy streak, plus clearer contact mark in the script rendering path.
- `addons/native_battle/src/combat_presentation.h`: matching bolt/streak geometry in the native rendering path.
- `scripts/resource_art.gd`: thin pickup outline to separate rewards from moving fire.

## Original capture

`capture_live.gd` launches the normal scene at speed 1, starts stage 2 point 3, and samples frames 20, 60, and 100. It sets seed 24017 and disables save writing. It changes no health, damage, combat duration, delta, or pause state. The same script was used on both revisions. The PNGs and complete console logs are in `evidence/before` and `evidence/after` (1372 × 883, raw Godot OpenGL output). They are supplied for parent visual review without image retouching or selection after capture.

| Frame | Base: enemies / hostile shots / draw calls | Candidate: enemies / hostile shots / draw calls |
| --- | --- | --- |
| 20 | 11 / 0 / 233 | 11 / 0 / 233 |
| 60 | 11 / 17 / 238 | 11 / 15 / 240 |
| 100 | 11 / 21 / 242 | 11 / 21 / 242 |

Both runs loaded `native=true`, `combat_presentation=true`, `speed=1.0` and ended with `BATTLE_DONE`. Frame 60 is not an identical event state (17 versus 15 hostile shots), so its draw calls are observational data rather than a strict same-state performance comparison. The draw-call observations do not establish frame-time performance.

Both DLLs were built from their respective 51-based source trees, using the pinned local godot-cpp release library. SHA-256: base `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`; candidate `A94D0A4D41393076DEE77C610871B47B50A527C0057E42287D28CD2E91A67D27`. DLLs are local build artifacts, not committed. Godot 4.7.2 editor import and four script syntax checks passed. Each run logged a root certificate-store warning, unrelated to rendering; neither logged a script error.
