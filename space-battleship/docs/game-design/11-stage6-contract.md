# Stage 6 implementation and acceptance record

[Design entry](README.md) defines the rules. This page records implementation and measured verification. `bin/`, generated configuration, imported Godot resources, screenshots, and local saves are test outputs.

## Implemented

| Area | Current behavior | Verification |
|---|---|---|
| S01/S02 save | One background writer publishes validated A/B snapshots, tracks generations and dirty state, and reports failed writes. A session saves the hash of the configuration bytes it initialized from. Writers refresh the on-disk generation and reject older queued jobs. | `_save_files_probe.gd`, `_stage6_session_probe.gd`, `_stage6_page_probe.gd`: flush, write, pointer, close, retry, config change and stale-preview cases. |
| S03/S04 candidate | Checksums, schema, module state, native IDs and filters are checked before a candidate replaces the live session. Import confirmation first writes and waits for a recoverable snapshot of the current session. Failed backup leaves the live session and preview in place. Failed candidate persistence is visible and retryable. | Session and page probes cover invalid import, invalid filter, old-session preservation, backup recovery and replacement failure. |
| S05/S06 recovery | Native persistent history and ID watermarks, checkpoint rebuild, pending drops, paid time, pause reasons, tutorial and offline credit restore. | `_stage6_checkpoint_probe.gd`, `_stage6_session_probe.gd`. |
| Configuration publication | One compiler validates real production workbooks, including positive hyperspace step and precision and probability within 0..1. Invalid candidates leave the active JSON unchanged. | `python -m unittest test_publish`: 32 tests passed, including three parameter negative cases. |
| Player pages | Settings persist separately: tutorial skip, music, effects, damage labels, autosave interval and preferred page. New game offers explicit keep/reset settings. Guidance, notifications, save status, import and reforge have page controls. | `_stage6_settings_probe.gd`, `_stage6_page_probe.gd`, `_stage6_window_ops_probe.gd`. |
| Battle presentation | Native receipts carry settled Amount damage to capped presentation labels. Visible controls and rendering do not decide combat. | Pinned native build, `_stage6_combat_oracle_probe.gd` C01, real OpenGL window probes. |

## Measured acceptance evidence

- Native C01 manual oracle: before contact damage 0; shield damage 30 and armour damage 40 at contact. Death/drop occurs once in its probe.
- Real OpenGL window on NVIDIA RTX 2060: 3,600 frames / 64.84 s; p95 frame wall 18.946 ms, p99 18.978 ms, two frames over 33 ms, one over 100 ms, peak 50 draw calls, 19 damage labels, 18 flights, 0.016661 s pending game time, 112.46 MiB static and 13.85 MiB video memory. The 60 fps cap explains most frames over 17 ms.
- Headless dense production 15-slot group at 10x: 4,800 frames / 784 game seconds; average work 1.20 ms, peak 11.55 ms, no frames over 17 ms, 22 peak flights and 0.0167 s peak pending time. Combat occupies 1,207 frames, so this is not sustained dense combat.
- Separate sustained native 15-slot wave at 10x: 3,600 frames / 600 game seconds; average work 0.462 ms, peak 1.235 ms, no frames over 17 ms; average 18.88 and peak 23 active flights, peak 16 queued native effects, 25 flight slots, 32 active and feedback capacities, 73.15 MiB static memory. This keeps the same wave alive; it does not measure full campaign progress.

## Remaining before main review

1. Complete the design's independent C02–C14 and CR01–CR09 manual expected-value matrix with the same native kernel and headless/GPU settlement comparison. The C01 result and current probes cover only a subset.
2. Complete the remaining performance matrix: maximum equipped slots and drones, burst/chain/beam combination, full warehouse, huge MAX, native allocation and GPU time. Existing long runs cover a sustained 15-slot wave and ordinary GPU presentation.
3. Operator-driven visual acceptance of live window flows remains outstanding. Scripted real-window actions and screenshot inspection covered guidance, growth, picker, failure status, notifications and battle, but did not establish all human interaction and reforge paths.

## Nonblocking follow-up

- Deep balance and playfeel tuning across the 0–10000 growth curve requires separate measured gameplay decisions.
- `data/ui_text.json` mentions `level_editor.gd` as a help label. No active editor entry exists in `src`, `foundation` or `run_game.ps1`.
- Local Godot log/certificate/cache warnings and `bin/` are environment or build outputs.
