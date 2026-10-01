extends Control

const Feedback := preload("res://scripts/planet_feedback.gd")
const Art := preload("res://scripts/planet_art.gd")
const Chrome := preload("res://scripts/dialog_presentation.gd")
const Parameters := preload("res://scripts/parameter_text.gd")

var host: Node
var cards: Dictionary = {}
var samples: Dictionary = {}
var selected_planet_id := ""
var dirty := true
var list_content: VBoxContainer
var bonus_dialog: AcceptDialog
var bonus_label: Label
var bonus_planet_id := ""
var facility_dialog: AcceptDialog
var facility_renderer = preload("res://scripts/orbital_facilities.gd").new()

func setup(owner_ui: Node) -> void:
	host = owner_ui
	add_child(facility_renderer)
	theme = Chrome.theme()
	add_theme_font_override("font", Chrome.SHELL.face(500))
	var list_frame := _panel(Rect2(16, 20, 194, 1138), Chrome.PAPER, Chrome.NAVY)
	_label(list_frame, UIText.t("planet.list_heading"), Rect2(14, 12, 166, 34), 21, Chrome.NAVY)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 56)
	scroll.size = Vector2(174, 1068)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_frame.add_child(scroll)
	list_content = VBoxContainer.new()
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.add_theme_constant_override("separation", 8)
	scroll.add_child(list_content)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			refresh()
			for id in cards:_clear_feedback(cards[id])
		else:
			for id in cards:_clear_feedback(cards[id]))
	refresh()
	host.game.event.connect(_on_log_event)

func _on_log_event(kind: String, info: Dictionary) -> void:
	if kind != "planet_changed" and kind != "planet_reforged":return
	var id := str(info.get("id", ""))
	if not cards.has(id):return
	var card: Dictionary = cards[id]
	if info.has("reward"):
		_append_log_phases(id, 4)
		card.log_phase = -1
		card.log_crew = ""
	_observe_log_buildings(id)
	_refresh_log_progress(id)
	if str(host.game.planet_progress(id).get("crewId", "")).is_empty():
		card.log_phase = -1
		card.log_crew = ""

func _append_log(id: String, text: String) -> void:
	var card: Dictionary = cards[id]
	card.log_entries.push_front(text)
	if card.log_entries.size() > 24:card.log_entries.pop_back()
	card.log_dirty = true
	_render_log(id)

func _render_log(id: String) -> void:
	var card: Dictionary = cards[id]
	if not card.log_dirty or id != selected_planet_id or not is_visible_in_tree():return
	host.set_ui_value(card.log_label, "text", "\n\n".join(card.log_entries))
	card.log_dirty = false

func _append_log_phases(id: String, phase: int) -> void:
	var card: Dictionary = cards[id]
	for index in range(int(card.log_phase) + 1, phase + 1):
		_append_log(id, UIText.t("planet.log.phase_" + str(index)))
	card.log_phase = maxi(int(card.log_phase), phase)

func _refresh_log_progress(id: String) -> void:
	var card: Dictionary = cards[id]
	var progress: Dictionary = host.game.planet_progress(id)
	var crew_id := str(progress.get("crewId", ""))
	if crew_id.is_empty():
		return
	if card.log_crew != crew_id:
		card.log_phase = -1
		card.log_crew = crew_id
	var ratio := float(progress.get("elapsed", 0)) / maxf(0.001, host.game.planet_duration(id))
	_append_log_phases(id, mini(3, int(clampf(ratio, 0.0, 1.0) * 4.0)))

func _observe_log_buildings(id: String) -> void:
	var card: Dictionary = cards[id]
	for row in host.game.planet_buildings.rows(host.game, id):
		var building_id := str(row.id)
		var status := str(host.game.planet_buildings.state(host.game, id, building_id).get("status", "locked"))
		var previous := str(card.log_buildings.get(building_id, status))
		if previous == "locked" and status != "locked":
			_append_log(id, UIText.t("planet.log.unlocked", {"name":str(row.name)}))
		if previous not in ["ready", "built"] and status == "ready":
			_append_log(id, UIText.t("planet.log.built", {"name":str(row.name)}))
		if previous == "ready" and status == "built":
			_append_log(id, UIText.t("planet.log.activated", {"name":str(row.name)}))
		card.log_buildings[building_id] = status

func _label(parent: Control, text: String, rect: Rect2, font_size: int, color := Chrome.NAVY) -> Label:
	var label: Label = host.equipment_card_label(parent, text, rect, font_size, color)
	label.add_theme_font_override("font", Chrome.SHELL.face(500))
	label.add_theme_color_override("font_color", color)
	return label

