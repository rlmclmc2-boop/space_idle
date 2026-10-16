# DPS native follow-up for parent review

Source: accepted `main` `e02501b38bff8069f2b15bd8947c54d1dc215a1a`; candidate `ae6f5d15` on `work/battle-dps-native-20261016`. Do not merge before parent review. `receipt-review.json` records exact source, control visual patches, DLL (`6bfa0d565eae83d96ee6e374d92b790a60a41cb52ae1d9209b23c90d1e7ef452`), Godot, driver, asset/game-data and per-run hashes.

## Changes and focused checks

- Legacy DPS now measures the actual shield/health state decrement, including GrowthNumber values too large for a small hit to change. A blocked native step no longer advances the DPS clock. Native DPS remains an optional observer; admission and ownership are unchanged.
- Chain visual origin uses the native `launch_point` at the hit enemy; chain body and impact use the source weapon's visual style in retained and non-retained presentation. `test_chain_visual_origin_native.gd` confirms the native carrier and its impact event start at the hit enemy and that the carrier does not emit a rail muzzle-fire event. The red full-height bands in `review-cannon-1-main.png` and `review-cannon-3-on.png` are the existing original cannon penetration effect, present on both sides.
- `test_battle_damage_stats.gd`: 29/29. Graphical main scene `test_battle_damage_stats_ui.gd`: 12/12, screenshot `review-main-scene.png` (the small displayed damage rows are injected for layout inspection). Native chain visual origin: 7 assertions. UI catalog check: 2372 valid rows. The project contract in `space-battleship/docs/UI_TEXT.md` names `data/ui_text.json` as the authority for ordinary UI text; its editor writes JSON, while Excel sources are exceptions for specified content.

## Final graphical performance comparison

`run_review.py` reused the two imported projects from `run_followup.py`; no repeated full asset copies. Five original high-load fixtures ran serially on Windows, each main/off/on/main, real 1×, fixed 60 Hz logic, FPS cap 0, VSync 0, `cache=true`, `save=false`, same DLL, resources, step counts, fixture events and foreground focus. Each run has 240 warm and 480 measured logic steps; native admission and zero handoffs; 15 enemies alive. `analysis-review.json` checks event counts, game/player/enemy/projectile state and RNG **state** equality across modes. The automatically generated RNG seed differs between separate processes even when the resulting state is equal, so the raw kernel hash differs.

| Fixture | Full-frame mean: main/off/on/main (ms) | Main-process mean: main/off/on/main (ms) | Main bracket drift | On refresh frame mean/max (ms) |
| --- | --- | --- | ---: | ---: |
| mixed | 10.157 / 10.417 / 11.121 / 10.610 | 3.691 / 3.852 / 4.201 / 3.916 | 4.36% | 29.030 / 49.422 |
| laser | 7.459 / 7.697 / 8.140 / 7.454 | 3.055 / 3.211 / 3.423 / 3.035 | 0.07% | 28.079 / 51.004 |
| cannon | 9.699 / 10.039 / 9.891 / 9.536 | 2.762 / 3.056 / 2.949 / 2.716 | 1.70% | 25.667 / 46.225 |
| missile | 8.841 / 9.458 / 9.821 / 9.181 | 2.952 / 3.250 / 3.381 / 3.090 | 3.78% | 30.038 / 53.169 |
| longLaser | 12.111 / 11.947 / 12.353 / 12.559 | 4.188 / 4.110 / 4.301 / 4.411 | 3.63% | 29.634 / 49.332 |

The largest enabled minus closed full-frame mean is 0.704 ms (mixed); all other suites are between -0.148 and +0.443 ms. Each enabled sample records exactly 16 UI refreshes, rather than one per hit. Full-frame traces and paired comparisons of every refresh are in `review-*.json.gz` and `analysis-review.json`; PNGs, console logs and system-load traces accompany each run.

The prominent refresh peaks line up with the fixture's 12-slot purchase every 60 logic steps. For example, mixed at battle clocks 5.12, 6.12, 7.12, 8.12 seconds has main/off/on/main frames of 41.4/42.1/41.0/43.4, 40.7/41.1/47.6/44.2, 43.7/45.2/42.7/41.9 and 43.9/43.9/43.6/46.7 ms. The other refreshes do not coincide with these purchases. Their actual paired values are recorded in the analysis JSON. No low-load or headless timing is used as performance acceptance.

`followup-*` traces are the preceding visual/clock candidate `7882538b` and remain as raw history. `review-*` traces are the final candidate `ae6f5d15`. The source, raw traces and screenshots are for parent review; main remains untouched.
