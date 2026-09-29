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
	for id in panel.cards:
		await click(panel.cards[id].list_button)
		var card: Dictionary = panel.cards[id]
		var visual = card.visual
		check(panel.selected_planet_id == id, id + " real list click selects body")
		check(visual.globe.size.x <= visual.size.x and visual.globe.size.y <= visual.size.y, id + " corona and beam envelope fits stage")
		check(card.list_name.get_rect().end.y <= card.list_button.size.y and card.list_name.max_lines_visible == 1, id + " long name stays above exploration count")
		check(card.stage_title.get_global_rect().end.x <= card.stage.get_global_rect().end.x, id + " heading fits stage")
		check(card.feedback.get_rect().end.y <= card.task.size.y, id + " reward fits task card")
		await capture("polish-body-" + id)
	panel.select_planet("1")
	var card: Dictionary = panel.cards["1"]
	var visual = card.visual
	visual.background_layer.draw.connect(func():background_draws += 1)
	await click(card.start)
	check(visual.active and visual.work_state_key() == "planet.work.arriving", "Dispatch starts approach stage")
	await step(3.2)
	check(visual.exploration_age >= visual.ENTRY_DURATION and visual.work_state_key() != "planet.work.arriving", "Approach enters orbit and begins work")
	await capture("polish-orbit")
	# Complete through the business event, not by directly invoking UI feedback.
	g.advance_planets(g.planet_duration("1"))
	check(visual.completion_age == 0.0, "Real completion starts pulse")
	await step(0.5)
	check(card.feedback.visible and card.feedback.modulate.a > 0.9, "Reward fades in after initial pulse")
	await capture("polish-complete")
	g.paused = true
	await process_frame
	panel.refresh_sample(0.0)
	await process_frame
	var frozen := [visual.completion_age, visual.exploration_age, visual.phase, visual.globe.parameter_writes, visual.draw_calls]
	scene.writes.clear()
	await step(0.6)
	check(frozen == [visual.completion_age, visual.exploration_age, visual.phase, visual.globe.parameter_writes, visual.draw_calls], "Pause freezes all VFX clocks, uniforms and scene redraws")
	check(scene.writes.is_empty(), "Stable paused page has zero property writes")
	g.paused = false
	await step(3.0)
	check(not card.feedback.visible and not card.task_fx.visible, "Completion feedback and task overlay expire")
	await click(card.start)
	await step(0.5)
	await click(card.cancel)
	check(not visual.active and visual.departure_age < 1.0, "Recall starts departure")
	await step(1.2)
	check(visual.departure_age >= 1.0, "Departure terminates")
	# A real transition reveals the same facility in card and scene.
	g.profile.planets["1"].degree = 10
	g.planet_buildings.sync(g, "1")
	panel.refresh()
	g.profile.planets["1"].buildings.station.status = "built"
	panel.refresh()
	check(card.facility_buttons.station.fx.visible and visual.facilities.any(func(entry):return entry.id == "station"), "New facility appears in card and orbit")
	await step(1.6)
	check(not card.facility_buttons.station.fx.visible and visual.facility_reveals.is_empty(), "Facility effect expires without node creation")
	# Moving the mouse across the real card links its orbital selection.
	var motion := InputEventMouseMotion.new()
	motion.position = card.facility_buttons.station.root.get_global_rect().position + Vector2(10, 90)
	viewport.push_input(motion, true)
	await process_frame
	check(visual.selected_facility == "station", "Facility hover highlights orbital entity")
	var count := get_node_count()
	var shader_writes: int = visual.globe.parameter_writes
	background_draws = 0
	var elapsed := Time.get_ticks_usec()
	await step(2.0)
	print("POLISH observation: 2s simulated in %.1fms, uniform writes=%d, static background redraws=%d" % [(Time.get_ticks_usec()-elapsed)/1000.0, visual.globe.parameter_writes-shader_writes, background_draws])
	check(get_node_count() == count and background_draws == 0, "Stable animation keeps nodes and static background")
	check(visual.globe.parameter_writes-shader_writes <= 98, "Sphere uniform writes respect 24Hz ceiling")
	scene.equipment_tabs.current_tab = 5
	await process_frame
	var hidden_writes: int = visual.globe.parameter_writes
	var hidden_draws: int = visual.draw_calls
	scene.writes.clear()
	await step(0.5)
	check(visual.globe.parameter_writes == hidden_writes and visual.draw_calls == hidden_draws and scene.writes.is_empty(), "Hidden planet page does no animation or property work")
	scene.equipment_tabs.current_tab = 6
	check(not card.feedback.visible and visual.facility_reveals.is_empty(), "Reveal does not replay old completion/build effects")
	# Exercise the disabled state at the current readable font size.
	var saved_crew: Array = g.profile.crew.duplicate(true)
	for member in g.profile.crew:member.assignmentType = "test_busy"
	panel.refresh_card("1")
	check(card.no_crew.visible and card.start.disabled and card.no_crew.get_rect().end.y <= card.auto.position.y, "No-crew hint fits without overlapping automatic exploration")
	await capture("polish-no-crew")
	check(card.no_crew.get_rect().end.x <= card.task.size.x - 20, "No-crew text remains within task column after layout")
	g.profile.crew = saved_crew
	g.profile.planets["1"].degree = 300
	g.planet_buildings.sync(g, "1")
	for building in g.profile.planets["1"].buildings.values():building.status = "built"
	panel.refresh()
	g.paused = true
	await capture("polish-built-paused")
	g.paused = false
	await step(1.6)
	await capture("polish-final")
	# Render the logical viewport through the same aspect-preserving screen fit.
	for dimensions in [Vector2i(1280,720), Vector2i(1373,883), Vector2i(1920,1080)]:
		var output := SubViewport.new()
		output.size = dimensions
		output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(output)
		var screen := TextureRect.new()
		screen.texture = viewport.get_texture()
		screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		screen.size = Vector2(dimensions)
		output.add_child(screen)
		await process_frame
		await RenderingServer.frame_post_draw
		output.get_texture().get_image().save_png("res://.runtime/polish-%dx%d.png" % [dimensions.x, dimensions.y])
		check(screen.get_rect().size == Vector2(dimensions), "Output frame fits %dx%d" % [dimensions.x, dimensions.y])
		output.queue_free()
		await process_frame
	print("PLANET POLISH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
