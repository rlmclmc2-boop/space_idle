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
- After the deferred-tick correction, a 600-frame native 15-slot wave at 10x measured 0.408 ms average, 0.811 ms peak, zero frames over 17 ms, peak 23 flights and 73.16 MiB static. The 600-frame production group measured 1.139 ms average, 7.641 ms peak, zero frames over 17 ms, peak 22 flights and 0.0167 s pending game time. These are headless CPU measurements on the local machine, not the remaining maximum-load GPU matrix.

## Fixed remaining acceptance list before main review

| Item | Current status | Evidence needed to close |
|---|---|---|
| C01 | Closed | Native manual values and before-contact timing in `_stage6_combat_oracle_probe.gd`. |
| C02 | Closed | `_stage6_shield_timing_oracle_probe.gd` observes one enemy hit at 1.16: shield remains 700 through the 2-second delay and reaches 702.25 after another 0.02 seconds. A single 1.6-second advance settles three beam jumps at due times 1.00/1.25/1.50 for shield 30 and armour 315. |
| C03 | Closed | The same native probe uses two 30-point shields with different resistance, recovery rates and delays plus 100 armour: a 160 raw hit consumes 30+30 shield then 70 armour; recovery totals 15/45 at separate deadlines. A 2.1 raw hit across two shields removes 3 total after one layer rounding. |
| C05 | Closed | `_stage6_reactive_oracle_probe.gd` checks 0.15/0.17-second volley grouping and exact 2.20/2.21-second continuation/reset. `_stage6_guidance_oracle_probe.gd` checks three four-missile native salvos against one and two targets. The first target begins with two guidance layers while the second begins with zero; impacts use one cached factor per target per salvo, then advance independently at the next root. |
| C07 | Closed | `_stage6_targeting_oracle_probe.gd` observes four native missile impacts on one target, alternating distribution on two targets, and no new attack count after the final target dies. |
| C15 | Closed | `_stage6_combat_oracle_probe.gd` rejects first-slot unload without changing slots or native configuration commits, accepts first-slot shield, and unloads the second defence slot on a Cruiser. |
| C08 | Closed | `_stage6_beam_oracle_probe.gd` checks ten 0.25-second due-time ticks in 0.37-second frames: damage grows from 100 at 1.00 to 300 at 3.00 and stays capped. Normal beam death resets charge and hits the next target at 2.25 for 100; endless beam retains charge and hits at 1.50 for 175. |
| C12 | Closed | `_stage6_cannon_oracle_probe.gd` verifies ordinary player cannon immediate 100, enemy cannon delayed 50, Higgs same-clock 3600 on two in-band targets while an out-of-band target remains untouched, and a cannon chain arriving 0.11 seconds after the root. `_stage6_higgs_clear_oracle_probe.gd` freezes three in-band candidates: the first Higgs hit triggers an adjacent enemy explosion that kills the other two, final clear stops subsequent Higgs impact effects, and no post-clear damage occurs. |
| C14 | Closed across native fixtures | The combat probe covers shield-positive/zero-maximum-armour and shield-positive/zero-current-positive-maximum-armour survival. The deferred oracle verifies next-global-tick payment without duplicate payment. The shared-clock oracle verifies recovery/debt before contact. `_stage6_debt_explosion_clear_probe.gd` observes a 3.43 hit leave shield zero and armour 100, followed at 3.50 by recovery/debt, a 100-point cannon hit and 1-point death explosion, final clear and cancellation of the still-pending hostile contact; armour stays 100. |
| CR01-CR05 | Closed | `_stage6_critical_oracle_probe.gd` compares fixed-seed native u1/u2, critical and bonus flags, and exact damage with independent expected values. |
| CR09 | Closed | The same native probe checks B3 gates at E=29/30, 39/40 and 49/50 for critical in positions one through three, each with equipment paid levels 1 and 30. |
| CR06 | Closed | A dormant native drone contribution adds 0.20 to the first-roll probability. Fixed seeds observe non-B3 u1=0.3053991 produce 230 at P=0.45, while B3 u2=0.4407568 still fails the original R=0.25 bonus roll and deals 100. |
| CR07 | Closed | The same native probe checks CR05's failed bonus still writes B1/B2 marks; the next attack matches authored 50% and 10% bonuses. A forced derived repeat inherits the source attack without refreshing marks, while a 3-second interval lets the 2-second B2 mark expire before the next root. |
| C06, C13 | Closed | C06: `_stage6_targeting_oracle_probe.gd` observes an orphaned missile avoid a surviving target; `_stage6_source_snapshot_oracle_probe.gd` removes a drone at 2.40 while its missile flies and checks damage at 3.16 remains attributed to that drone; `_stage6_same_clock_oracle_probe.gd` checks two cannons due at 3.50 cause one root hit, death and drop. C13: `_stage6_combat_oracle_probe.gd` follows shield-only death through full Session frames to the exact return destination with shield restored; `_stage6_rebuild_oracle_probe.gd` sacrifices its only drone on the 1.16 lethal hit, rebuilds 1,700 armour, then confirms 1.66 lethal hit ends the sortie. |
| C04 | Closed | `_stage6_memory_deferred_oracle_probe.gd` arranges zero current shield, 100 armour, 10 memory recovery and 10 debt due on each shared 0.2-second tick. Ten ticks retain zero shield and full armour; the first tick after debt expiry restores 10 shield. `_stage6_same_clock_debt_contact_probe.gd` adds a second hostile contact exactly at the first shared 1.20 tick: memory and debt hold shield at zero, then exactly one 5-point contact reduces armour from 100 to 95. |
| C09-C11 | Open/partial | `_stage6_enhancement_gate_probe.gd` passes 216 authored gate cases: six effects, three A/B nodes, three order positions and just-below/at-threshold values; early stored selections do not alter numeric values, and repeat B2 stays inactive. Native branch behavior and the full legendary interaction matrix remain open. C10 enemy death explosion/source ownership is partially covered by `_stage6_higgs_clear_oracle_probe.gd`: two adjacent deaths carry the Higgs drone source and exactly 100 total damage from the Higgs/explosion sequence. |
| CR08 | Closed | `_stage6_snapshot_oracle_probe.gd` uses CR04/CR05 fixed seeds and changes drone probability after launch. Four missiles and a delayed repeat retain original critical/bonus flags and damage; the repeat applies only its authored multiplier. One native root count remains for both repeat impacts. |
| Display-frame equivalence | Closed for native battle and tested GameSession path | `_stage6_frame_equivalence_probe.gd` runs the same seed and 1,000 fixed 0.01-second business steps with one versus four business steps per presentation frame. Full native persistent state, history, enemy views, 11 settled receipts and two drop entries match exactly. `_stage6_session_frame_equivalence_probe.gd` compares 600 business steps in 1/4-step display frames through the production campaign path; campaign, economy, research, crew, native state, history and notifications match. Its initial failure exposed an accumulated floating-point pending-step boundary, now clamped in `GameSession.frame`. The fixture covers one combat/retreat path, not every economy/save operation. |
| Remaining performance matrix | Partial | `_stage6_max_mount_stress_probe.gd`: runtime maximum Heavy_Battleship 5 weapons/3 defences/4 drones against 15 enemies, mixed missile/cannon/beam plus authored chain/secondary branches, 600 display frames/100 game seconds at 10x; average 0.767 ms, peak 1.438 ms, zero frames over 17 ms, peak 56 flights/44 queued effects/61 flight slots/64 active capacity, 73.30 MiB static. Enemy and player health use Amount 1e1000. Full warehouse, huge MAX purchasing and GPU timing remain open. Configuration discrepancy: ship.para_5 gives Heavy_Battleship capacity 4 while hyperspace hull capacity lists 5; runtime currently uses 4. No authored values were changed. |
| Operator visual acceptance | Open | Human review of tutorial, import, failure, notification and reforge interactions in a live window. Scripted real-window actions and inspected screenshots cover the first four paths. |

