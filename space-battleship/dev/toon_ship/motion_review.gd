extends SceneTree
## Focused deterministic presentation motion capture. Never advances or edits gameplay.

const DT := 1.0 / 30.0
const STATIONARY_FRAMES := 180
const MOTION_FRAMES := 180
const EPSILON := 0.00001

var scene
var output := ""
var facts: Dictionary = {}
var errors: Array[String] = []
var frame_facts: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition and not errors.has(message):
		errors.append(message)
		printerr("FAIL: ",message)

func vector_values(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

func carrier_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var view = scene.ship_view
	for module in view.modules:
		if str(module.carrier) != "drone": continue
		var carrier: Node3D = module.mount
		while carrier.get_parent() != view.world and carrier.get_parent() != view.ship:
			carrier = carrier.get_parent() as Node3D
		var offset: Array = view.hull_config.drone_offsets[int(module.mount_index)]
		var target: Vector3 = view.ship.to_global(Vector3(float(offset[0]),float(offset[1]),float(offset[2])))
		records.append({"slot":int(module.slot),"node":carrier,"position":carrier.global_position,"target":target,
			"lag_model":carrier.global_position.distance_to(target)/view.ship.scale.x})
	return records

func pose_snapshot() -> Array:
	var poses: Array = [scene.ship_view.ship.global_transform]
	for carrier in scene.ship_view.carriers: poses.append(carrier.global_transform)
	for module in scene.ship_view.modules: poses.append(module.muzzle.global_transform)
	return poses

func inspect_pose(frame: int, stage: String, center: Vector2) -> Dictionary:
	var view = scene.ship_view
	var records := carrier_records()
	var maximum_lag := 0.0
	var carriers: Array = []
	var muzzles: Array = []
	check(view.modules.size() == 8,"Heavy fixture must retain all eight weapons")
	check(view.carriers.size() == records.size(),"Every carrier must have one mounted weapon")
	check(view.ship.rotation.is_equal_approx(Vector3.ZERO),"Mother ship yaw must remain zero")
	for record in records:
		var carrier: Node3D = record.node
		maximum_lag = maxf(maximum_lag,float(record.lag_model))
		check(carrier.get_parent() == view.world and not view.ship.is_ancestor_of(carrier),"Carrier must be a world sibling, never inherit mother transform")
		check(carrier.scale.is_equal_approx(view.ship.scale*view.CARRIER_SCALE),"World carrier must receive explicit authored scale")
		check(absf(carrier.rotation.y)<=0.14001 and is_zero_approx(carrier.rotation.x) and is_zero_approx(carrier.rotation.z),"Independent carrier heading must stay within its small authored bound")
		check(carrier_safety(record.position,records,int(record.slot)),"Carrier must remain clear of the hull, weapons, other carriers and viewport edges")
		carriers.append({"slot":record.slot,"position":vector_values(record.position),"target":vector_values(record.target),"lag_model":record.lag_model})
	for module in view.modules:
		var point: Vector2 = view.screen_muzzle_for_slot(int(module.slot))
		check(point.is_finite() and Rect2(Vector2.ZERO,scene.BATTLE_VIEW_SIZE).has_point(point),"Every muzzle must project inside the battlefield")
		check(module.pivot.is_ancestor_of(module.muzzle),"Muzzle must remain under its independent aiming pivot")
		muzzles.append({"slot":int(module.slot),"screen":[point.x,point.y]})
	return {"frame":frame,"stage":stage,"time_seconds":float(frame)*DT,"center":[center.x,center.y],
		"mother_world":vector_values(view.ship.global_position),"maximum_lag_model":maximum_lag,"carriers":carriers,"muzzles":muzzles}

func carrier_safety(point: Vector3, records: Array[Dictionary], own_slot: int) -> bool:
	# Independent reconstruction of the documented conservative safety envelopes.
	var view=scene.ship_view
	var scale_value: float=view.ship.scale.x
	var local: Vector3=(point-view.ship.global_position)/scale_value
	var low: Array=view.hull_config.godot_aabb_min
	var high: Array=view.hull_config.godot_aabb_max
	var radius: float=float(view.manifest.weapon_contract.conservative_xz_rotation_radius)*view.CARRIER_SCALE
	if local.x>float(low[0])-radius and local.x<float(high[0])+radius and local.z>float(low[2])-radius and local.z<float(high[2])+radius: return false
	for mount in view.hull_config.weapon_mounts:
		var position: Array=mount.position
		if Vector2(local.x-float(position[0]),local.z-float(position[2])).length()<radius+1.24+0.08: return false
	for record in records:
		if int(record.slot)==own_slot: continue
		var diff: Vector3=(point-Vector3(record.position))/scale_value
		if Vector2(diff.x,diff.z).length()<radius*2.0+0.12: return false
	var screen: Vector2=view.camera.unproject_position(point)
	var pixel_radius: float=radius*scale_value/view.WORLD_PER_PIXEL+10.0
	return Rect2(Vector2.ONE*pixel_radius,view.size-Vector2.ONE*pixel_radius*2.0).has_point(screen)

func label_capture() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.025,0.035,0.05,0.95)
	background.position = Vector2(6,5)
	background.size = Vector2(1080,37)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	var label := Label.new()
	label.text = "PRESENTATION MOTION TEST | SYNTHETIC HEAVY | COMBAT PAUSED | 30 FPS"
	label.position = Vector2(14,8)
	label.add_theme_font_size_override("font_size",22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.get_size() == Vector2i(1335,859),"Capture must use the actual 1335x859 window surface")
	check(frame.save_png(output.path_join(path)) == OK,"Failed to save rendered PNG: "+path)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty():
		printerr("Supply --output=ABSOLUTE_DIRECTORY and --prototype-fixture=Heavy_Battleship")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	scene=load("res://dev/toon_ship_test.tscn").instantiate()
	root.add_child(scene)
	# The scene's _ready uses the no-save fixture path. Pause before its first process.
	scene.game.paused=true
	scene.set_process(false)
	root.size=Vector2i(1335,859)
	root.position=Vector2i(8,40)
	root.title="PRESENTATION MOTION TEST | SYNTHETIC HEAVY | COMBAT PAUSED"
	check(scene.fixture_name == "Heavy_Battleship","Only the synthetic Heavy_Battleship fixture is valid")
	check(not scene.game.save_enabled,"Fixture must never write player progress")
	var before := JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	var rng_before: int=scene.game.rng.state
	var view=scene.ship_view
	scene.set_effects(false)
	label_capture()
	var center: Vector2=scene.player_render_position()+scene.reference_offset
	var target: Vector2=center+Vector2(0,-600)
	view.set_pose(center,scene.reference_height,0,target,0,false,false,0.0)
	for i in 12: await process_frame
	var stationary_mother: Transform3D = view.ship.global_transform
	var stationary_carriers := carrier_records()
	var carrier_maximum_displacements := {}
	for record in stationary_carriers: carrier_maximum_displacements[int(record.slot)]=0.0
	facts={"label":"PRESENTATION MOTION TEST","fixture":"synthetic Heavy_Battleship full loadout, not a player save",
		"gameplay_paused":scene.game.paused,"save_enabled":scene.game.save_enabled,"visual_delta_seconds":DT,
		"stationary_frames":STATIONARY_FRAMES,"movement_and_settle_frames":MOTION_FRAMES,"continuous_frame_count":STATIONARY_FRAMES+MOTION_FRAMES,
		"motion_input":"presentation center x +40 logical pixels over 1 second, then 5 seconds hold; no gameplay input",
		"window":[1335,859],"battle_logical":[scene.BATTLE_VIEW_SIZE.x,scene.BATTLE_VIEW_SIZE.y],
		"reference_height_logical":scene.reference_height,"reference_height_physical":scene.reference_height*1335.0/1952.0,
		"mother_scale":view.ship.scale.x,"weapon_count":view.modules.size(),"drone_count":view.carriers.size(),
		"stationary_mother_maximum_drift":0.0,"maximum_lag_model":0.0,
		"stationkeeping":"independent visual RNG, per-drone destinations/dwell, .90 model-unit anchor deadband and .78 per-axis wander",
		"normal_movement_source":{"game_player_coordinates":"scripts/game.gd reset_player initializes fixed PLAYER_POSITION; no normal x/y integration found",
			"travel":"scripts/game.gd travel changes distance by ship_movement()*dt",
			"existing_presentation":"scripts/main.gd player_render_position and player_idle_angle contain visual sine offsets; prototype removes these"}}
	await capture("full-window-before-motion.png")
	# One rendered image for every deterministic visual step; no sampling or interpolated images.
	for frame in STATIONARY_FRAMES+MOTION_FRAMES:
		var stage := "stationary"
		var rendered_center := center
		if frame >= STATIONARY_FRAMES:
			var motion_frame := frame-STATIONARY_FRAMES
			stage="moving" if motion_frame < 30 else "settling"
			rendered_center.x += 40.0*minf(float(motion_frame+1)/30.0,1.0)
		view.set_pose(rendered_center,scene.reference_height,0,target+rendered_center-center,float(frame+1)*DT,false,false,DT)
		var observation := inspect_pose(frame,stage,rendered_center)
		facts.maximum_lag_model=maxf(float(facts.maximum_lag_model),float(observation.maximum_lag_model))
		frame_facts.append(observation)
		if frame<STATIONARY_FRAMES:
			check(view.ship.global_transform == stationary_mother,"Stationary mother must have exactly zero transform drift")
			facts.stationary_mother_maximum_drift=maxf(float(facts.stationary_mother_maximum_drift),view.ship.global_position.distance_to(stationary_mother.origin))
			var current_carriers := carrier_records()
			for index in current_carriers.size():
				var record: Dictionary=current_carriers[index]
				var movement: float=record.position.distance_to(stationary_carriers[index].position)/view.ship.scale.x
				carrier_maximum_displacements[int(record.slot)]=maxf(float(carrier_maximum_displacements[int(record.slot)]),movement)
		await capture("frames/frame-%04d.png"%frame)
	facts.final_lag_model=frame_facts.back().maximum_lag_model
	facts.stationary_carrier_displacements_model=carrier_maximum_displacements
	check(carrier_maximum_displacements.values().all(func(distance):return float(distance)>0.01),"Every drone must show independent stationkeeping movement while the mother remains still")
	facts.mother_ended_at_x40=view.rendered_position.is_equal_approx(center+Vector2(40,0))
	check(facts.mother_ended_at_x40,"Mother must stop at exactly x+40 after the controlled one-second move")
	await capture("full-window-after-settle.png")
	# A nonzero error is intentionally created, then dt=0 must preserve it exactly.
	var moved_center := center+Vector2(45,0)
	view.set_pose(moved_center,scene.reference_height,0,target+Vector2(45,0),12,false,false,DT)
	var paused_pose := pose_snapshot()
	var paused_carrier_state := str(view.carrier_states)
	var paused_visual_rng: int=view.visual_rng.state
	for i in 20:
		view.set_pose(moved_center,scene.reference_height,0,target+Vector2(45,0),12,false,false,0.0)
	facts.zero_delta_freezes_pose=pose_snapshot()==paused_pose and paused_carrier_state==str(view.carrier_states) and paused_visual_rng==view.visual_rng.state
	check(facts.zero_delta_freezes_pose,"Zero visual delta must not integrate carrier motion")
	# Verify the active prototype position/heading itself has no sine drift.
	var saved_fx: float=scene.fx_time
	var presentation_positions: Array=[]
	var presentation_angles: Array=[]
	for time_value in [0.0,1.0,3.0,6.0,12.0]:
		scene.fx_time=time_value
		presentation_positions.append(scene.player_render_position())
		presentation_angles.append(scene.player_idle_angle())
	scene.fx_time=saved_fx
	facts.no_idle_translation=presentation_positions.all(func(point):return point==presentation_positions[0])
	facts.no_idle_yaw=presentation_angles.all(func(angle):return is_zero_approx(float(angle)))
	check(facts.no_idle_translation and facts.no_idle_yaw,"Prototype source pose must remain still when only presentation time changes")
	# Rebuild only the view and restore Heavy. Neither profile nor game player changes.
	var entries: Array=scene.game.weapon_entries().duplicate(true)
	check(view.set_hull("Frigate"),"Frigate switch failed")
	check(view.set_loadout(entries,int(scene.db.ship("Frigate").weaponSlots)),"Frigate loadout failed")
	view.set_pose(center,scene.reference_height,0,target,0,false,false,0.0)
	facts.frigate_carriers_are_world_siblings=view.carriers.all(func(carrier):return carrier.get_parent()==view.world)
	check(facts.frigate_carriers_are_world_siblings,"Frigate carrier cleanup/reparenting failed")
	check(view.set_hull("Heavy_Battleship"),"Heavy return switch failed")
	check(view.set_loadout(entries,scene.game.active_slot_count("weapons")),"Heavy return loadout failed")
	view.set_pose(center,scene.reference_height,0,target,0,false,false,0.0)
	var restored := inspect_pose(0,"restored",center)
	facts.restored_weapon_count=view.modules.size()
	facts.restored_carrier_count=view.carriers.size()
	facts.restored_initial_lag_model=restored.maximum_lag_model
	facts.restored_no_origin_pop=carrier_records().all(func(record):return record.position.distance_to(record.target)<EPSILON and record.position.distance_to(Vector3.ZERO)>EPSILON)
	check(facts.restored_no_origin_pop,"New carriers must initialize directly at their authored world target")
	facts.presentation_preserves_state=before==JSON.stringify([scene.game.profile,scene.game.player,scene.game.projectiles])
	facts.presentation_preserves_rng=rng_before==scene.game.rng.state
	facts.gameplay_remains_paused=scene.game.paused
	check(facts.presentation_preserves_state and facts.presentation_preserves_rng and facts.gameplay_remains_paused,"Presentation test must leave game profile, player, projectiles and RNG untouched")
	facts.errors=errors
	facts.passed=errors.is_empty()
	FileAccess.open(output.path_join("facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	FileAccess.open(output.path_join("frame-facts.json"),FileAccess.WRITE).store_string(JSON.stringify(frame_facts,"\t"))
	print("MOTION_REVIEW ",JSON.stringify(facts))
	quit(0 if facts.passed else 1)
