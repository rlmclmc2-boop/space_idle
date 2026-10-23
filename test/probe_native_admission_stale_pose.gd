extends SceneTree
const Geometry=preload("res://scripts/simulation_geometry_authority.gd")

var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=PackedStringArray(["--capture"])
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.hide()
	# A legacy display pose can outlive its contact until the next draw boundary.
	# Native admission must discard it instead of rebinding its entity to {}.
	scene.enemy_poses[0]={"entity":{"uid":900001,"slot":0,"hp":0.0}}
	var geometry=Geometry.new()
	geometry.prepare(scene,scene.game)
	if not geometry.enemy_poses.is_empty():
		printerr("FAIL stale enemy pose retained at native admission")
		quit(1)
		return
	geometry.finish_display_boundary()
	print("PASS stale enemy pose discarded before freeze_display_entity")
	geometry.close({"spatial":scene.game.target_spatial_source})
	var g=scene.game
	var authority=scene.simulation_geometry_authority
	check(authority.canonical_generation>0,"capture startup advances only after authority preparation")
	var caption_metrics_ok:=true
	for registry in [g.db.enemies,g.manual_hyperspace.registry.get("enemies",{}),g.db.groups,g.manual_hyperspace.registry.get("groups",{})]:
		for row in registry.values():
			var caption:String=str(row.get("des",row.get("description",""))).strip_edges()
			if not authority.status_metrics.has(caption):caption_metrics_ok=false;continue
			var metrics:Dictionary=authority.status_caption_metrics(caption)
			var fitted:String=scene.fit_battle_text(caption,260.0,17)
			if metrics.text!=fitted or metrics.size17!=scene.font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,17):caption_metrics_ok=false
	check(caption_metrics_ok,"ordinary and hyperspace caption metrics match the drawing font")
	check(authority.prepared and g.launch_provider.get_object()==authority and g.target_provider.get_object()==authority,"formal startup owns numerical providers before first step")
	var provider:Callable=g.launch_provider
	var initial_hull:String=g.equipment.selected_ship()
	g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
	for hull in ["Destroyer",initial_hull]:
		check(g.switch_ship(hull),"round-trip ship switch "+hull)
		var expected:float=float(scene.visual_config.ships[hull].static_height)*scene.SHIP_VISUALS.player_display_multiplier()*float(g.db.config.get("playerVisualScale"+hull,1.0))
		scene.publish_time_frame()
		check(authority.reference_height==expected and scene.battle_slice_runtime.frame.rendered_height==expected,"configuration height shared by simulation and display "+hull)
		check(is_same(authority,scene.simulation_geometry_authority) and g.launch_provider==provider,"ship switch retains authority/provider")
	var elapsed:float=authority.fleet_pose.elapsed
	var orbit:float=authority.fleet_pose.orbit_elapsed
	check(scene.set_battle_display_enabled(false),"display detaches")
	check(scene.player_render_position()==authority.player_render_position() and scene._stable_player_anchor()==authority.player_render_position(),"detached player queries use authority anchor")
	check(g.launch_provider==provider and authority.fleet_pose.elapsed==elapsed and authority.fleet_pose.orbit_elapsed==orbit,"display detach leaves numerical pose and provider intact")
	check(scene.set_battle_display_enabled(true),"display reattaches")
	check(is_same(scene.battle_slice_runtime.geometry,authority) and g.launch_provider==provider,"display reuses persistent authority")
	g.native_execution_auto=false;g.paused=false
	check(g.start(1,false),"legacy battle starts")
	g.spawn_group();g.state=BattleGame.State.COMBAT
	for enemy in g.enemies:enemy.hp=1e12;enemy.max_hp=1e12;enemy.equipment=[];enemy.cooldowns=[]
	g.player.armour=1e12;g.player.shield=1e12
	g.enemies[0].explicit_formation=true;g.enemies[0].formation_count=g.enemies.size()
	g.notify_configuration_changed();scene.publish_time_frame()
	var validation_time:float=authority.fx_time
	var validation_x:float=float(g.enemies[0].x)
	g.enemies[0].x=-2000.0
	var formation_errors:Array=scene.validate_explicit_formation()
	check(not formation_errors.is_empty(),"formation validation rejects live invalid geometry despite older published view")
	check(authority.fx_time==validation_time,"seven-time formation sampling restores authority clock")
	g.enemies[0].x=validation_x
	var fired:Array=[]
	var drone_fires:=[0]
	var hit_count:=[0]
	g.event.connect(func(kind:String,info:Dictionary):
		if kind=="hit":hit_count[0]+=1
		if kind in ["fire","beam_started"] and info.has("shot") and not bool(info.shot.get("hostile",false)):
			fired.append(str(info.shot.key))
			if not str(info.shot.get("entry",{}).get("drone_id","")).is_empty():drone_fires[0]+=1)
	for weapon in ["laser","missile","cannon","longLaser"]:
		g.projectile_clear()
		if str(g.weapon_entries()[0].key)!=weapon:check(g.equip_slot("weapons",0,weapon),"equip actual weapon "+weapon)
		g.equipment.clear_switches()
		scene._process(1.0/60.0)
		var target:Dictionary=g.enemies[0]
		g.begin_enhancement_attack(0,target)
		var attack:Dictionary=g.jewel_attack(0)
		g.launch_player_attack(0,target,g.player_weapon_row(g.combat_entry(0)),attack,g.player_weapon_offset(0),0.0)
		g.finish_enhancement_attack(0)
		for step in 60:scene._process(1.0/60.0)
		check(fired.has(weapon),"actual launch/beam path "+weapon)
		check(g.launch_provider==provider,"weapon path retains provider "+weapon)
	check(hit_count[0]>0,"actual damage events after weapon launch")
	g.projectile_clear()
	var rng:=RandomNumberGenerator.new();rng.seed=34
	var drone=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"geometry-drone","legendary","laser",5,"1")
	drone.affixes=[]
	var drone_snapshot:Dictionary=g.hyperspace.save_data()
	preload("res://scripts/drone_inventory.gd").insert(drone_snapshot.hyperspace.inventory,drone,g.hyperspace.config)
	check(g.hyperspace.install_snapshot(drone_snapshot,g.db),"install isolated drone inventory fixture")
	check(g.hyperspace_runtime.set_equipped(g,[drone.id]),"equip real drone")
	var drone_slot:int=g.weapon_entries().size()
	var target:Dictionary=g.enemies[0]
	g.begin_enhancement_attack(drone_slot,target)
	var drone_attack:Dictionary=g.jewel_attack(drone_slot)
	g.launch_player_attack(drone_slot,target,g.player_weapon_row(g.combat_entry(drone_slot)),drone_attack,g.player_weapon_offset(drone_slot),0.0)
	g.finish_enhancement_attack(drone_slot)
	check(drone_fires[0]>0 and g.drone_launch_provider.get_object()==authority,"actual drone fire event uses authority mount")
	g.projectile_clear();g.hyperspace_runtime.set_equipped(g,[])
	check(g.admit_native_compiled_execution("native_rich15_layer2"),"native admission")
	scene._process(1.0/60.0)
	check(is_same(scene.battle_slice_runtime.geometry,authority) and g.launch_provider==provider,"native admission preserves authority/provider")
	check(g.native_before_configuration_change(),"native handoff to legacy")
	check(g.native_execution==null and is_same(scene.battle_slice_runtime.geometry,authority) and g.launch_provider==provider,"handoff preserves authority/provider")
	scene._process(1.0/60.0)
	print("GEOMETRY LIFECYCLE: ",checks," checks, ",failures," failures")
	scene.queue_free();await process_frame
	quit(1 if failures else 0)
