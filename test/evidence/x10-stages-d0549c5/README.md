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

## Cadence correction and next checkpoints

The original600-frame tests supply1/60 wall delta regardless of actual render time. They are equal-work microbenchmarks only. Their100game-sec/51.8wall-sec ratio is not production liveX10 acceptance. All480 measured fixed-input frames exceed16.67ms. No claim of stable60fps or productionX10 full speed is supported. 260checks mean260assertions inside one unlock test, not260independent tests.

New live runs manually pass elapsed real wall time between rendered frames into the actual scene._process; the scene uses its unchanged foreground0.1-second clamp. Rendering and frame_post_draw remain enabled. Live samples150frames, exclude30warmup for quantiles. Each variant starts the same synthetic populated scene. Elapsed input above0.1 is discarded by production; there is no persistent time-debt queue. Sum of discarded wall seconds is reported.

|Live variant|Wall sec|Simulation sec|Effective real-time multiplier|Clamp discarded sec|Main P50/P95 ms|Frame P50/P95 ms|
|---|---:|---:|---:|---:|---:|---:|
|live-baseline|34.672|149.16670|4.302|19.548|149.613/238.644|201.725/294.928|
|live-reconcile|30.121|149.16670|4.952|15.012|115.819/220.424|163.555/276.795|
|live-quality|27.075|148.85538|5.498|12.010|120.334/203.578|155.049/239.683|

Baseline is d0549c5. Reconcile checkpoint a4d84e2 resolves common branch choice/gate eligibility once per synchronous module reconciliation, retains nothing across calls/ticks, preserves original full reconciliation order and exact1/60 substeps. Fixed600 frame and live150 frame gameplay traces match baseline exactly. X1 headless240-frame protection pair also matches every trace/final field. Existing branch regression146assertions passes. No high-speed approximation was introduced.

Ship-quality checkpoint3b30189 builds on a4d84e2. At speed>=10 only, disables player viewport4xMSAA and directional shadows; below10 restores both. Same viewport size, camera, launch coordinates, models, every-frame rendering, pause/hidden policies. Quality transition regression51assertions passes. Actual rendered image inspected. Fixed600-frame gameplay trace exactly matches a4d84e2. Live quality run differs in supplied wall deltas and has148.85538 vs149.1667game-sec: damage/hits/RNG/receipts/stage/group/state/player match; fire events4326vs4325. Do not call these different-cadence runs strict trace equivalence. Same-delta replay is being added. Main fixture records zero body damage due enormous high-level defense; its equal survival alone is weak pressure coverage, so an additional isolated hostile-pressure exact pair is being added.

The entire battle remains visible and continuously rendered. These are cloud llvmpipe measurements and do not establish Windows gain. Largest live bottleneck is now simulation feedback under long real deltas (mainP95>200ms), not merely MSAA. Full coarse stepping remains rejected. Further synchronous membership reuse is being measured, not published here as verified yet.

## Final exact production checkpoint / interruption handoff

Formal branch perf/x10-main-path-checkpoint at0b6bd199577d9f837eefe69050ccd759bc92c7da. Incremental source commits after cache: a4d84e2 (common branch eligibility);3b30189 (X10MSAA/shadow reduction, full-resolution every-frame viewport);a4bf9f9 (one scalar membership query per weapon reconciliation);0b6bd19 (all5tubes per8slots transition coverage and test routing). All pushed; main untouched. No diagnostic switches in production. No coarse full-game stepping or half-resolution viewport kept.

Final uninstrumented fixed600 inputs: mainP50/P95/max24.438/36.882/49.174ms; entire frame58.474/74.248/92.433ms; wall36.824122sec.600/600 gameplay traces match d0549c5. This is equal-work evidence, not live full-speed acceptance.

Final live150 inputs: wall24.590494sec,143.44829game-sec, effective5.8335x,10.099161sec foreground-clamp loss. After30warm frames: mainP50/P95/max99.927/190.630/234.628ms; frame136.747/229.310/271.946ms. All120measured frames exceed33.333ms. Battlefield continuously rendered. Different live cadence is not a strict before/after semantic pair.

Same captured live delta replay:150/150 trace rows and every gameplay final field identical, including weapon/defense timers, module damage, memory buffers, deferred buckets/ticks, player health, receipts and RNG. X1 standalone protection:240/240frames/final fields identical. High incoming damage fixture: initial hostile dmgMultiple normalized to100x player armour per weapon via original attack-ratio calculation, all defenseBnodes enabled, original hostile fire path retained.60/60same-input frames/final fields match; incoming9.403056992629715e22,9hostile impacts,1RETREAT. Thus actual death/reset was exercised, not just zero-damage survival. Regular lightweight pressure fixture also240/240equal but zero body damage, and is not used as death proof. Branch regression146assertions and final quality transition179assertions pass.

