# Independent rotating weapon art — selected51aae1ac

User provisionally selected art_sources/enemy-fleet-20261019/cannon-em-appearance-review-10/cannon-design.png. No further art generation. The short segmented rails and recessed aperture are appearance only: production weapon type, equipment, numerical damage/cooldown and attack logic remain unchanged.

prepare_ranked_assets.py imports the exact selected source with alpha cleanup, crop, uniform resize and180° orientation conversion. Runtime cannon-rotating.png remains320×640 RGBA down-forward, with mechanical pivot and inset aperture converted from the design metadata. No stationary foundation in this sprite; all foundations remain in the unchanged hull PNGs. Source/hash/commit, runtime pixel pivot/aperture and true normalized housing width are in manifest.json.

Coverage is copied from07's selected95%-outer-bearing, per-mount hull-clamped plan. manifest.coverage stores each case/slot's canvas width, UV width, outer bearing width and applied fraction. No use of the smallest dark well as a global scale cap. Original24 pivot coordinates are unchanged. Bounds-limited mounts retain the accepted07 differences.

The dormant enemy_weapon_interface references this texture/manifest and the coverage source. The existing explicit QA fixture installs2/4 cannon-mon entries in an isolated save-disabled main.tscn, copies each presentation component profile for its own aperture vector, and stamps retained sprite nodes with their per-mount scale. Canonical and retained paths draw this same sprite. The QA renderer is not registered by production scripts. Normal/elite/BOSS1/2/4 counts remain an unapplied interface.

Integration evidence: evidence/em-turret-integration-20261020/README.md. No main merge; parent reviews candidate. Previous integrated/compact/bold cannon sources remain historical and are no longer the selected gun importer input.
