# Native chrono production fix: isolated causes and bounded regressions

Original failure preserved in `../native-chrono-provider-trace` and native700 baseline: same X1 budget,885 vs883 kills and different RNG. Root causes were rendering fx/demo clocks advancing once per render, turret updates skipped between accelerated logical ticks, fast-mode fire handling skipping the mount's target state, and formation animation age being initialized lazily by render visits.

Production fix moves the canonical carrier/target/turret inputs to every fixed1/60 game tick. It retains historical X1 ordering (carrier pose, fx/turret update, combat tick), initializes all formation members at the previous logical boundary, and retains firing target updates before suppressing fast-mode visual/audio work. Original X1 display/provider trajectory is preserved in the controlled trace. The ordinary main scene without canonical providers keeps its existing frame behavior. Full scene/event-hook QA Driver remains intact.

Final validation:
- `logical-enemy-age-imported-trace`: seed1701,360 logical kinematic inputs match between nativeX1/X10;1301 actual target/launch calls match, including forced-X1 viewport-quality control; original pre-fix X1 actual calls and RNG unchanged. Package fingerprint7f54969ded3d4c6c8fa163d80e985fc70c60392fd066ad46e3ee4151b59bd3f0.
- `final-chrono-budget700`: offline600+online100=700 X1 seconds, remainingchrono0; nativeX1/nativeX10 both885kills/1death, exact resources/RNG equality. No actions, controlled missile farm.
- `final-native-driver-fresh900`, `final-native-driver-late30900`: full event hook and geometry, native production frame vs QA Driver, every-second exact combat/resources/RNG/research/queues/crew/planet/galaxy signatures for900 seconds. Late checkpoint is a cross-version legal30 saved profile, not fresh completion. Legacy BALANCED decisions are identical in both paths; this is engine validation, not human-strategy acceptance.
- `late30-native-chrono-all-lines60`: TWO native production frame paths,54 offlinechrono+6online=60 X1seconds,360 shared boundaries match complete signatures. This30 snapshot has active equipment-upgrade crew and a freshly unlocked planet; its planet/galaxy queues are not yet running. `active-planet-shipyard34-chrono60` also passes360 shared boundaries with active auto exploration, navigator, shipyard construction at69/180 and assigned engineer, scientist assignments, and equipment-upgrade researcher; do not interpret locked galaxy state as active galaxy equivalence proof.

Intermediate pose-only and pose-plus-fire iterations are preserved. Their provider/input mismatches are retained even though some later combat outputs matched. `logical-enemy-age-provider-trace` is an INVALID cache-copy run, rejected for SVG resource-loader SCRIPT ERROR; own editor import and a new label repaired infrastructure. Its old partial runtime payload was superseded by the retry, so only the actual failed log/manifest is retained. `run_entry --skip-import` now requires a successful own-project import marker with matching path and manifest fingerprint; a copied .godot cache alone cannot authorize skipping import.

Reproduce with Godot4.6.3 official7d41c59c4:
```
python test/progression/build_qa.py --scene --output /tmp/chrono-qa
CHRONO_EXPECT_EQ=1 python test/progression/run_entry.py --project /tmp/chrono-qa --entry res://qa/native_chrono_provider_trace.gd --label provider --timeout 300
python test/progression/run_entry.py --project /tmp/chrono-qa --entry res://qa/native_chrono_budget.gd --label budget700 --skip-import --timeout 1200
PROGRESSION_COMPARE_SCENE=1 PROGRESSION_COMPARE_DURATION=900 python test/progression/run_entry.py --project /tmp/chrono-qa --entry res://qa/test_progression_scene_equivalence.gd --label fresh900 --skip-import --timeout 3600
PROGRESSION_CHRONO_CHECKPOINT=/absolute/save_reach_34.json python test/progression/run_entry.py --project /tmp/chrono-qa --entry res://qa/native_chrono_late_equivalence.gd --label active34 --skip-import --timeout 1800
```
Use supplied checkpoints and each immutable run.json/manifest to reproduce their exact versions. Current numerical v18 differs from17 only35–220 enemy ratios via source/formula dependencies; these timing fixtures use stages≤34. Validated scopes remain bounded, not a claim of all frame rates, every weapon/planet/active galaxy, or one-version whole journey. Only test infrastructure was briefly SIGSTOPped for4-core CPU contention; X1 clocks unchanged, all resumed.
