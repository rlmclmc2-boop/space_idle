# ShipViewport structure check (2026-10-15)

Decision: **do not implement mesh batching yet**. This is a short, read-only structure export of the accepted mixed fixture, not a performance comparison. Production source and DLL were unchanged. The 12 rendered frames advanced 22 logical steps at speed 1. The isolated QA project used Godot 4.7.2 GL Compatibility on the NVIDIA RTX 2060, with the accepted DLL SHA-256 `1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5` and the frozen mixed fixture SHA-256 `cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4`. The first invocation omitted `RENDER_CASE=mixed` and failed its assertion before export; the successful retry used that variable. The raw successful export is `ship_structure.json`; the script is `ship_structure.gd`; both console logs are retained.

| Visible part | Mesh nodes | Surfaces | Shadow-casting nodes / surfaces |
|---|---:|---:|---:|
| Hull body | 5 | 18 | 5 / 18 |
| Three carrier bodies | 9 | 33 | 9 / 33 |
| Ordinary laser modules | 6 | 15 | 6 / 15 |
| Long laser modules | 4 | 10 | 4 / 10 |
| Missile modules | 6 | 18 | 6 / 18 |
| Five hyperspace drone bodies | 89 | 89 | 89 / 89 |
| Hyperspace Appearance meshes | 5 | 15 | 0 / 0 |
| Exhaust | 4 | 4 | 0 / 0 |
| Shield | 1 | 1 | 0 / 0 |
| **Total** | **129** | **203** | **119 / 183** |

All 129 `MeshInstance3D` nodes are visible in the tree. There are 75 distinct mesh resource identities and 43 active material identities; material sharing alone does not establish draw batching. The 183 shadow-casting surfaces use the toon shader; the five Appearance nodes use `StandardMaterial3D` on 15 surfaces, with transparency settings not exported. Exhaust is additive and the shield has its own blended shader. The viewport is 572×960, updates every displayed frame, and has 4× 3D MSAA (`msaa_3d=2`). Its directional key light has shadows enabled.

All **nine body-baker records are inactive**: zero source parts hidden and zero visible proxy planes. None of their nine appearance signatures matches any of the 22 keys in the offline body-bake catalog. The baker returns before creating a proxy on a catalog miss (`ship_body_baker.gd`); therefore this scene uses live hull, carrier and hyperspace drone geometry. No baked proxy is counted as a visible mesh here. Activating a bake would change geometry and possibly its shadow; it requires separate visual review and is not a free batching substitute.

Grouping only exact `(mesh resource, ordered active materials, shadow setting, layer)` matches yields 81 groups. Of these, 41 repeated groups contain 89 nodes and 144 surfaces. Replacing each repeated group with one submission per surface would eliminate **at most 83 of the 203 surface submissions (40.9%)** before renderer behavior, pass duplication, culling, dynamic transforms and per-instance appearance are considered. By category that ceiling is carrier body 22, laser 10, long laser 5, missile 12, hyperspace body 34. Hull, exhaust and shield have no exact repeated group. The five `Appearance` meshes and other transparent effects are excluded from the proposed opaque candidate. These are structural counts, **not** measured saved draw calls or time.

The visible render-info query returned 386 objects, 386 draw calls and 30,068 primitives. The shadow query returned 8,388 primitives but zero objects/calls. Because the light is enabled and live shadow-casting surfaces exist, zero shadow calls in this GL counter cannot establish that shadows were skipped. The 386 visible calls exceed 203 mesh surfaces and include engine passes; subtracting 83 from 386 is unjustified. The scene source has no explicit `MultiMeshInstance3D` for these nodes; whether Godot GL automatically batches same-material ordinary MeshInstance3D submissions was not established by this query. Godot [documents MultiMesh as a single draw primitive with group-level culling](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html); that does not prove this scene would save 83 actual calls.

The prior phase probe measured the entire ship viewport at about 0.762 ms CPU and 1.702 ms GPU on one-step frames, with possible one-frame lag and overlap. To meet the required 0.5 ms **whole-frame** gain through ship CPU alone would need to remove about 66% of that entire viewport CPU time. Even the structural ceiling covers only 40.9% of surfaces, with no demonstrated time cost for them. Instancing does not remove their shaded pixels, 4× MSAA work or shadow geometry, and the GPU viewport clock is larger than CPU. Shader/pixel and shadow work are plausible contributors, but this export cannot apportion them. I oppose a production mesh-batching patch on this evidence; first isolate opaque submissions from shader/pixel and shadow cost with a controlled, visually identical diagnostic if further work is authorized. Preserve every mesh, transform, material, shield, exhaust and shadow in any later candidate.

This fixture does not cover natural death, consecutive waves, drops or purchase quotes.
