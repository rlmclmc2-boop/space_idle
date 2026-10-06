# QA sparse-repeat-failure candidate and same-source600-second contrast

Code branch review/hyperspace-repeat-failure-sparse; commit8879606e808bf28f8f5ca5669aa2fe9661a14804 based on e5283ab8. Three QA scripts and one targeted fixture only. Production scripts/data/assets and Excel all unchanged. Candidate fingerprint9d583eb7acba26c538001a2ae4e765b928364d049cc6aa1256ec5e25418580f8,889 files. qa-sparse.patch and prerequisite-e528 qa-sparse.bundle included. No main push and no new agent/task/thread.

Changes:
1. Remember visible public combat round/route/stage/group. First real defeat for an observed encounter retains an immediate tour; later failures of that encounter keep the existing baseline. Distinct encounters and new unlock IDs retain immediate response; duplicate unlock IDs do not trigger it. Early1–10 policy is unchanged. No hidden enemy stats/wealth ranking is added. The first immediate response can still produce one short interval;300 is the baseline after that response.
2. Idle white dismantles are charged by successful production command-sequence advancement. Keep successful timestamps and expire them only after300 X1 seconds; at most3 within any half-open rolling300 interval. An early actual tour or reforge does not reset the limit. Full-storage recovery remains separate; protected fleet/backups/nonwhite restrictions are unchanged.
3. New reaction dictionaries/current-encounter and successful salvage timestamps are part of atomic QA checkpoint capture/restore. The21 targeted fixture assertions passed, including early-tour and reforge budget bypass prevention, failed transaction accounting, legal full-storage recovery, first/duplicate/new-encounter reactions and checkpoint memory preservation.

Both native short arms use the same fully earned source ec3c211d1f5f6abcf1de85cf37df5f385ef153061219d71d65e68994ac05ff32 atX1116796.449994348, same seed/options, absolute cap117396.449994348 and actual terminal117396.466660875. Fixed source conversion7d599a5a15fb618276636d7114d3f90adc1ead51b8a8cacd33e5e84e67cbf245 changes only QA identity metadata and new empty QA memories; all original save/controller/policy members and RNG verified by Variant digests. Both restore formally regenerate battle; neither is claimed live-combat lossless. Existing source conversion pending-reforge Dictionary{} detail remains preserved; actual native captured field is Array[] in both arms. Original source remains untouched.

|600-second result|Original e528|QA fix|
|---|---:|---:|
|Tours|6|3|
|Counted successful actions|231|150|
|Page navigation|60|30|
|Native inputs|159|108|
|Focus/select setup|88/7|54/6|
|Upgrade/MAX buttons|24|20|
|Resource pickups|25|15|
|Successful domain transactions|12|12|
|Empty checks / all checks|42/60|19/30|
|Actual defeats|4|13|
|Idle dismantles total|4|4|
|Max idle dismantles within rolling300s|4|3|

Original tour intervals12.62,26.42,300,12.32,9.87 seconds. Fixed intervals12.62,300 seconds. Fixed13 retreat reactions: first immediate and12 suppressed repeats of [1,main,34,2]. The fourth white dismantle moves from116981.816660972 to117265.916660905 (312.62sec after first instead of28.52sec). Native transactions all succeed; script errors0 and input failures{} on both arms. Both33-clear times116937.183327649 and neither clears34. Materials at end identical:glue17/degenerate4/antiproton4.

Tradeoff is real: after resuming progression, repeated defeats no longer prompt immediate global inspection; at the next baseline tour the player may return to the earned safe point. In this bounded window the fixed arm ends idle after11 defeats since guard-off; original is already back farming. Fixed weapons all244 and defence245/244/244 vs original245/245/244/244/244/244 and245/245/245. Fixed terminal iron4.17944952545656e21/uranium1.777150790031572e17 vs original2.553123846442764e21/3.4076754150661434e17. End-resource differences reflect scheduling, pickups, purchases and farming; do not claim a net-income or full-progression benefit from this short contrast.

Full raw streams, terminal atomicCPs/backups/save snapshots, manifests, converter and audit/digests are retained. A first importer attempt used unwritable default Godot editor-cache paths; its failure log is preserved. Isolated writable XDG rerun succeeded before fixtures and actual fixed native run. ALSA fallback is environmental; neither arm has script errors. Completed c90 reconstructible cache removal was already authorized; its raw evidence/source remain intact, archived old import marker and byte count included.

Original long gate PID122294 remains unchanged and continues from original e528 source/deadline. Its result is a more actively operated pressure test, not normal300-second low-frequency experience. These two600-second arms are targeted diagnostics, not another full campaign. No12h hard-gate acceptance or new long progression timing is claimed. QA fix has not been switched into either original long-running comparison.
