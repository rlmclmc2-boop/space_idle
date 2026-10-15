# Revision 02 — art review, not accepted production

The user rejected revision 01 as empty and the three hull studies as insufficiently distinct. The parent has NOT accepted e852614c. Its background must not be treated as finished or merged on the strength of import/seam checks. This revision deliberately produces one substantial scene and a combat-scale identity study before extending the route.

## Review files

- `broken-orbit-source.png`: original ImageGen scene, 972×1619 RGB. An enormous damaged orbital gate, warm exposed power cavity at right, close armored structure at lower left and a distant atmospheric planetary limb. Large coherent forms establish near/mid/far scale; this is not a repeated margin strip.
- `actual-battlefield-review.png`: actual Godot main-scene framebuffer. Existing first-encounter enemies/UI, original renderer, paused art fixture; the review-only shader samples the new image across the full battlefield and applies a 0.42 intensity factor. No composited/faked UI screenshot. Existing enemies are intentionally NOT replaced; new hull alpha is not bound to hit geometry.
- `enemy-identities-source.png`: original ImageGen true-alpha sheet, 1774×887. Needle: wide delta wings; Anvil: blunt armored slab; Crown: open U-shaped hull with large negative space. Large forms, not colored spines, distinguish identity.
- `enemy-actual-pixel-review.png`: Godot-drawn review board at 1100×760. Rows use 80/50/30px destination rectangles (visible silhouettes slightly inset), against the new scene. View at 100% for scale judgment. These are art prototypes, not combat actors or confirmed threat rules.
- `capture_review.gd`: reproducible isolated art review fixture. It binds a review material once; no production script, simulation, firing rate, geometry authority, kernel, roster or reward edits. Onboarding dismissal is in-memory only. Absolute review path is for this workspace; adapt REVIEW when replaying elsewhere.

## Source / prompts / tools

Both source PNGs were actually produced with the available `image_gen.imagegen` tool in this turn; originals retained under `/workspace/generated_images` and copied into Git. No Library used. Scene prompt: portrait full-bleed Broken Orbit Gate; monumental layered industrial ring, damaged power chamber, close hull plates, far planetary arc, warm sun/cold bounce/amber utility light; lower central contrast without empty space; no UI, ships, text or bullets. Hull prompt: transparent top-down, three sharply different compact silhouettes, graphite/oxide-red/bone-metal armor, no installed weapons or baked shields; readable at 30–80px, no gray-long-hull repetition. Godot performed scaling, region sampling and review layout; source images were not repainted by Python. Blender, Inkscape and GIMP are available, but were not used to produce these two new sources.

## Limits and next gate

This is a visual review, not acceptance. The bright planetary rim and fine station detail need live-effects comparison before production; the 30px row is the most demanding silhouette case. New hulls still need approved archetype mapping and geometry-safe integration. No invented charge, resistance or recovery state is depicted. No three-stage extension, tile reuse, seam claim or ten-stage completion is claimed here. Next work is to carry the accepted scene language through three coherent neighboring route segments, not repeat this single picture.

Godot 4.6.3 + Mesa software display used only for layout. The accepted native 4.7 Windows extension is unavailable, so no kernel/performance acceptance is claimed. Existing performance boundaries remain in force. Only this revision's source art, review captures and fixture are new in this commit.
