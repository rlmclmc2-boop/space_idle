extends SceneTree
## Config-driven visual regression, with optional real-time ten-second capture.
class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:writes.append(control)
		super.set_ui_value(control, property, value)

var checks := 0
var failures := 0
var viewport: SubViewport
var scene: TrackedUI
var static_draws := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr(label)

func _initialize() -> void:call_deferred("run")

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

func capture(name: String, dimensions := Vector2i(1373,883)) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("res://.runtime/" + name + ".png")

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1952,1256)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	scene = TrackedUI.new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.fps_label.hide()
	var g = scene.game
	var configuration: Dictionary = g.db.data.duplicate(true)
	g.save_enabled = false
	g.paused = false
	g.pending_unlocks.clear()
	g.profile.onboarding.completed = true
	g.load_planets({})
	g.profile.cleared = range(1,101)
	g.profile.highestLevel = 101
	g.rebuild_unlocks()
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	var panel = scene.planet_panel
	panel.refresh()
	await process_frame
	var ids: Array = g.db.data.planet.keys()
	ids.sort_custom(func(a,b):return int(a)<int(b))
	var first_id: String = ids[0]
	check(panel.cards.size() == 1 and panel.cards.has(first_id), "Unconquered fixture respects the current locked-body chain")
	var card: Dictionary = panel.cards[first_id]
	check(card.stage_title.text == UIText.data_text("planet",first_id,"name",str(g.planet_row(first_id).name)) and card.stage_degree.text.contains("0"), "Separate name and colored exploration metric preserve source values")
	check(card.task.get_theme_stylebox("panel").bg_color == panel.Chrome.PAPER, "Planet-local paper chrome")
	check(card.progress.text.contains("[color=#214663]%.1f 秒[/color]" % g.planet_duration(first_id)), "Countdown value and unit share parameter color")
	check(panel.crew_reward_text(42004534).contains(scene.number(42004534)), "Experience presentation reuses the global quantity formatter")
	await capture("toon-first-locked")
	var nodes := get_node_count()
	var visual = card.visual
	visual.background_layer.draw.connect(func():static_draws += 1)
	await click(card.start)
	check(visual.active and not str(g.planet_progress(first_id).crewId).is_empty(), "Real primary action dispatches existing crew")
	var start: Vector2 = visual.globe.phases
	for frame in 60:
		panel.refresh_sample(1.0/30.0)
		await process_frame
	check(visual.globe.phases.x > start.x and is_zero_approx(visual.globe.rotation), "Rotation moves spherical UVs, never the flat control")
	check(get_node_count() == nodes and static_draws == 0, "Active animation preserves nodes and static backdrop")
	await capture("toon-first-active")
	g.paused = true
	panel.refresh_sample(0.0)
	await process_frame
	var frozen := [visual.globe.phases,visual.globe.parameter_writes,visual.draw_calls]
	scene.writes.clear()
	for frame in 8:
		panel.refresh_sample(0.1)
		await process_frame
	check([visual.globe.phases,visual.globe.parameter_writes,visual.draw_calls] == frozen and scene.writes.is_empty(), "Stable pause freezes uniforms, redraws and property writes")
	await capture("toon-first-paused")
	g.paused = false
	scene.equipment_tabs.current_tab = 5
	await process_frame
	frozen = [visual.globe.phases,visual.globe.parameter_writes,visual.draw_calls]
	scene.writes.clear()
	panel.refresh_sample(1.0)
	visual.advance(1.0,false)
	check([visual.globe.phases,visual.globe.parameter_writes,visual.draw_calls] == frozen and scene.writes.is_empty(), "Hidden page stops visual updates")
	scene.equipment_tabs.current_tab = 6
	await click(card.cancel)
	check(not visual.active and str(g.planet_progress(first_id).crewId).is_empty(), "Recall releases existing crew")
	# The actual permanent-buff chain opens the later bodies; no configuration edit.
	for id in ids:g.profile.planets[id].conquered = true
	panel.refresh()
	check(panel.cards.size() == ids.size(), "Conquered fixture displays every configured celestial body")
	for id in ids:
		await click(panel.cards[id].list_button)
		var selected: Dictionary = panel.cards[id]
		check(panel.selected_planet_id == id and selected.stage.visible, id + " actual list selection")
		check(selected.visual.facility_renderer == panel.facility_renderer, id + " keeps the shared facility renderer")
		check(selected.visual.globe.size.x <= selected.visual.size.x, id + " authored body envelope fits stage")
		await capture("toon-body-" + id)
		if id != first_id:check(not visual.is_visible_in_tree(), id + " previous globe is hidden")
	await click(panel.cards[first_id].list_button)
	await click(card.bonuses)
	check(is_instance_valid(panel.bonus_dialog) and panel.bonus_dialog.visible, "Bonus action opens existing source-driven details")
	panel.bonus_dialog.hide()
	if OS.get_environment("PLANET_TOON_RECORD") == "1":await record(panel,card,first_id)
	check(g.db.data == configuration, "Visual presentation leaves configuration unchanged")
	print("PLANET TOON: %d checks, %d failures; bodies=%d; no gameplay/configuration writes" % [checks,failures,ids.size()])
	screen.queue_free()
	viewport.queue_free()
	await process_frame
	scene = null
	viewport = null
	quit(1 if failures else 0)

func record(panel, card: Dictionary, id: String) -> void:
	await click(card.start)
	# Continue only in this isolated fixture. Delta follows wall time, not replay speed.
	var folder := "res://.runtime/toon-frames"
	DirAccess.make_dir_recursive_absolute(folder)
	for filename in DirAccess.get_files_at(folder):
		if filename.begins_with("frame-") and filename.ends_with(".png"):
			DirAccess.remove_absolute(folder + "/" + filename)
	var start := Time.get_ticks_usec()
	var previous := start
	var next_frame := start
	var frames := 0
	while Time.get_ticks_usec() - start < 10000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - previous)/1000000.0
		previous = now
		scene.game.advance_planets(dt)
		panel.refresh_sample(dt)
		if now >= next_frame:
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.resize(1373,883,Image.INTERPOLATE_BILINEAR)
			image.save_png(folder + "/frame-%04d.png" % frames)
			frames += 1
			next_frame += 1000000.0/12.0
	print("TOON RECORD: duration=%.3f seconds, frames=%d, rendered source=1952x1256, output=1373x883" % [float(Time.get_ticks_usec()-start)/1000000.0,frames])
	await capture("toon-first-final")
