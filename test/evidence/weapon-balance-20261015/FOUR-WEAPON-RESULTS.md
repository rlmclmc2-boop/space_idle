# Four-weapon candidate: targeted old/native results

**Status:** review evidence for the unmounted 170/1000/0.25 candidate, not production acceptance. The isolated probe changes only missile damage 200→170, cannon damage 1500→1000, and continuous beam interval 0.28→0.25 s in its temporary database. Pulse stays 300 damage and 1.5 s; missile remains four per 2.4 s with concentrated salvos; cannon remains 3.5 s; beam still first hits 1 s after lock and ramps linearly from 1x to 3x over 2 s of hit age. The 25%/1.0 s recovery shield is a separate test-only fixture. No encounter, upgrade, projectile, or targeting rule was edited.

The 74 focused rows use one level-1 slot, equal authored purchase cost, fixed seed 1729, no enemy attacks, 1x scale, and a 60 s ceiling. All 37 native configurations admitted through the real compiled owner and performed native work. The 34 cleared cases each handed off once; the three reactive non-clears did not hand off. Old/native winner rankings agree in every sampled case; clear-time offsets are small and retain the previously traced scheduling differences. The reactive beam reaches 234 old hits versus 233 native hits by the 60 s cutoff, so this evidence does not claim exact event-time parity.

## Type-first moderate groups

Six same-HP hull targets; times below are old presented seconds. Native ranks agree. `>60` means the pair was not cleared by the observation limit.

| Hull resistance | HP each | Pulse, energy | Missile, physical | Cannon, physical | Beam, energy | Reading |
|---|---:|---:|---:|---:|---:|---|
| Physical | 260 | **9.10** | 13.72 | 21.10 | 12.00 | Energy pulse first; cannon's large overkill and wait cost time. |
| Physical | 400 | 18.20 | 18.32 | 21.10 | **15.00** | Energy beam first; pulse and missile nearly tie, so do not claim every energy weapon always beats every physical weapon. |
| Energy | 260 | 18.20 | **6.47** | 21.10 | 16.50 | Missile dominates the group; cannon's slow single-target cycle still loses to both energy weapons. |
| Energy | 400 | 27.30 | **11.07** | 21.10 | 21.00 | Missile first. The resisted beam edges cannon by 0.10 s because cannon wastes most of each 1000-point hit on 400 HP. |

The *best applicable type* wins all four sampled groups, but this is not a strict four-by-four type ordering. The cannon exceptions are visible consequences of 3.5 s first fire/repeat and overkill on six medium targets; the beam's long-run formula advantage does not mean it wins the 260-HP physical-resistant group before it charges. Reasonable HP variation 260→400 changes which energy weapon wins a physical-resistant group, not the winning damage type. Those are coherent secondary mechanics, though the 0.10–0.12 s near ties should not become content design thresholds.

## Within-type and last-enemy checks

| Fixture | Pulse | Missile 170 | Cannon 1000 | Beam 0.25 s | Reading |
|---|---:|---:|---:|---:|---|
| 10 × 100 neutral low swarm | 15.17 | **6.23** | 35.17 | 15.00 | Four parallel missile tubes retain a clear group advantage. |
| 2 × 5000 neutral heavy | 51.57 | 35.47 | 35.17 | **27.00** | Beam dominates this neutral sustained fight. Cannon is only 0.30 s ahead of missile; ordinary neutral heavy is **not** yet a robust cannon niche. |
| 2 × 5000 neutral reactive | >60 | >60 | **35.17** | >60 | Cannon's 3.5 s spacing clears the existing reactive-stack window. |
| 1 × 5000 energy-resistant survivor | 51.57 | 18.32 | **17.58** | 25.25 | All four missile tubes can focus one survivor; there is no artificial one-tube tail. Current 200-damage missile finishes in 15.77 s, so the candidate adds 2.55 s (16.2%) here. |
| 1100 HP + 600 physical-resistant shield / energy-resistant hull; 25%/1.0 s shield recovery | 19.72 | 13.60 | 24.62 | **8.25** | Beam's frequent hits prevent shield regeneration; old measured regain is 0 beam, 787.5 missile, 930 pulse, and 2265 cannon. |

