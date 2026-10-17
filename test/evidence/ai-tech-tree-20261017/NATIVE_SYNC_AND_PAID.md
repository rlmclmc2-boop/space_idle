# Native residency and paid research follow-up

## Native configuration boundary

`scripts/game.gd:1116` applies the technology combat factor to equipment stats. `scripts/native_execution_compiler.gd` compiles those stats into the resident kernel weapon and defence descriptors. `scripts/native_execution_session.gd:112` hands off the kernel before a general configuration mutation; `game.gd:830` cache invalidation alone merely marks its session as changed. The old technology upgrade path used `native_before_configuration_change()` before mutation.

`scripts/ai_tech_tree.gd` now calls that boundary before each completed level and before a higher income peak changes an active unification factor. A failed handoff leaves the level or peak unchanged. Earlier paid work in the same research advance is still finalized.

`native-sync-probe.py` runs the accepted 15-enemy main-scene fixture with the real `space_native.dll`. Its raw `native-sync-probe.log` confirms admission and two independent handoffs: weapon accuracy level 1 increases the laser stat after handoff, then an iron income peak of 100 increases the unification factor after a second admission and handoff. `native-fix-headless.log` records 35/35 checks after the fix.

## Paid workload

The earlier 25 performance runs selected singularity and showed progress, but both technology inputs were zero; they did not exercise deduction. `paid-performance-probe.py` runs one focused mixed high-load sample with weapon accuracy research and iron input 1000 per game second. The real native kernel remained resident (`handoffs=0`), and the 480-step sample passed validity and actual 1x checks. Progress rose from 7 to 21 seconds; iron fell from 996000 to 988000 over eight game seconds, exactly 8000 units. The raw log, JSON frame times, and screenshot are retained alongside this note. This focused sample is additional workload evidence, not a replacement for the five-case comparison.
