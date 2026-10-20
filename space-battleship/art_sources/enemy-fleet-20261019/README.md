# Enemy fleet source assets

Ordinary eight hulls retain their approved source atlas base-eight-transparent.png from f9af84734145a6df6bcc1998fff15730936aa78a and reactive-refined-approved.png from e9e8da87b96ba8a191b0ba275a344f4733279ba4. prepare_assets.py remains their importer; all eight ordinary runtime PNGs are unchanged.

## Current integrated-foundation elite/BOSS source

The only current design reference is integrated-turret-bases-approved-20261020.png from15a102ac3bee1b43d14e6f9666b8f19c10b21a06. integrated-empty-bases-atlas.png is its imagegen stationary-hull conversion: four columns anchor/reactive/shielded/command, two rows elite/BOSS, exactly2/4 integrated empty foundations, no movable gun housing or barrel. integrated-gun-source.png is the separately generated rotating white housing/long dark cannon. Full tool requests are integrated-hulls-request.json and integrated-gun-request.json; both reference only the new approved sheet.

prepare_ranked_assets.py imports these source copies, retains component pixels and alpha fringe, uniformly scales/centres the hulls, locates dark-well centroids from authored search seeds, and synchronizes reserved visual metadata. It normalizes the separate gun, converts it180° to runtime down-forward, and records mechanical pivot/muzzle pixels. Source-pixel scale is shared by each elite/BOSS pair within the unchanged2×2/3×2 display-frame limits. There is no hull redraw, gun removal by code, layout/formation allocator or production numerical edit.

The old elite-boss-approved.png and elite-boss-transparent.png are historical source material and are not consumed by the current ranked importer. The rejected ca60668b point plan is not used. Original generated tool output files remain in /workspace/generated_images; only source copies are stored here. Runtime ownership/docs: assets/ships/enemy/elite_boss_20261020/README.md and assets/weapons/integrated_ranked_20261020/README.md.
