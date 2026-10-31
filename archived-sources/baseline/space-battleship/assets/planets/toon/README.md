# Cartoon exploration assets

Hand-authored SVG artwork (2026-10-01), no third-party source images. `origin-surface.svg` is an unlit 2048×1024 equirectangular albedo with broad navy-outlined cream/green land, teal oceans, and matching ocean seams. `origin-clouds.svg` is an independent black/white density field. Both use mipmaps and feed `rotating_planet.gd`; the shader provides sphere projection, stationary light, cel bands, rim and differential rotation. The body is approximately 424 logical pixels wide in its exploration stage. This is a presentation prototype for the first configured body's default maps, not a new planet or gameplay rule.

`exploration-field.svg` is a static 764×884 stage field: navy gradient, subdued orbital guides and sparse stars. `planet_visual.gd` draws it on its separate background layer; animations never redraw that layer. Existing configured bodies retain their map paths, rotations and unique corona/beam envelopes. The globe has no per-card 3D viewport; orbital facilities continue using the page's single existing renderer.

No ImageGen prompt: these resources are vector/code-native artwork.
