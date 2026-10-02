# Current-main review candidate

Base `a22fd7d4c12d8f573c332cfc9e5ef85ffc19337d`, tree `450b6aaf522d740827d35a7abf4314d904636f87`. Independently reconciles the historical `c71ba9855e51a509883861e7c398fd4edf687159` enemy design onto current main. No main push or merge.

The old consumer JSON was discarded during reconciliation. The current equipment source was retained and only cannon base damage changed 350→1500; existing CD3.5, speed40 and every other source cell retained. New enemy/group rows and `battle_design` were then formally exported against current source. Enhancement gate, save import/export, galaxy, rail art/audio and other newer main changes are retained. Level, motion and enhancement workbooks are byte-identical to a22. See `source-audit.json`.

Current-main compatibility: **88 critical cases, identical outcomes**, all tier boundaries and neutral duration criteria still pass. Seven missile times differ from the old evidence by one or two 1/60 steps; maximum delta0.033334s. Original 496-case selected evidence remains separately attributed to its old runtime and snapshots; this replay is not a claimed full320 test on a22. Native gate checks retain the authored base-critical value and run against the fixed main gate; the current replay helper defaults to no suppression. Historical replay input files explicitly request suppression.

Source/schema and **172 current-main grid checks pass**. The earlier visible-window grid checks/screenshots remain layout evidence on the old base. Linux software rendering is not Windows performance evidence. No raw user save/sample/log is included.

The independent dark-red rail VFX candidate `a18f106` changes only `dev/toon_ship/rail_vfx.gd`; this enemy candidate leaves that file unchanged. They are deliberately separate review units. Cannon base1500 is an authorized balance proposal; the VFX candidate preserves main's current damage350. Growth and attack/chain mechanics are unchanged by either proposal.

Review decisions: retain Lv10 Destroyer as +0 design baseline; accept or revise the proposed numerical neutrality criterion in the parent `REVIEW.md`; review the base-damage proposal before publication. No new enemy defence mechanism is proposed or required. Some neutral +1 builds finish with only a few hundred armour; sampled seeds are not a broad-build robustness guarantee.
