Authorized source is parent actual845 clear60 checkpoint at evidence/hyperspace-parent-20261006 commitbf09ce3c9c8bf2c0405a7893337896484237aab7, memberparent-845/clear60/checkpoint.bin.gz. Source SHAf51b1178c17173a103184d7d39e7d0f24040ad82e8f79d6bd4128bb7a22f11ef, X1181472.19997929, sourceFP4e07f51458d778fa152222ab0d39042cc07f4d7f83d2e1c563479de5e4123983.

Target codee5283ab8f8d53b5524e41bdaec0dd2e3b07bc4de,888 files, FP13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d (matches parent independently built target). Whitelist enumerates exact12 changed/added file hashes. Income/enemy workbook-derived game_data and hyperspace_config hashes unchanged. Added dormant QA refund test is explicitly whitelisted; no unlisted file addition/removal permitted.

Dedicated converter compares full source bytes, valid CP header/body, complete source/target manifests and every changed file to whitelist. All original top-level payload values remain byte-digest equal except code_fingerprint, lineage, candidate_transition and space_policy; every original space_policy member remains digest-equal. Only two new members are added: idle_salvage_enabled=true; idle_salvage_budget={round:-1,used:0,tour_started:-1.0}. No controller scheduling, resources, inventory, RNG, histories, failures or options are cleared. First actual visible-page choice derives the budget from the restored round and actual controller tour_started. Source options remain unchanged in CP; explicit common runtime options override only at normal startup.

Converted CP SHAa62e26b39c2ea26011ea8ec0e594c835bf17f0f828a02584c2b6f7259cb6c673. Formal production reload regenerates battle/GUI and suppresses offline compensation, not a live-battle restoration. Any production active/manual reload rules remain operative; original flags/receipts are preserved in the converter, not suppressed.

Common window: absolute duration185072.19997929 (=source+3600), stop_clear0 (must not stop on already earned60), allow_reforgefalse, allow_new_manualtrue, visit_seconds300, checkpoint_wall_seconds30, affix_target_tier0, seed20261005, wall_limit_seconds14400. Use the explicit post60_supply_hold60.gd entry: actual native warp/guard actions maintain main60 and release it only for genuine queued exploration; stage_campaign.gd alone does not enforce this boundary. Original exact equipped IDs and drone attributes are supplied inoriginal-equipped-baseline.json; report their modernization separately from replacement equipment. Real ultimate restore/core cost applies; no injected cores/materials or c90 data.

Use your independently imported matching target package. For ready CP run:

```bash
POST60_READY=/absolute/path/to/unified-e528-post60/ready
POST60_PACKAGE=/absolute/path/to/e528-888-file-package
gzip -dc "$POST60_READY/checkpoint.bin.gz" > "$POST60_PACKAGE/source845-clear60-converted.bin"
DISPLAY=:88 LIBGL_ALWAYS_SOFTWARE=1 QA_STAGE_MODE=cached QA_STAGE_VFX_PROBE=1 QA_STAGE_VFX_FAST=1 QA_IDLE_SALVAGE=1 \
python "$POST60_READY/run_entry_window.py" --project "$POST60_PACKAGE" --entry res://qa/post60_supply_hold60.gd \
 --label e528-post60-3600x1 --godot /usr/local/bin/godot --resume "$POST60_PACKAGE/source845-clear60-converted.bin" \
 --longrun-options "$POST60_READY/options.json" --skip-import --timeout 14500
```

To independently reconvert, write a request JSON with absolute source_manifest, source, whitelist and a new output path. Set QA_UNIFIED_POST60_TRANSITION to that request and invoke transition.gd under the matching target package with writable isolated XDG dirs. Converter/own target import passed. The short native continuation is next; this is not new-price full progression,34,reforge or galaxy completion acceptance. Known inherited terminal-report lambda errors must remain classified and preserved if encountered.

Correction: first Sol launch used stage_campaign.gd and actually advanced to61. It is excluded from the agreed hold60 comparison, stopped through the canonical STOP request and preserved separately. Restart uses the original same converted sourceCP, same target888 manifest and same options, with only the correct explicit hold60 entry. No code/CP hotfix or resource backfill.
