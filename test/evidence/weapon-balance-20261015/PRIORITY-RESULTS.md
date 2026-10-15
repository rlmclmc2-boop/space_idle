# Priority 350/170/1200/0.25 candidate: narrow verification

**Status:** isolated test override and opening-design evidence, not authoritative Excel/JSON adoption. Pulse 350 damage / fixed 1.5 s, missile 4 × 170 / 2.4 s with its existing 0.4 s opener and same-target concentration, cannon 1200 / 3.5 s, and beam 35 every 0.25 s with 1 s charge and an additive 1x→3x ramp were used. The low-swarm, missile single-survivor, and beam comparisons that did not change from the [previous probe](FOUR-WEAPON-RESULTS.md) were reused, not repeated.

Thirty new rows form 15 old/native pairs. Every native configuration admitted through the compiled owner, performed attacks, cleared its target, and handed off once. Clear state and hit count agree in all 15 pairs. Old/native clear clocks retain small known scheduling offsets; no exact clock equality is asserted. Each run used 1x speed, a level-1 single weapon slot, fixed seed 1729, no enemy attacks, the production stat cache, and a 60 s ceiling. The two selected `1e40` comparisons are the only added scale checks.

## Physical cannon versus physical missile on energy-resistant heavies

All targets have energy-resistant hull, so neither physical weapon is reduced. Times are seconds; `advantage` is how much longer missile takes than cannon, divided by cannon time. The 5000-HP near tie was deliberately retained.

| Two targets, HP each | Old missile | Old cannon | Cannon advantage | Native missile / cannon | Hits old/native, missile / cannon |
|---:|---:|---:|---:|---:|---:|
| 5000 | 35.47 | 35.17 | **0.9%** | 35.22 / 35.00 | 60 / 10 |
| 6500 | 47.32 | 42.20 | **12.1%** | 46.98 / 42.00 | 78 / 12 |
| 8000 | 57.22 | 49.23 | **16.2%** | 56.82 / 49.00 | 96 / 14 |

At nominal `1e40`, the 6500-HP pair repeats the same 78 missile and 12 cannon hits and the same executor-specific clear times and ranking. Cannon's first hit was 3.5 s; missile's first impact was about 1.217 s. The long-run 1200/3.5 versus 4×170/2.4 budget gives cannon **21.0%** more raw sustained output, but its slow opening and discrete fifth hit explain the 5000-HP near tie. Across the two larger separated samples it has a meaningful observed margin; the small sample does **not** prove every heavy HP in between or every upgrade arrangement favors cannon. Do not place enemy HP just inside one hit boundary to manufacture the role. The user does not require identical extreme-scale last-hit counts, so the acceptance question is the broad winner relation.

## Pulse 350, type relation, and recovering shield

Six-target hull groups at 260 and 400 HP produce old pulse times **9.10/18.20 s** against physical resistance and **18.20/27.30 s** against energy resistance. Native times are 9.02/18.02 and 18.02/27.02 s. Hit counts are 6/12 and 12/18 respectively. For these sampled HP, the 350 pulse takes **the same number of hits and the same times as the prior 300 pulse**; the 16.7% authored increase does not become a visible time gain on every target. Reusing unchanged 170-missile and 0.25-s-beam rows, physical-resistant 260 HP still favors pulse (9.10 s versus beam 12.00 and missile 13.72), while physical-resistant 400 HP favors beam (15.00 versus pulse 18.20). Energy-resistant 260/400 HP favor missile (6.47/11.07 versus pulse 18.20/27.30). These are two type samples, not an every-target hierarchy. The selected physical-resistant 260-HP pulse case retains its 6 hits and 9.10/9.02 s old/native times at `1e40`.

Against the test-only dual-layer 1100-HP + 600-shield fixture (physical-resistant shield, energy-resistant hull, 25% of maximum shield per second after 1.0 s without a hit), pulse 350 clears in **15.17 s old / 15.02 s native** with 10 hits; the old executor measured 697.5 regained shield. Cannon 1200 clears in **14.07/14.00 s** with four hits and 1132.5 regained shield. Reused unchanged missile 170 and beam 0.25 s results are **13.60/13.50 s** and **8.25/8.27 s**; beam prevents regeneration in the old measured fixture. All four make progress. This is *not* the draft shield's authored 8%/1.8 s recovery, and beam is not unlocked in the first three stages, so the result must not become a stage-3 beam requirement.

## Consequence for the opening proposal

The candidate now has evidence for its two-layer design: type is primary on representative exposed hulls, with missile handling distributed low targets and cannon gaining a measured margin on larger same-type energy-resistant heavies. The 5000-HP near tie stays visible. Pulse 350's impact is discrete and may be muted on some short encounters. All claims are limited to no-incoming-damage target probes; player net damage, upgrades, collectible resource timing, boss-entry HP, and the 18-point route require a separate short validation after authoring. No current-level row was mounted or changed here. The Windows test window was released after this serial run.

`priority-budget-candidate.jsonl` contains all 30 rows and `raw/priority-budget-candidate.txt` is the unfiltered isolated Godot output, SHA256 `d71427e7c8f697de8524be152930913f5fe09c51da77b704edfab9de9cf70385`. The native DLL hash and build provenance are in [BUILD.md](BUILD.md). Reproduce in an agreed serial window with `SPACE_BALANCE_PRIORITY_BUDGET=1` and `python test/run.py probe_weapon_roles.gd --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --headless --timeout 360`.
