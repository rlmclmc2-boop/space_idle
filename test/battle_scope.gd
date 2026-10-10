extends RefCounted
static func manifest(g,scene)->Dictionary:
 var weapons=[]
 for entry in g.profile.loadout.weapons:weapons.append(g.player_weapon_row(entry))
 return {"scope":"pure combat updates, inherited static rich-fixture modifiers; synthetic held-health authored wave, not natural player",
 "active_tick_updates":["productionElapsed clock","enhancement weapon timers","combat drops","drone combat","repair/repeats","cooldowns","projectiles","enemy shields/attacks"],
 "omitted_tick_updates":["manual hyperspace dispatch/work","hyperspace expeditions","planet production/building","galaxy simulation","crew training","auto generator","hightech research","resource history pruning"],
 "presentation":"original visible battle/HUD/equipment; hidden UI remains instantiated; its background presentation processing has NOT yet been proven isolated",
 "static_galaxy_fixture_retained":true,"enhancement_level":g.profile.enhancementLevel,
 "enhancement_branch_choice":g.profile.get("enhancementBranchChoice",{}),
 "selected_ship":g.profile.selectedShip,"weapon_rows":weapons,"player":g.player.duplicate(true),
 "hyperspace_static":g.profile.hyperspace.duplicate(true),"loadout":g.profile.loadout.duplicate(true),
 "stage":g.stage,"group":g.group_index,"enemies":g.enemies.size(),"speed":g.speed,
 "ship_viewport":str(scene.ship_view.viewport.size),"scale_3d":scene.ship_view.viewport.scaling_3d_scale,
 "msaa_3d":scene.ship_view.viewport.msaa_3d,"shadows":scene.ship_view.world.get_node("KeyLight").shadow_enabled,
 "clock":"fixed 1/60 simulation step per submitted frame; throughput, not natural 1x FPS"}
