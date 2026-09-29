extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048,1280)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = preload("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	var g = scene.game
	g.save_enabled = false
	g.profile.cleared = range(1,101)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.load_planets({})
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	var panel = scene.planet_panel
	panel.refresh()
	check(panel.bonus_text("1") == UIText.t("planet.bonuses_empty"), "No unearned bonuses")
	var station: Dictionary = g.db.data.planet_build.station
	g.profile.planets["1"].degree = station.unlock_explore
	g.planet_buildings.sync(g,"1")
	g.profile.planets["1"].buildings.station.build_progress = station.build_explore - 1
	check(g.start_planet_exploration("1","navigator"), "Station final trip dispatch")
	g.advance_planets(g.planet_duration("1"))
	check(g.planet_progress("1").auto_explore and g.planet_progress("1").crewId == "navigator", "Auto unlocked on final trip and next trip already active")
	g.set_planet_auto("1",false)
	g.planet_buildings.sync(g,"1")
	check(not g.planet_progress("1").auto_explore, "Manual off survives synchronization")
	var old: Dictionary = g.profile.planets.duplicate(true)
	g.load_planets(old)
	check(not g.planet_progress("1").auto_explore, "Explicit saved false retained")
	old["1"].erase("auto_explore")
	g.load_planets(old)
	check(g.planet_progress("1").auto_explore and not g.planet_progress("2").auto_explore, "Missing old preference defaults only on built station")
	g.profile.planets["1"].degree = 111
	for id in ["refinery","workshop"]:
		g.profile.planets["1"].buildings[id].status = "built"
	g.profile.planets["2"].degree = 900
	g.profile.planets["2"].buildings.refinery.status = "built"
	var text: String = panel.bonus_text("1")
	var mult = g.planet_buildings.building_multiplier(g,"1",g.db.data.planet_build.refinery)
	check(text.contains(GrowthNumber.text(mult)), "Current planet multiplier displayed")
	check(not text.contains(GrowthNumber.text(g.planet_resource_multiplier())), "Other planet multiplier excluded")
	check(not text.contains(g.db.data.planet_build.shipyard.name), "Unbuilt facility omitted")
	g.profile.planets["1"].conquered = true
	for buff in g.planet_buffs.rows(g,"1"):
		check(panel.bonus_text("1").contains(buff.des), "Every active configured buff included")
	panel.refresh()
	await process_frame
	await process_frame
	var button: Button = panel.cards["1"].bonuses
	check(button.get_parent() == panel.cards["1"].summary and button.position.y >= panel.cards["1"].detail_scroll.get_rect().end.y and button.get_rect().end.y < panel.cards["1"].reforge.position.y, "Bonus action fits overview below details and above reforge")
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	viewport.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	check(is_instance_valid(panel.bonus_dialog) and panel.bonus_dialog.visible, "Real button click opens dialog")
	if not is_instance_valid(panel.bonus_dialog):quit(1);return
	var instance: int = panel.bonus_dialog.get_instance_id()
	var label: int = panel.bonus_label.get_instance_id()
	g.profile.planets["1"].degree += 1
	panel.refresh_card("1")
	check(panel.bonus_label.text == panel.bonus_text("1") and panel.bonus_label.get_instance_id() == label, "Open dialog updates current effects without rebuilding")
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/planet-bonuses.png")
	panel.bonus_dialog.hide()
	panel.show_bonuses("2")
	check(panel.bonus_dialog.get_instance_id() == instance and panel.bonus_label.text == panel.bonus_text("2"), "Dialog reused without mixing planet bonuses")
	panel.bonus_dialog.hide()
	g.set_planet_auto("1",false)
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(g.db,false)
	restored.load_progress()
	check(not restored.planet_progress("1").auto_explore, "Manual off survives real save/load")
	print("PLANET BONUS DIALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
