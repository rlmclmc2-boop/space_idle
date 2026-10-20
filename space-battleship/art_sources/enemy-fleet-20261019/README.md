# Approved eight enemy hull sources

`base-eight-transparent.png`: parent-approved atlas from f9af84734145a6df6bcc1998fff15730936aa78a. Source order: scout/sentry/interceptor/swarm/anchor/reactive/shielded/command. Anchor crosses a nominal tile boundary; use prepare_assets.py regions.

`reactive-refined-approved.png`: user-approved parent imagegen refinement delivered by e9e8da87b96ba8a191b0ba275a344f4733279ba4; prompt intent: three major white-grey armor masses around a small burgundy/orange core, open structural gaps, blunt front, no central long nose, transparent background and no installed weapons. This is the runtime reactive source; the other seven retain atlas pixels. Import only cleans alpha residue, scales uniformly to 720px body width and centres on 887×1774. No procedural hull drawing. Runtime consumer uses the approved 90.4×79.333 logical display box independently of formation or actor rank.

## Final ranked hulls and selected rotating weapon

The final source set is self-contained: integrated-empty-bases-atlas.png contains the8 elite/BOSS hulls with24 empty fixed foundations; approved-emitter-20261020.png is the exact final selected emitter from51aae1ac/707981f3. integrated-turret-bases-approved-20261020.png is the approved15a102ac design reference retained for approval/provenance inspection, not an intermediate rejected design.

ranked-import.json contains only final pivot/aperture calibration, final per-mount95%-outer-bearing/hull-clamped coverage, source hashes and the9 expected runtime PNG hashes. It replaces dependencies on historical design-review folders. prepare_ranked_assets.py reads these final inputs and regenerates the runtime PNGs/manifests/dormant descriptor; no historical branch, HTML board, old trial source or image generation is needed.

Prompt intent of retained final sources: fixed burgundy foundations integrated in white/cool-gray hull armor; no movable guns in hull pixels. Independent compact bright emitter with paired short segmented rails and recessed aperture, white support armor/burgundy couplers; only a small amber status chip, no long cylindrical barrel or decorative light strips. Source PNGs remain authoritative; importer performs alpha isolation/crop/uniform normalization/180-degree orientation conversion, never creative pixel painting.

Run from repository root: python space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py. Verified import environment: Python3.12, Pillow12.3.0, numpy2.3.5, scipy1.17.0. Runtime ownership: assets/ships/enemy/elite_boss_20261020 and assets/weapons/integrated_ranked_20261020. Release evidence/scope: evidence/em-turret-integration-20261020/README.md and RELEASE_SCOPE.md.
