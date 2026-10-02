extends SceneTree
## Final presentation regression. Uses the runner's isolated project and user data.
class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:writes.append(control)
		super.set_ui_value(control, property, value)

var checks := 0
var failures := 0
var background_draws := 0
var viewport: SubViewport
var scene: TrackedUI

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/" + name + ".png")

func step(seconds: float) -> void:
	for frame in ceili(seconds * 30.0):
		scene.planet_panel.refresh_sample(1.0 / 30.0)
		await process_frame

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1952, 1256)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = TrackedUI.new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	var g = scene.game
	g.save_enabled = false
	g.paused = false
	g.pending_unlocks.clear()
	g.load_planets({})
	g.profile.grantedUnlocks = []
	for gate in g.db.data.unlock.values():
		if gate.type in ["planet", "crew"] or gate.get("target", "") == "crew_level":
			g.profile.grantedUnlocks.append(gate.name)
			g.profile.cleared.append(int(gate.level))
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	var panel = scene.planet_panel
	panel.refresh()
	await process_frame
	var card: Dictionary = panel.cards["1"]
	var visual = card.visual
	var renderer = panel.facility_renderer
	check(card.log_entries.is_empty(), "New session starts with no invented log history")
	await click(card.start)
	check(card.log_entries.size() == 1, "Dispatch records first exploration phase once")
	for quarter in 3:
		g.advance_planets(g.planet_duration("1") * 0.25)
		panel.refresh_sample(0.05)
		check(card.log_entries.size() == quarter + 2, "Quarter progress adds exactly one log phase")
	g.advance_planets(g.planet_duration("1") * 0.25)
	check(card.log_entries.size() == 5 and card.log_entries[0] == UIText.t("planet.log.phase_4"), "Completion records exactly five ordered phases")
	for repeat in 3:panel.refresh()
	check(card.log_entries.size() == 5, "Refresh does not duplicate exploration history")
	g.profile.planets["1"].degree = 9
	g.planet_buildings.sync(g,"1")
	panel.refresh()
	await click(card.start)
	g.advance_planets(g.planet_duration("1"))
	check(card.log_entries.has(UIText.t("planet.log.unlocked", {"name":str(g.db.data.planet_build.station.name)})), "Real threshold crossing records facility unlock")
	for trip in 5:
		if str(g.planet_progress("1").crewId).is_empty():await click(card.start)
		g.advance_planets(g.planet_duration("1"))
	check(card.log_entries.has(UIText.t("planet.log.built", {"name":str(g.db.data.planet_build.station.name)})), "Real construction completion records built event")
	check(card.log_entries.size() <= 24, "Exploration history has a bounded capacity")
	g.cancel_planet_exploration("1")
	var previous_text: String = card.log_label.text
	await click(card.start)
	scene.equipment_tabs.current_tab = 5
	await process_frame
	scene.writes.clear()
	g.advance_planets(g.planet_duration("1"))
	check(not scene.writes.has(card.log_label), "Hidden history records without writing hidden labels")
	scene.equipment_tabs.current_tab = 6
	check(card.log_label.text == "\n\n".join(card.log_entries), "Reveal catches up history text")
	g.cancel_planet_exploration("1")
	var first_history: Array = card.log_entries.duplicate()
	# Later planets require conquest of their predecessor as well as the unlock gate.
	g.profile.planets["1"].conquered = true
	panel.refresh()
	check(panel.cards.has("2"), "Conquest unlocks the second planet for history isolation")
	await click(panel.cards["2"].list_button)
	check(panel.cards["2"].log_entries.is_empty(), "Planet histories are independent")
	await click(card.list_button)
	check(card.log_entries == first_history, "Planet switch preserves original history")
	g.profile.planets["1"].degree = 300
	g.planet_buildings.sync(g,"1")
	for item in g.profile.planets["1"].buildings.values():item.status = "built"
	panel.refresh()
	await step(0.2)
	check(renderer.owned.size() == 4 and visual.facilities.size() == 4, "Four owned facilities use shared atlas")
	check(renderer.viewport.size == Vector2i(1024,256), "Atlas retains bounded production resolution")
	var rotations: Dictionary = {}
	for kind in renderer.owned:rotations[kind] = renderer.models[kind].rotation
	var dock_position: Vector2 = visual._facility_point(visual.size*0.5,visual._orbit_radius(),"shipyard",renderer.angle_for("shipyard",visual.phase))
	var nodes := get_node_count()
	await step(1.0)
	for kind in renderer.owned:check(renderer.models[kind].rotation != rotations[kind], kind + " body rotates independently")
	check(dock_position.is_equal_approx(visual._facility_point(visual.size*0.5,visual._orbit_radius(),"shipyard",renderer.angle_for("shipyard",visual.phase))), "Dock remains at fixed orbital position while body spins")
	check(get_node_count() == nodes, "Animation allocates no nodes")
	g.paused = true
	panel.refresh_sample(0.0)
	await process_frame
	await process_frame
	var clock: float = renderer.last_clock
	scene.writes.clear()
	await step(0.4)
	print("PAUSE clock_before=%.4f clock_after=%.4f mode=%d calls=%d" % [clock,renderer.last_clock,renderer.viewport.render_target_update_mode,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var paused_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	renderer.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var forced_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	renderer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	print("PAUSE rendering paused=%d forced=%d" % [paused_calls,forced_calls])
	check(renderer.last_clock == clock and forced_calls > paused_calls, "Pause stops atlas poses and extra model draw calls")
	check(scene.writes.is_empty(), "Paused presentation writes no control properties")
	g.paused = false
	scene.equipment_tabs.current_tab = 5
	await process_frame
	clock = renderer.last_clock
	await step(0.4)
	check(renderer.last_clock == clock, "Hidden page stops 3D updates")
	scene.equipment_tabs.current_tab = 6
	await step(0.2)
	check(renderer.last_clock > clock, "Returning page resumes 3D updates")
	await click(card.facility_buttons.refinery.root)
	check(is_instance_valid(panel.facility_dialog) and panel.facility_dialog.visible, "Real facility click opens effect details")
	panel.facility_dialog.hide()
	await capture("acceptance-orbits-and-log")
	# Selected-planet ownership must never leak through the shared atlas.
	for id in ["2", "3", "4", "5"]:g.profile.planets[id].conquered = true
	panel.refresh()
	for id in panel.cards:
		await click(panel.cards[id].list_button)
		var selected: Dictionary = panel.cards[id]
		check(selected.visual.facility_renderer == renderer, id + " reuses the one renderer")
		if id != "1":check(renderer.owned.is_empty(), id + " has no unearned 3D buildings")
		g.profile.planets[id].degree = 300
		g.planet_buildings.sync(g,id)
		for item in g.profile.planets[id].buildings.values():item.status = "built"
		panel.refresh()
		await step(0.15)
		await capture("acceptance-owned-" + id)
	await click(card.list_button)
	await benchmark(panel,visual,renderer)
	print("ORBIT ACCEPTANCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func benchmark(panel, visual, renderer) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var entries: Array = visual.facilities.duplicate(true)
	for mode in ["none","sprites","3d"]:
		visual.facilities = [] if mode == "none" else entries
		visual.facility_renderer = renderer if mode == "3d" else null
		renderer.configure(entries if mode == "3d" else [])
		for warmup in 30:
			panel.refresh_sample(1.0/60.0)
			await process_frame
		var times: Array[float] = []
		var calls := 0.0
		var previous := Time.get_ticks_usec()
		for frame in 240:
			panel.refresh_sample(1.0/60.0)
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now-previous)/1000.0)
			previous = now
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var mean := 0.0
		for value in times:mean += value
		times.sort()
		print("BENCH %s mean_ms=%.3f p95_ms=%.3f draw_calls=%.1f video_memory_mb=%.2f" % [mode,mean/times.size(),times[int(times.size()*0.95)],calls/times.size(),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0])
	visual.facilities = entries
	visual.facility_renderer = renderer
	renderer.configure(entries)