### Deferred payment correction

The C14 native `_stage6_deferred_oracle_probe.gd` exposes a previous off-by-one global tick: a hit at clock 1.16 with a 0.2-second payment interval first paid at 1.40. The corrected kernel schedules the first payment at 1.20 and the next at 1.40; the probe checks the 75 -> 72.5 -> 70 shield progression across both boundaries. C14 remains partial because the distinct zero-current, positive-capacity and same-time shield/explosion cases still need a full combined fixture.

## Nonblocking follow-up

## Fixed open scenarios after d02263ff

The following are acceptance gaps, not nonblocking tuning. A passed subset must not close its whole row.

| ID | Remaining concrete scenario and required evidence |
|---|---|
| C09-critical | Native A-node probability changes; existing CR01-CR09 cover the fixed-seed B interactions. |
| C09-proficiency | B1 focus reset after target change and B2 initial-wait behavior; A damage, sustained B1, B2 interval and B3 resistance already pass. |
| C09-repeat | A-node probability; B1 chain root identity across weapon types; B3 secondary-target identity and no-target behavior. Existing cannon chain and delayed repeat snapshot tests cover subsets. |
| C09-adaptation | A capacity; B1 per-source stack growth/reset; B2 cover birth/expiry/recovery order; B3 matching resistance. |
| C09-memory | A heal/buffer values; B1 proc reduction duration; B2 damage-type protection and lockout; B3 armour capacity and shield charge. Shared recovery/debt clocks already pass. |
| C09-deferred | A clearing probability; B1 clearing/reduction duration; B2 probability conversion; B3 forced clearing and damage scaling. Payment scheduling and shared explosion clocks pass. |
| C10 | Verify root/derived AttackId ownership for chain, repeat, secondary and recursive death explosion together; no duplicate kill/drop or recursive derived refresh. Higgs source attribution and cannon explosion clear are passed subsets. |
| C11 | Native prism_tower, strange_matter, wild_missile, dodge_counter, drone_master and black_hole; black-hole/guidance overlap; rebuild with another legend and unload; timers/source selection across replacement and retreat. Scatter/laser-charge overlap and unload/reinstall, precise guidance caching, endless beam, Higgs and single-donor rebuild have passed fixtures. |
| MAX-perf | `_stage6_huge_max_probe.gd` passes a real equipment MAX purchase with Amount 1e1000 balances: paid level 12598, next level rejected for insufficient resources. Measured work 5783.877 ms is an unresolved UI stall; correctness passing does not close performance. |
| GPU/window | Maximum-mount GPU time and human tutorial/import/failure/notification/reforge acceptance. Window enumeration remains an environment limitation; repeated process launches are not acceptance. |

