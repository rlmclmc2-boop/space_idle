extends SceneTree
## Focused graphical inspection only: import, mounts, aim and actual-size frames.

var scene
var output := ""
var facts := {}

func module_rect(node: Node) -> Rect2:
	var result := Rect2()
	var meshes := node.find_children("*","MeshInstance3D",true,false)
	if node==scene.ship_view.ship:
		for carrier in scene.ship_view.carriers: meshes.append_array(carrier.find_children("*","MeshInstance3D",true,false))
	var first := true
	for mesh in meshes:
		if mesh.name in ["PrototypeShield","BlueExhaust"]: continue
		var bounds: AABB = mesh.get_aabb()
		for index in 8:
			var point: Vector2 = scene.ship_view.camera.unproject_position(mesh.global_transform*bounds.get_endpoint(index))
			if first:
				result=Rect2(point,Vector2.ZERO)
				first=false
			else: result=result.expand(point)
	return result

func measure_clearance() -> Dictionary:
	var view=scene.ship_view
	var overlaps := []
	var minimum_gap := INF
	var footprints := []
	for module in view.modules: footprints.append(module_rect(module.node))
	for i in footprints.size():
		for j in range(i+1,footprints.size()):
			var a: Rect2=footprints[i]
			var b: Rect2=footprints[j]
			if a.intersects(b): overlaps.append([view.modules[i].slot,view.modules[j].slot])
			var gap := Vector2(maxf(0,maxf(a.position.x-b.end.x,b.position.x-a.end.x)),maxf(0,maxf(a.position.y-b.end.y,b.position.y-a.end.y))).length()
			minimum_gap=minf(minimum_gap,gap)
	return {"projected_bounds_overlaps":overlaps,"minimum_gap_logical_pixels":minimum_gap}

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	facts.render_surface=str(frame.get_size())
	facts.battle_physical=str(scene.BATTLE_VIEW_SIZE*(float(frame.get_width())/1952.0))
	frame.save_png(output.path_join(name+".png"))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	scene=load("res://dev/toon_ship_test.tscn").instantiate()
	root.add_child(scene)
	root.size=Vector2i(1335,859)
	root.position=Vector2i(8,40)
	for i in 20: await process_frame
	scene.game.paused=true
	scene.set_process(false)
	var center: Vector2=scene.player_render_position()+scene.reference_offset
	var view=scene.ship_view
	var before := JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	var rng_before: int=scene.game.rng.state
	facts={"fixture":"synthetic-full-loadout" if not scene.fixture_name.is_empty() else "isolated-snapshot","silhouette_protection":scene.protect_silhouette,"hull_modules":view.modules.filter(func(item):return item.carrier=="hull").size(),"drone_modules":view.carriers.size(),"ship":scene.game.profile.selectedShip,"slots":[],"save_enabled":scene.game.save_enabled,
		"window":str(root.size),"battle_logical":str(scene.BATTLE_VIEW_SIZE),"reference_height":scene.reference_height,
		"render_surface":str(root.get_texture().get_size()),"battle_physical":str(scene.BATTLE_VIEW_SIZE*(root.get_texture().get_size().x/1952.0)),"directions":{},
		"diagnostic_aim_override":true,"live_aim_limit_unchanged":true,"turn_overlaps":[],"turn_minimum_gap":INF}
	if view.modules.size()!=scene.game.weapon_entries().filter(func(entry):return not str(entry.key).is_empty()).size():
		printerr("FAIL: incomplete loadout")
		quit(1)
		return
	for module in view.modules:
		facts.slots.append({"slot":module.slot,"key":module.key,"mount":str(module.mount.position),
			"carrier":module.carrier,"mount_index":module.mount_index,"identity_transform":module.node.transform==Transform3D.IDENTITY,
			"independent_aim_geometry":module.pivot.find_children("*","MeshInstance3D",true,false).size()>0,
			"muzzle_child_of_pivot":module.pivot.is_ancestor_of(module.muzzle)})
	var directions := {"front":Vector2(0,-600),"left":Vector2(-600,0),"right":Vector2(600,0),
		"rear-left":Vector2(-450,450),"rear-right":Vector2(450,450)}
	scene.set_effects(false)
	for direction in directions:
		view.set_pose(center,scene.reference_height,0,center+directions[direction],2.1,false,false)
		var points := []
		for module in view.modules:
			points.append({"slot":module.slot,"angle":module.pivot.rotation.y,"muzzle":str(view.screen_muzzle_for_slot(module.slot))})
		facts.directions[direction]={"muzzles":points,"clearance":measure_clearance(),"combined_footprint":str(module_rect(view.ship))}
		await capture("full-window-"+direction+"-clean")
	# Record a deterministic presentation turn. It does not tick combat or RNG.
	for frame in 180:
		var angle := TAU*float(frame)/179.0
		view.set_pose(center,scene.reference_height,0,center+Vector2(sin(angle),-cos(angle))*600,2.1,false,false)
		var clearance := measure_clearance()
		facts.turn_minimum_gap=minf(facts.turn_minimum_gap,clearance.minimum_gap_logical_pixels)
		if not clearance.projected_bounds_overlaps.is_empty(): facts.turn_overlaps.append({"frame":frame,"slots":clearance.projected_bounds_overlaps})
		if frame%15==0: await capture("frames/turn-%04d"%frame)
		else: await process_frame
	scene.set_effects(true)
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-600),2.7,true,false)
	scene.battle_layer.queue_redraw()
	await capture("full-window-effects")
	facts.combined_footprint_front=str(module_rect(view.ship))
	var combined: Rect2=module_rect(view.ship)
	facts.formation_inside_battle=Rect2(Vector2.ZERO,scene.BATTLE_VIEW_SIZE).encloses(combined)
	facts.presentation_preserves_state=before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	facts.presentation_preserves_rng=rng_before==scene.game.rng.state
	# Repeated no-change updates preserve nodes; edits and switching rebuild only this view.
	var first_id: int=view.modules[0].node.get_instance_id() if not view.modules.is_empty() else 0
	view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	facts.unchanged_loadout_preserves_nodes=first_id==(view.modules[0].node.get_instance_id() if not view.modules.is_empty() else 0)
	var fixture_entries: Array=scene.game.weapon_entries().duplicate(true)
	fixture_entries[0].key=""
	view.set_loadout(fixture_entries,scene.game.active_slot_count("weapons"))
	facts.empty_slot_absent=not view.modules.any(func(item):return item.slot==0)
	view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	facts.restored_count=view.modules.size()
	view.set_loadout([],scene.game.active_slot_count("weapons"))
	facts.all_empty_removes_carriers=view.modules.is_empty() and view.carriers.is_empty()
	var alternate_hull := "Frigate" if str(scene.game.profile.selectedShip)!="Frigate" else "Heavy_Battleship"
	view.set_hull(alternate_hull)
	view.set_loadout(scene.game.weapon_entries(),int(scene.db.ship(alternate_hull).weaponSlots))
	facts.switch_roundtrip=view.set_hull(str(scene.game.profile.selectedShip)) and view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-600),2.7,true,false)
	facts.presentation_edit_preserves_state=before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	# Resume the unchanged game only to inspect existing firing effects from these mounts.
	scene.game.paused=false
	scene.set_process(true)
	facts.live_projectile_keys=[]
	for frame in 150:
		await process_frame
		for shot in scene.game.projectiles:
			if not shot.hostile and not facts.live_projectile_keys.has(str(shot.key)): facts.live_projectile_keys.append(str(shot.key))
		if frame in [15,40,70,100]: await capture("full-window-live-effects-%03d"%frame)
		if frame%15==0: await capture("frames/effects-%04d"%frame)
	scene.game.paused=true
	scene.set_process(false)
	await capture("effects-original-order-same-state")
	var effect_state := JSON.stringify([scene.game.player,scene.game.projectiles])
	var effect_rng: int = scene.game.rng.state
	scene.battle_clip.move_child(view,scene.battle_layer.get_index()+1)
	await capture("effects-experimental-mask-same-state")
	facts.effect_order_preserves_state=effect_state==JSON.stringify([scene.game.player,scene.game.projectiles]) and effect_rng==scene.game.rng.state
	scene.battle_clip.move_child(view,scene.battle_layer.get_index())
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	print("FULL_LOADOUT ",JSON.stringify(facts))
	var passed: bool=facts.presentation_preserves_state and facts.presentation_preserves_rng and facts.unchanged_loadout_preserves_nodes and facts.empty_slot_absent and facts.presentation_edit_preserves_state and facts.effect_order_preserves_state and facts.all_empty_removes_carriers and facts.switch_roundtrip and not facts.save_enabled
	if not passed: printerr("FAIL: hybrid presentation contract")
	quit(0 if passed else 1)
