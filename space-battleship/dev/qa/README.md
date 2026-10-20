# Integrated gun QA renderer only

integrated_turret_preview.gd is explicitly selected by test_enemy_ranked_art.gd after its isolated2/4 loadout installation. It inherits existing enemy geometry/state and draws only the independent gun PNG around its mechanical housing pivot. The stationary burgundy foundation is already baked into the hull and is never redrawn or rotated by this painter.

The per-case gun width comes from the measured well width. The fixture copies a visual cannon profile in memory and derives its port vector from the PNG pivot-to-tip distance, leaving production profiles and numerical equipment/damage/CD untouched. Probe yaw changes only the textured gun quad around that pivot while the hull/foundation pixels remain fixed; paused±35° examples demonstrate separation. Normal aim is still driven by the existing component pose. This is not registered by production scripts and does not enable the numerical1/2/4 interface or redesign formations.
