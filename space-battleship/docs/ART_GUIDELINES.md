# ART: asset constraints
- Ships: true-alpha PNG, source canvas 887x1774; one compact top-down ship, bow up, transparent safe margin. NO background/ground shadow/text/logo/projectile/installed weapon. Enemy rotates 180° in game.
- Hull art has no baked weapons or turrets. Visual hardpoints, shared-slot mapping, size class, faction skin and muzzle/VFX live in `data/ship_weapon_visuals.json`; new loadouts do not require hull redraw.
- Player palette navy/white/cyan; enemy graphite/dark-red/amber. Armor layers, seams, engine glow readable.
- assets/weapons/icons/=slot modules; assets/weapons/*.png=projectile textures; never interchange. Icon: one centered module, square transparent PNG, >=10% margin, visible body ~70–80% mount inner diameter; scale by mount size; exclude hull/ring/UI/text.
- Recognition: laser cyan-white lens/energy track; missile white armor/red spine/twin bays; cannon dark metal/copper/amber coil. New asset -> owning assets README with purpose/source/prompt/consumer scale; prompt transparent single module, no ship/background/text, target size.