Native old-comparable times for the low swarm are missile 6.18, pulse 15.02, cannon 35.00, beam 15.17 s; for the ordinary heavy pair 35.22 missile, 35.00 cannon, 27.03 beam; for the energy-resistant survivor 18.18 missile and 17.50 cannon; and for the dual-layer shield 13.50 missile, 24.50 cannon, 8.27 beam. The outcome relations remain the same. A 1× lone-target result supports keeping same-target concentration, but does not measure every equipment level or upgrade effect.

## Decision from this run

The candidate is **promising for the type-first axis**, not a finished four-weapon balance. Physical-resistant moderate groups choose an energy weapon, energy-resistant moderate groups choose a physical missile, and a reactive target rewards the cannon's spaced heavy hit. Three tradeoffs remain material before authoring the opening: (1) the cannon is nearly tied with missile on ordinary neutral heavy targets, despite a clear reactive niche; (2) cannon overkill makes it unattractive even on some energy-resistant medium groups; (3) beam suppresses the test recovery shield strongly, but that shield rate is not the authored draft rate. The first two may be acceptable if cannon's intended role is resistant single/heavy or reactive targets rather than every group, but should be a conscious design decision. Do not compensate by lengthening cannon charge to many seconds, forcing missile shots onto distinct targets, or claiming output-ratio inequalities guarantee every short fight.

## Static early progression budget

The **currently mounted, restored five-point** layout is not the disconnected 18-point opening. Generated rows have stage-1 physical-resistant hulls (51 enemies), stage-2 energy-resistant hulls (75), and stage-3 energy-resistant hulls (7). Missile unlocks after stage 1, cannon after stage 2, and beam after stage 5. The draft `27000x` enemies are not mounted in these stages.

Ignoring resistance, criticals, upgrades, target sharing, and travel, stage-2 HP are sixty × 976, thirteen × 2327, and two × 6980. At level 1, current 200-damage missiles need respectively 5/12/35 hits per target; candidate 170 needs 6/14/42. Across the whole stage that is **526→626 theoretical missile hits, +19.0%**. Candidate missile level 2 rounds to 210 damage, restoring 5/12/34 hits; one additional level costs **65** of resource 1 after the original 50 purchase. This is far less migration cost than the earlier 120-damage option's level-4 recovery, but it still spends a resource shared with other upgrades.

Stage-3 HP are four × 46528, two × 42456, and one × 14540. At level 1, current 1500-damage cannon needs respectively 32/29/10 hits per target; candidate 1000 needs 47/43/15. Total theoretical cannon hits rise **196→289, +47.4%**. Candidate cannon levels 2 and 3 round to 1200 and 1400; level 3 costs **65+75=140** extra resource 1 and nearly restores current level-1 per-hit damage. This is a larger pacing risk than the missile change and must be designed with the actual attainable upgrade budget before adoption.

The authored base resource-1 drops, before collection and other modifiers, sum to stage 1 **588**, stage 2 **570**, stage 3 **92**. In stage 2, each of the first four groups offers 90 and the last 210. These are a theoretical drop budget, not an earned currency trace: prior spending, collection, planet/reactor multipliers, and player defenses affect what can be bought and when. No old-stage long replay was run. Any future opening redesign must bind rewards and prices so a player can progress without retreating a whole stage to farm the critical resource. Memory healing at high enhancement levels and stage-18 fragment income remain separate open risks.

## Reproduction

`four-budget-candidate.jsonl` contains all 74 rows; `raw/four-budget-candidate.txt` is the unfiltered isolated Godot output, SHA256 `76fe7323dd57a3cc8d1f349a24c5b0404244b8ca64816a4124650b09db9cdba9`. The DLL and input provenance are in [BUILD.md](BUILD.md). Set `SPACE_BALANCE_FOUR_BUDGET=1` and run `python test/run.py probe_weapon_roles.gd --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --headless --timeout 360`. The probe ran serially and exited 0. The Windows Godot window is released; any further numerical run needs the next coordinated window.
