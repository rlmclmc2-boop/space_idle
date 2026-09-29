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
	viewport.gui_embed_subwindows = true
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
	check(scene.equipment_tabs.get_tab_control(6) == scene.planet_panel, "Independent planet tab exists")
	check(scene.equipment_tabs.is_tab_hidden(6), "Planet tab hidden before level 30")
	scene.game.profile.cleared = range(1, 31)
	scene.game.profile.highestLevel = 30
	scene.refresh_structure()
	check(not scene.equipment_tabs.is_tab_hidden(6), "Planet tab appears at level 30")
	scene.equipment_tabs.current_tab = 6
	scene.planet_panel.refresh()
	check(scene.planet_panel.cards.size() == 1, "First planet shown")
	var card: Dictionary = scene.planet_panel.cards["1"]
	check(card.stage.size.x > card.root.size.x * 2.0 and card.stage.size.y > 500, "Central planet stage dominates side panels")
	check(card.stage.get_global_rect().end.y <= card.rail.get_global_rect().position.y and card.rail.get_global_rect().end.y <= 1200, "Stage and facility rail fit viewport")
	var selected_style: StyleBox = card.list_button.get_theme_stylebox("normal")
	scene.planet_panel.refresh()
	check(card.list_button.get_theme_stylebox("normal") == selected_style, "Stable refresh keeps planet selection style instance")
	check(card.task.get_global_rect().end.y < card.summary.get_global_rect().position.y, "Task and overview are separate non-overlapping sections")
	check(card.stage_title.text.begins_with(card.list_name.text) and card.stage_title.text.contains(UIText.t("planet.degree", {"degree":"0"})) and card.title.text == UIText.t("planet.task_heading"), "Main title and task heading have distinct roles")
	check(card.auto.get_rect().end.y < card.start.position.y and card.start.get_rect().end.y < card.feedback.position.y, "Task controls and completion message do not overlap")
	check(card.task_state.text == UIText.t("planet.task_paused"), "Paused state explicitly visible")
	check(card.visual.planet_id == "1" and card.visual.facilities.is_empty(), "Planet visual uses current planet without inventing ownership")
	check(card.facility_buttons.size()==1 and card.facility_buttons.station.label.text.contains("空间站"),"Only next applicable building preview is visible")
	check(not card.facility_buttons.station.root.tooltip_text.contains(str(scene.game.db.data.planet_build.station.des)) and not card.facility_buttons.station.assign.visible,"Locked preview leaks no effect or construction requirement")
	check(not card.auto.visible and not card.reforge.visible,"Locked actions hidden")
	scene.game.profile.planets["1"].degree=10
	scene.game.planet_buildings.sync(scene.game,"1")
	scene.planet_panel.refresh()
	check(card.facility_buttons.size()==2 and card.facility_buttons.station.metric.text.contains("0/5") and card.facility_buttons.refinery.label.text.contains("资源精炼厂"),"Unlock moves building into construction and reveals next only")
	check(card.facility_buttons.station.metric.text.ends_with("0/5") and not card.facility_buttons.station.metric.text.contains(".0"),"Construction counts have no decimal suffix")
	check(card.facility_buttons.refinery.label.text=="资源精炼厂" and card.facility_buttons.refinery.metric.text=="再探索 20 次解锁","Next preview shows remaining exploration count")
	check(scene.planet_panel.exploration_count_text(10.0)=="10" and not scene.planet_panel.exploration_count_text({"m":1.23,"e":450.0}).contains("."),"Exploration counters stay integer even at large magnitudes")
	scene.game.profile.planets["1"].degree=0
	scene.game.profile.planets["1"].buildings.station.status="locked"
	scene.planet_panel.refresh()
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
	var saved_crew: Array = scene.game.profile.crew.duplicate(true)
	for member in scene.game.profile.crew:member.assignmentType = "test_busy"
	scene.planet_panel.refresh_card("1")
	check(card.start.disabled and card.no_crew.visible and not card.picker.visible, "No idle crew explains the disabled primary action")
	scene.game.profile.crew = saved_crew
	scene.planet_panel.refresh_card("1")
	var chosen := str(card.crew_ids[0]) if not card.crew_ids.is_empty() else ""
	await click_control(viewport, card.start)
	check(str(scene.game.planet_progress("1").crewId) == chosen and not chosen.is_empty(), "UI selection can start exploration")
	check(card.visual.active, "Exploration activates scan visual")
	check(card.cancel.visible and not card.start.visible, "Only active controls update")
	scene.equipment_tabs.current_tab = 5
	var crew_panel = scene.crew_panel
	crew_panel.select(chosen)
	var chosen_row: Button = crew_panel.rows[chosen]
	var other_id: String = str(crew_panel.rows.keys().filter(func(id):return id != chosen)[0])
	var other_row: Button = crew_panel.rows[other_id]
	check(crew_panel.row_fields[chosen].role.text=="探索中", "Crew row names current exploration")
	var duration: float = scene.game.planet_duration("1")
	check(crew_panel.status.text.contains("始源星") and crew_panel.status.text.contains("剩余 %d秒" % ceili(duration)), "Selected crew detail shows planet and remaining time")
	check(not crew_panel.assignment_section.visible and not crew_panel.effect_section.visible, "Exploration hides assignment controls without extra actions")
	scene.writes.clear()
	scene.game.advance_planets(1.2)
	crew_panel.refresh_exploration_sample()
	check(crew_panel.row_fields[chosen].role.text=="探索中" and crew_panel.status.text.contains("剩余 %d秒" % ceili(duration - 1.2)), "Countdown updates detail while compact row keeps necessary state")
	check(crew_panel.rows[other_id] == other_row and not scene.writes.has(other_row), "Countdown preserves unrelated crew row")
	scene.writes.clear()
	crew_panel.refresh_exploration_sample()
	check(scene.writes.is_empty(), "Stable countdown writes no properties")
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/crew-exploring.png")
	scene.system_nav_buttons[6].pressed.emit()
	check(scene.equipment_tabs.current_tab == 6, "Existing navigation opens planet tab")
	await click_control(viewport, card.cancel)
	scene.equipment_tabs.current_tab = 5
	check(str(scene.game.planet_progress("1").crewId).is_empty(), "Crew can be recalled")
	check(crew_panel.row_fields[chosen].role.text=="空闲", "Recall restores idle crew row")
	scene.equipment_tabs.current_tab = 6
	check(card.start.visible and not card.cancel.visible, "Controls restore after recall")
	scene.planet_panel.show_completion("1")
	check(card.visual.completion_age == 0.0, "Completion pulse does not change exploration state")
	card.visual.advance(2.0, true)
	scene.planet_panel.refresh_sample(0.0)
	check(card.visual.completion_age == 0.0 and not card.feedback.visible, "Pause freezes completion before delayed reward reveal")
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/planet-tab.png")
	scene.planet_panel.refresh_sample(0.0)
	await process_frame
	await process_frame
	var draw_count: int = card.visual.draw_calls
	var task_instance: int = card.task.get_instance_id()
	var facility_instance: int = card.facility_buttons.station.root.get_instance_id()
	var unrelated_instance: int = scene.crew_panel.get_instance_id()
	scene.writes.clear()
	scene.planet_panel.refresh_sample(0.0)
	await process_frame
	check(scene.writes.is_empty() and card.visual.draw_calls == draw_count, "Stable paused page writes no properties and adds no scene redraws")
	check(card.task.get_instance_id() == task_instance and card.facility_buttons.station.root.get_instance_id() == facility_instance and scene.crew_panel.get_instance_id() == unrelated_instance, "Stable refresh preserves local and unrelated control instances")
	var g=scene.game
	g.profile.planets["1"].degree=300
	g.planet_buildings.sync(g,"1")
	for item in g.profile.planets["1"].buildings.values():
		item.status="built"
		item.build_progress=10
	scene.planet_panel.refresh()
	check(card.auto.visible and card.reforge.visible and card.visual.facilities.size()==4,"Completed buildings expose only their abilities")
	await process_frame
	await process_frame
	var last_card: Control = card.rail_content.get_child(card.rail_content.get_child_count()-1)
	check(last_card.get_global_rect().end.x <= card.rail_scroll.get_global_rect().end.x, "Four facility cards fit the rail without horizontal clipping")
	check(not card.facility_buttons.station.status.visible and not card.facility_buttons.station.metric.visible, "Built facility hides redundant status and progress")
	viewport.get_texture().get_image().save_png("res://.runtime/planet-layout-built.png")
	card.auto.button_pressed=true
	check(g.planet_progress("1").auto_explore,"UI auto switch changes authoritative state")
	card.reforge.pressed.emit()
	var dialog: ConfirmationDialog=null
	for child in scene.planet_panel.get_children():
		if child is ConfirmationDialog:dialog=child
	check(is_instance_valid(dialog) and not g.planet_progress("1").conquered,"First reforge click only opens confirmation")
	check(dialog.dialog_text.contains("第%d关" % g.planet_reforge_start("1")),"Confirmation displays configured start stage")
	check(dialog.dialog_text.contains("永久清除") and dialog.dialog_text.contains("宝石") and dialog.dialog_text.contains("解锁"),"Confirmation explains permanent deletion")
	dialog.canceled.emit()
	await process_frame
	check(not g.planet_progress("1").conquered,"Cancel makes no permanent change")
	# Exercise extended quantities through the existing UI entry points.
	g.db.data.planet_build.workshop.config2=2.0
	g.db.data.planet_build.refinery.config2=2.0
	g.profile.planets["1"].degree=1e250
	g.profile.resources["1"]={"m":1.5,"e":450.0}
	g.resource_samples.clear()
	g.resource_samples.append({"time":Time.get_unix_time_from_system(),"id":"1","amount":g.profile.resources["1"],"production_base":10.0,"origin":"drop"})
	g.invalidate_stat_cache();g.reset_player()
	scene.resource_rate_mode=true
	check(scene.resource_display("1").contains("e+"),"Large resource rate renders safely")
	scene.equipment_tabs.current_tab=0
	scene.equipment_panel.invalidate_stats({"category":"weapons"})
	scene.equipment_panel.refresh_stats()
	scene.equipment_tabs.current_tab=6
	scene.planet_panel.refresh()
	scene.battle_layer.queue_redraw()
	scene.battle_hud_layer.queue_redraw()
	scene.resource_layer.queue_redraw()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.runtime/planet-built-large.png")
	card.reforge.pressed.emit()
	for child in scene.planet_panel.get_children():
		if child is ConfirmationDialog:dialog=child
	dialog.confirmed.emit()
	await process_frame
	await process_frame
	check(g.stage==g.planet_reforge_start("1") and g.planet_progress("1").conquered and not g.can_reforge_planet("1"),"Confirmed UI action starts configured stage and marks conquest")
	scene.equipment_tabs.current_tab=6
	scene.planet_panel.refresh()
	check(scene.planet_panel.cards["1"].conquered.visible and not scene.planet_panel.cards["1"].reforge.visible,"Conquered planet removes reforge action")
	print("PLANET UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func click_control(viewport: SubViewport, control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame
