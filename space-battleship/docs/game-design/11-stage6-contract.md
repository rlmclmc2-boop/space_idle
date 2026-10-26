# Stage 6 implementation and acceptance record

[Design entry](README.md) defines gameplay rules; [verification](07-verification.md) defines the acceptance matrix. This page records actual coverage. `bin/`, generated JSON, Godot import metadata, screenshots and local saves are test outputs.

## Implemented and verified

| Area | Evidence |
|---|---|
| S01/S02 async save, generation, dirty state and write failure | `_save_files_probe.gd`, `_stage6_session_probe.gd`, `_stage6_page_probe.gd`. Frozen initialization config hash, stale candidate generation, backup, writer failure and retry are asserted. |
| S03/S04 candidate validation and live-session preservation | Session and page probes reject malformed checksum, state, filter and configuration. Import confirmation persists the unsaved old session first; failed backup keeps it live, failed candidate write is visible and retryable. |
| S05/S06 checkpoint, offline and time recovery | `_stage6_checkpoint_probe.gd` and `_stage6_session_probe.gd`: native history/ID watermark, rebuilt battlefield, pending drops, paid time, pause reasons, tutorial and offline credit. |
| Configuration publication and startup | `config_tools/hyperspace_parameter_contract.json` is read by the compiler and GameSession. All 40 registered keys have type, magnitude and applicable range checks. Fixed values, hard caps, authored-stage references and capacity relations are checked by both entries. Affix and legendary random intervals must contain a value on the configured sampling lattice, with both indices inside the signed 32-bit `randi_range` bounds. Invalid workbook publication preserves the active JSON. Invalid startup and import config is rejected before gameplay initialization. The publication suite and session probe verify both runtime paths. |
| Player pages and controls | `_stage6_settings_probe.gd`, `_stage6_page_probe.gd`, `_stage6_window_ops_probe.gd`: separate settings, new-game keep/reset, guidance pause, notifications, save and import, growth/return and file picker. The real-window probe isolates player settings. |
| Native battle presentation | Receipts carry settled Amount damage into bounded labels. C01 manual oracle, single death/drop and no-target assertions run against the same native kernel as the game. |

## Measured runs

- C01: zero damage before contact; shield loses 30 and armour loses 40 at contact. The native oracle also checks shield-only sortie/depletion and first defence slot empty/refit behavior as partial C13/C15 evidence.
- Real OpenGL on NVIDIA RTX 2060: 3,600 frames / 64.84 s; p95 wall 18.946 ms, p99 18.978 ms, two frames over 33 ms, one over 100 ms, peak 50 draw calls, 19 damage labels, 18 flights, 0.016661 s pending game time, 112.46 MiB static and 13.85 MiB video memory. The 60 fps cap explains most frames over 17 ms.
- Production 15-slot group at 10x: 4,800 headless frames / 784 game seconds; average work 1.20 ms, peak 11.55 ms, zero frames over 17 ms, 22 peak flights, 0.0167 s peak pending time. Combat occupied 1,207 frames.
- Sustained native 15-slot wave at 10x: 3,600 frames / 600 game seconds; average work 0.462 ms, peak 1.235 ms, zero frames over 17 ms, average 18.88 and peak 23 flights, peak 16 queued effects, 25 flight slots, 32 active and feedback capacities, 73.15 MiB static memory. This holds one wave alive; it does not measure full campaign progress.

## Fixed remaining acceptance list before main review

| Item | Current status | Evidence needed to close |
|---|---|---|
| C01 | Closed | Native manual values and before-contact timing in `_stage6_combat_oracle_probe.gd`. |
| C07 | Closed | `_stage6_targeting_oracle_probe.gd` observes four native missile impacts on one target, alternating distribution on two targets, and no new attack count after the final target dies. |
| C15 | Closed | `_stage6_combat_oracle_probe.gd` rejects first-slot unload without changing slots or native configuration commits, accepts first-slot shield, and unloads the second defence slot on a Cruiser. |
| C14 | Partial | The same native probe starts with shield current health and zero maximum armour, then equips an armour module at zero current health and positive maximum; neither state is treated as depleted. Expiring deferred payment remains open. |
| CR01-CR05 | Closed | `_stage6_critical_oracle_probe.gd` compares fixed-seed native u1/u2, critical and bonus flags, and exact damage with independent expected values. |
| CR09 | Closed | The same native probe checks B3 gates at E=29/30, 39/40 and 49/50 for critical in positions one through three, each with equipment paid levels 1 and 30. |
| CR07 | Partial | The same native probe checks CR05's failed bonus still writes B1/B2 marks; the next native attack is about 1.65 times the equal-seed unmarked reference, matching authored 50% and 10% bonuses. Expiration and derived attacks remain open. |
| C06, C13 | Partial | C06: `_stage6_targeting_oracle_probe.gd` kills one of two targets mid-salvo and sees the orphaned missile avoid the surviving target; source change and same-time double hit remain open. C13: rebuild failure and return destination remain open. Existing probes cover shield-only sortie/depletion. |
| C02-C05, C08-C12 | Open | Independent authored values and event order in real native fixtures, including beam timing, multi-layer defences, reactive stacks, enhancement branches and cannon/Higgs. |
| CR06, CR08 | Open | Fixed documented seeds and actual u1/u2 observations, critical/bonus flags, damage and snapshot inheritance from the native kernel. |
| Display-frame equivalence | Open | Same seed and fixed business steps with different draw-frame grouping; compare settlement, drops, IDs and state. |
| Remaining performance matrix | Open | Maximum enabled slots/drones, burst/chain/beam, full warehouse and huge MAX with native allocation and GPU time. Existing long runs only cover a sustained 15-slot wave and ordinary GPU presentation. |
| Operator visual acceptance | Open | Human review of tutorial, import, failure, notification and reforge interactions in a live window. Scripted real-window actions and inspected screenshots cover the first four paths. |

## Nonblocking follow-up

- Deep balance and playfeel tuning across the 0-10000 growth curve requires separate measured gameplay decisions.
- `data/ui_text.json` mentions `level_editor.gd` as a help label; no active editor entry exists in `src`, `foundation` or `run_game.ps1`.
- Local Godot log/certificate/cache warnings and `bin/` are environment or build outputs.
