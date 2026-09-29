# Planet texture assets

`surface.png` and `clouds.png`: generated with the built-in imagegen tool, 2026-09-29. Reference: `../ui/planet-globe.png` (palette/style only). Native outputs: 1774×887 each. Consumer: `scripts/rotating_planet.gd`, roughly 359 logical pixels across in the exploration stage. Mipmaps reduce minification shimmer. Original globe is retained for other consumers.

Surface is an unlit equirectangular albedo. Clouds are an independent grayscale density map (black clear, white dense); the shader supplies opacity, differential motion, cloud shadow, fixed lighting and atmosphere. No extra atmosphere bitmap is required. A narrow shader overlap closes generated horizontal seams.

## Reuse

Instantiate `rotating_planet.gd`, call `fit_sphere(center, radius)`, then `advance(delta, paused)` only while its owner is visible. Swap `surface_map` / `cloud_map` and call `apply_settings()` after changing exported appearance properties. Each instance owns its material. Speeds are turns/second, glow/shadow/cloud opacity are 0–1, and `light_direction` is screen-space xyz with positive z toward the viewer.

The `planet.xlsx` optional `visual` JSON column is the appearance authority (projected by the existing importer). It accepts `surfaceTexture`, `cloudTexture`, `surfaceSpeed`, `cloudSpeed`, `glowStrength`, `shadowStrength`, `cloudOpacity`, `atmosphereColor`. The legacy `texture` field describes a pre-rendered globe and is deliberately not treated as a scrolling surface map.

Stellar appearances use the same sphere: `emission`, `surfaceTint`, `shadowTint`, `detailScale`, `detailStrength`, `radiusScale`, `axisRatio`, `coronaWidth`, `pulseStrength`, `pulseSpeed`, `flareStrength`, `beamLength`, `beamWidth`, `beamSpeed`, `magnetosphere`. Radii and beam lengths are relative to the body; time settings use seconds, rotation uses turns/second. Omitted fields inherit neutral defaults; missing maps use the original textures. Geometry, halo, transparent cones and magnetic field are shader-generated. Visual clock is owned by the visible page, independent of exploration time. New bodies need only table rows and assets; IDs never select rendering code. The pulsar retains numeric gameplay ID `6` and display name `脉冲星-PSR T46+38`; resource filenames use safe ASCII.

`t587e_surface.png` and `stellar_plasma.png`: built-in ImageGen, 2026-09-29, native 1774×887. Gas uses one map at two UV rates; all stellar bodies share the neutral plasma map at different scales/contrasts. Exploration body diameters: gas ~377, main sequence ~298, red giant ~438, dwarf ~79, pulsar ~57 logical pixels. No physical planetary ring bitmap or mesh is added. Import with mipmaps.

Additional generation prompts:

> Generate ONE game-ready rectangular equirectangular albedo texture, 2:1 aspect ratio, full-bleed seamless horizontally tileable atmospheric gas giant map. Soft horizontal cream ivory pale gold sand and muted light brown cloud bands, broad stable gentle flows, fine subtle wisps, very weak large oval storms. Low contrast elegant heavy atmosphere, Saturn-like palette but original alien cloud patterns, NOT Jupiter. Flat uniformly unlit texture fills EVERY pixel; no spherical globe, no lighting, no shadow, no rings, no space, no text or borders. Shader will provide spherical mapping and differential cloud motion. Save output image locally for game project asset.

> ONE full-bleed game texture: flat rectangular 2:1 equirectangular stellar convection plasma density field. Grayscale only, bright silver-gray irregular convection cells separated by darker thin meandering channels, organic billowing cellular granulation, multiscale turbulent fine filament details inside each cell. Approximately 35 cells across width, irregular natural sizes. Moderate contrast no pure black, no black holes. Horizontally seamless tileable, consistent scale and brightness everywhere, uniform unlit map. No sphere, no globe, no directional light, no corona, no beams, no stars, no space background, no lettering, no border. This single neutral texture will be colored warm white for fine main sequence granulation and dark orange/red for coarse red giant convection by Godot shader UV scale, and subtler blue-white for compact stellar cores.

## Generation prompts

Surface:

> Generate a game-ready flat equirectangular 2:1 planetary surface albedo texture, 2048x1024. Reference image is STYLE AND PALETTE ONLY: preserve its rich navy ocean, turquoise shallow seas, olive green alien continents, intricate beige ridges and snowy mountain chains. Unwrap a full fictional terrestrial world into a RECTANGULAR map filling every pixel. Seamlessly horizontally tileable with matching left/right ocean margins, continuous fine grain, polar ice at top and bottom. Large recognizable irregular continents and archipelagos, premium realistic satellite terrain. Uniform unlit diffuse color, NO clouds, NO cast shadows, NO directional illumination, NO globe, NO sphere, NO horizon, NO space, NO text, NO borders, NO UI. Shader will supply spherical projection, lighting, rotation and atmosphere.

Clouds:

> Game texture asset: full rectangular 2:1 equirectangular planetary CLOUD DENSITY MAP. White wispy realistic satellite cirrus cloud systems and a few delicate swirling weather fronts on pure black background. Soft gray semitransparent feathered detail, fine tendrils, broad clear empty gaps, roughly 35 percent cloud coverage. Seamless horizontal tile, matching left/right edges. Flat unlit global map filling entire frame, no globe no sphere no terrain no ocean no lighting no border no text. Will be sampled as a monochrome opacity mask by a shader on a blue green terrestrial planet. 2048x1024.
