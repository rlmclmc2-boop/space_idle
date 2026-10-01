# X10 exact lookup optimization checkpoint

Base: 2669df8452701749b3ce347b1e3de67d150a9504
Production: d0549c5 (perf/x10-hotspot-2669df8)

Only production change: cache positive unlock identities by kind/target. Every hit validates the live row; gate levels and availability are never cached. Missing keys are not retained. Per-kind positive storage is capped at 128. Authored unlock targets are unique. Runtime/save/attack/RNG/recovery stepping and graphics are unchanged.

## Controlled rendered comparison
Godot 4.6.3 Linux Compatibility, Mesa llvmpipe, 1373×883. Actual main scene: heavy hull, 8 missile weapons +4 defense modules, populated enemies with their weapons, shared enhancement 30 and equipped modules 150. Main equipment page, upgrade +1, speed X10. Private project and user data; no player save. Manual process delta 1/60 per rendered frame, 600 frames =100 game seconds. Exclude first120 warmup frames for timings. Battlefield remains rendered with original ship viewport, MSAA and shadow settings.

| Uninstrumented metric ms | Base P50/P95/max | Fix P50/P95/max |
|---|---|---|
| Main |39.221 /56.470 /70.135|32.371 /44.690 /68.397|
| Entire rendered frame |91.579 /115.602 /157.931|82.018 /102.025 /150.373|

Main P95 reduced20.86%; whole-frame P95 reduced11.74% in this single controlled cloud pair. Instrumented independent pair also improved (main P9556.225→48.239). These are cloud software-renderer measurements, not a prediction for Windows/RTX3090. X10 remains below stable60fps; optimization is a verified partial improvement.

All600 frame traces exactly match for damage/hits/attack count/RNG/projectile count/queued launches/repeats. Every final gameplay field exactly matches, including received resources iron267/uranium6, stage1/group9/COMBAT, damage1.152682583352923e28,2751 hits,3275 fire events. No save, timing or semantic approximation introduced. Focused unlock regression:260checks/0fails, covers authored mapping, live gate edits, removal/replacement/renaming, source table replacement, unknown queries and bounded positive retention. git diff --check clean.

## Hotspot / rejected work
Instrumented X10 baseline performs5163 full game ticks in480 measured real frames; PresentedBattleGame.tick repartitions into1/60 despite outer1/15. Inclusive average per measured frame: tick35.75ms, repair10.455, weapons10.157, defense8.180, projectile9.011. Repeated weapon/defense reconciliation repeatedly performs unlock-table scans. Nested stages cannot be summed.

A coarse1/15 PresentedBattleGame candidate reduced mainP95 to27.868ms but was REJECTED and reverted: equal100game-second receipts iron1555 vs fixed-step reference267, clear-state divergence, even though damage differed under1%. Rejected patch is evidence only, not part of fix.patch. X1 equal-time reference yielded iron282 and LEVEL_CLEAR versus existing X10 iron267/COMBAT; this pre-existing speed discrepancy is not fixed by the identity cache. Never present coarse results as accepted optimization. Graphics probes on rejected coarse model were not accepted changes.

## Reproduction
Apply fix.patch to base. Regression: copy project runtime + addons into an isolated project, import, copy test/test_unlock_lookup.gd to its root, then run godot --headless --path ISOLATED --script res://test_unlock_lookup.gd with isolated XDG user dirs. Reuse the included probe.gd in a copied actual project for rendered tests. Scripts contain original workspace paths and local import-cache convenience: adapt root/work paths to your checkout; use this included xorg.conf rather than an unrelated working directory. setup.py installs inclusive instrumentation, so for final uninstrumented pairs restore main.gd/game.gd/presented_battle_game.gd/enhancement_branches.gd from production and use the corresponding base/candidate database.gd. run.py owns display96 and outputs to its work directory. Do not run other CPU loads concurrently. accuracy.py is headless equal-time semantic evidence, not rendering/performance acceptance.

Files are synthetic fixture evidence only. No user raw logs or saves included. Original Library samples could not be materialized in prior blocked route; Windows summary provided by parent was used only as direction, not the basis of this measured cloud claim.

## Complete inclusive phases

Each reported phase is inclusive; parent/child timings overlap. 480 measured frames after120 warmup.

|Phase|Baseline ms/frame|Cache ms/frame|Baseline calls|Cache calls|
|---|---:|---:|---:|---:|
|main.advance_game_time|35.847|29.579|480|480|
|game.tick|35.746|29.484|5163|5163|
|game.advance_jewel_repair|10.455|8.111|5163|5163|
|enhancement_branches.advance_weapons|10.157|7.524|5163|5163|
|presented_battle_game.tick_projectiles|9.011|8.778|5163|5163|
|game.tick_projectiles|8.304|8.098|5163|5163|
|enhancement_branches.advance_defense|8.180|6.061|5190|5190|
|presented_battle_game.advance_custom_projectile|7.046|6.885|235103|235103|
|game.advance_hightech|1.481|1.157|5163|5163|
|game.sync_enhancement_buffers|1.235|1.019|5454|5454|
|main.refresh_draw_layers|0.600|0.619|480|480|
|main.draw_battle|0.403|0.406|480|480|
|game.sync_jewel_defence_damage|0.398|0.385|5322|5322|
|game.jewel_attack|0.380|0.295|2420|2420|
|main.refresh_visible_cards|0.333|0.285|480|480|
|game.advance_jewel_repeats|0.143|0.133|5163|5163|
|main.on_event|0.083|0.076|5206|5206|
|game.advance_planets|0.060|0.056|5163|5163|

## Actual complete600-frame runs

|Run|Wall seconds|Sum frame intervals seconds|Sum synchronous logic seconds|
|---|---:|---:|---:|
|baseline|57.958489|57.827511|24.073543|
|lookup-candidate|53.311269|53.174547|20.218108|
|final-baseline|56.914877|56.819777|23.487443|
|final-candidate|51.801937|51.706360|19.159101|

Frame interval includes synchronous logic plus waiting for frame_post_draw. The remainder is not GPU time: it includes engine/render submission, software rasterization and scheduling. With cache, complete run is51.802wall seconds for100 game seconds (effective1.930x real time despite selectedX10), about11.58 observed rendered frames/second. Main synchronous work totals19.159s; approximately32.55s lies outside that measured function. Thus rendering/engine waiting is now the largest whole-frame segment; logic still about32msP50/45msP95. The full live player viewport uses4xMSAA and directional shadow; accelerated mode already suppresses many2D effects. Next isolated probes preserve all gameplay/muzzle poses and continuous viewport rendering, reducing only MSAA and shadow quality atX10. No cadence reduction/freeze is accepted.