## Latest complete inclusive phases

Final instrumented same600-frame fixture,480afterwarmup; nested phases cannot be added.

|Phase|ms per measured frame|Calls|
|---|---:|---:|
|main.advance_game_time|21.408|480|
|game.tick|21.323|5163|
|presented_battle_game.tick_projectiles|8.674|5163|
|game.tick_projectiles|8.022|5163|
|presented_battle_game.advance_custom_projectile|6.825|235103|
|game.advance_jewel_repair|4.165|5163|
|enhancement_branches.advance_weapons|3.607|5163|
|enhancement_branches.advance_defense|2.170|5190|
|game.advance_hightech|1.093|5163|
|game.sync_enhancement_buffers|1.024|5454|
|main.refresh_draw_layers|0.577|480|
|main.draw_battle|0.397|480|
|game.sync_jewel_defence_damage|0.368|5322|
|game.jewel_attack|0.298|2420|
|main.refresh_visible_cards|0.282|480|
|game.advance_jewel_repeats|0.133|5163|
|main.on_event|0.073|5206|
|game.advance_planets|0.053|5163|

Remaining largest identified child is projectiles8.674ms, player missile physics6.825ms. Full-game1/60 and missile packet due-time boundaries remain intact.

## Rejected / unreviewed experiments

Half-resolution X10 viewport with all projection readers compensated:600/600 gameplay matches, but whole-frameP9574.248→75.954ms and wall36.824→36.751sec (no useful gain). Rejected and reverted. Production retains original physical resolution and projection paths.

UNREVIEWED-projectile-30hz.patch is ISOLATED DIAGNOSTIC ONLY, not in formal production branch. It merges only friendly prototype missile kinematics at selected speed>=10 after accumulating~1/30game-sec; individual merged interval may reach1/20due to remaining1/60 packet-bound steps. Keeps full game/attack/recovery stepping exact. A pending interval is flushed with<=1/60pieces after speed falls below10. Speed transition/X1/lifecycle validation for this candidate is NOT complete. Do not apply or publish as accepted.

One rendered same100game-sec seed1701 candidate: mainP9536.882→31.197ms; whole frame74.248→69.237ms; wall36.824→35.337sec. Damage−0.956968%,hits2751→2748,fire3275→3276. Rewards267iron/6uranium,stage1/group9/COMBAT,attack count,health and final RNG equal. Two additional isolated headless same100game-sec pairs:1702damage+0.567841%,hits1994→2002,rewards877/6,stage2/group2/TRAVEL;1703damage+0.111289%,hits1842→1843,rewards877/6,stage2/group2/TRAVEL. Both playerhealth/retreatcount/attackcount/RNG equal. Headless runs are semantic checks only. These three bounded cases do not prove a global<=1% bound or long-run safety. Candidate cannot yet be accepted.

At interruption request executor commands still worked; all tests completed, no process awaiting completion, no new environment created. Next steps require reviewing delivered exact changes and deciding whether to finish this isolated physics candidate's transition/lifecycle/live validation. X10 stable usable target remains unmet; queued UI work remains pending.

## Exact checkpoint release and rejected refined motion

Published main: `8cc7f4a2f03344b91b5c1b1b942f996b5aea8671`, merge tree equal to reviewed `0b6bd199577d9f837eefe69050ccd759bc92c7da`. Independent release scripts passed 260+146+179=585 assertions. Rich X1 protect1 same-state pair: all240 per-frame rows and final gameplay state equal, including memory/deferred elapsed, defense timers, buffer/deferred/module damage, weapon stack timers and RNG. Incoming damage7.192213233498253e20,20deferred ticks,11nonempty debt frames,229nonempty buffer frames. See x1-protection-publish and release logs.

Refined X10 missile motion candidate completed lifecycle checks but is REJECTED and removed from production. Same captured143.44829game-sec delta replay: damage−0.290386%; iron5083→5077; stage2same but group6→7/TRAVEL→COMBAT; root attacks1000785→1000779; fires4178→4158; deferred ticks197→196; defense exposure39.4320267→39.3986933sec; memory/deferred phase .0320267→.1986933sec (cyclic phase); RNG and critical stack/timers differ. Threat pair10game-sec: identical death damage/player health/retreat1, but group1→2/TRAVEL→COMBAT and root attacks1000023→1000015. Final reward/damage closeness cannot bound these progress/timer effects.

Refined live candidate150frames improved effective multiplier5.833485→6.797162 and wall24.590494→20.773415sec, but all120 measured frames still>33.33ms and semantic checks failed the provisional progress constraint. This is not an accepted performance result. Patches/tests retained only as rejected diagnostics; do not apply. No Windows performance claim. Performance objective stays open.
