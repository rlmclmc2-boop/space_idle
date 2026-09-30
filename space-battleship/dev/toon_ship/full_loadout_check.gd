extends SceneTree
## Focused graphical inspection only: import, mounts, aim and actual-size frames.

var scene
var output := ""
var facts := {}

func module_rect(node: Node) -> Rect2:
	var result := Rect2()
	var meshes := node.find_children("*","MeshInstance3D",true,false)
	var first := true
	for mesh in meshes:
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
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	scene=load("res://dev/toon_ship_test.tscn").instantiate()
	root.add_child(scene)
	for i in 20: await process_frame
	scene.game.paused=true
	scene.set_process(false)
	var center: Vector2=scene.player_render_position()+scene.reference_offset
	var view=scene.ship_view
	var before := JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	var rng_before: int=scene.game.rng.state
	facts={"ship":scene.game.profile.selectedShip,"slots":[],"save_enabled":scene.game.save_enabled,
		"window":str(root.size),"battle_logical":str(scene.BATTLE_VIEW_SIZE),"reference_height":scene.reference_height,
		"battle_physical":str(scene.BATTLE_VIEW_SIZE*Vector2(root.size)/Vector2(1952,1256)),"directions":{},
		"diagnostic_aim_override":true,"live_aim_limit_unchanged":true,"turn_overlaps":[],"turn_minimum_gap":INF}
	if view.modules.size()!=scene.game.weapon_entries().size():
		printerr("FAIL: incomplete loadout")
		quit(1)
		return
	for module in view.modules:
		facts.slots.append({"slot":module.slot,"key":module.key,"mount":str(module.mount.position),
			"identity_transform":module.node.transform==Transform3D.IDENTITY,
			"independent_barrel":module.node.find_child("EnergyBarrel",true,false)!=null or module.node.find_child("Barrel",true,false)!=null,
			"muzzle_child_of_pivot":module.pivot.is_ancestor_of(module.muzzle)})
	var directions := {"front":Vector2(0,-600),"left":Vector2(-600,0),"right":Vector2(600,0),
		"rear-left":Vector2(-450,450),"rear-right":Vector2(450,450)}
	scene.set_effects(false)
	for direction in directions:
		view.set_pose(center,scene.reference_height,0,center+directions[direction],2.1,false,false)
		var points := []
		for module in view.modules:
			points.append({"slot":module.slot,"angle":module.pivot.rotation.y,"muzzle":str(view.screen_muzzle_for_slot(module.slot))})
		facts.directions[direction]={"muzzles":points,"clearance":measure_clearance()}
		await capture("full-window-"+direction+"-clean")
	# Record a deterministic presentation turn. It does not tick combat or RNG.
	for frame in 150:
		var angle := TAU*float(frame)/149.0
		view.set_pose(center,scene.reference_height,0,center+Vector2(sin(angle),-cos(angle))*600,2.1,false,false)
		var clearance := measure_clearance()
		facts.turn_minimum_gap=minf(facts.turn_minimum_gap,clearance.minimum_gap_logical_pixels)
		if not clearance.projected_bounds_overlaps.is_empty(): facts.turn_overlaps.append({"frame":frame,"slots":clearance.projected_bounds_overlaps})
		await capture("frames/turn-%04d"%frame)
	scene.set_effects(true)
	view.set_pose(center,scene.reference_height,0,center+Vector2(0,-600),2.7,true,false)
	scene.battle_layer.queue_redraw()
	await capture("full-window-effects")
	facts.presentation_preserves_state=before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	facts.presentation_preserves_rng=rng_before==scene.game.rng.state
	# Resume the unchanged game only to inspect existing firing effects from these mounts.
	scene.game.paused=false
	scene.set_process(true)
	for frame in 150:
		await process_frame
		if frame in [15,40,70,100]: await capture("full-window-live-effects-%03d"%frame)
		await capture("frames/effects-%04d"%frame)
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	print("FULL_LOADOUT ",JSON.stringify(facts))
	quit()