func _panel(rect: Rect2, fill: Color, edge: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", Chrome.surface(fill, edge, 0))
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
		_advance_feedback(cards[selected_planet_id], dt)
	if cards.has(selected_planet_id):
		var id := selected_planet_id
		var progress: Dictionary = host.game.planet_progress(id)
		var sample := [int(float(progress.get("elapsed", 0))), progress.get("crewId", ""), host.game.paused, cards[id].visual.work_state_key()]
		if samples.get(id) != sample:
			samples[id] = sample
			_refresh_task(id, false)

func _add_feedback(parent: Control) -> Control:
	var overlay := Feedback.new()
	parent.add_child(overlay)
	return overlay

func _clear_feedback(card: Dictionary) -> void:
	card.visual.clear_transients()
	card.visual.select_facility("")
	card.task_fx.clear()
	host.set_ui_value(card.feedback, "visible", false)
	host.set_ui_value(card.feedback, "modulate", Color.WHITE)
	host.set_ui_value(card.list_degree, "modulate", Color.WHITE)
	for controls in card.facility_buttons.values():controls.fx.clear()

func _advance_feedback(card: Dictionary, dt: float) -> void:
	if host.game.paused or dt <= 0.0:return
	card.task_fx.advance(dt, false)
	for controls in card.facility_buttons.values():controls.fx.advance(dt, false)
	var age: float = card.visual.completion_age
	var showing := age >= 0.18 and age < 3.2
	host.set_ui_value(card.feedback, "visible", showing)
	if showing:
		var alpha := smoothstep(0.18, 0.42, age) * (1.0 - smoothstep(2.6, 3.2, age))
		host.set_ui_value(card.feedback, "modulate", Color(1, 1, 1, alpha))
	var pulse := maxf(0.0, 1.0 - age / 0.85)
	host.set_ui_value(card.list_degree, "modulate", Color(1.0 + pulse * 0.6, 1.0 + pulse * 0.6, 1.0 + pulse * 0.6))
	# Follow authoritative elapsed time smoothly; no tween owns a second progress value.
	var progress: Dictionary = host.game.planet_progress(card.visual.planet_id)
	var active := not str(progress.get("crewId", "")).is_empty()
	var duration: float = host.game.planet_duration(card.visual.planet_id)
	var value := clampf(float(progress.get("elapsed", 0)) / maxf(1.0, duration) * 100.0, 0.0, 100.0) if active else 0.0
	host.set_ui_value(card.bar, "value", 100.0 if age < 0.18 else value)

func refresh() -> void:
	if not is_visible_in_tree():
		dirty = true
		return
	var ids: Array = []
	for id in host.game.db.data.get("planet", {}):
		if not host.game.planet_unlocked(str(id)):continue
		ids.append(str(id))
		if not cards.has(str(id)):add_card(str(id))
	for id in cards.keys():
		if not ids.has(id):
			cards[id].root.queue_free()
			cards[id].stage.queue_free()
			cards[id].rail.queue_free()
			cards[id].list_button.queue_free()
			cards.erase(id)
			samples.erase(id)
	if not ids.has(selected_planet_id):selected_planet_id = str(ids[0]) if not ids.is_empty() else ""
	for id in ids:refresh_card(str(id))
	_apply_selection()
	dirty = false

# Stage-one layout uses the existing controls and event ownership. Build once per
# unlocked planet; refresh only writes changed values and facility state styles.
func _section(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", Chrome.surface(Chrome.PAPER, Chrome.NAVY, 0))
	parent.add_child(panel)
	return panel

func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return label

func add_card(id: String) -> void:
	var list_button := Button.new()
	list_button.custom_minimum_size = Vector2(170, 84)
	list_button.clip_text = true
	list_button.pressed.connect(func():select_planet(id))
	list_content.add_child(list_button)
	var list_name: Label = _label(list_button, "", Rect2(66, 27, 98, 30), 21)
	list_name.max_lines_visible = 1
	list_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list_degree: Label = _label(list_button, "", Rect2(12, 98, 146, 28), 21, Chrome.MUTED)
	list_degree.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list_degree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_degree.hide()
	var icon := preload("res://scripts/planet_visual.gd").new()
	icon.icon_mode = true
	icon.position = Vector2(4, 10)
	icon.size = Vector2(60, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_button.add_child(icon)
	icon.configure(id, host.game.planet_row(id))
	var stage := _panel(Rect2(224, 20, 764, 944), Chrome.PAPER, Chrome.NAVY)
	var visual := preload("res://scripts/planet_visual.gd").new()
	visual.facility_renderer = facility_renderer
	visual.position = Vector2(10, 72)
	visual.size = Vector2(744, 862)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.clip_contents = true
	stage.add_child(visual)
	var stage_title: Label = _label(stage, "", Rect2(24, 18, 490, 38), 27)
	stage_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var stage_degree := _label(stage, "", Rect2(522, 23, 218, 32), 21, Color("005449"))
	stage_degree.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_degree.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rail := _panel(Rect2(224, 980, 1114, 178), Chrome.PAPER, Chrome.NAVY)
	_label(rail, UIText.t("planet.facility_heading"), Rect2(18, 12, 1078, 30), 22)
	var empty_facilities: Label = _wrap(_label(rail, UIText.t("planet.facility_empty"), Rect2(20, 70, 1074, 54), 18, Chrome.MUTED))
	var rail_scroll := ScrollContainer.new()
	rail_scroll.position = Vector2(16, 54)
	rail_scroll.size = Vector2(1082, 120)
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(rail_scroll)
	var rail_content := HBoxContainer.new()
	rail_content.add_theme_constant_override("separation", 12)
	rail_scroll.add_child(rail_content)
	var root := _panel(Rect2(1002, 20, 336, 944), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	var task := _section(root, Rect2(0, 0, 336, 434))
	var summary := _section(root, Rect2(0, 450, 336, 238))
	var title: Label = _label(task, UIText.t("planet.task_heading"), Rect2(20, 18, 296, 36), 25)
	var task_state: Label = _label(task, "", Rect2(20, 62, 296, 28), 18, Color.WHITE)
	var progress := Parameters.create_label(task, Rect2(20, 100, 296, 78), 20, Chrome.SHELL.face(500), Chrome.NAVY)
	progress.add_theme_constant_override("line_spacing", 2)
	var bar := ProgressBar.new()
	bar.position = Vector2(20, 178)
	bar.size = Vector2(296, 12)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", Chrome.surface(Color("d7ded2"), Chrome.NAVY, 0))
	bar.add_theme_stylebox_override("fill", Chrome.surface(Chrome.TEAL, Chrome.TEAL, 0))
	task.add_child(bar)
	var picker := OptionButton.new()
	picker.position = Vector2(20, 142)
	picker.size = Vector2(296, 44)
	picker.add_theme_font_override("font", host.font)
	picker.add_theme_font_size_override("font_size", 19)
	preload("res://scripts/dialog_presentation.gd").option(picker)
	task.add_child(picker)
	var no_crew := _wrap(_label(task, UIText.t("planet.no_idle_crew"), Rect2(20, 142, 296, 66), 21, Chrome.MUTED))
	# Initial text can expand a Label before autowrap is enabled; restore its column.
	no_crew.size = Vector2(296, 66)
	var auto := CheckButton.new()
	auto.text = UIText.t("planet.auto")
	auto.position = Vector2(20, 228)
	auto.size = Vector2(296, 36)
	auto.add_theme_font_size_override("font_size", 19)
	task.add_child(auto)
	Chrome.button_skin(auto)
	auto.toggled.connect(func(enabled):host.game.set_planet_auto(id,enabled))
	var start: Button = host.button(UIText.t("planet.start"), Rect2(20, 280, 296, 52), func():_start_exploration(id, picker), true)
	start.reparent(task, false)
	var cancel: Button = host.button(UIText.t("planet.cancel"), Rect2(20, 280, 296, 52), func():host.game.cancel_planet_exploration(id))
	cancel.reparent(task, false)
	for action in [start, cancel]:
		action.add_theme_font_size_override("font_size", 20)
		Chrome.button_skin(action, action == start)
	var feedback: Label = _wrap(_label(task, "", Rect2(20, 344, 296, 70), 21, Chrome.NAVY))
	feedback.visible = false
	_label(summary, UIText.t("planet.rewards_heading"), Rect2(20, 16, 296, 32), 22)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.position = Vector2(20, 56)
	detail_scroll.size = Vector2(296, 68)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary.add_child(detail_scroll)
	var detail: Label = _wrap(_label(detail_scroll, "", Rect2(0, 0, 278, 54), 19, Color("005449")))
	detail.custom_minimum_size = Vector2(0, 54)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.clip_text = false
	var bonuses: Button = host.button(UIText.t("planet.bonuses"), Rect2(20, 132, 296, 40), func():show_bonuses(id))
	bonuses.reparent(summary, false)
	bonuses.add_theme_font_size_override("font_size", 19)
	Chrome.button_skin(bonuses)
	var reforge: Button = host.button(UIText.t("planet.reforge"), Rect2(20, 184, 296, 40), func():_confirm_reforge(id))
	reforge.reparent(summary, false)
	Chrome.button_skin(reforge)
	var conquered: Label = _label(summary, UIText.t("planet.conquered"), Rect2(20, 184, 296, 40), 18, Color("005449"))
	var task_fx := _add_feedback(task)
	var log_panel := _section(root, Rect2(0, 704, 336, 240))
	_label(log_panel, UIText.t("planet.log.heading"), Rect2(20, 14, 296, 32), 22)
	var log_scroll := ScrollContainer.new()
	log_scroll.position = Vector2(20, 54)
	log_scroll.size = Vector2(296, 170)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(log_scroll)
	var log_label := Label.new()
	log_label.text = UIText.t("planet.log.empty")
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("font_size", 18)
	log_label.add_theme_color_override("font_color", Chrome.MUTED)
	log_label.add_theme_font_override("font", Chrome.SHELL.face(500))
	log_label.add_theme_constant_override("line_spacing", 4)
	log_scroll.add_child(log_label)
	cards[id] = {"icon":icon,"task_fx":task_fx,"task":task,"summary":summary,"task_state":task_state,"no_crew":no_crew,"list_name":list_name,"list_degree":list_degree,"rail_scroll":rail_scroll,"detail_scroll":detail_scroll,"auto":auto,"reforge":reforge,"conquered":conquered,"root":root,"stage":stage,"rail":rail,"rail_content":rail_content,"list_button":list_button,"title":title,"stage_title":stage_title,"stage_degree":stage_degree,"detail":detail,"progress":progress,"bar":bar,"picker":picker,"start":start,"cancel":cancel,"feedback":feedback,"empty_facilities":empty_facilities,"facility_buttons":{},"visual":visual,"crew_ids":[],"selected":null,"bonuses":bonuses}

	# Session-only presentation history; lifecycle follows this planet card.
	cards[id].merge({"log_label":log_label,"log_entries":[],"log_phase":-1,"log_crew":"","log_buildings":{},"log_dirty":false})
	_observe_log_buildings(id)

func bonus_text(id: String) -> String:
	var g = host.game
	var lines: PackedStringArray = []
	for row in g.planet_buildings.rows(g,id):
		if g.planet_buildings.state(g,id,str(row.id)).get("status") != "built":continue
		var description := str(row.name) + "\n" + str(row.des)
		if str(row.type) in ["refinery", "equipment"]:
			description += "\n" + UIText.t("planet.build_effect", {"mult":GrowthNumber.text(g.planet_buildings.building_multiplier(g,id,row))})
		lines.append(description)
	for row in g.planet_buffs.rows(g,id):lines.append(str(row.des))
	return "\n\n".join(lines) if not lines.is_empty() else UIText.t("planet.bonuses_empty")

func show_bonuses(id: String) -> void:
	if not is_instance_valid(bonus_dialog):
		bonus_dialog = AcceptDialog.new()
		preload("res://scripts/dialog_presentation.gd").dialog(bonus_dialog)
		bonus_dialog.min_size = Vector2i(660, 500)
		add_child(bonus_dialog)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(620, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		bonus_dialog.add_child(scroll)
		bonus_label = Label.new()
		bonus_label.custom_minimum_size.x = 580
		bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus_label.add_theme_font_size_override("font_size",20)
		scroll.add_child(bonus_label)
	bonus_planet_id = id
	bonus_dialog.title = UIText.t("planet.bonuses_title", {"planet":UIText.data_text("planet",id,"name",str(host.game.planet_row(id).get("name",id)))})
	bonus_label.text = bonus_text(id)
	bonus_dialog.popup_centered()

func _start_exploration(id: String, picker: OptionButton) -> void:
	var ids: Array = cards[id].crew_ids
	if picker.selected >= 0 and picker.selected < ids.size():
		var chosen_id := str(ids[picker.selected])
		host.game.start_planet_exploration(id, chosen_id)
		if str(host.game.planet_progress(id).get("crewId", "")) == chosen_id:
			cards[id].task_fx.trigger(host.CYAN, 0.55)

func exploration_count_text(value) -> String:
	# Counts never show decimal places; retain compact big-number support.
	if value is Dictionary or GrowthNumber.compare(value,1e20)>=0:
		var parts := GrowthNumber.parts(value)
		return "%.0fe+%.0f" % [parts[0]*100.0,parts[1]-2.0]
	return "%.0f" % float(value)

func refresh_card(id: String) -> void:
	var card: Dictionary = cards[id]
	if is_instance_valid(bonus_dialog) and bonus_dialog.visible and bonus_planet_id == id:
		host.set_ui_value(bonus_label, "text", bonus_text(id))
	var row: Dictionary = host.game.planet_row(id)
	var progress: Dictionary = host.game.planet_progress(id)
	var degree = progress.get("degree", 0)
	var name := UIText.data_text("planet", id, "name", str(row.get("name", id)))
	host.set_ui_value(card.list_name, "text", name.get_slice("-", 0))
	host.set_ui_value(card.list_degree, "text", UIText.t("planet.degree", {"degree":exploration_count_text(degree)}))
	host.set_ui_value(card.list_button, "tooltip_text", UIText.t("planet.list_entry", {"planet":name, "degree":exploration_count_text(degree)}))
	if not selected_planet_id.is_empty() and id != selected_planet_id:return
	host.set_ui_value(card.title, "text", UIText.t("planet.task_heading"))
	host.set_ui_value(card.stage_title, "text", name)
	host.set_ui_value(card.stage_degree, "text", UIText.t("planet.degree", {"degree":exploration_count_text(degree)}))
	host.set_ui_value(card.stage_degree, "tooltip_text", card.stage_degree.text)
	host.set_ui_value(card.stage_title, "tooltip_text", name)
	var visual_row := row.duplicate(true)
	visual_row.visualFacilities=[]
	for building in host.game.planet_buildings.rows(host.game,id):
		if host.game.planet_buildings.state(host.game,id,str(building.id)).get("status", "") in ["ready", "built"]:
			visual_row.visualFacilities.append({"id":str(building.id),"type":str(building.type),"owned":true})
	card.visual.configure(id, visual_row)
	card.visual.set_exploration(not str(progress.get("crewId", "")).is_empty(), progress.get("degree", 0), float(progress.get("elapsed", 0)))
	_sync_facility_buttons(id)
	var reward: float = host.game.planet_exp_reward(id)
	var detail_text := UIText.t("planet.trip_gain")
	if reward > 0 and host.game.crew.levels_unlocked(host.game):detail_text += "\n" + crew_reward_text(reward)
	host.set_ui_value(card.detail,"text",detail_text)
	var exact_detail := UIText.t("planet.trip_gain")
	if reward > 0 and host.game.crew.levels_unlocked(host.game):exact_detail += "\n" + host.game.crew.format_text(host.game,"planet_exp",{"exp":NumberFormat.precise(reward)})
	host.set_ui_value(card.detail,"tooltip_text",exact_detail)
	_refresh_task(id)

func _refresh_task(id: String, refresh_roster := true) -> void:
	_refresh_log_progress(id)
	_render_log(id)
	var card: Dictionary = cards[id]
	var progress: Dictionary = host.game.planet_progress(id)
	var duration: float = host.game.planet_duration(id)
	var crew_id := str(progress.get("crewId", ""))
	var active := not crew_id.is_empty()
	var member: Dictionary = host.game.crew.definitions(host.game).get(crew_id, {})
	var progress_text := Parameters.render("planet.exploring", {"crew":str(member.get("name", crew_id)), "remaining":"%.1f" % maxf(0, duration-float(progress.get("elapsed", 0)))}, {"remaining":{"role":"time", "unit":" 秒"}}) + "\n" + Parameters.escape(UIText.t(card.visual.work_state_key())) if active else Parameters.render("planet.duration_compact", {"seconds":"%.1f" % duration}, {"seconds":{"role":"time", "unit":" 秒"}})
	host.set_ui_value(card.progress, "text", progress_text)
	host.set_ui_value(card.progress, "tooltip_text", card.progress.get_parsed_text())
	var state_key := "planet.task_paused" if host.game.paused else ("planet.task_active" if active else "planet.task_idle")
	host.set_ui_value(card.task_state, "text", UIText.t(state_key))
	host.set_ui_value(card.task_state, "visible", active or host.game.paused)
	host.set_ui_value(card.progress, "position", Vector2(20, 100 if active or host.game.paused else 66))
	host.set_ui_value(card.bar, "visible", active)
	host.set_ui_value(card.task_state, "modulate", Color("946426") if host.game.paused else (Color("005449") if active else Chrome.MUTED))
	var bar_value := clampf(float(progress.get("elapsed", 0)) / maxf(1.0, duration) * 100.0, 0.0, 100.0) if active else 0.0
	host.set_ui_value(card.bar, "value", 100.0 if card.visual.completion_age < 0.18 else bar_value)
	if not refresh_roster:return
	var available: Array = []
	for item in host.game.profile.crew:
		if not host.game.crew.unlocked(host.game, item.crewId) or not str(item.assignmentType).is_empty():continue
		if not host.game.crew_exploration(str(item.crewId)).is_empty():continue
		available.append(item.crewId)
	if card.crew_ids != available:
		var previous := str(card.crew_ids[card.picker.selected]) if card.picker.selected >= 0 and card.picker.selected < card.crew_ids.size() else ""
		card.picker.clear()
		card.crew_ids = available
		for member_id in available:card.picker.add_item(str(host.game.crew.definitions(host.game)[member_id].name))
		if not available.is_empty():card.picker.select(maxi(0, available.find(previous)))
	host.set_ui_value(card.picker, "visible", not active and not available.is_empty())
	host.set_ui_value(card.no_crew, "visible", not active and available.is_empty())
	host.set_ui_value(card.start, "visible", not active)
	host.set_ui_value(card.start, "disabled", available.is_empty())
	host.set_ui_value(card.cancel, "visible", active)

func _sync_facility_buttons(id: String) -> void:
	var card: Dictionary=cards[id]
	var g=host.game
	var wanted := {}
	var preview: Dictionary=g.planet_buildings.preview(g,id)
	for row in g.planet_buildings.rows(g,id):
		var building_id := str(row.id)
		var state: Dictionary=g.planet_buildings.state(g,id,building_id)
		var locked: bool=state.get("status","locked")=="locked"
		if locked and str(preview.get("id",""))!=building_id:continue
		wanted[building_id]=true
		if not card.facility_buttons.has(building_id):
			var box := Panel.new()
			box.custom_minimum_size = Vector2(160, 118)
			card.rail_content.add_child(box)
			box.mouse_entered.connect(func():box.self_modulate = Color(1.12, 1.12, 1.12);card.visual.select_facility(building_id))
			box.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:_show_facility(id, building_id))
			box.mouse_exited.connect(func():box.self_modulate = Color.WHITE;card.visual.select_facility(""))
			var silhouette := Control.new()
			silhouette.position = Vector2(8, 6)
			silhouette.size = Vector2(76, 64)
			silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(silhouette)
			silhouette.draw.connect(func():_draw_building_silhouette(silhouette,str(row.type)))
			var label := _label(box, "", Rect2(92, 10, 150, 36), 21)
			var status: Label = _label(box, "", Rect2(16, 76, 226, 26), 17)
			var metric := _wrap(_label(box, "", Rect2(16, 105, 226, 48), 21, Color("005449")))
			var assign: Button = host.button("", Rect2(88, 78, 156, 36), func():_toggle_builder(id,building_id))
			assign.reparent(box, false)
			assign.clip_text = true
			assign.add_theme_font_size_override("font_size", 15)
			Chrome.button_skin(assign, true)
			card.facility_buttons[building_id] = {"root":box,"label":label,"status":status,"metric":metric,"assign":assign,"silhouette":silhouette,"presentation_state":"","fx":_add_feedback(box)}
		var controls: Dictionary = card.facility_buttons[building_id]
		var built: bool = state.get("status") == "built"
		var ready: bool = state.get("status") == "ready"
		# Only the next applicable preview reveals its name and remaining trips.
		var remaining = GrowthNumber.ceiling(GrowthNumber.subtract(row.unlock_explore,g.planet_progress(id).degree))
		var presentation := "locked" if locked else ("built" if built else "ready" if ready else "building")
		var tint: Color = Chrome.MUTED if locked else (Color("005449") if built else Color("946426"))
		if controls.presentation_state != presentation:
			if not str(controls.presentation_state).is_empty() and id == selected_planet_id and is_visible_in_tree():
				controls.fx.trigger(tint, 1.4)
				
			controls.root.add_theme_stylebox_override("panel", Chrome.surface(Color("dfe2d6") if locked else Color("f4f0df"), Color("95a9aa") if locked else Chrome.NAVY, 0))
			controls.presentation_state = presentation
		host.set_ui_value(controls.silhouette, "modulate", Color(0.30, 0.40, 0.48, 0.65) if locked else Color.WHITE)
		host.set_ui_value(controls.label, "text", str(row.name))
		host.set_ui_value(controls.label, "modulate", Color.WHITE)
		host.set_ui_value(controls.status, "text", UIText.t("planet.facility_status_" + presentation))
		host.set_ui_value(controls.status, "visible", false)
		host.set_ui_value(controls.status, "modulate", tint)
		var metric_text := UIText.t("planet.facility_remaining", {"count":exploration_count_text(remaining)}) if locked else "" if built else UIText.t("planet.facility_status_ready") if ready else UIText.t("planet.facility_progress", {"progress":exploration_count_text(state.get("build_progress",0)),"total":exploration_count_text(row.build_explore)})
		host.set_ui_value(controls.metric, "text", metric_text)
		host.set_ui_value(controls.metric, "visible", not built)
		host.set_ui_value(controls.root, "custom_minimum_size", Vector2(160 if built else 252, 118))
		host.set_ui_value(controls.silhouette, "position", Vector2(42, 4) if built else Vector2(8, 8))
		host.set_ui_value(controls.label, "position", Vector2(8, 78) if built else Vector2(88, 8))
		host.set_ui_value(controls.label, "size", Vector2(144 if built else 156, 36))
		host.set_ui_value(controls.label, "horizontal_alignment", HORIZONTAL_ALIGNMENT_CENTER if built else HORIZONTAL_ALIGNMENT_LEFT)
		host.set_ui_value(controls.metric, "position", Vector2(8, 82) if locked else Vector2(88, 42))
		host.set_ui_value(controls.metric, "size", Vector2(236 if locked else 156, 32))
		var description := str(row.name) + "\n" + (metric_text if locked else str(row.des))
		if ready:description += "\n" + UIText.t("planet.facility_status_ready")
		if not locked and str(row.type) in ["refinery","equipment"]:
			var mult=g.planet_buildings.building_multiplier(g,id,row)
			description+="\n"+UIText.t("planet.build_effect",{"mult":GrowthNumber.text(mult)})
		host.set_ui_value(controls.root,"tooltip_text",description)
		var needs_crew: bool=not locked and not built and not ready and int(row.extra_crew)>0
		host.set_ui_value(controls.assign,"visible",needs_crew or ready)
		if ready:host.set_ui_value(controls.assign, "text", UIText.t("planet.activate"))
		if needs_crew:
			var builders: Array=state.get("crew",[])
			host.set_ui_value(controls.assign,"text",UIText.t("planet.builder_compact", {"count":builders.size(),"required":exploration_count_text(row.extra_crew)}))
		host.set_ui_value(controls.assign, "tooltip_text", controls.assign.text)
		if controls.root.get_index() != wanted.size()-1:card.rail_content.move_child(controls.root,wanted.size()-1)
	for building_id in card.facility_buttons.keys():
		if not wanted.has(building_id):
			card.facility_buttons[building_id].root.queue_free()
			card.facility_buttons.erase(building_id)
	host.set_ui_value(card.empty_facilities,"visible",wanted.is_empty())
	host.set_ui_value(card.auto,"visible",g.planet_buildings.built(g,id,"auto_explore"))
	var auto_enabled: bool = g.planet_progress(id).get("auto_explore",false)
	if card.auto.button_pressed != auto_enabled:card.auto.set_pressed_no_signal(auto_enabled)
	host.set_ui_value(card.reforge,"visible",g.can_reforge_planet(id))
	host.set_ui_value(card.conquered,"visible",g.planet_progress(id).get("conquered",false))

func _draw_building_silhouette(control: Control, kind: String) -> void:
	var artwork: Texture2D = Art.facility(kind)
	if artwork != null:
		Art.draw_fitted(control, artwork, Rect2(Vector2.ZERO, control.size))
		return
	var tint := Color.WHITE
	match kind:
		"auto_explore":
			control.draw_circle(Vector2(28,14),10,tint)
			control.draw_rect(Rect2(4,10,48,8),tint)
			control.draw_rect(Rect2(25,0,6,28),tint)
		"refinery":
			control.draw_colored_polygon(PackedVector2Array([Vector2(8,10),Vector2(44,10),Vector2(38,27),Vector2(14,27)]),tint)
			control.draw_rect(Rect2(16,1,6,12),tint)
			control.draw_rect(Rect2(32,4,6,9),tint)
		"equipment":
			control.draw_rect(Rect2(8,10,40,18),tint)
			control.draw_colored_polygon(PackedVector2Array([Vector2(8,10),Vector2(20,1),Vector2(20,10),Vector2(33,1),Vector2(33,10)]),tint)
		_:
			control.draw_rect(Rect2(7,5,5,23),tint)
			control.draw_rect(Rect2(44,5,5,23),tint)
			control.draw_rect(Rect2(7,3,42,5),tint)
			control.draw_rect(Rect2(15,20,26,6),tint)

func _show_facility(id: String, building_id: String) -> void:
	if not cards[id].facility_buttons.has(building_id):return
	var controls: Dictionary = cards[id].facility_buttons[building_id]
	if not is_instance_valid(facility_dialog):
		facility_dialog = AcceptDialog.new()
		preload("res://scripts/dialog_presentation.gd").dialog(facility_dialog)
		facility_dialog.add_theme_font_size_override("font_size", 22)
		facility_dialog.min_size = Vector2i(520, 220)
		add_child(facility_dialog)
	facility_dialog.title = controls.label.text
	facility_dialog.dialog_text = controls.root.tooltip_text
	facility_dialog.popup_centered()

func _toggle_builder(id: String, building_id: String) -> void:
	var g=host.game
	var state: Dictionary=g.planet_buildings.state(g,id,building_id)
	if state.get("status", "") == "ready":
		g.planet_buildings.activate(g, id, building_id)
		return
	var builders: Array=state.get("crew",[])
	var row: Dictionary=g.db.data.planet_build[building_id]
	if builders.size()>=int(row.extra_crew):
		g.planet_buildings.assign(g,id,building_id,str(builders.back()))
		return
	# Explicit selection; never silently occupy the first available crew member.
	var anchor: Button = cards[id].facility_buttons[building_id].assign
	var popup := PopupMenu.new()
	anchor.add_child(popup)
	preload("res://scripts/dialog_presentation.gd").popup(popup)
	var ids: Array=[]
	var five_rows_height := 0.0
	for member in g.profile.crew:
		if g.idle_planet_crew(str(member.crewId)):
			ids.append(str(member.crewId))
			popup.add_item(str(g.crew.definitions(g)[member.crewId].name))
			if popup.item_count == 5:five_rows_height = popup.get_contents_minimum_size().y
	for member_id in builders:
		ids.append(str(member_id))
		popup.add_item(UIText.t("planet.recall_builder",{"name":g.crew.definitions(g)[member_id].name}))
		if popup.item_count == 5:five_rows_height = popup.get_contents_minimum_size().y
	popup.id_pressed.connect(func(index):g.planet_buildings.assign(g,id,building_id,ids[index]))
	popup.popup_hide.connect(popup.queue_free)
	anchor.visibility_changed.connect(popup.hide)
	# Use the same screen transform for the button and playable viewport, including
	# window offset, canvas scaling and letterboxing. Never use logical mouse coordinates.
	var screen_transform := anchor.get_screen_transform()
	var anchor_rect := screen_transform * Rect2(Vector2.ZERO, anchor.size)
	var viewport_transform := screen_transform * anchor.get_global_transform_with_canvas().affine_inverse()
	var bounds := (viewport_transform * anchor.get_viewport_rect()).grow(-8.0)
	# Measure five real rows, including theme padding, before adding overflow items.
	var height_limit := bounds.size.y
	if five_rows_height > 0.0:
		var menu_scale := screen_transform.get_scale().abs()
		height_limit = minf(height_limit, ceilf(five_rows_height * minf(menu_scale.x, menu_scale.y)))
	popup.max_size = Vector2i(int(bounds.size.x), int(height_limit))
	popup.min_size = Vector2i(ceili(anchor_rect.size.x), 0)
	popup.popup()
	var menu_size := Vector2(popup.size)
	var menu_position := Vector2(anchor_rect.position.x, anchor_rect.position.y - menu_size.y - 4.0)
	menu_position.x = clampf(menu_position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - menu_size.x))
	menu_position.y = clampf(menu_position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - menu_size.y))
	popup.position = Vector2i(menu_position)

func _confirm_reforge(id: String) -> void:
	if not host.game.can_reforge_planet(id):return
	var dialog := ConfirmationDialog.new()
	dialog.title=UIText.t("planet.reforge")
	dialog.dialog_text=UIText.t("planet.reforge_confirm", {"level":host.game.planet_reforge_start(id)})
	dialog.min_size=Vector2i(650,340)
	preload("res://scripts/dialog_presentation.gd").dialog(dialog)
	add_child(dialog)
	dialog.confirmed.connect(func():host.game.reforge_planet(id);dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func select_planet(id: String) -> void:
	if not cards.has(id) or selected_planet_id == id:return
	if cards.has(selected_planet_id):_clear_feedback(cards[selected_planet_id])
	_clear_feedback(cards[id])
	selected_planet_id = id
	_apply_selection()
	refresh_card(id)
	_clear_feedback(cards[id])

func _apply_selection() -> void:
	for id in cards:
		var card: Dictionary = cards[id]
		var selected: bool = id == selected_planet_id
		host.set_ui_value(card.root, "visible", selected)
		host.set_ui_value(card.stage, "visible", selected)
		host.set_ui_value(card.rail, "visible", selected)
		if card.selected != selected:
			Chrome.button_skin(card.list_button, selected)
			card.selected = selected

func show_completion(id: String, reward: float = -1.0) -> void:
	if not cards.has(id):return
	var card: Dictionary = cards[id]
	if id != selected_planet_id or not is_visible_in_tree():return
	card.visual.complete()
	card.task_fx.trigger(host.CYAN, 0.85)
	var shown_reward: float = reward if reward >= 0.0 else host.game.planet_exp_reward(id)
	host.set_ui_value(card.feedback, "text", UIText.t("planet.trip_gain") + ("  " + crew_reward_text(shown_reward) if shown_reward > 0 else ""))
	host.set_ui_value(card.feedback, "tooltip_text", UIText.t("planet.trip_gain") + ("  " + host.game.crew.format_text(host.game,"planet_exp",{"exp":NumberFormat.precise(shown_reward)}) if shown_reward > 0 else ""))
	host.set_ui_value(card.feedback, "visible", false)
	host.set_ui_value(card.feedback, "modulate", Color(1, 1, 1, 0))

func select_facility(planet_id: String, facility_id: String) -> void:
	if cards.has(planet_id):cards[planet_id].visual.select_facility(facility_id)

func crew_reward_text(amount: float) -> String:
	var g=host.game
	return g.crew.format_text(g,"planet_exp",{"exp":host.number(amount)}) if g.crew.levels_unlocked(g) else ""
