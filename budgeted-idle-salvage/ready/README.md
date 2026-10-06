Frozen runnable comparison: 6abe0048f6d6afacd570d6e9b2c202a02b09c56d, branch review/hyperspace-budgeted-idle-salvage-2d20, exact 2d814122 baseline. Only two QA files change. No income increase, production change, modernization cost or UI patch mixed in.

Policy opt-in QA_IDLE_SALVAGE=1. Keep equipped, favorites, presets, sealed, legendary, ultimate, installed hangings and the best usable unequipped backup for each weapon. Select remaining earned white drones by existing visible score; only then ask the production dismantle preview. At most three successful dismantles per round, at least300 X1 seconds apart. Native one-action clicks and original page cadence remain. Successful production transaction consumes the budget; failed transaction does not. This three-action prototype is not a proven endgame strategy. Missing fields in the original source checkpoint leave class defaults; converted source is identical for both arms. Later checkpoints persist the flag and budget, so switching environment on an already running arm does not silently switch policy.

Source checkpoint SHA256 cf5042c688e2418290afdfa8e6f646e94f041acc8cb5c86291b6af8531bb9084, actual clear20 X1 42767.8833349779. Converted checkpoint SHA256 b8759d9e4d439f3c834258f4aecece2c3a3c9c25710ae4390afae3fc565f3f4c. Converter verifies original header/body,887 source entries, exact two changed QA inputs, unchanged data SHA86634b4b91b7a0437f1ce4de557b549be04da170c59b177c00a4c504848a354c and all original payload fields except three identity/lineage fields. The private RNG, controller, inventory, resources, policy, option fields and snapshots are preserved byte-digest-wise. Formal reload regenerates battle and GUI; neither arm is a live-battle restoration.

Use the original frozen 887-file 2d package (not the repository root) as --source. The supplied builder verifies every original source hash before copying, overlays two supplied QA files, runs its own isolated editor import and restores frozen .import input bytes. Do not share another package's .godot or import marker. Commands below use task-local shell variables; adapt GODOT and display to your executor.

```bash
READY=/absolute/path/to/budgeted-idle-salvage/ready
ORIGINAL_2D=/absolute/path/to/original-887-file-2d-package
PACKAGE=/absolute/path/to/new-idle-salvage-package
GODOT=/usr/local/bin/godot
python "$READY/prepare-package.py" --source "$ORIGINAL_2D" --target "$PACKAGE" --godot "$GODOT"
gzip -dc "$READY/checkpoint.bin.gz" > "$PACKAGE/source20.bin"
# Run sequentially, same source, same code, same options; labels must be fresh.
for ARM in 0 1; do
  DISPLAY=:88 LIBGL_ALWAYS_SOFTWARE=1 QA_STAGE_MODE=cached QA_STAGE_VFX_PROBE=1 QA_STAGE_VFX_FAST=1 QA_IDLE_SALVAGE="$ARM" \
  python "$READY/run_entry_window.py" --project "$PACKAGE" --entry res://qa/stage_campaign.gd \
    --label "idle-salvage-arm${ARM}-3600x1" --godot "$GODOT" --resume "$PACKAGE/source20.bin" \
    --longrun-options "$READY/options.json" --skip-import --timeout 14500
 done
```

The options stop at absolute X1 46367.8833349779, a3600 X1 second window after actual20, rather than a new full campaign. The original QA can emit two terminal-report missing link.discontinuities lambda errors; preserve and classify them, validate the actual checkpoint and input_failure independently, and never call an exit1 run fully passed. Both own sequential native runs have been launched; results are pending. Source conversion and editor import passed; no native salvage success is claimed yet.

To reconvert the included original source yourself, create a JSON request with absolute source_manifest, source and a nonexistent output path. Set QA_IDLE_SALVAGE_REQUEST to that JSON path and run the supplied transition.gd with the target package plus writable isolated XDG directories. The already converted source above avoids needing reconversion.
