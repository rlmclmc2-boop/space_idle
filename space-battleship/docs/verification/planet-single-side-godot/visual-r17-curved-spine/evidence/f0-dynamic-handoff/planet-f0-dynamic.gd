extends SceneTree

const OUT := "/tmp/planet-f0-dynamic"
const PHASE_FRAMES := 96
const PHASE_STEP := TAU / (float(PHASE_FRAMES) * 0.045)
var game
var session
var panel
var manifest: Array = []

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT.path_join(name + ".png")) == OK)

func facts() -> Dictionary:
	var result := {}
	for fact in panel._facts:
		result[str(fact.id)] = {"state":str(fact.state), "claim_allowed":bool(fact.claim_allowed)}
	return result

func record_state(name: String, item: String = "") -> void:
	var visual = panel._visual
	var architecture = visual.architecture
	var parts := {}
	if architecture != null:
		for kind in architecture._owned:
			var moving := {}
			for label in architecture._parts[kind]:
				var node: Node3D = architecture._parts[kind][label]
				moving[label] = {"position":str(node.position), "rotation":str(node.rotation)}
			parts[kind] = moving
	manifest.append({"image":name,"building":item,"facts":facts(),"owned":architecture._owned.duplicate() if architecture != null else [],"visual_phase":visual.phase,"surface_phase":visual.globe.phases.x,"scout_age":visual.exploration_age,"scout_front":visual._scout_in_front(),"parts":parts})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT.path_join("motion"))
	root.size = Vector2i(1440,900)
	assert(GDExtensionManager.load_extension("/tmp/planet-native-472/planet.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial = true
	session = game.session
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var grants: Dictionary = session.campaign_system.save_state()
	for row in config.unlock.unlock:
		grants.grants[str(row.type)+":"+str(row.target)] = true
	assert(session.campaign_system.restore_state(grants).ok)
	session.crew_system.refresh_availability(session.campaign_system.available)
	game._sync_guidance()
	game._refresh_feature_visibility()
	game._left_buttons.planet.pressed.emit()
	panel = game.planet_scene
	panel.select_planet("1")
	var order := ["station","refinery","workshop","shipyard"]
	var baseline: Dictionary = session.planet_system.save_state()
	baseline.planets["1"].exploration = 240
	baseline.planets["1"].conquered = true
	assert(session.planet_system.restore_state(baseline).ok)
	session.planet_system.refresh_availability(session.campaign_system.available)
	panel.refresh()
	await create_timer(0.25).timeout
	await shot("stage_0")
	record_state("stage_0")
	for index in order.size():
		var key: String = order[index]
		var state: Dictionary = session.planet_system.save_state()
		state.planets["1"].buildings[key].state = "ready"
		for candidate in config.planet_build.planet_build:
			if str(candidate.id) == key:
				state.planets["1"].buildings[key].work = int(candidate.build_explore)
		assert(session.planet_system.restore_state(state).ok)
		session.planet_system.refresh_availability(session.campaign_system.available)
		panel.refresh()
		await create_timer(0.25).timeout
		assert(facts()[key].state == "ready")
		await shot("ready_" + key)
		record_state("ready_" + key,key)
		var claim: Dictionary = session.planet_system.claim_build("1",key,Callable(session,"publish_planet_claim"))
		print("CLAIM ",key," ",claim)
		assert(claim.ok)
		panel.refresh()
		await create_timer(0.25).timeout
		assert(facts()[key].state == "built")
		await shot("stage_" + str(index+1))
		record_state("stage_" + str(index+1),key)
	# The panel normally advances the visual on every rendered frame. Stop that
	# clock for the deterministic phase sweep; only explicit advance() calls count.
	panel.set_process(false)
	panel._visual.set_exploration(true,240,20.0)
	var visual = panel._visual
	var before: float = visual.phase
	visual.advance(PHASE_STEP,true)
	assert(is_equal_approx(before,visual.phase))
	await shot("paused")
	record_state("paused")
	for index in PHASE_FRAMES+1:
		if index > 0: visual.advance(PHASE_STEP,false)
		var name := "motion/frame_%03d" % index
		await shot(name)
		record_state(name)
		if index % 16 == 0: print("CAPTURE ",index," phase=",visual.phase," surface=",visual.globe.phases.x)
	var file := FileAccess.open(OUT.path_join("states.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase_step_simulated_seconds":PHASE_STEP,"frames":manifest},"  "))
	file.close()
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
