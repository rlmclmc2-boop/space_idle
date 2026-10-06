Exact source obtained from parent Git a5bd689fdd2476ea09a4e66dde00b163ff4a0653,parent-e528-strong34/source32-to049.bin.gz. Original bodySHA100c4dc5a6ddb318144cf55a7f4dd2263d565d4bc7313a5a419062d12f08a138; fullSHA1d3412d1a5bb7608a058a6a3760824168a572e757472fc76896a72ab04869522. Current production inventory and current-generation parameter audit passed; no source legendary effect, no old master strength. Round1/reforge0, resource balances and exact original four equipped drones agree with parent. All original dictionaries/fields are preserved as described in the digest audit, including private/main RNG, source schedule, history and manual failures.

Frozen paired-source converted CP SHAec3c211d1f5f6abcf1de85cf37df5f385ef153061219d71d65e68994ac05ff32 matches parent's independently reconverted source. Target is unchanged e528888-file FP13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d. These are new-version same-source continuations at natural32, not a new full-run timeline.

Important converter schema correction: the frozen ec3 converter added the new empty reforge_checkpoint_pending as Dictionary{} although target declares Array[]. Godot4.6.3 Object.set silently declines that incompatible assignment and retains the native emptyArray[]; the isolated production apply_fields probe proves no error and actual Sol initial checkpoint captures[]. No original source field is dropped or rewritten, since that new member was absent in the old source. Keep the already started parent/Sol ec3 pair unchanged; no hot replacement. transition-source32-typed-default.gd is the corrected future tool using explicitArray[] and will have a DIFFERENT output CP identity. It is not the frozen pair's source; do not silently substitute it. Raw frozen converter, CP, type probe and metadata are retained.

Gate observer uses parent's original event logic: super.observe first; ignore already armed clocks/manual routes; at first actual main34 COMBAT saveqa34_entry_x1 and set duration=start+43200, markcheckpoint_due and recordactual34_gate_clock_armed. The source options lack the initial flag, so options.get(...,-1) handles that absence without adding a different initial runtime option. This only observes actual state and changes the diagnostic clock. External observer SHA bbdeea88ce954ab5aa10ff2194eb375e60b9c7481ad750ae6027586324cb6bd1; it is separately pinned instead of changing the target888 manifest.

Common initial options exactly supplied by parent: duration181596.449994348,stop_clear34,allow_new_manualtrue,allow_reforgefalse,affix_target_tier0,visit_seconds300,checkpoint_wall_seconds30,wall_limit_seconds14400,seed20261005. The actual gate then replaces only duration and adds the persisted gate start. First main34start in both parent and Sol=116942.199994314; deadline160142.199994314. No injected resources/affixes/gear, no income/c90 change.

Independent reconversion and launch under your own already imported matching target package:

```bash
GATE_READY=/absolute/path/to/gate34-source-preflight/ready
GATE_WORK=/absolute/path/to/new-gate34-work
GATE_PACKAGE=/absolute/path/to/e528-888-file-package
GODOT=/usr/local/bin/godot
python "$GATE_READY/prepare-requests.py" --ready "$GATE_READY" --work "$GATE_WORK"
XDG_DATA_HOME="$GATE_WORK/xdg/data" XDG_CONFIG_HOME="$GATE_WORK/xdg/config" XDG_CACHE_HOME="$GATE_WORK/xdg/cache" \
 QA_AUDIT_SOURCE32="$GATE_WORK/audit-request.json" "$GODOT" --headless --path "$GATE_PACKAGE" --script "$GATE_READY/audit-source32.gd"
XDG_DATA_HOME="$GATE_WORK/xdg/data" XDG_CONFIG_HOME="$GATE_WORK/xdg/config" XDG_CACHE_HOME="$GATE_WORK/xdg/cache" \
 QA_TRANSITION_SOURCE32="$GATE_WORK/transition-request.json" "$GODOT" --headless --path "$GATE_PACKAGE" --script "$GATE_READY/transition-source32.gd"
# Confirm ec3 SHA and the external observer SHA above before running.
sha256sum "$GATE_WORK/source32-e528.bin" "$GATE_READY/gate34_first_main_combat.gd"
DISPLAY=:88 LIBGL_ALWAYS_SOFTWARE=1 QA_STAGE_MODE=cached QA_STAGE_VFX_PROBE=1 QA_STAGE_VFX_FAST=1 QA_IDLE_SALVAGE=1 \
 python "$GATE_READY/run_entry_window.py" --project "$GATE_PACKAGE" --entry "$GATE_READY/gate34_first_main_combat.gd" \
 --label e528-source32-gate34-no-reforge12h --godot "$GODOT" --resume "$GATE_WORK/source32-e528.bin" \
 --longrun-options "$GATE_READY/gate34-options.json" --skip-import --timeout 14500
```

The ready gzip convertedCP is identical to independently reconstructed ec3 and can be used directly. Deadline/gate are persisted in options for later ordinary checkpoint recovery; do not resetqa34_entry_x1 or replay fresh gate options on a mid-gate resume. Use a fresh label for every run. A wall-limit/operator stop before the actual gate deadline is partial evidence. A clear34 before deadline fails the desired hard gate; actual elapsed12h without clear is timing evidence only until the earned loadout/weapon/defence/MAX state is audited. Original early segment, new candidate segment and any future reforge benchmark remain separate.
