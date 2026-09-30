# Flexible Toon Shader · Godot 4

Source: https://github.com/atzuk4451/FlexibleToonShaderGD-4.0

Vendored revision: `f397a8d9d1e7416501910725b001c3a14bfd5d38`.
Original author: CaptainProton42; Godot 4 port: atzuk4451. MIT license in [LICENSE](LICENSE).

Only the spatial shader and its material are installed; examples and hatching are omitted. Upstream is a shader resource pack, with no `EditorPlugin` or `plugin.cfg` to enable. The prototype enables it by assigning ShaderMaterial instances to imported GLB surfaces. It is tested with this project's Godot 4.7.2 GL Compatibility renderer.

Small local extensions in `flexible_toon.gdshader`: emission color/strength, a continuous-lighting A/B switch, a nonnegative Blinn–Phong dot product, and centered cel bands to stabilize large armor roofs. The material's null steepness is changed to 1.0. The upstream ramp, attenuation, specular and rim implementation is retained. These resources are referenced only by the development prototype.

Optional outline assessment: https://www.sol.vin/projects/assets/shaders/low_poly_pos.html . Its precomputed surface-map mesh workflow is unnecessary for this single removable prototype and is not installed.