`_stage6_full_warehouse_probe.gd` passes production capacities 200 main/10 overflow: blocked claim leaves full saved state unchanged, freeing one overflow slot permits claim, and duplicate claim adds no drone. Blocked-claim work measured 0.007 ms. This closes the claim-boundary subset, not full warehouse UI/GPU performance.

### Drone capacity source conflict

The design catalog itself records both values: section `hyperspace_config` hull capacity lists Heavy_Battleship=5, while section `ship` lists para_5=4. `Campaign.ship_facts` in `src/systems/campaign.gd` returns para_5; Session passes that result to equip/preview/preset/ship-change operations (`src/game_session.gd`), and `Battle.prepare_player` slices contributions and writes the native descriptor capacity from it (`src/systems/battle.gd`). The current hyperspace owner has no hull-capacity map; its loadout APIs receive capacity from Session. Thus runtime admits four drones and rejects the fifth with DroneCapacityExceeded, reducing the maximum-load fixture to four. Choosing four or five changes authored gameplay; neither table was edited. The duplicated design records require an explicit authority decision before replacing this consumer.

`_stage6_legend_overlap_probe.gd` adds native C11 overlap/unload/reinstall coverage: scatter plus three-source laser charge yields 875 damage, removing charge yields 350, removing both yields 100, and reinstalling both yields 875. Other legendary pairs and rebuild/cooldown combinations remain open. The C14 explosion fixture now uses the existing player cannon, avoiding the earlier extra drone-configuration fixture path; its measured times and amounts are asserted directly rather than treating the old unexpected contact as a kernel failure.

### Native proficiency boundary follow-up

`_stage6_proficiency_native_probe.gd` verifies authored proficiency A1/A2/A3 together, eight B1 focus hits, B2's 1.50 -> 1.05 second interval, and B3 resistance against matching armour. It exposed a native floating-point floor boundary: after three complete focus seconds the old kernel applied two growth ticks (144 damage instead of approximately 173). The kernel now uses the same time tolerance as scheduled boundaries. The new probe and the existing CR01-CR07/CR09 native oracle pass after incremental rebuilding in the existing build directory. Other C09 effects and C10/C11/C14 combination gaps above remain open.

- Deep balance and playfeel tuning across the 0-10000 growth curve requires separate measured gameplay decisions.
- `data/ui_text.json` mentions `level_editor.gd` as a help label; no active editor entry exists in `src`, `foundation` or `run_game.ps1`.
- Local Godot log/certificate/cache warnings and `bin/` are environment or build outputs.
