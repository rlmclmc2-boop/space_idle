# Final five-fixture acceptance

Battle baseline: `51a7e1b9bc5784927e7d5b232a112194d990a41c`. Measured final art candidate: `68246c4926a176316f7843c3ae5574a9d98bb86b`. This follow-up changes acceptance tools, documentation and evidence only. Main is not merged or rewritten.

## Correctness result: all five pass

The existing mixed, laser, cannon, missile and longLaser fixtures ran as serial before/after pairs. Pair order alternated: before/after for mixed, cannon and longLaser; after/before for laser and missile. Every pair has identical **full event dictionaries including `equipment_stats`**, stress counts, legendary-effect counters, sample-start state and final state.

The state comparison includes the full public state and native kernel export: player, all enemies, resources, loadout, clocks, queues, flights, cooldowns, counters and transferred RNG state. The explicitly excluded fields are the native RNG's historical randomly initialized `seed` property and the derived pre-normalization `kernel_hash`; the actual RNG `state` matches. This is the same exception documented in the earlier single-laser audit. Every differing-path list in the final summary is empty.

| Fixture | equipment_stats before / after | Full events | Start / final public and native state |
| --- | ---: | --- | --- |
| mixed | 260 / 260 | Equal | Equal |
| laser | 242 / 242 | Equal | Equal |
| cannon | 215 / 215 | Equal | Equal |
| missile | 208 / 208 | Equal | Equal |
| longLaser | 192 / 192 | Equal | Equal |

The former -32 notification difference is absent in every fixture. These five runs verify full event **counts** and full boundary states; they do not record every event's complete payload or prove every possible combat scenario's transient timing. The prior laser diagnostic separately verifies callback payloads and logical steps.

## Full-picture performance

All ten initial runs and the two mixed confirmation runs passed native admission, 240 warmup + 480 sample logic steps, actual 1x, focused-window/sample validity, production stat cache enabled, saving disabled, uncapped rendering and VSync off. Rendering remained Godot 4.7.2 OpenGL Compatibility on the NVIDIA RTX 2060. Each retained frame has its phase timings; each run has the full original frame trace and a complete framebuffer PNG. The reported window is 1373x883; all captured framebuffer PNGs are 1372x883.

| Fixture | Main51 mean / P95 ms | Candidate mean / P95 ms | Mean / P95 delta ms |
| --- | ---: | ---: | ---: |
| mixed, initial before/after | 7.778 / 11.402 | 8.567 / 13.438 | +0.789 / +2.036 |
| laser | 5.887 / 9.234 | 5.981 / 9.322 | +0.093 / +0.088 |
| cannon | 7.782 / 11.711 | 7.724 / 11.704 | -0.058 / -0.007 |
| missile | 7.541 / 10.649 | 7.382 / 10.375 | -0.159 / -0.274 |
| longLaser | 9.303 / 13.937 | 9.096 / 13.707 | -0.207 / -0.230 |
| mixed, reverse-order confirmation | 8.381 / 12.131 | 7.792 / 11.137 | -0.589 / -0.994 |

The initial mixed increase warranted exactly one additional reversed pair; the other four cases were not repeated. Mixed's sign reverses, so these samples do not show a reproducible one-direction mixed slowdown. The unweighted average of the two mixed run means is 8.080 ms before and 8.180 ms after (+0.100 ms). Both observations are retained without selecting a preferred result. Laser has a small positive mean/P95 delta; the other three initial nonmixed cases decrease. These limited samples are evidence for the measured fixtures, not a statistical guarantee of universal performance parity. No numerical performance threshold was invented.

## Evidence and reproduction

- [Initial ten raw traces, logs, screenshots and summary](evidence/final-acceptance/summary.json).
- [Mixed reverse-order raw pair and summary](evidence/final-acceptance/mixed-confirmation/summary.json).
- [Offline audit, original-file SHA-256 hashes and validation details](evidence/final-acceptance/audit.json); reproduce with `python analyze_final_acceptance.py`, without launching Godot.
- [Paired runner](measure_fleet_final.py) reuses the retained earlier `perf_driver.gd`, adapting only its GDExtension assertion path to `addons/native_battle/space_native.gdextension`, plus the same retained probes and fixtures. It can resume from already completed valid raw measurements. Optional `FLEET_PERF_CASES`, `FLEET_PERF_OUTPUT` and `FLEET_PERF_REVERSE` select the separate confirmation run.

Both projects loaded the unchanged DLL SHA-256 `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`; no compilation was performed. One initial candidate launch failed because the local imported-script registry needed regeneration; [the failed setup log](evidence/final-acceptance/setup-script-registration-failed.log) is retained and was not counted as a measurement. The already completed valid mixed baseline was reused. Accepted logs end `PORT_PERF_DONE` with no script error. The OS certificate-store warning does not affect this local run.

The [previous acceptance boundary](BOUNDS_AND_TIMING_AUDIT.md) is now closed for the requested five fixtures. There is no known remaining correctness discrepancy in these runs. Performance variability and the scope limits above remain explicit; main's documentation-only update is preserved.
