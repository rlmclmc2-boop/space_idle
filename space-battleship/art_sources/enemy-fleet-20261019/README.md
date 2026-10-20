# Enemy fleet source assets

Ordinary eight hulls retain base-eight-transparent.png fromf9af84734145a6df6bcc1998fff15730936aa78a and reactive-refined-approved.png frome9e8da87b96ba8a191b0ba275a344f4733279ba4. prepare_assets.py remains their importer; their runtime PNGs are unchanged.

## Fixed integrated hull foundations

Hull authority: integrated-turret-bases-approved-20261020.png from15a102ac3bee1b43d14e6f9666b8f19c10b21a06. integrated-empty-bases-atlas.png is the conversion retaining2/4 stationary empty foundations, without movable guns. integrated-hulls-request.json records its request. prepare_ranked_assets.py retains these hull pixels and24 measured static pivot coordinates; the selected weapon integration does not change hull geometry/display size.

## Selected rotating weapon —51aae1ac

The user provisionally selected cannon-em-appearance-review-10/cannon-design.png. This exact PNG is now the independent gun input of prepare_ranked_assets.py; no further design generation. The importer reads its design-meta.json for the mechanical pivot and inset visual aperture, performs alpha cleanup/crop/uniform scale/180° direction conversion, and writes assets/weapons/integrated_ranked_20261020/cannon-rotating.png plus manifest.

cannon-coverage-review-07/coverage-measurements.json supplies the already-reviewed95%-outer-bearing target with per-mount hull clamp. Imported manifest stores the exact canvas/UV widths for every elite/BOSS slot; the original24 axis coordinates remain unchanged. The reserved enemy_weapon_interface references this manifest. Coverage is consumed only by the explicit isolated2/4 showcase; production1/2/4 numeric equipment is not activated.

The short segmented rails and inset aperture change appearance only. Original weapon type, profiles, numerical damage/CD, production code and formation remain unchanged. Actual-window integration evidence: evidence/em-turret-integration-20261020/README.md. Candidate is not merged to main.

integrated-gun-source.png, compact-gun-source.png, bold-cannon-source.png and design review03–09 remain historical, not the selected gun importer input. Earlier elite-boss-approved.png/elite-boss-transparent.png are historical hull sources; ca60668b layout is not used. Original imagegen PNGs remain in/workspace/generated_images. Runtime owner docs: assets/ships/enemy/elite_boss_20261020/README.md and assets/weapons/integrated_ranked_20261020/README.md.
