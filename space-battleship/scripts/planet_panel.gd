extends Control

var host: Node
var cards: Dictionary = {}
var samples: Dictionary = {}
var selected_planet_id := ""
var dirty := true
var list_content: VBoxContainer

func setup(owner_ui: Node) -> void:
	host = owner_ui
	add_theme_font_override("font", host.font)
	var list_frame := _panel(Rect2(16, 20, 258, 1138), Color("0d1d2b"), Color("2b5268"))
	host.equipment_card_label(list_frame, UIText.t("planet.list_heading"), Rect2(16, 12, 225, 34), 21, host.CYAN)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 56)
	scroll.size = Vector2(238, 1068)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_frame.add_child(scroll)
	list_content = VBoxContainer.new()
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.add_theme_constant_override("separation", 8)
	scroll.add_child(list_content)
	visibility_changed.connect(func():
		if is_visible_in_tree():refresh())
	refresh()

func _panel(rect: Rect2, fill: Color, edge: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", host.style(fill, edge))
	add_child(panel)
	return panel

func invalidate() -> void:
	dirty = true
	if is_visible_in_tree():refresh()

func refresh_sample(dt: float) -> void:
	if not is_visible_in_tree():return
	if dirty:
		refresh()
		return
	if cards.has(selected_planet_id):
		var visual = cards[selected_planet_id].visual
		visual.advance(dt, host.game.paused)
		var feedback: Label = cards[selected_planet_id].feedback
		var showing: bool = visual.completion_age < 1.5
		if feedback.visible != showing:feedback.visible = showing
	for id in cards:
		var progress: Dictionary = host.game.planet_progress(str(id))
		var sample := [progress.get("degree", 0), int(float(progress.get("elapsed", 0))), progress.get("crewId", ""), host.game.paused]
		if samples.get(id) != sample:
			samples[id] = sample
			refresh_card(str(id))

func refresh() -> void:
	if not is_visible_in_tree():
		dirty = true
		return
	var ids: Array = []
	for id in host.game.db.data.get("planet", {}):
		if not host.game.planet_unlocked(str(id)):continue
		ids.append(str(id))
		if not cards.has(str(id)):add_card(str(id))
		refresh_card(str(id))
	for id in cards.keys():
		if not ids.has(id):
			cards[id].root.queue_free()
			cards[id].stage.queue_free()
			cards[id].rail.queue_free()
			cards[id].list_button.queue_free()
			cards.erase(id)
	if not ids.has(selected_planet_id):selected_planet_id = str(ids[0]) if not ids.is_empty() else ""
	_apply_selection()
	dirty = false

func add_card(id: String) -> void:
	var list_button := Button.new()
	list_button.custom_minimum_size = Vector2(222, 74)
	list_button.add_theme_font_override("font", host.font)
	list_button.add_theme_font_size_override("font_size", 17)
	list_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list_button.pressed.connect(func():select_planet(id))
	list_content.add_child(list_button)
	var stage := _panel(Rect2(284, 20, 724, 972), Color("081827"), Color("2b5268"))
	var visual := preload("res://scripts/planet_visual.gd").new()
	visual.position = Vector2(0, 36)
	visual.size = Vector2(724, 936)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.clip_contents = true
	stage.add_child(visual)
	var stage_title: Label = host.equipment_card_label(stage, "", Rect2(18, 7, 688, 34), 23, host.CYAN)
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rail := _panel(Rect2(284, 1002, 724, 156), Color("0d1d2b"), Color("2b5268"))
	host.equipment_card_label(rail, UIText.t("planet.facility_heading"), Rect2(16, 8, 680, 26), 17, host.CYAN)
	var empty_facilities: Label = host.equipment_card_label(rail, UIText.t("planet.facility_empty"), Rect2(18, 60, 670, 54), 15, host.MUTED)
	var rail_scroll := ScrollContainer.new()
	rail_scroll.position = Vector2(12, 36)
	rail_scroll.size = Vector2(700, 108)
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(rail_scroll)
	var rail_content := HBoxContainer.new()
	rail_content.add_theme_constant_override("separation", 10)
	rail_scroll.add_child(rail_content)
	var root := _panel(Rect2(1018, 20, 320, 1138), Color("0d1d2b"), Color("2b5268"))
	var title: Label = host.equipment_card_label(root, "", Rect2(19, 18, 282, 42), 24, host.CYAN)
	host.equipment_card_label(root, UIText.t("planet.info_heading"), Rect2(20, 68, 280, 32), 18, host.MUTED)
	var detail_scroll:=ScrollContainer.new()
	detail_scroll.position=Vector2(20,106)
	detail_scroll.size=Vector2(280,392)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(detail_scroll)
	var detail: Label = host.equipment_card_label(detail_scroll, "", Rect2(0, 0, 270, 360), 16)
	detail.custom_minimum_size=Vector2(270,360)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var progress: Label = host.equipment_card_label(root, "", Rect2(20, 548, 280, 90), 17, host.CYAN)
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := ProgressBar.new()
	bar.position = Vector2(20, 648)
	bar.size = Vector2(280, 12)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", host.style(Color("152838"), Color("2b5268")))
	bar.add_theme_stylebox_override("fill", host.style(Color("4bc7e9"), Color("4bc7e9")))
	root.add_child(bar)
	var picker := OptionButton.new()
	picker.position = Vector2(20, 808)
	picker.size = Vector2(280, 42)
	picker.add_theme_font_override("font", host.font)
	picker.add_theme_font_size_override("font_size", 16)
	root.add_child(picker)
	var start: Button = host.button(UIText.t("planet.start"), Rect2(20, 878, 280, 53), func():_start_exploration(id, picker), true)
	start.reparent(root, false)
	var cancel: Button = host.button(UIText.t("planet.cancel"), Rect2(20, 878, 280, 53), func():host.game.cancel_planet_exploration(id))
	cancel.reparent(root, false)
	var feedback: Label = host.equipment_card_label(root, "", Rect2(20, 970, 280, 72), 18, host.CYAN)
	feedback.visible = false
	cards[id] = {"root":root, "stage":stage, "rail":rail, "rail_content":rail_content, "list_button":list_button, "title":title, "stage_title":stage_title, "detail":detail, "progress":progress, "bar":bar, "picker":picker, "start":start, "cancel":cancel, "feedback":feedback, "empty_facilities":empty_facilities, "facility_buttons":{}, "visual":visual, "crew_ids":[], "selected":null}

func _start_exploration(id: String, picker: OptionButton) -> void:
	var ids: Array = cards[id].crew_ids
	if picker.selected >= 0 and picker.selected < ids.size():
		host.game.start_planet_exploration(id, str(ids[picker.selected]))

func refresh_card(id: String) -> void:
	var card: Dictionary = cards[id]
	var row: Dictionary = host.game.planet_row(id)
	var progress: Dictionary = host.game.planet_progress(id)
	card.visual.configure(id, row)
	card.visual.set_exploration(not str(progress.get("crewId", "")).is_empty(), int(progress.get("degree", 0)))
	_sync_facility_buttons(id)
	var degree := int(progress.get("degree", 0))
	var duration: float = host.game.planet_duration(id)
	var reward: float = float(row.get("baseExp", 0)) * host.game.planet_exp_multiplier()
	var name := UIText.data_text("planet", id)
	host.set_ui_value(card.title, "text", name)
	host.set_ui_value(card.stage_title, "text", name)
	host.set_ui_value(card.list_button, "text", UIText.t("planet.list_entry", {"planet":name, "degree":degree}))
	host.set_ui_value(card.detail, "text", UIText.t("planet.detail", {"degree":degree, "bonus":"%.2f" % host.game.planet_equipment_multiplier(), "experience":"%.2f" % reward}))
	host.set_ui_value(card.detail,"custom_minimum_size",Vector2(270,maxf(360.0,card.detail.get_line_count()*26.0)))
	var crew_id := str(progress.get("crewId", ""))
	var active := not crew_id.is_empty()
	var member: Dictionary = host.game.crew.definitions(host.game).get(crew_id, {})
	host.set_ui_value(card.progress, "text", UIText.t("planet.exploring", {"crew":str(member.get("name", crew_id)), "remaining":"%.1f" % maxf(0, duration-float(progress.get("elapsed", 0)))}) if active else UIText.t("planet.ready", {"seconds":"%.1f" % duration}))
	host.set_ui_value(card.bar, "value", clampf(float(progress.get("elapsed", 0)) / maxf(1.0, duration) * 100.0, 0.0, 100.0) if active else 0.0)
	var available: Array = []
	for item in host.game.profile.crew:
		if not host.game.crew.unlocked(host.game, item.crewId) or not str(item.assignmentType).is_empty():continue
		if host.game.profile.planets.values().any(func(other):return other.crewId == item.crewId):continue
		available.append(item.crewId)
	if card.crew_ids != available:
		var previous := str(card.crew_ids[card.picker.selected]) if card.picker.selected >= 0 and card.picker.selected < card.crew_ids.size() else ""
		card.picker.clear()
		card.crew_ids = available
		for member_id in available:card.picker.add_item(str(host.game.crew.definitions(host.game)[member_id].name))
		if not available.is_empty():card.picker.select(maxi(0, available.find(previous)))
	host.set_ui_value(card.picker, "visible", not active)
	host.set_ui_value(card.start, "visible", not active)
	host.set_ui_value(card.start, "disabled", available.is_empty())
	host.set_ui_value(card.cancel, "visible", active)

func _sync_facility_buttons(id: String) -> void:
	var card: Dictionary = cards[id]
	var wanted: Dictionary = {}
	for index in card.visual.facilities.size():
		var entry: Dictionary = card.visual.facilities[index]
		var facility_id := str(entry.get("id", "%s-%d" % [entry.get("type", ""), index]))
		wanted[facility_id] = true
		if not card.facility_buttons.has(facility_id):
			var button: Button = host.button("", Rect2(0, 0, 106, 49), func():select_facility(id, facility_id))
			button.custom_minimum_size = Vector2(106, 49)
			button.reparent(card.rail_content, false)
			card.facility_buttons[facility_id] = button
		var item: Button = card.facility_buttons[facility_id]
		host.set_ui_value(item, "text", UIText.t("planet.facility_item", {"name":_facility_name(str(entry.get("type", ""))), "level":int(entry.get("level", 1))}))
	for facility_id in card.facility_buttons.keys():
		if not wanted.has(facility_id):
			card.facility_buttons[facility_id].queue_free()
			card.facility_buttons.erase(facility_id)
	host.set_ui_value(card.empty_facilities, "visible", wanted.is_empty())

func _facility_name(kind: String) -> String:
	match kind:
		"scout_satellite":return UIText.t("planet.facility.scout_satellite")
		"space_station":return UIText.t("planet.facility.space_station")
		"mining_platform":return UIText.t("planet.facility.mining_platform")
		"research_facility":return UIText.t("planet.facility.research_facility")
		"defense_platform":return UIText.t("planet.facility.defense_platform")
		"orbital_factory":return UIText.t("planet.facility.orbital_factory")
	return ""

func select_planet(id: String) -> void:
	if not cards.has(id) or selected_planet_id == id:return
	selected_planet_id = id
	_apply_selection()

func _apply_selection() -> void:
	for id in cards:
		var card: Dictionary = cards[id]
		var selected: bool = id == selected_planet_id
		host.set_ui_value(card.root, "visible", selected)
		host.set_ui_value(card.stage, "visible", selected)
		host.set_ui_value(card.rail, "visible", selected)
		if card.selected != selected:
			card.list_button.add_theme_stylebox_override("normal", host.style(Color("143b56") if selected else Color("112333"), host.CYAN if selected else host.LINE))
			card.selected = selected

func show_completion(id: String, reward: float = -1.0) -> void:
	if not cards.has(id):return
	var card: Dictionary = cards[id]
	if id != selected_planet_id:return
	card.visual.complete()
	var degree := int(host.game.planet_progress(id).get("degree", 0))
	var shown_reward: float = reward if reward >= 0.0 else float(host.game.planet_row(id).get("baseExp", 0)) * host.game.planet_exp_multiplier()
	host.set_ui_value(card.feedback, "text", UIText.t("planet.complete_feedback", {"degree":degree, "experience":"%.2f" % shown_reward}))
	card.feedback.visible = true

func select_facility(planet_id: String, facility_id: String) -> void:
	if cards.has(planet_id):cards[planet_id].visual.select_facility(facility_id)
