# Opening enemy hull candidates

Four approved candidate bindings; source, prompts, alpha and mount evidence: [defence-candidates](../../../../docs/art/opening-three/defence-candidates/README.md). ImageGen original art, mechanically standardized; no baked weapons/shields. 887×1774 RGBA, bow up, runtime rotates 180°. Read at visible hull heights 30/50/80px; crowded 30px four-mount U remains a readability risk pending authoritative loadouts.

`enemy_visual_identity.gd` selects only matching archetype_id/armourType; numeric IDs and size do not infer new identity. Unknown/missing candidates retain old size-key hulls with one diagnostic per reason. `ship_weapon_visuals.json` owns texture and shared mounts; one appearance ship_key feeds both painters and existing geometry capture. No background or battle-data changes.
