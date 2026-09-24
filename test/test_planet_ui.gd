extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:writes.append(control)
		super.set_ui_value(control, property, value)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := TrackedUI.new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	check(scene.equipment_tabs.get_tab_count() == 7, "Independent planet tab exists")
	check(scene.equipment_tabs.is_tab_hidden(6), "Planet tab hidden before level 30")
	scene.game.profile.cleared = range(1, 31)
	scene.game.profile.highestLevel = 30
	scene.refresh_structure()
	check(not scene.equipment_tabs.is_tab_hidden(6), "Planet tab appears at level 30")
	scene.equipment_tabs.current_tab = 6
	scene.planet_panel.refresh()
	check(scene.planet_panel.cards.size() == 1, "First planet shown")
	var card: Dictionary = scene.planet_panel.cards.first
	check(card.stage.size.x > card.root.size.x * 2.0 and card.stage.size.y > 500, "Central planet stage dominates side panels")
	check(card.stage.get_global_rect().end.y <= card.rail.get_global_rect().position.y and card.rail.get_global_rect().end.y <= 1200, "Stage and facility rail fit viewport")
	var selected_style: StyleBox = card.list_button.get_theme_stylebox("normal")
	scene.planet_panel.refresh()
	check(card.list_button.get_theme_stylebox("normal") == selected_style, "Stable refresh keeps planet selection style instance")
	check(card.visual.planet_id == "first" and card.visual.facilities.is_empty(), "Planet visual uses current planet without inventing ownership")
	var visual_row: Dictionary = scene.game.planet_row("first").duplicate(true)
	visual_row["visualFacilities"] = [
		{"id":"scout", "type":"scout_satellite", "owned":true, "orbit":0},
		{"id":"station", "type":"space_station", "owned":true, "orbit":1},
		{"id":"mine", "type":"mining_platform", "owned":true, "orbit":2},
		{"id":"research", "type":"research_facility", "owned":true, "orbit":0},
		{"id":"defense", "type":"defense_platform", "owned":true, "orbit":1},
		{"id":"factory", "type":"orbital_factory", "owned":true, "orbit":2},
		{"id":"locked", "type":"space_station", "owned":false, "orbit":0},
	]
	card.visual.configure("first", visual_row)
	scene.planet_panel._sync_facility_buttons("first")
	check(card.visual.facilities.size() == 6, "Six owned facility types mount on configured orbits")
	check(card.facility_buttons.size() == 6 and card.facility_buttons["station"].text.contains("空间站"), "Facility cards reflect owned orbit instances")
	card.facility_buttons["station"].pressed.emit()
	check(card.visual.selected_facility == "station", "Facility card highlights its orbit instance")
	visual_row["visualFacilities"] = JSON.stringify(visual_row["visualFacilities"])
	card.visual.configure("first", visual_row)
	check(card.visual.facilities.size() == 6, "Excel text can drive facility visuals")
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/planet-six-facilities.png")
	scene.planet_panel.select_facility("first", "station")
	check(card.visual.selected_facility == "station", "Facility selection reaches orbit visual")
	card.visual.configure("first", scene.game.planet_row("first"))
	scene.planet_panel._sync_facility_buttons("first")
	card.visual.advance(0.05, false)
	var visible_phase: float = card.visual.phase
	scene.equipment_tabs.current_tab = 5
	card.visual.advance(1.0, false)
	check(is_equal_approx(card.visual.phase, visible_phase), "Hidden planet stops decorative motion")
	scene.equipment_tabs.current_tab = 6
	card.visual.advance(1.0, true)
	check(is_equal_approx(card.visual.phase, visible_phase), "Paused planet stops decorative motion")
	check(scene.equipment_tabs.size.y > 600 and card.start.get_global_rect().end.y <= 1200, "Planet page and actions fit viewport")
	check(card.crew_ids.size() > 0 and not card.start.disabled, "Idle crew available")
	var chosen := str(card.crew_ids[0]) if not card.crew_ids.is_empty() else ""
	card.start.pressed.emit()
	check(str(scene.game.planet_progress("first").crewId) == chosen and not chosen.is_empty(), "UI selection can start exploration")
	check(card.visual.active, "Exploration activates scan visual")
	check(card.cancel.visible and not card.start.visible, "Only active controls update")
	scene.equipment_tabs.current_tab = 5
	var crew_panel = scene.crew_panel
	crew_panel.select(chosen)
	var chosen_row: Button = crew_panel.rows[chosen]
	var other_id: String = str(crew_panel.rows.keys().filter(func(id):return id != chosen)[0])
	var other_row: Button = crew_panel.rows[other_id]
	check(chosen_row.text.contains("探索中") and chosen_row.text.contains("始源星") and not chosen_row.text.contains("待命"), "Crew row names current exploration")
	check(crew_panel.status.text.contains("探索：始源星") and crew_panel.status.text.contains("剩余 100 秒"), "Selected crew detail shows planet and remaining time")
	check(crew_panel.view_planet_button.visible and crew_panel.recall_planet_button.visible and not crew_panel.jobs.visible and not crew_panel.assign_button.visible, "Exploration actions replace job controls")
	scene.writes.clear()
	scene.game.advance_planets(1.2)
	crew_panel.refresh_exploration_sample()
	check(chosen_row.text.contains("剩余 99 秒") and crew_panel.status.text.contains("剩余 99 秒"), "Countdown updates crew row and detail")
	check(crew_panel.rows[other_id] == other_row and not scene.writes.has(other_row), "Countdown preserves unrelated crew row")
	scene.writes.clear()
	crew_panel.refresh_exploration_sample()
	check(scene.writes.is_empty(), "Stable countdown writes no properties")
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/crew-exploring.png")
	crew_panel.view_planet_button.pressed.emit()
	check(scene.equipment_tabs.current_tab == 6, "Crew detail opens planet tab")
	scene.equipment_tabs.current_tab = 5
	crew_panel.recall_planet_button.pressed.emit()
	check(str(scene.game.planet_progress("first").crewId).is_empty(), "Crew can be recalled")
	check(chosen_row.text.contains("待命") and not chosen_row.text.contains("探索中"), "Recall restores idle crew row")
	scene.equipment_tabs.current_tab = 6
	check(card.start.visible and not card.cancel.visible, "Controls restore after recall")
	scene.planet_panel.show_completion("first")
	check(card.visual.completion_age == 0.0, "Completion pulse does not change exploration state")
	card.visual.advance(2.0, true)
	scene.planet_panel.refresh_sample(0.0)
	check(not card.feedback.visible, "Completion feedback expires even while game is paused")
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/planet-tab.png")
	print("PLANET UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
