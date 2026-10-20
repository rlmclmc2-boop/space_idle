# Enemy fleet source assets

Ordinary eight hulls retain base-eight-transparent.png fromf9af84734145a6df6bcc1998fff15730936aa78a and reactive-refined-approved.png frome9e8da87b96ba8a191b0ba275a344f4733279ba4. prepare_assets.py is their importer; their eight runtime PNGs are unchanged.

## Integrated-foundation elite/BOSS hulls

Sole hull design reference: integrated-turret-bases-approved-20261020.png from15a102ac3bee1b43d14e6f9666b8f19c10b21a06. integrated-empty-bases-atlas.png is the imagegen conversion retaining exactly2/4 empty stationary foundations and removing movable weapons; integrated-hulls-request.json records its request. Hull pixels and all24 socket centres remain unchanged during cannon redesign.

prepare_ranked_assets.py isolates connected hull components, cleans alpha fringe, crops/scales/centres them, locates dark-well centroids and synchronizes reserved visual metadata. Each elite/BOSS pair shares a source-pixel scale within unchanged2×2/3×2 frame limits. No procedural hull drawing, gun erasure or formation allocator.

## Current separate rotating cannon

bold-cannon-source.png and bold-cannon-request.json are the current source and full imagegen request. Approved15a102ac hull sheet is the style reference. A single ivory rear housing, broad graphite barrel and continuous steel directional face replace the rejected small gray-cluster appearance. No small panels/engraving or stationary base. Source pivot(512,1000), muzzle(512,158), barrel opaque span397..627 at y500. Runtime320×640down-forward conversion is technical crop/scale/180° rotation only; manifest records pivot, muzzle, measured barrel width and hashes.

The separate gun housing is110% of the original dark-well width. The fixed foundation shoulders, all8 hull PNGs and24 sockets are unchanged. Isolated main.tscn checks require13px housing and5px barrel width, rotation support/bounds and axis/muzzle alignment. Production code, numerical equipment/damage/CD and formation remain unchanged; dormant1/2/4 counts are not applied.

integrated-gun-source.png and compact-gun-source.png are rejected historical weapon sources. elite-boss-approved.png and elite-boss-transparent.png are historical hull sources, not consumed. ca60668b point plan is not used. Original generated PNGs remain in/workspace/generated_images. Latest eight original-window images, turns and before/after comparison: evidence/cannon-redesign-20261020/README.md. Runtime owners: assets/ships/enemy/elite_boss_20261020/README.md and assets/weapons/integrated_ranked_20261020/README.md.
