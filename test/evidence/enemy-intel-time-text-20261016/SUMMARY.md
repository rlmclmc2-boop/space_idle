# Exact enemy-intelligence time text

The page now supplies integer milliseconds for enemy weapon cooldown, shield-recovery delay and reactive-armour reset time. The three authored UI templates no longer append a fixed “秒” suffix. The actual values and combat calculations remain unchanged: 2.2 seconds appears as 2200 毫秒, 1.8 seconds as 1800 毫秒, and 0.5/0.2/1.0-second cooldowns as 500/200/1000 毫秒. Current authored timer values all have exact whole-millisecond representations; the targeted data test checks that invariant before formatting.

`enemy-intel-page.log` records 32/32 real page checks, including exact reactive, recovery and cooldown text and no redundant seconds suffix. The UI text catalog validates all 2361 rows. `reactive-2200ms.png` and `recovery-1800ms.png` show those states in the actual stage-three main scene. Godot reported a 1600×1000 root/window and saved 1554×1000 render textures; the screenshots retain their actual PNG size.

The final five-suite presence control in `enemy-intel-final-perf-20261016` samples source commit `e4c2543e`. This follow-up changes only page text formatting, three UI text strings and focused tests; no combat or frame-loop path changed. Per parent direction, the five suites were not rerun. The existing full-frame-under-10ms limit and the two baseline `test_resource_display.gd` failures remain as reported there.
