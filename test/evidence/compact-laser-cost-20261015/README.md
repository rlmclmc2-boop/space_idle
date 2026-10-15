# Accepted compact path: top-level cost localization

Branch input `b6ab391e28ca55eb39827f95821bf94d95c8c8bb`; accepted DLL SHA256 `1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5`. Godot 4.7.2 full GL at 1x and 60 logical Hz. These are the existing mixed and pulse laser fixtures, not natural play. `run_cost.py` copied no production code into the branch: it temporarily wrapped top-level calls in the two isolated D: projects, then restored their scripts. Each fixture ran **timer off / timer on / timer off** with one DLL and identical fixture. Raw reports, logs, on screenshots, fixture/source hashes and order are in `receipt.json` and the named `.json.gz` files. GDScript timers are one pair per top-level invocation, never per flight.

Two preliminary mixed imports failed on QA-only parser issues (wrapper indentation, then a duplicate inherited constant). `mixed-import-failed*.log` and `failed-receipt*.json` preserve those attempts. The six reported runs are the subsequent completed series.

## Inclusive cost, timer-on

All values are **ms per indicated call**, arithmetic mean over 480 logical steps or all displayed frames. Child scopes are inside parent scopes and must not be summed.

| Scope | Calls mixed / pulse | Mixed | Pulse laser | Boundary |
|---|---:|---:|---:|---|
| `consume_feedback` | 480 / 480 | 1.767 | 3.128 | Includes native feedback retrieval and downstream event handlers; upper bound on savings from this entire path. |
| `kernel_advance_call` | 480 / 480 | 0.237 | 0.419 | Native step call only; below 0.5 ms per step. |
| `geometry_before_tick` | 480 / 480 | 0.542 | 0.532 | Entire visual geometry preparation. |
| `prepare_geometry` | 480 / 480 | 0.190 | 0.191 | Geometry input to native. |
| `shared_clock` | 480 / 480 | 0.591 | 0.574 | Economy, planet, galaxy, crew and collection work together. |
| `snapshot` | 924 / 1057 | 0.495 | 0.511 | Entire battle snapshot once per rendered frame. |
| `draw_battle` | 924 / 1057 | 1.292 | 0.644 | Entire battle draw; includes both presentation rows below. |
| `presentation_draw_flights` | 924 / 1057 | 0.467 | 0.046 | All flight types; not a missile-specific measurement. |
| `presentation_prepare_flights` | 924 / 1057 | 0.072 | 0.034 | All flight types. |

`session_advance` inclusive is 2.087 / 3.628 ms per logical step. Excluding its measured feedback and kernel child calls leaves ~0.083 / 0.082 ms per step. `presented_tick` inclusive is 2.690 / 4.215 ms per step; excluding `session_advance` and `shared_clock` leaves ~0.013 ms. `slice_advance` includes those children and the per-frame snapshot. The remaining battle draw after the two presentation calls is 0.752 / 0.563 ms per frame; this is a broad upper bound covering ship, enemies, overlays, retained submission and other drawing. The counters' own post-clock bookkeeping was 0.010 / 0.009 ms per frame. Wrapper dispatch and clock read costs are inside measured scopes, so these are upper bounds, not expected optimization gains.

## Control and outcome

| Fixture | Off 1 / On / Off 2 whole-frame mean ms | One-step mean ms | One-step P95 ms |
|---|---|---|---|
| Mixed | 9.021 / 8.566 / 8.559 | 11.336 / 10.925 / 10.898 | 14.670 / 14.257 / 13.872 |
| Pulse laser | 7.584 / 7.471 / 7.519 | 11.203 / 11.049 / 11.098 | 17.527 / 17.725 / 17.539 |

Full busy frames remain above 10 ms. The mixed control drift is 0.462 ms in mean; the pulse drift is 0.065 ms. This experiment does not establish an optimization gain. It only locates the broad cost ceiling. All six runs completed 480 sample steps at actual 1x with identical fires, hits, events, purchases, logical player/enemy/projectile state, compact membership, kernel metrics and RNG **state** within each fixture. Frame counts and purchase frame indices naturally vary under uncapped rendering. The kernel RNG object's initial `seed` field is run-specific while its state and resulting gameplay match; therefore whole `kernel_hash` differs. No scripts or DLL were changed in the branch.

Priority for any later *authorized* design work is feedback retrieval/event dispatch: it is the sole isolated top-level path with a large ceiling in both fixtures (1.77 / 3.13 ms per logical step). These measurements do not divide retrieval, allocation and handlers, and do not justify suppressing events or changing cadence. Next broad ceilings are mixed remaining battle draw (0.75 ms per displayed frame), shared clock (0.59 / 0.57 ms per step), geometry preparation (0.54 / 0.53 ms per step), and snapshot (~0.5 ms per displayed frame); each needs a specific correct design and whole-frame net gain above control drift before retention. Missile-only savings cannot be inferred from this run.

## Feedback boundary follow-up

`feedback-boundary/` holds one additional QA-only run per existing fixture. It brackets `kernel.take_feedback()` once per logical step, inside the existing `consume_feedback` wrapper. Same accepted DLL; 480 steps, same fires/hits/events/purchases/kernel metrics/RNG state as the earlier on run. No per-hit timing. The full complement still includes all required event handling and profiler overhead.

| Fixture | `take_feedback` ms/step | Remaining `consume_feedback` ms/step | Hits / step | Mean visible floats |
|---|---:|---:|---:|---:|
| Mixed | 0.237 | 1.566 | 27.19 | 15.98 |
| Pulse laser | 0.430 | 2.720 | 38.41 | 15.98 |

These are gross inclusive boundaries, not removable budget. The older `b8c7f3e6` feedback probe separately measured native take 0.202 ms/rendered frame, script payload 0.240, emit 2.358, and battlefield listener 1.292 on an older fixture. Its final-payload candidate gained only 0.220 ms against its faster control and was rejected. This follow-up does not reopen that route.

The old `bc03d74a` damage localization measured `damage.hit_lookup` 0.198 ms/rendered frame with 6,520 hits across 240 steps, about 4.86 visible floats and an older display policy. Current fixtures have about 16 visible floats with 13,050 / 18,436 hits across 480 steps. Scaling that old lookup by hit and float counts suggests roughly 0.65 / 0.91 ms per logical step, or 0.35 / 0.44 ms per *uncapped displayed frame*. This is only a rough operation-count projection: matching often stops early, the old probe adds clock overhead, and current summary semantics differ. It cannot establish a 0.5 ms whole-frame gain or cap the current lookup cost. A semantically exact candidate must beat its own unwrapped control before retention.

The earlier timer-off arms still call a wrapper, `QACost.begin()` and `QACost.finish()` on each scope; timer-on additionally reads clocks and records rows. Thus off/on/off estimates the **incremental enabled-timer** effect plus run drift. It is not an uninstrumented production baseline, and the inclusive scope means above contain fixed wrapper overhead. No claim of exact probe-free cost follows from these numbers.
