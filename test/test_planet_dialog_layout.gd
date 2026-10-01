extends SceneTree
## Planet modal presentation and actual input, with isolated in-memory fixtures.
class TrackedUI extends "res://scripts/main.gd":
	var writes := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:writes += 1
		super.set_ui_value(control, property, value)

var failures := 0
var checks := 0
var viewport: SubViewport
var scene: TrackedUI

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr(label)

func _initialize() -> void:call_deferred("run")

func settle() -> void:
	for frame in 3:await process_frame

func click(control: Control) -> void:
	await settle()
	var target := viewport
	var point := control.get_global_rect().get_center()
	if control.get_viewport() is Window:point += Vector2(control.get_viewport().position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	target.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		target.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/" + name + ".png")

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(2048, 1280)
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
	g.paused = true
	g.profile.grantedUnlocks = []
	for gate in g.db.data.unlock.values():
		if gate.type in ["planet", "crew"]:
			g.profile.grantedUnlocks.append(gate.name)
			g.profile.cleared.append(int(gate.level))
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.load_planets({})
	for id in ["1", "2", "3", "4", "5", "6"]:
		g.profile.planets[id].degree = 300
		g.profile.planets[id].conquered = true
		g.planet_buildings.sync(g, id)
		for state in g.profile.planets[id].buildings.values():state.status = "built"
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	var panel = scene.planet_panel
	panel.refresh()
	await settle()
	check(panel._multiplier_percent(98) == "+9.7K%", "Compact percentage points, no multiplier/percent confusion")
	check(panel._multiplier_percent(1.126) == "+13%", "Small percent uses integer points")
	check(panel._description_metric("AI工厂效果等级 +20") == ["AI工厂效果等级", "+20"], "Description remains authoritative despite value 5")
	check(panel._description_metric("所有充能模块免费充能 +10%") == ["所有充能模块免费充能", "+10%"], "Percentage unit remains with highlighted value")
	await click(panel.cards["1"].bonuses)
	check(panel.bonus_dialog.visible, "Real bonus button opens grouped modal")
	var details_buttons: Array = panel.bonus_dialog.find_children("*", "Button", true, false).filter(func(button):return button.text == UIText.t("planet.bonus_details"))
	check(details_buttons.is_empty(), "Planet bonus modal has no details entry")
	var buff: Dictionary = g.db.data.planet_buff["2"]
	var authored_description: String = buff.des
	var business_value: float = buff.value
	buff.des = "AI工厂效果等级 +27"
	panel._refresh_bonus_dialog()
	check(panel.bonus_rows["buff:2"].metric.text == "+27", "UI preserves distinct authored description fixture")
	check(float(buff.value) == business_value, "Rendering description never changes business value")
	buff.des = authored_description
	panel._refresh_bonus_dialog()
	var unlock_buff: Dictionary = g.db.data.planet_buff["31"]
	var unlock_description: String = unlock_buff.des
	unlock_buff.des = "能够探索新星球：脉冲星-PSR T46+38"
	panel._refresh_bonus_dialog()
	check(panel.bonus_rows["buff:31"].label.text == unlock_buff.des and panel.bonus_rows["buff:31"].metric.text.is_empty(), "Signed suffix in unlocked planet name is not a numeric bonus")
	unlock_buff.des = unlock_description
	panel._refresh_bonus_dialog()
	var metric = panel.bonus_rows["building:refinery"].metric
	var identity: int = metric.get_instance_id()
	g.profile.planets["1"].degree += 10
	panel.refresh_card("1")
	check(metric.get_instance_id() == identity and metric.text == panel._multiplier_percent(g.planet_buildings.building_multiplier(g, "1", g.db.data.planet_build.refinery)), "Live multiplier update reuses aligned row")
	await settle()
	var right: float = metric.get_global_rect().end.x
	for controls in panel.bonus_rows.values():
		if controls.root.visible:check(is_equal_approx(controls.metric.get_global_rect().end.x, right), "Visible effect values align on one right edge")
	scene.writes = 0
	panel._refresh_bonus_dialog()
	panel._refresh_bonus_dialog()
	check(scene.writes == 0, "Stable dialog refresh writes no properties")
	await capture("planet-bonus-groups")
	check(panel.bonus_rows["buff:2"].root.tooltip_text == g.db.data.planet_buff["2"].des, "Authoritative description remains available on effect card")
	check(panel.bonus_label.text.contains(g.db.data.planet_buff["2"].des), "Full authoritative description retained")
	panel.bonus_dialog.hide()
	panel.show_bonuses("2")
	check(not panel.bonus_label.visible, "Explicit reopening starts with primary effects")
	check(not panel.bonus_rows["buff:2"].root.visible and panel.bonus_rows["buff:12"].root.visible, "Planet switch hides previous planet bonuses")
	for id in ["3", "4", "5", "6"]:
		panel.show_bonuses(id)
		check(panel.bonus_label.text == panel.bonus_text(id), "Each planet uses its active effects")
	panel.bonus_dialog.hide()
	panel.select_planet("1")
	for building_id in ["station", "refinery", "workshop", "shipyard"]:
		panel._show_facility("1", building_id)
		await settle()
		check(panel.facility_icon.texture == panel.Art.facility(str(g.db.data.planet_build[building_id].type)), "Facility uses matching runtime model icon")
		check(panel.facility_description.text == g.db.data.planet_build[building_id].des, "Facility preserves authored description")
		await capture("facility-" + building_id)
		panel.facility_dialog.hide()
	var renderer = panel.facility_renderer
	var initial_nodes := get_node_count()
	g.paused = false
	panel.refresh_sample(0.5)
	var rotations: Dictionary = {}
	for kind in renderer.KINDS:rotations[kind] = renderer.models[kind].rotation
	panel.refresh_sample(0.5)
	for kind in renderer.KINDS:check(renderer.models[kind].rotation != rotations[kind], "Every facility retains body animation")
	check(get_node_count() == initial_nodes, "Facility animation allocates no nodes")
	g.paused = true
	var clock: float = renderer.last_clock
	panel.refresh_sample(0.5)
	check(renderer.last_clock == clock, "Paused page leaves atlas clock unchanged")
	scene.equipment_tabs.current_tab = 5
	panel.refresh_sample(0.5)
	check(renderer.last_clock == clock, "Hidden planet page leaves atlas clock unchanged")
	scene.equipment_tabs.current_tab = 6
	g.profile.planets["1"].buildings.station.status = "ready"
	panel.refresh_card("1")
	panel._show_facility("1", "station")
	await click(panel.facility_action)
	check(g.profile.planets["1"].buildings.station.status == "built", "Bottom action activates ready station")
	var previous: bool = g.planet_progress("1").auto_explore
	await click(panel.facility_action)
	check(g.planet_progress("1").auto_explore != previous, "Bottom auto action changes actual preference")
	panel.facility_dialog.hide()
	g.profile.planets["1"].buildings.shipyard.status = "building"
	g.profile.planets["1"].buildings.shipyard.crew = []
	panel.refresh_card("1")
	panel._show_facility("1", "shipyard")
	await click(panel.facility_action)
	check(panel.facility_action.get_child_count() > 0, "Bottom construction action opens crew selector at modal button")
	for child in panel.facility_action.get_children():
		if child is PopupMenu:child.hide()
	panel.facility_dialog.hide()
	g.profile.planets["1"].conquered = false
	g.profile.planets["1"].buildings.shipyard.status = "built"
	panel.refresh_card("1")
	panel._show_facility("1", "shipyard")
	await click(panel.facility_action)
	var confirmations := panel.find_children("*", "ConfirmationDialog", true, false)
	check(confirmations.size() == 1 and confirmations[0].visible and not g.profile.planets["1"].conquered, "Reforge bottom action opens confirmation without performing reforge")
	for dialog in confirmations:dialog.hide();dialog.queue_free()
	g.profile.planets["1"].buildings.station.status = "locked"
	panel.refresh_card("1")
	panel._show_facility("1", "station")
	check(not panel.facility_action.visible and panel.facility_status.text.contains(UIText.t("planet.facility_status_locked")), "Locked facility explains unlock status with no action")
	panel.facility_dialog.hide()
	g.profile.planets["1"].degree = {"m":1.0, "e":100.0}
	panel.show_bonuses("1")
	check(panel.bonus_rows["building:refinery"].metric.text.contains("e+") and not panel.bonus_rows["building:refinery"].metric.text.contains("inf"), "GrowthNumber percentage remains finite and compact")
	await capture("planet-bonus-large")
	panel.bonus_dialog.hide()
	g.db.data.planet_build.refinery.des = "长描述保持配置来源，多个星球效果相乘。".repeat(30)
	g.db.data.planet_build.refinery.name = "资源精炼厂与轨道深层资源回收设施".repeat(3)
	panel._show_facility("1", "refinery")
	await settle()
	check(panel.facility_description.get_line_count() > 3, "Long authored description wraps")
	var scroll: ScrollContainer = panel.facility_dialog.find_children("*", "ScrollContainer", true, false)[0]
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Long facility content scrolls while actions stay outside scroll")
	await capture("facility-long-description")
	panel.facility_dialog.hide()
	for state in g.profile.planets["6"].buildings.values():state.status = "locked"
	g.profile.planets["6"].conquered = false
	panel.show_bonuses("6")
	check(panel.bonus_empty.visible, "Empty planet has no earned bonus rows")
	for controls in panel.bonus_rows.values():check(not controls.root.visible, "Previous earned rows hidden on empty planet")
	panel.bonus_dialog.hide()
	for dimensions in [Vector2i(1280,720), Vector2i(1024,768)]:
		viewport.size = dimensions
		await settle()
		panel.show_bonuses("1")
		await settle()
		check(panel.bonus_dialog.position.x >= 0 and panel.bonus_dialog.position.y >= 0 and panel.bonus_dialog.position.x + panel.bonus_dialog.size.x <= dimensions.x and panel.bonus_dialog.position.y + panel.bonus_dialog.size.y <= dimensions.y, "Bonus modal stays inside small viewport")
		panel.bonus_dialog.hide()
		panel._show_facility("1", "refinery")
		await settle()
		check(panel.facility_dialog.position.x >= 0 and panel.facility_dialog.position.y >= 0 and panel.facility_dialog.position.x + panel.facility_dialog.size.x <= dimensions.x and panel.facility_dialog.position.y + panel.facility_dialog.size.y <= dimensions.y, "Long facility modal stays inside small viewport")
		await capture("facility-small-%d" % dimensions.x)
		panel.facility_dialog.hide()

	scene.queue_free()
	viewport.queue_free()
	scene = null
	viewport = null
	await process_frame
	await process_frame
	print("PLANET DIALOG LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
