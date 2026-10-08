# Fixed-view body assets

Original project GLBs and toon materials, exported with Godot 4.6.3 Compatibility at 1024² with 4×MSAA and the existing directional light. Source/recipe: `dev/toon_ship/export_body_bakes.gd`; run with a graphical rendering backend, not the headless dummy renderer. This is an art export, without game simulation or saves.

The catalog covers five hulls, the weapon carrier and four hyperspace body families in white/blue/gold/legendary colors. It records geometry extent and bottom-plane height. Geometry hashes, authored mesh names/transforms, shader source and uniform values identify the appearance; machine-local imported subresource IDs are excluded.

Runtime loads a matching asset or retains the original live body. It does not generate missing variants during play. Turrets, sockets, shields, exhaust and Appearance ornaments remain independent. Above-native magnification also retains live geometry.

Lighting/self-shadow is baked. The display shader is unshaded to prevent a second lighting/shadow multiplier; its flat alpha silhouette can cast a live shadow, but cannot reproduce volumetric occlusion or receive turret shadows on the depicted hull surface. The proxy sits at the body bottom to avoid covering turret bases. These visual differences and first-load costs require parent acceptance.
