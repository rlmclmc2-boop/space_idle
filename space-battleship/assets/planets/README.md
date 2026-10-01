# Planet texture assets

The first-body cartoon prototype and its static exploration backdrop are documented in [toon/README.md](toon/README.md). These are the current default sphere maps; configured map paths remain authoritative.

`surface.png` and `clouds.png`: generated with the built-in imagegen tool, 2026-09-29. Reference: `../ui/planet-globe.png` (palette/style only). Native outputs: 1774×887 each. Legacy albedo/cloud assets remain available to `scripts/rotating_planet.gd` through configured map paths. Mipmaps reduce minification shimmer. The original finished globe is retained for other consumers.

Surface is an unlit equirectangular albedo. Clouds are an independent grayscale density map (black clear, white dense); the shader supplies opacity, differential motion, cloud shadow, fixed lighting and atmosphere. No extra atmosphere bitmap is required. A narrow shader overlap closes generated horizontal seams.

## Reuse

Instantiate `rotating_planet.gd`, call `fit_sphere(center, radius)`, then `advance(delta, paused)` only while its owner is visible. Swap `surface_map` / `cloud_map` and call `apply_settings()` after changing exported appearance properties. Each instance owns its material. Speeds are turns/second, glow/shadow/cloud opacity are 0–1, and `light_direction` is screen-space xyz with positive z toward the viewer.

The `planet.xlsx` optional `visual` JSON column is the appearance authority (projected by the existing importer). It accepts `surfaceTexture`, `cloudTexture`, `surfaceSpeed`, `cloudSpeed`, `glowStrength`, `shadowStrength`, `cloudOpacity`, `atmosphereColor`. The legacy `texture` field describes a pre-rendered globe and is deliberately not treated as a scrolling surface map.

Stellar appearances use the same sphere: `emission`, `surfaceTint`, `shadowTint`, `detailScale`, `detailStrength`, `radiusScale`, `axisRatio`, `coronaWidth`, `pulseStrength`, `pulseSpeed`, `flareStrength`, `beamLength`, `beamWidth`, `beamSpeed`, `magnetosphere`. Radii and beam lengths are relative to the body; time settings use seconds, rotation uses turns/second. Omitted fields inherit neutral defaults; missing maps use the current default sphere textures. Geometry, halo, transparent cones and magnetic field are shader-generated. Visual clock is owned by the visible page, independent of exploration time. New bodies need only table rows and assets; IDs never select rendering code. The pulsar retains numeric gameplay ID `6` and display name `脉冲星-PSR T46+38`; resource filenames use safe ASCII.

`t587e_surface.png` and `stellar_plasma.png`: built-in ImageGen, 2026-10-01, native 1774×887 RGB. Cartoon replacements are saved at the existing configured paths, with mipmaps. Gas has broad cream/gold/olive atmospheric bands and rounded eddies; its one map is sampled at the two configured UV rates. All four stellar bodies share the neutral rounded-cell plasma map. Existing appearance fields control scale, tint, radius, corona, pulse and jets. No extra ring mesh, bitmap or second magnetic-field layer is added.

## Cartoon generation prompts

Gas:

> Game-ready cartoon science-fiction gas-giant unlit albedo; flat full-bleed 2:1 equirectangular map, seamless horizontally. Broad calm cream/ivory/pale-gold/sandy-beige/pale-olive bands, a few clean rounded flowing swells and sparse stylized oval eddies. Soft cel-painted flat patches, minimal detail, no photographic grit. Shader supplies spherical wrapping and light. No globe, sphere, planet outline, rings, halo, space, stars, text, UI or frame. Matching left/right edges.

Shared stellar map:

> Cartoon stellar plasma density albedo; flat full-bleed 2:1 horizontally seamless grayscale map. Large organic rounded convection cells, broad cloud-puff interiors and medium-gray channels, clean two/three-tone patches with minimal wispy highlights. No fine noise or photographic granulation. Uniformly unlit, no sphere, globe, corona, beams, space, stars, text, border or UI. Shader supplies tint, spherical wrapping, scale differences, glow and magnetic jets. Matching left/right edges.

## Generation prompts

Surface:

> Generate a game-ready flat equirectangular 2:1 planetary surface albedo texture, 2048x1024. Reference image is STYLE AND PALETTE ONLY: preserve its rich navy ocean, turquoise shallow seas, olive green alien continents, intricate beige ridges and snowy mountain chains. Unwrap a full fictional terrestrial world into a RECTANGULAR map filling every pixel. Seamlessly horizontally tileable with matching left/right ocean margins, continuous fine grain, polar ice at top and bottom. Large recognizable irregular continents and archipelagos, premium realistic satellite terrain. Uniform unlit diffuse color, NO clouds, NO cast shadows, NO directional illumination, NO globe, NO sphere, NO horizon, NO space, NO text, NO borders, NO UI. Shader will supply spherical projection, lighting, rotation and atmosphere.

Clouds:

> Game texture asset: full rectangular 2:1 equirectangular planetary CLOUD DENSITY MAP. White wispy realistic satellite cirrus cloud systems and a few delicate swirling weather fronts on pure black background. Soft gray semitransparent feathered detail, fine tendrils, broad clear empty gaps, roughly 35 percent cloud coverage. Seamless horizontal tile, matching left/right edges. Flat unlit global map filling entire frame, no globe no sphere no terrain no ocean no lighting no border no text. Will be sampled as a monochrome opacity mask by a shader on a blue green terrestrial planet. 2048x1024.
