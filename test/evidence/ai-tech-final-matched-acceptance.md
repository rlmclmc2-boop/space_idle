# Matched final-candidate AI page comparison

Source/runtime commit: `679712193b55394096c33f3825228064e5b93268`, based on final integrated candidate `da95e636c1ad2a5c6b8ce5d5c081fca2bc1fd5b2`. This branch has not been merged into main.

The existing five-weapon suite now uses one copied final-candidate project, one fixture per weapon case, one native DLL, one level/monster/game data set, and the same `singularity` research selection in all states. A/E set the debug-only `AI_TECH_PERF_PAGE_ABSENT=1`: fixed tab index 1 retains an inert hidden placeholder, while the technology page class, snapshot provider, signal listeners, and draw tree are not constructed. B/D retain the normal page closed; C opens it. The production default and release builds still construct the page normally.

Each of `mixed`, `laser`, `cannon`, `missile`, and `longLaser` ran A/B/C/D/E with 240 warmup + 480 sampled logic steps, 15 held-health enemies, 1x speed, native execution admitted, VSync off, uncapped OpenGL Compatibility on RTX 2060 at 1373x883. **All 25 runs passed** sample validity, step/phase closure, complete event-count equality, and fixture stress-count equality. The original strict suite printed `SUITE_OK five cases` and exited 0. Raw JSON and system-load samples (gzip), original logs, screenshots, runner and fixtures are in `ai-tech-final-matched-five-weapon/`; `summary.json` SHA256 is `BAA84DBE95DE5157D670A58029B1701F0F92EE16A50FE7D9303CE55E144AC107`.

| Weapon case | Absent A/E frame mean ms | Closed B/D frame mean ms | Open C frame mean / p95 ms |
| --- | ---: | ---: | ---: |
| mixed | 7.885 | 7.705 | 7.231 / 10.390 |
| laser | 5.823 | 5.588 | 5.036 / 7.837 |
| cannon | 7.938 | 7.481 | 6.944 / 10.487 |
| missile | 7.118 | 6.998 | 6.677 / 9.226 |
| longLaser | 8.741 | 8.778 | 8.399 / 12.884 |

Times are this sequential fixture's measured wall frame times, not a hardware-independent FPS or pure game-tick estimate. Opening the page changes visible content. The earlier failed historical-baseline replay remains intact under `ai-tech-final-da95-five-weapon/` and its failure is not reclassified as a pass.

The verified player entry's `BASE` now names `679712193b55394096c33f3825228064e5b93268`. In an isolated checkout with spaces and Chinese characters in its path, the actual entry validated local Godot 4.7.2, descriptor, native DLL SHA256 `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`, source state and data SHA, imported assets, then launched the graphical main scene twice using isolated user data. Both short auto-quit runs exited 0 with identical receipts. The acceptance wrapper substitutes `main` only for the branch-name query because this task branch must not be merged here; production main still needs its normal branch gate checked after integration. Entry unit tests passed 12/12; AI technology headless checks passed 49/49 after import, without script errors. Original logs and receipt are in `ai-tech-final-matched-entry/`.
