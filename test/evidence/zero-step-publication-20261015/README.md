# Zero-step display publication diagnosis (2026-10-15)

Decision: **reject the zero-logical-step snapshot/publication reuse route.** This is one diagnostic timer-off / timer-on / timer-off series on the frozen mixed fixture, not a production candidate or a five-environment performance pass. Production files and the accepted DLL stayed unchanged. `receipt.json` pins the exact fixture, full loadout manifest, Godot binary, native DLL, driver, ledger, patches, import and raw run hashes. `analysis.json` is reproducible with `python analyze.py`.

The QA-only project ran Godot 4.7.2 in full GL Compatibility on the NVIDIA RTX 2060, actual speed 1, 60 Hz logical simulation, uncapped display, VSync off, focused throughout, with 120 warm and 240 sampled logical steps. All three arms used identical QA wrappers and counters; only the on arm read timers. Initial, pre-sample and post-sample gameplay state, RNG state, and full frozen manifest matched exactly across arms. All sample frames were valid. A preliminary QA-only import failed because of an instrument patch indentation error; `import-failed.log` preserves it. The corrected isolated import and all three runs succeeded without game script errors.

## Full displayed-frame observations

| Arm | Frames: 0 / 1 / >1 logical steps | All frames mean | Zero-step mean / P95 | One-step mean / P95 |
|---|---:|---:|---:|---:|
| Timer off A | 212 / 236 / 2 | 8.904 ms | 6.391 / 7.782 ms | 11.102 / 14.146 ms |
| Timer on | 179 / 234 / 3 | 9.615 ms | 6.817 / 8.562 ms | 11.663 / 15.826 ms |
| Timer off B | 194 / 236 / 2 | 9.218 ms | 6.580 / 7.710 ms | 11.323 / 14.820 ms |

Timer on exceeded the off midpoint by 0.554 ms per full frame; off/off drift was 0.314 ms. On zero-step frames the corresponding values were +0.331 and 0.190 ms. Timer-on measurements include clock and wrapper cost; those control differences must not be subtracted mechanically from individual scopes. The >1-step bucket has only 2–3 frames per arm and gives no reliable estimate. One-step busy frames remain above the <10 ms target in all arms.

## Timer-on scopes, zero-step frames

The table is inclusive milliseconds **per zero-step full displayed frame**, over 179 frames. Nested scopes must not be added to their parents.

| Scope | Calls | Mean ms | Reuse boundary |
|---|---:|---:|---|
| `snapshot` | 179 | 0.530 | Rebuilds the slice view on every external advance, including zero steps. |
| `apply_nodes` | 179 | 0.068 | Applies ship and hyperspace presentation pose every unpaused frame. |
| `retained_sync` | 179 | 0.611 | Checks live enemy identity, spatial pose, geometry and signatures; static command cache already exists. Full cost is a generous upper allowance, not proved reusable. |
| `foreground_stage` | 179 | 0.601 | Reads and stages live flights/shots; exclude from reusable logical publication. |
| Dynamic retained `Part._draw` | 358 | 0.616 | Two drawing calls per displayed frame; wall-time cues remain live. |
| Static retained `Part._draw` | **0** | **0** | Immutable ship/enemy parts did not rebuild draw commands after warm-up in any arm. |
| `advance_projectile_visuals` | 179 | 0.164 | Wall-time flight motion. |
| `muzzle_draw` | 179 | 0.087 | Wall-time cue fade. |
| `refresh_draw_layers` | 179 | 0.312 | Includes broad scene draw preparation. |
| `draw_battle_core` | 179 | 1.332 | Contains `retained_sync` and `foreground_stage`; cannot add those costs to it. |
| `battlefield_process` | 179 | 1.765 | Contains `apply_nodes` and broader presentation. |

Zero-step `snapshot`, `apply_nodes`, `retained_sync`, `foreground_stage` each ran once per frame in all three arms; dynamic Part drew twice per frame and static Part never drew. The zero-step frames had no change in recorded logical `fx_time`, but `star_travel` and encounter scenery time changed on **every** such frame. Visible floats also changed in 5 timer-on zero-step frames. Those observations show that zero logical steps do not mean frozen presentation.

## Reuse budget and invalidation

The non-overlapping `snapshot + apply_nodes` scope totals 0.598 ms per zero-step frame, or **0.257 ms per all displayed frames** using the measured 179/416 zero-step fraction. That is a gross bound before adding a version check, retained view lifetime, catch-up publication, and invalidation work. Even granting the **entire** `retained_sync` cost as removable yields 1.210 ms per zero-step frame, **0.521 ms per all frames**. Reaching 0.5 ms net would require recovering 96.1% of this overgenerous bound and spending under **0.021 ms per all frames** on all checks and maintenance; the timer effect and off/off drift both exceed that margin. No net benefit is established.

Any shared publication would need to invalidate on logical step, enemy/projectile membership, entity identity, hull or equipment/ship configuration, spatial shape and pose, pause/transition, and graphics visibility/quality changes. `apply_nodes` and retained enemy presentation also depend on wall-time ship/target pose, star/encounter motion, camera offset and shake. Foreground shot/beam cues, flight motion, float decay, shader/view updates, muzzle fade, and dynamic draw commands must continue every displayed frame. Godot caches CanvasItem `_draw()` commands until `queue_redraw()` ([official custom drawing documentation](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)); static Part commands already realize this boundary, and zero rebuild calls confirm it locally. Cached commands do not imply zero GPU rendering cost.

The next broad measured bottleneck is the full draw/render path: the earlier accepted-DLL mixed localization measured `draw_battle` at 1.292 ms/full frame with 0.752 ms outside its flight scopes in [`compact-laser-cost-20261015/README.md`](../compact-laser-cost-20261015/README.md); the frozen mixed frame still spends 1.332 ms in `draw_battle_core` on zero-step frames. These are inclusive ceilings, not demonstrated removable work. Any further direction needs a new design and full-frame net evidence; this study does not reopen rejected feedback, upgrade-local, or projectile-reduction routes.

The synthetic held-health fixture does not cover natural deaths, consecutive wave transitions, drops, or live purchase quotes. The study preserves full display work and does not claim player-play coverage or five environments meeting target.
