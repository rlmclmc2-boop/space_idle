# DECISIONS: long-term constraints only
| ID | Decision |
|---|---|
| D002 | Keep Godot/GDScript and existing game/QA/editor boundaries. No ECS/Service/Manager or mechanical main/game split merely for tidiness. |
| D003 | Excel sheets are edit source; legacy workbook cannot auto-overwrite; JSON is rebuildable projection. No automatic merge of two editable sources. |
| D004 | Module slot owns equipment level/player CD; legacy name-based levels only at compatibility boundary. Reads cannot silently normalize/write back. |
| D005 | run_resources=run pickup total; furnaceIncomePeak=historical peak. Neither is redundant balance. |
| D006 | incremental_import and Store retain distinct acceptance/validation/transaction semantics; share only proven-equivalent parts, no mode/policy abstraction for dedupe. |
| D007 | Perf change: measure repeatable hotspot -> preserve behavior -> same-scene remeasure; revert absent net gain. Cross-frame cache needs owner/key/invalidation/readers/writers; no global cache framework. |
| D008 | IF any active research item has >=1e20 available points: authorized batch approximation applies to all active items; combine per-level events, skip per-level rounding, estimate furnace at final level. Level cap 9e18; unbounded budget 1e308; preserve remainder. Never extend to lower range. |
| D009 | Scientist MAX availability tests first-person cost; actual buy uses original algorithm. Free first person cannot make MAX falsely available. |
| D010 | Windows x64 single EXE: matching Godot release template + embedded PCK; publish only after full validation, no silent fallback/unverified artifact. |
| D014 | True screen reflow requires system-page redesign. |
