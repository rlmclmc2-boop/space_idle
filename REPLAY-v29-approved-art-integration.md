# Frozen V29 and approved enemy recognition integration

## Source and scope

Independent candidate source **30d46fcbd5e6f5227c2d1d9b6215f186fb253b79**, two parents main **b02038529552c04f8f65504928ed845ea34e2ea7** and frozen V29 **b4855e35dae1fcaf476f9949b9280671c57ae67e**. No main push/merge. Running frozen root package79 remains unchanged. Auto-merge shared main.gd and battlefield.gd succeeded without text conflicts.

Relative to frozen V29, production script changes are exactly main.gd, battlefield.gd, weapon_visual.gd, enemy_recognition_visual.gd and enemy_protection_geometry.gd, all inherited approved recognition integration. Relative to main, V29 numeric/Excel/importer/time/zero-armour/tier/galaxy gate/hint changes and their QA infrastructure are merged. main-only recognition support scripts and original recognition test are byte-preserved; assets/art_sources/addons have no changed content. Core game.gd/database.gd/presented_battle_game.gd, numeric Excel and data are byte-identical to V29. game_data.json SHA256 **eb9dba486b24b3441b329062f598fa80915513d8c45595d5df6dfaaabbffbd6f**. Cold normal Excel export/gameplay equality and543protected rows pass.

Integration QA fingerprint **dc2005d733cd0f1314c917252f7c33f7dfd1dd016eb08d699b9b1b5fbd3bb843**,798files; frozen fingerprint19c494391ea34a32c4c93b05d41b5f6df04af09c6a5374a2daa8e085657ecc3e,764files. New fingerprint is not called frozen19c494. No integrated wholefresh completion claim.

## Bundles

`progression-v29-approved-art-integration.bundle.base64` decodes2327bytes, SHA256 **186d3367286663cd5ed990c9fb60c2daff0b244c2defe802b1994b7cc3d28766**. Requires both exact parents above. Refrefs/heads/candidate/progression-v29-art-integration points30d46fc. Source delivery Gitcommitca7a8b4b01ba15e03fa790f11ba242cae153acd7.

`progression-v29-approved-art-regression.bundle.base64` decodes235750bytes, SHA256 **bbc15d0cc3d18ccebc81ea009781e07e673ec63a896b428c294c4eacb555d6c5**. Requires30d46fc, evidence source **9f93dd822623811804a33b2a2ced635e1a688e8e**, refrefs/heads/evidence-v29-approved-art-integration-regression. Delivery Gitcommit25d2115c3fa4555e214260bb5e181959cd65bb1b. Includes both raw traces/manifests/run logs, all4actual20wave diagnostics, zero-armour output, renderer report/log, standalone probe and SHA manifests. Both bundles locally git-bundle-verified. New screenshots remain private, not in Git bundle.

Decode base64, verify SHA256, `git bundle verify`, then fetch the named ref into an independent local branch/worktree. main fetch is read-only. Parent already holds frozenV29 source. Godot4.6.3 official7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3; Python3/openpyxl.

## Actual bounded equivalence

Existing native provider trace: entire output identical across packages, including360logicalticks/1301actual provider calls for each declared nativeX1/X10/quality-control case.

Stronger external native15slot probe: nativeX1 andnativeX10 each360logicaltick signatures/1301provider calls/finalstate exact across frozen and integrated. Covers15alive enemies,7dead, slot14,34projectiles,9queuedshots. No target provider call to an already-dead entity observed (do not invent such coverage). Candidate cleanup removes stale deadpose caches max7→0; expected presentation difference, not combat divergence. Explicit recognition projection audits4734+470=5204 leave full combat/resources/RNG state unchanged. Actual launch/mount/target vectors, projectile/queue contents and timing hashes identical.

Same genuine freshclear20 checkpoint, preserved levels/public refits: all4fullwave rows exact across packages, including incoming hits, outgoingdamage, RNG, projectile-settled result and times. Beam60.4500000123s, laser119.6500000244s, missile141.2000000288s, cannon102.2166666875s. Beam remains0.45s above nominal60; no numeric edit. Zero-armour public equip/start/live retreat/recovery cases pass integrated candidate.

Actual unchanged approved renderer test:112checks/0failures/103realframes, ordinary actual scene on OpenGL4.5 Mesa llvmpipe, temporary Xvfb. Confirms geometry/paused/recovery/hit/death/15slotcleanup and renderer leaves game/RNG unchanged. Controlled in-memory encounter/profile, not fullfresh screenshots or device performance benchmark.

## Necessary rerun commands

Build each exact source independently:
```
python test/progression/build_qa.py --scene --output /absolute/new-package
CHRONO_EXPECT_EQ=1 python test/progression/run_entry.py --project /absolute/new-package --entry res://qa/native_chrono_provider_trace.gd --label unique-provider --timeout 900
python test/progression/run_entry.py --project /absolute/new-package --entry /absolute/evidence-source/test/progression/evidence/v29-approved-art-integration/integration_scene_trace.gd --label unique-native15 --skip-import --timeout 1200
```
Use the SAME standalone probe bytes on frozen and integrated packages. Compare native15 result `cases[i].ticks`, `.calls`, `.final` exactly; cache observations/projection audit counts intentionally differ. Probe content hash is in both raw results and manifest. Nothing changes running fullfresh package. Source evidence lives belowevidence, so building evidence9f93 instead30d46 produces same798file fingerprint.

Realcheckpoint wave:
```
PROGRESSION_WAVE_CHECKPOINT=/absolute/save_20.json PROGRESSION_WAVE_STAGE=20 PROGRESSION_WAVE_NODES=9 PROGRESSION_WAVE_WEAPONS=longLaser,laser,missile,cannon PROGRESSION_WAVE_LIMIT_SECONDS=600 python test/progression/run_entry.py --project /absolute/new-package --entry res://qa/late_advantage_waves.gd --label unique-wave20 --skip-import --timeout 1800
PROGRESSION_WAVE_CHECKPOINT=/absolute/save_32.json python test/progression/run_entry.py --project /absolute/new-package --entry res://qa/zero_armour_lifecycle.gd --label unique-zeroarmour --skip-import --timeout 900
```
Root genuine30/32/reach34/forge1 native files are also delivered in v29-root-continuous-fresh-native-30-32-reach34-forge1.json (deliverybfd6298b21653c521b3827a4479fff7c4aabc5fd), wrapperfiles keyednative. Through20 bundlewrapper delivery365945ade59562621ad49e0beff288ecfba18447.

## Private screenshots

New actual integrated physical-armour and large-blue-shield screenshots were rendered, viewed, and retained in private workspace. Library private save failed before preparation with network connectivity; no Library fileids/version invented and no fallback public screenshot upload. private-image-receipts.json records exact295843/261774bytes andSHA256. Source/QA delivery is unaffected. Optional parent local screenshot rerun: with an available X display, run unchanged `test/test_enemy_recognition_visual.gd` on the integrated package, and view `.runtime/battle-physical-armour.png` and `.runtime/battle-large-shield.png`.

These regressions show no observed affected combat difference. They are bounded; do not relabel frozen V29 fullfresh chain as a second integrated wholefresh chain. Append verification if any later geometry/queuedshot/timing discrepancy appears.
