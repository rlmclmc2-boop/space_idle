extends RefCounted
static func stop_hidden(node:Node,rows:Array)->void:
 if node.is_processing() or node.is_physics_processing():rows.append({"path":str(node.get_path()),"process_before":node.is_processing(),"physics_before":node.is_physics_processing()})
 node.set_process(false);node.set_physics_process(false)
 for child in node.get_children():stop_hidden(child,rows)

static func isolate_hidden_pages(scene)->Array:
 var rows=[]
 for page in scene.equipment_tabs.get_children():
  if page is Control and not page.is_visible_in_tree():stop_hidden(page,rows)
 if is_instance_valid(scene.beginner_guide) and not scene.beginner_guide.is_visible_in_tree():stop_hidden(scene.beginner_guide,rows)
 return rows

static func processing_inventory(scene)->Array:
 var rows=[]
 for node in scene.find_children("*","Node",true,false):
  if node.is_processing() or node.is_physics_processing():
   rows.append({"path":str(node.get_path()),"process":node.is_processing(),"physics":node.is_physics_processing(),"visible":node.is_visible_in_tree() if node is CanvasItem or node is Node3D else null})
 return rows

static func manifest(g,scene)->Dictionary:
 var weapons=[];var enhancement=[]
 for entry in g.profile.loadout.weapons:
  weapons.append(g.player_weapon_row(entry));enhancement.append(g.enhancement_effects(entry))
 var defence_enhancement=[]
 for entry in g.profile.loadout.defence:defence_enhancement.append(g.enhancement_effects(entry))
 return {"scope":"pure combat updates, inherited static rich-fixture modifiers; synthetic held-health authored wave, not natural player",
 "active_tick_updates":["productionElapsed clock","enhancement weapon timers","combat drops","drone combat","repair/repeats","cooldowns","projectiles","enemy shields/attacks"],
 "omitted_tick_updates":["manual hyperspace dispatch/work","hyperspace expeditions","planet production/building","galaxy simulation","crew training","auto generator","hightech research","resource history pruning"],
 "presentation":"original visible battle/HUD/equipment; hidden tab pages retained but autonomous process callbacks explicitly disabled",
 "static_galaxy_fixture_retained":true,"enhancement_level":g.profile.enhancementLevel,
 "enhancement_branches":g.profile.enhancementBranches.duplicate(true),
 "selected_ship":g.profile.selectedShip,"weapon_rows":weapons,"player":g.player.duplicate(true),
 "weapon_enhancement_effects":enhancement,"defence_enhancement_effects":defence_enhancement,
 "hyperspace_totals":g.hyperspace_totals().duplicate(true),"firing_constants":{"missile_lifetime":g.MISSILE_LIFETIME,"ejection_gap":g.EJECTION_GAP},
 "hyperspace_static":g.profile.hyperspace.duplicate(true),"loadout":g.profile.loadout.duplicate(true),
 "stage":g.stage,"group":g.group_index,"enemies":g.enemies.size(),"speed":g.speed,
 "ship_viewport":str(scene.ship_view.viewport.size),"scale_3d":scene.ship_view.viewport.scaling_3d_scale,
 "msaa_3d":scene.ship_view.viewport.msaa_3d,"shadows":scene.ship_view.world.get_node("KeyLight").shadow_enabled,
 "clock":"fixed 1/60 simulation step per submitted frame; throughput, not natural 1x FPS"}
