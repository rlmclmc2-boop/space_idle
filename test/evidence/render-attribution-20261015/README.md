# Frozen mixed full-frame render attribution (2026-10-15)

Decision: **diagnostic only; no production rendering change is justified yet.** The one-step busy frame remains above 10 ms. Accepted source and DLL were unchanged. `receipt.json` pins the frozen manifest, fixture, DLL, Godot executable, QA patches, and raw hashes. `analyze.py` reproduces `analysis.json` from the three complete JSON reports. This is a synthetic held-health mixed fixture, not natural deaths, consecutive waves, drops, or purchase quote coverage.

Godot 4.7.2 GL Compatibility on the NVIDIA RTX 2060 exposed `viewport_set_measure_render_time`, per-viewport CPU/GPU reads, and `get_frame_setup_time_cpu` (`api_probe.log`). Its [RenderingServer documentation](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-cpu) defines these as rendering-only measurements, not `_process` time; disabled viewport measurement returns zero. GPU and CPU clocks can overlap and are **never added as elapsed full-frame time**. No forced GPU sync, renderer quality change, FPS cap, VSync, power-state adjustment, or hidden viewport was used.

## Controlled run

One isolated QA project copied the complete frozen mixed fixture and accepted DLL SHA-256 `1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5`. All three arms used identical `_draw` wrappers and call counters; only the middle arm enabled timer reads and viewport render measurement. Each had 120 warm and 240 sampled logical steps at actual 1×, 60 Hz logic, uncapped display, VSync off, full GL, focused frames. Complete loadout manifest and initial, before, after logical state including RNG matched across arms; the isolated project's 175 other GDScript files matched the branch. Three QA-only files carried the timer hooks. Neither production source nor DLL changed.

Two failed QA starts are retained separately. `failed-off-a.log` shows an obsolete environment-variable assertion before sampling. `failed2-on.log` shows the first viewport probe retaining a short-lived `BodyBake` viewport node after it was freed; that series is excluded. The final series skipped freed nodes, imported cleanly and completed all three arms. Its seven-viewport inventory was identical at sample start/end in all arms. The stable list comprises root window, visible `ShipViewport` (update mode `UPDATE_ALWAYS`, 4), disabled Planet and Galaxy subviewports (mode 0), and three hidden dialogs. Only root and ship yielded nonzero per-frame render times. Transient viewports during the sample were not independently enumerated; none remained at its end.

## Mutually exclusive wall-clock intervals

Milliseconds per **complete displayed frame**. `post→main`, `main`, `main→pre`, and `pre→post` partition each observed frame. `_draw` clocks and engine counters are separate inclusions, never additional intervals.

| Arm / logical steps | Frames | Full mean / P95 | `main` | `main→pre` | `pre→post` |
|---|---:|---:|---:|---:|---:|
| Off A / 0 | 223 | 6.217 / 7.094 | 1.564 | 2.039 | 2.563 |
| On / 0 | 202 | 6.581 / 7.599 | 1.654 | 2.126 | 2.718 |
| Off B / 0 | 220 | 6.279 / 7.355 | 1.580 | 2.056 | 2.591 |
| Off A / 1 | 234 | 10.914 / 13.740 | 5.558 | 2.544 | 2.756 |
| On / 1 | 233 | 11.271 / 13.911 | 5.783 | 2.609 | 2.790 |
| Off B / 1 | 234 | 10.982 / 13.963 | 5.619 | 2.563 | 2.743 |
| Off A / >1 | 3 | 16.038 / 17.017 | 11.109 | 2.200 | 2.673 |
| On / >1 | 3 | 17.799 / 21.108 | 12.773 | 2.288 | 2.660 |
| Off B / >1 | 3 | 16.790 / 18.175 | 11.672 | 2.406 | 2.653 |

`post→main` was 0.052–0.088 ms across zero/one-step arms; full values include it. The >1-step bucket has only three frames per arm. On one-step frames, enabling the probe raised full mean 0.323 ms above the off midpoint; off/off drift was 0.068 ms. Over all frames those values were +0.439 / 0.085 ms. The on arm's direct pre+post API-query clocks averaged 0.045 ms per one-step frame. Other timer, render-measurement, scheduling and drift effects remain; no measured scope has been mechanically corrected by the control difference.

## Script draw and viewport engine values

On one-step frames, QA `_draw` callbacks total **2.356 ms/frame** inclusive: main battle layer 1.323, retained foreground 0.510, battle HUD layer 0.320 (96 calls over 233 frames), pulse layer 0.100, retained foreground overlay 0.086, stars layer 0.016. The callbacks are separate CanvasItem draw invocations; the main battle callback prepares retained enemy/flight state, while the retained foreground callback draws it later. They are not a demonstrated removable 2.356 ms. Zero-step callback total was 1.998 ms/frame; multi-step 1.955 ms/frame, the latter too sparse to interpret. Static retained Part `_draw` was not called after warm-up.

Excluding six initial zero readouts while measurements became available, viewport results **reported** in one-step query iterations were root CPU **1.672**, root GPU **0.413**, ship CPU **0.762**, ship GPU **1.702** ms; frame setup CPU was **0.035** ms. Zero-step reports were root CPU 1.653 / GPU 0.409 and ship CPU 0.745 / GPU 1.685 ms; all-frame means were root CPU 1.663 / GPU 0.411 and ship CPU 0.754 / GPU 1.694 ms. Other inventoried viewports returned zero throughout because they were disabled or hidden; zero is not used to infer that root/ship rendering is free.

Viewport values were identical at `frame_pre_draw` and `frame_post_draw` on **438/438** query iterations, but the next iteration's pre value matched the prior post on only 5/437. These counters update between callbacks and can describe an earlier completed frame; the API supplies no frame ID. Treat 0/1/>1 labels above as **query-iteration labels**, not exact GPU-frame labels. Assigning each reported viewport value to the preceding iteration instead moves one-step means to root CPU 1.656 / GPU 0.409 and ship CPU 0.750 / GPU 1.689 ms, without changing the broad conclusion. Frame setup showed the opposite pattern: pre matched prior post on 437/437, so post reports the newly updated setup value. CPU render clocks may overlap draw-callback/engine work; GPU clocks may overlap CPU and each other. The ~2.79 ms `pre→post` wall interval still contains unseparated render submission, GPU completion, driver and wait time. No subtraction of viewport CPU/GPU or callback scopes from it is an exact residual.

## Decision boundary

The one-step full frame spends roughly **5.59 ms** in the off-arm main process, **2.55 ms** between main end and pre-draw, and **2.75 ms** from pre-draw to post-draw. The latter two are a large stable block, but the middle arm locates about 2.36 ms in required script draw callbacks, with separate root render CPU around 1.67 ms and ship GPU around 1.70 ms; these measurements overlap or lag. Static enemy command caching and native retained flight batching already exist. The largest distinct *investigation target* is repeated 3D ship mesh submission in the live `ShipViewport`, which updates every displayed frame. A candidate would batch only mesh/material compatible opaque instances while preserving every transform, shader, shield, exhaust, layering and visual output in the same 3D viewport. It is distinct from the disabled flat compositor and from hiding geometry or reducing projectiles. Existing measurements do not identify how much of the ship CPU/GPU time those compatible instances consume, so this is **not** an approved implementation or a projected ≥0.5 ms gain. Inspect exact instance/material eligibility and isolate that cost before a production patch.

The original busy-frame target is a full displayed frame under 10 ms, with ≥0.5 ms net gain beyond drift before retention. No such gain was measured here.
