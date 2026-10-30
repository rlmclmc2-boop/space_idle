extends Control
signal reforge_requested(planet_id: String)
signal exclusive_ui_changed
## One selected planet owns all visible task/facility/crew content.
const ERRORS := {"UnknownPlanet": "尚未选择星球", "PlanetLocked": "星球尚未开放", "PlanetConquestSourceUnavailable": "征服来源暂不可用", "PlanetStationRequired": "需先领取空间站", "PlanetBuildingUnavailable": "建筑当前不可派遣施工", "PlanetBuildingNotReady": "建筑尚未完工", "CrewTargetOccupied": "该岗位人数已满", "CrewLocked": "船员尚未开放", "HyperspaceCrewReserved": "船员仍被超空间任务占用"}
const STATES := {"locked": "未达门槛", "building": "施工中", "ready": "待领取", "built": "已领取"}
const PAUSES := {"ExplorationNotRunning": "探索未运行，施工暂停", "NoExplorer": "缺少探索者，施工暂停", "MissingBuilders": "缺少额外施工人员，施工暂停"}
const ResourceVisuals := preload("res://src/ui/resource_visuals.gd")
var _host: Callable
var _planet
var _crew
var _cancel: Callable
var _publish: Callable
var _coordinate: Callable
var _visual_context: Callable
var _visual
var _selected_id := ""
var _selected_facility := ""
var _open_section := ""
var _dirty := true
var _options_dirty := true
var _crew_options_dirty := true
var _snapshot: Dictionary = {}
var _facts: Array = []
var _crew_views: Dictionary = {"explorers": {}, "builders": {}}
var _last_degree := -1
var _context: Dictionary = {}
var _detail_signature: Dictionary = {}
var _conquest_open := false
var _conquest_planet_dirty := true
var _conquest_cumulative_dirty := true
var _conquest_planet: Dictionary = {}
var _conquest_rewards: Array = []
var _conquest_error := ""
var world_planet_picker := OptionButton.new()
var world_building_picker: OptionButton
var _task_button := Button.new()
var _crew_button := Button.new()
var _facility_button := Button.new()
var _stop_button: Button
var _cancel_button: Button
var _auto_button: Button
var _progress := ProgressBar.new()
var _wallet := HBoxContainer.new()
var _wallet_rows: Array = []
var _wallet_signature: Array = []
var _task_line := Label.new()
var _feedback := Label.new()
var _feedback_seconds := 0.0
var _drawer := PanelContainer.new()
var _drawer_box := VBoxContainer.new()
var _drawer_title := Label.new()
var _drawer_body := VBoxContainer.new()
var _detail_text: Label
var _work_text: Label
var _work_bar: ProgressBar
var _unlock_text: Label
var _factor_text: Label
var _claim_button: Button
var _reforge_button: Button
var _member_picker: OptionButton
var _assignment_picker: OptionButton
var _member_id := ""
var _assignment_target := ""
var _shared_host_enabled := false
var _context_slot: Control

func _init(planet, cancel: Callable, publish: Callable, command: Callable, visual_context: Callable = Callable(), crew = null, coordinate: Callable = Callable()) -> void:
	_planet = planet
	_cancel = cancel
	_publish = publish
	_host = command
	_visual_context = visual_context
	_crew = crew
	_coordinate = coordinate
	custom_minimum_size = Vector2(760, 740)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_planet.availability_changed.connect(_queue_options)
	_planet.status_changed.connect(_queue_planets)
	_planet.buildings_changed.connect(_queue_planets)
	_planet.conquest_changed.connect(_on_conquest_changed.bind(_planet))
	if _crew != null:
		_crew.members_changed.connect(func(_ids): _queue_crew_options())
		_crew.options_changed.connect(_queue_crew_options)

func _ready() -> void:
	process_priority = 1
	theme = _theme()
	_visual = preload("res://scripts/planet_visual.gd").new()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	for button in [_task_button, _crew_button, _facility_button]:
		button.toggle_mode = true
		add_child(button)
	_paint_button(_task_button, Color("264b58"), Color("31616b"), Color("e6d5ac"), Color("b39a68"), Color("f6efdc"))
	for button in [_crew_button, _facility_button]:
		_paint_button(button, Color("173847"), Color("285464"), Color("e4dcc6"), Color("6f9ba0"), Color("f0ead8"))
	_paint_button(world_planet_picker, Color("e7e4d6"), Color("f7f1df"), Color("d9e8e0"), Color("78999c"), Color("203f4c"))
	_task_button.pressed.connect(func(): _toggle_section("exploration"))
	_crew_button.pressed.connect(func(): _toggle_section("crew"))
	_facility_button.pressed.connect(func(): _toggle_section("facilities"))
	add_child(world_planet_picker)
	_track_picker(world_planet_picker)
	world_planet_picker.item_selected.connect(func(index): select_planet(str(world_planet_picker.get_item_metadata(index))))
	_stop_button = _action(self, "本次完成后停止", func(): return _planet.set_automatic(_selected_id, false))
	_cancel_button = _action(self, "立即取消探索", func(): return _cancel.call(_selected_id))
	_paint_button(_stop_button, Color("173747"), Color("285365"), Color("315f6c"), Color("4b7580"), Color("e8ebdf"))
	_paint_button(_cancel_button, Color("342f31"), Color("594041"), Color("654848"), Color("9c7264"), Color("f1e3d2"))
	for label in [_task_line, _feedback, _wallet]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_wallet.add_theme_constant_override("separation", 7)
	for index in 3:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size.x = 185
		cell.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(17, 17)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var amount := Label.new()
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.clip_text = true
		amount.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(amount)
		_wallet.add_child(cell)
		_wallet_rows.append({"cell": cell, "icon": icon, "amount": amount})
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_color_override("font_color", Color("ffd496"))
	_task_line.add_theme_font_size_override("font_size", 17)
	var status_plate := _skin(Color("142f3b", 0.94), Color("bd9e6e"), 1, 5)
	status_plate.border_width_left = 3
	status_plate.content_margin_left = 11
	status_plate.content_margin_top = 4
	status_plate.content_margin_bottom = 4
	status_plate.border_width_bottom = 2
	_task_line.add_theme_stylebox_override("normal", status_plate)
	add_child(_progress)
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drawer)
	_drawer.add_child(_drawer_box)
	_drawer.draw.connect(_draw_drawer_trim)
	_drawer_box.add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	_drawer_box.add_child(header)
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_title.add_theme_font_size_override("font_size", 20)
	_drawer_title.add_theme_color_override("font_color", Color("f0ead9"))
	header.add_child(_drawer_title)
	var close := Button.new()
	close.text = "收起"
	close.pressed.connect(func(): _toggle_section(_open_section))
	_paint_secondary(close)
	header.add_child(close)
	_drawer_box.add_child(_drawer_body)
	_drawer.hide()
	resized.connect(_layout)
	_layout()
	_refresh_options()
	_read_conquest_if_needed()
	refresh()

func _exit_tree() -> void:
	var callback := _on_conquest_changed.bind(_planet)
	if _planet != null and _planet.conquest_changed.is_connected(callback):
		_planet.conquest_changed.disconnect(callback)

func _theme() -> Theme:
	var result := preload("res://src/ui/bridge_theme.gd").create()
	result.default_font_size = 17
	result.set_color("font_color", "Label", Color("274554"))
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, _skin(Color("173847"), Color("4d7882")))
		result.set_stylebox("hover", type, _skin(Color("285464"), Color("8fc6c2"), 2))
		result.set_stylebox("pressed", type, _skin(Color("e4dcc6"), Color("be9d67"), 2))
		result.set_stylebox("focus", type, _skin(Color("000000", 0.0), Color("e8c982"), 2))
		result.set_stylebox("disabled", type, _skin(Color("243743"), Color("4d6269")))
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			result.set_color(state, type, Color("eee9d9"))
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			result.set_color(state, type, Color("173747"))
		result.set_color("font_disabled_color", type, Color("95a7a8"))
	var panel := _skin(Color("e6e1d1"), Color("55727a"), 1, 4)
	panel.set_content_margin_all(13)
	panel.shadow_color = Color("061824", 0.38)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(1, 3)
	result.set_stylebox("panel", "PanelContainer", panel)
	var popup := StyleBoxFlat.new()
	popup.bg_color = Color("143746")
	popup.border_color = Color("80b9b2")
	popup.set_border_width_all(1)
	popup.set_corner_radius_all(7)
	popup.set_content_margin_all(6)
	result.set_stylebox("panel", "PopupMenu", popup)
	var hovered := StyleBoxFlat.new()
	hovered.bg_color = Color("2a6069")
	hovered.set_corner_radius_all(4)
	result.set_stylebox("hover", "PopupMenu", hovered)
	result.set_font_size("font_size", "PopupMenu", 17)
	for key in ["font_color", "font_hover_color", "font_accelerator_color"]:
		result.set_color(key, "PopupMenu", Color("f0eddf"))
	for state in ["background", "fill"]:
		var bar := _skin(Color("d6ab6c") if state == "fill" else Color("173747"), Color("325968"), 0, 3)
		bar.set_content_margin_all(0)
		result.set_stylebox(state, "ProgressBar", bar)
	return result

func _skin(fill: Color, edge: Color, border: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(mini(radius, 4))
	style.set_content_margin_all(8)
	return style

func _paint_button(button: Button, normal: Color, hover: Color, pressed: Color, edge: Color, ink: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var fill := normal if state == "normal" else hover if state == "hover" else pressed
		var style := _skin(fill, edge, 1, 4)
		style.shadow_color = Color("061823", 0.28 if state != "pressed" else 0.14)
		style.shadow_size = 2 if state != "pressed" else 1
		style.shadow_offset = Vector2(0, 1)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", _skin(Color("000000", 0.0), Color("edc37c"), 2))
	button.add_theme_stylebox_override("disabled", _skin(Color("243743"), Color("4d6269")))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("173747"))
	button.add_theme_color_override("font_disabled_color", Color("95a7a8"))
	button.set_meta("bevel_gold", normal.r > 0.7 and normal.g > 0.45 and normal.b < 0.55)
	if not button.has_meta("bevel_draw_connected"):
		button.set_meta("bevel_draw_connected", true)
		button.draw.connect(_draw_button_bevel.bind(button))

func _paint_secondary(button: Button) -> void:
	_paint_button(button, Color("1a3e4b"), Color("2b5661"), Color("d8d5c5"), Color("729296"), Color("eee9d9"))

func _draw_button_bevel(button: Button) -> void:
	if button.size.x < 24 or button.size.y < 18: return
	var gold := bool(button.get_meta("bevel_gold", false))
	var sheen := Color("fff6df", 0.23) if gold or button.button_pressed else Color("b4dcda", 0.19)
	var shade := Color("715336", 0.09) if gold or button.button_pressed else Color("041722", 0.13)
	if button.disabled:
		sheen.a *= 0.25
		shade.a *= 0.25
	button.draw_polygon(
		PackedVector2Array([Vector2(2, 2), Vector2(button.size.x - 2, 2), Vector2(button.size.x - 2, button.size.y - 2), Vector2(2, button.size.y - 2)]),
		PackedColorArray([sheen, sheen, shade, shade]))

func _draw_drawer_trim() -> void:
	var width := _drawer.size.x
	var height := _drawer.size.y
	_drawer.draw_polygon(
		PackedVector2Array([Vector2(2, 50), Vector2(width - 2, 50), Vector2(width - 2, height - 3), Vector2(2, height - 3)]),
		PackedColorArray([Color("fff9e8", 0.46), Color("fff9e8", 0.46), Color("aabcb8", 0.24), Color("aabcb8", 0.24)]))
	_drawer.draw_rect(Rect2(2, 2, width - 4, 48), Color("234653"))
	_drawer.draw_line(Vector2(2, 50), Vector2(width - 2, 50), Color("8fa49d", 0.72), 1.0)

func _layout() -> void:
	if _visual == null: return
	# Keep the complete scene visible beside an open detail drawer. The full
	# composition returns when the drawer closes; no facility is masked by it.
	var drawer_open := not _open_section.is_empty()
	var visual_top := 65 if _shared_host_enabled else 90
	_visual.position = Vector2(292, visual_top) if drawer_open else Vector2(0, visual_top)
	_visual.size = Vector2(maxf(400, size.x - 292), maxf(500, size.y - visual_top)) if drawer_open else Vector2(size.x, maxf(500, size.y - visual_top))
	_task_button.position = Vector2(258, 112)
	_task_button.size = Vector2(226, 44)
	_crew_button.position = Vector2(148, 112)
	_crew_button.size = Vector2(100, 44)
	_facility_button.position = Vector2(22, 112)
	_facility_button.size = Vector2(116, 44)
	world_planet_picker.position = Vector2(494, 112)
	world_planet_picker.size = Vector2(176, 44)
	_stop_button.position = Vector2(390, 168)
	_stop_button.size = Vector2(190, 42)
	_cancel_button.position = Vector2(590 if _stop_button.visible else 390, 168)
	_cancel_button.size = Vector2(190, 42)
	_progress.position = Vector2(258, 158)
	_progress.size = Vector2(226, 4)
	_task_line.position = Vector2(22, 168)
	_task_line.size = Vector2(340, 46 if bool(_snapshot.get("running", false)) else 28)
	_task_line.add_theme_color_override("font_color", Color("e0eee9"))
	_feedback.position = Vector2(22, size.y - 80)
	_feedback.size = Vector2(500, 70)
	# Shared left drawer belongs to the three scoped entry tabs; facility aligns above it.
	_drawer.position = Vector2(22, 278)
	_drawer.size.x = 276
	_drawer.size.y = 0
	_wallet.position = Vector2(200, 14)
	_wallet.size = Vector2(580, 30)
	_wallet.clip_contents = true
	queue_redraw()

func _draw() -> void:
	if not _open_section.is_empty():
		# Extend the scene's quiet blue falloff behind the existing drawer so
		# resizing its art viewport does not leave a hard vertical void.
		var visual_top := 65 if _shared_host_enabled else 90
		for index in 24:
			var top := float(index) / 24.0
			var bottom := float(index + 1) / 24.0
			var tint := Color("061b28").lerp(Color("0b2634"), minf(top * 1.5, 1.0))
			if top > 0.67: tint = tint.lerp(Color("09212f"), (top - 0.67) / 0.33)
			draw_rect(Rect2(0, visual_top + (size.y - visual_top) * top, 292, (size.y - visual_top) * (bottom - top) + 1), tint)
	if not _shared_host_enabled:
		draw_rect(Rect2(0, 0, size.x, 90), Color("f0eddf"))
		draw_string(get_theme_default_font(), Vector2(22, 34), "远航舰桥", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("243d50"))
		draw_string(get_theme_default_font(), Vector2(24, 74), "星球探索", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("40676b"))

## The host owns global chrome. This view keeps its 808x900 interior geometry.
func set_shared_host(enabled: bool, context_slot: Control, _backdrop: Texture2D = null) -> void:
	_shared_host_enabled = enabled
	_wallet.visible = not enabled
	if _context_slot != null:
		for child in _context_slot.get_children(): child.queue_free()
	_context_slot = context_slot
	if enabled and context_slot != null:
		var caption := Label.new()
		caption.text = "星球"
		caption.size = Vector2(96, 26)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		context_slot.add_child(caption)
	queue_redraw()

func _track_picker(picker: OptionButton) -> void:
	picker.get_popup().visibility_changed.connect(func(): exclusive_ui_changed.emit())

func has_exclusive_ui() -> bool:
	for picker in [world_planet_picker, world_building_picker, _member_picker, _assignment_picker]:
		if is_instance_valid(picker) and picker.get_popup().visible: return true
	return false

func prepare_host_hide(force: bool = false) -> bool:
	if has_exclusive_ui() and not force: return false
	if force:
		for picker in [world_planet_picker, world_building_picker, _member_picker, _assignment_picker]:
			if is_instance_valid(picker): picker.get_popup().hide()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	return true

func refresh() -> void:
	_dirty = true

func _queue_options() -> void:
	_options_dirty = true
	_dirty = true

func _queue_planets(ids: Array) -> void:
	if ids.is_empty() or _selected_id in ids: _dirty = true

func _queue_crew_options() -> void:
	_crew_options_dirty = true
	_dirty = true

func _on_conquest_changed(ids: PackedStringArray, cumulative: bool, source) -> void:
	if source != _planet or is_queued_for_deletion(): return
	if _selected_id in ids: _conquest_planet_dirty = true
	if cumulative: _conquest_cumulative_dirty = true

func _read_conquest_if_needed() -> void:
	if not _conquest_planet_dirty and not _conquest_cumulative_dirty: return
	if _selected_id.is_empty():
		_conquest_error = "PlanetLocked"
		_conquest_planet_dirty = false
		_conquest_cumulative_dirty = false
		return
	var facts: Dictionary = _planet.conquest_facts(_selected_id)
	if not facts.get("ok", false):
		_conquest_error = str(facts.get("reason", "PlanetConquestSourceUnavailable"))
		_conquest_planet_dirty = false
		_conquest_cumulative_dirty = false
		return
	var recovering := not _conquest_error.is_empty()
	_conquest_error = ""
	if recovering or _conquest_planet_dirty:
		_conquest_planet = {"conquered": facts.conquered, "shared_experience": facts.shared_experience}
	if recovering or _conquest_cumulative_dirty: _conquest_rewards = facts.rewards.duplicate(true)
	_conquest_planet_dirty = false
	_conquest_cumulative_dirty = false

func selected_planet_id() -> String:
	return _selected_id

func select_planet(id: String) -> void:
	if id == _selected_id: return
	_selected_id = id
	_selected_facility = ""
	_assignment_target = ""
	_snapshot = {}
	_facts = []
	_detail_signature = {}
	_conquest_planet_dirty = true
	_conquest_cumulative_dirty = true
	_feedback.text = ""
	_last_degree = -1
	if _visual != null: _visual.clear_transients()
	for index in world_planet_picker.item_count:
		if str(world_planet_picker.get_item_metadata(index)) == id: world_planet_picker.select(index)
	# Clear and bind synchronously so an open drawer can never submit the old ID.
	_read_selected()
	_rebuild_drawer()
	_dirty = false

func _refresh_options() -> void:
	var options: Array = _planet.planet_options()
	var ids: Array = []
	for option in options: ids.append(str(option.id))
	if not _selected_id in ids:
		_selected_id = str(ids[0]) if not ids.is_empty() else ""
		_conquest_planet_dirty = true
		_conquest_cumulative_dirty = true
		_selected_facility = ""
		_assignment_target = ""
		_last_degree = -1
		_feedback.text = ""
		_visual.clear_transients()
	world_planet_picker.clear()
	for option in options:
		world_planet_picker.add_item(option.name)
		var index := world_planet_picker.item_count - 1
		world_planet_picker.set_item_metadata(index, option.id)
		if str(option.id) == _selected_id: world_planet_picker.select(index)
	world_planet_picker.disabled = options.is_empty()

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	if _feedback_seconds > 0:
		_feedback_seconds = maxf(0, _feedback_seconds - dt)
		if _feedback_seconds == 0: _feedback.text = ""
	_context = _visual_context.call() if _visual_context.is_valid() else {}
	_update_wallet()
	if _dirty or _options_dirty:
		_dirty = false
		if _options_dirty:
			_options_dirty = false
			_refresh_options()
		_read_selected()
	if _open_section == "exploration" and _conquest_open and (_conquest_planet_dirty or _conquest_cumulative_dirty):
		_read_conquest_if_needed()
		_rebuild_drawer()
	if _visual != null: _visual.advance(dt * float(_context.get("speed", 1.0)), bool(_context.get("paused", false)))
	# Pause context may change without a planet signal; it only changes text.
	_update_task()

func _update_wallet() -> void:
	var balances: Array = _context.get("balances", []).slice(0, 3)
	var signature: Array = []
	for row in balances: signature.append([str(row.get("id", "")), str(row.get("text", ""))])
	if signature == _wallet_signature: return
	_wallet_signature = signature.duplicate(true)
	for index in _wallet_rows.size():
		var widgets: Dictionary = _wallet_rows[index]
		var cell: HBoxContainer = widgets.cell
		cell.visible = index < balances.size()
		if not cell.visible: continue
		var resource_id := str(balances[index].get("id", ""))
		var icon: TextureRect = widgets.icon
		icon.texture = ResourceVisuals.icon(resource_id)
		icon.modulate = ResourceVisuals.color(resource_id)
		icon.visible = icon.texture != null
		var amount: Label = widgets.amount
		amount.text = str(balances[index].get("text", ""))
		amount.tooltip_text = amount.text

func _read_selected() -> void:
	_snapshot = _planet.visual_snapshot(_selected_id)
	_crew_views = _crew.step_assignments() if _crew != null else {"explorers": {}, "builders": {}}
	_facts = _planet.facility_facts(_selected_id, _crew_views.explorers, _crew_views.builders)
	if _snapshot.is_empty():
		_visual.hide()
		_facts = []
	else:
		_visual.show()
		_visual.configure(_selected_id, _snapshot.row)
		_visual.set_exploration(_snapshot.running, _snapshot.exploration, _snapshot.elapsed)
		if _last_degree >= 0 and int(_snapshot.exploration) > _last_degree: _visual.complete()
		_last_degree = int(_snapshot.exploration)
	var ready := 0
	for fact in _facts:
		if fact.state == "ready": ready += 1
	_facility_button.text = "设施 · %d待领" % ready if ready else "设施"
	var personnel: int = _crew_views.explorers.get(_selected_id, []).size()
	for fact in _facts: personnel += int(fact.builders_present)
	_crew_button.text = "人员 %d" % personnel
	var local_people := {"explorers": _crew_views.explorers.get(_selected_id, []), "builders": {}}
	for fact in _facts: local_people.builders[fact.id] = _crew_views.builders.get(_selected_id + ":" + str(fact.id), [])
	# Work ticks change one caption and one bar. They do not change the drawer's
	# controls, so keep their live values out of the structural signature.
	var signature_facts: Array = _facts.duplicate(true)
	for item in signature_facts:
		if not item is Dictionary: continue
		item.erase("source_factor")
		if item.get("state") == "building":
			item.erase("work")
			item.erase("work_fraction")
	var signature := {"id": _selected_id, "facts": signature_facts, "crew": local_people}
	if signature != _detail_signature or (_crew_options_dirty and _open_section == "crew"):
		_detail_signature = signature.duplicate(true)
		_rebuild_drawer()
	_update_facility_detail_values()
	_crew_options_dirty = false
	_update_task()

func _update_task() -> void:
	var running: bool = bool(_snapshot.get("running", false))
	var paused: bool = bool(_context.get("paused", false))
	var duration: float = float(_snapshot.get("duration", 0))
	var elapsed: float = float(_snapshot.get("elapsed", 0))
	var fraction: float = elapsed / duration if running and duration > 0 else 0.0
	_progress.value = fraction * 100.0
	_task_button.text = ("已暂停" if paused else "探索中") + " · 本次 %.0f%%" % (fraction * 100) if running else "探索 · 未派遣"
	_task_line.text = "探索度 %d · 本次 %.1f / %.1f 秒\n自动探索：%s" % [int(_snapshot.get("exploration", 0)), elapsed, duration, "开启" if _snapshot.get("automatic", false) else "关闭"] if running else "探索度 %d · 探索未运行" % int(_snapshot.get("exploration", 0))
	var show_stop := running and bool(_snapshot.get("automatic", false))
	var actions_changed := _stop_button.visible != show_stop or _cancel_button.visible != running
	_stop_button.visible = show_stop
	_cancel_button.visible = running
	var auto_changed := false
	if is_instance_valid(_auto_button):
		var show_auto := not bool(_snapshot.get("automatic", false))
		auto_changed = _auto_button.visible != show_auto
		_auto_button.visible = show_auto
		_auto_button.disabled = _snapshot.is_empty()
	if actions_changed or auto_changed: _layout()
	if _open_section == "exploration" and is_instance_valid(_detail_text):
		_detail_text.text = "%s\n探索者 %d / 1" % [_snapshot.get("row", {}).get("name", "无星球"), _crew_views.explorers.get(_selected_id, []).size()]

func _toggle_section(section: String) -> void:
	_open_section = "" if _open_section == section else section
	_rebuild_drawer()
	_layout()

func _clear_body() -> void:
	_work_text = null
	_work_bar = null
	_unlock_text = null
	_factor_text = null
	for child in _drawer_body.get_children():
		_drawer_body.remove_child(child)
		child.queue_free()

func _rebuild_drawer() -> void:
	if not is_inside_tree(): return
	_task_button.set_pressed_no_signal(_open_section == "exploration")
	_crew_button.set_pressed_no_signal(_open_section == "crew")
	_facility_button.set_pressed_no_signal(_open_section == "facilities")
	_drawer.visible = not _open_section.is_empty()
	_clear_body()
	if _open_section.is_empty(): return
	_drawer_title.text = str({"facilities": "设施管理", "crew": "人员派遣", "exploration": "探索任务"}[_open_section])
	if _open_section != "exploration": _caption(_drawer_body, str(_snapshot.get("row", {}).get("name", "无已开放星球")))
	if _open_section == "facilities": _build_facility_detail()
	elif _open_section == "crew": _build_crew_detail()
	else:
		_detail_text = _caption(_drawer_body, "")
		_auto_button = _action(_drawer_body, "开启自动探索", func(): return _planet.set_automatic(_selected_id, true))
		var conquest_button := Button.new()
		conquest_button.text = "征服奖励 · 收起" if _conquest_open else "征服奖励 · 展开"
		_drawer_body.add_child(conquest_button)
		_paint_secondary(conquest_button)
		conquest_button.pressed.connect(func():
			_conquest_open = not _conquest_open
			_rebuild_drawer())
		if _conquest_open: _build_conquest_detail()
		_update_task()
	_layout()

func _build_conquest_detail() -> void:
	_read_conquest_if_needed()
	if not _conquest_error.is_empty():
		_caption(_drawer_body, "征服详情暂不可用：" + describe_error(_conquest_error))
		return
	_caption(_drawer_body, "本星球：%s" % ["已征服" if _conquest_planet.get("conquered", false) else "未征服"])
	_caption(_drawer_body, "探索经验共享：%s" % ["开启" if _conquest_planet.get("shared_experience", false) else "未开启"])
	var rewards_heading := _caption(_drawer_body, "已征服星球累计奖励")
	rewards_heading.custom_minimum_size.y = 31
	rewards_heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rewards_heading.add_theme_font_size_override("font_size", 19)
	rewards_heading.add_theme_color_override("font_color", Color("173b4b"))
	var names := {"level_bonus:equipment": "装备有效等级加成", "level_bonus:enhancement": "强化额外等级", "free_charge:all": "免费充能比例", "luck:all": "幸运加成"}
	for row in _conquest_rewards:
		var key: String = str(row.kind) + ":" + str(row.target)
		var reward_line := HBoxContainer.new()
		reward_line.add_theme_constant_override("separation", 4)
		_drawer_body.add_child(reward_line)
		var reward_name := Label.new()
		reward_name.text = str(names.get(key, key))
		reward_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_name.add_theme_font_size_override("font_size", 16)
		reward_name.add_theme_color_override("font_color", Color("46606a"))
		reward_line.add_child(reward_name)
		var reward_value := Label.new()
		reward_value.text = str(row.display_text)
		reward_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reward_value.add_theme_font_size_override("font_size", 16)
		reward_value.add_theme_color_override("font_color", Color("173b4b"))
		reward_line.add_child(reward_value)

func _build_facility_detail() -> void:
	world_building_picker = OptionButton.new()
	_track_picker(world_building_picker)
	_drawer_body.add_child(world_building_picker)
	_paint_secondary(world_building_picker)
	var found := false
	for fact in _facts:
		if str(fact.id) == _selected_facility: found = true
	if not found:
		_selected_facility = str(_facts[0].id) if not _facts.is_empty() else ""
		for fact in _facts:
			if fact.state == "building": _selected_facility = str(fact.id)
		for fact in _facts:
			if fact.state == "ready":
				_selected_facility = str(fact.id)
				break
	for fact in _facts:
		world_building_picker.add_item("%s · %s" % [fact.name, STATES[fact.state]])
		var index := world_building_picker.item_count - 1
		world_building_picker.set_item_metadata(index, fact.id)
		if str(fact.id) == _selected_facility: world_building_picker.select(index)
	world_building_picker.item_selected.connect(func(index):
		_selected_facility = str(world_building_picker.get_item_metadata(index))
		_rebuild_drawer())
	for fact in _facts:
		if str(fact.id) != _selected_facility: continue
		if fact.state == "building":
			_work_text = _caption(_drawer_body, "施工 %d / %d 次探索" % [fact.work, fact.required_work])
			_work_bar = ProgressBar.new()
			_work_bar.custom_minimum_size.y = 10
			_work_bar.show_percentage = false
			_work_bar.value = float(fact.work_fraction) * 100
			_drawer_body.add_child(_work_bar)
			_caption(_drawer_body, "额外施工人员 %d / %d" % [fact.builders_present, fact.extra_crew_required])
			if not str(fact.pause_reason).is_empty(): _caption(_drawer_body, PAUSES[fact.pause_reason])
		elif fact.state == "locked": _unlock_text = _caption(_drawer_body, "探索度 %d 开放 · 当前 %d" % [fact.unlock_exploration, _snapshot.exploration])
		var effect: String = {"refinery": "铁、铀原生掉落加成", "equipment": "普通装备属性加成", "auto_explore": "允许开启自动探索", "shipyard": "允许首次征服 / 重铸"}.get(fact.type, "")
		_caption(_drawer_body, ("领取后生效：\n" if fact.state != "built" else "已生效：\n") + effect)
		if fact.state == "built" and fact.type in ["refinery", "equipment"]:
			_factor_text = _caption(_drawer_body, "")
			_factor_text.custom_minimum_size.y = 42
			_factor_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_factor_text.add_theme_font_size_override("font_size", 19)
			_factor_text.add_theme_color_override("font_color", Color("f0d49a"))
			var factor_plate := _skin(Color("193a47"), Color("a88c59"), 1, 3)
			factor_plate.border_width_left = 2
			factor_plate.content_margin_left = 10
			_factor_text.add_theme_stylebox_override("normal", factor_plate)
			_update_factor_text(fact.source_factor)
		if fact.type == "shipyard" and fact.state == "built":
			_reforge_button = Button.new()
			_reforge_button.text = "前往征服 / 重铸预览"
			_reforge_button.pressed.connect(func(): reforge_requested.emit(_selected_id))
			_drawer_body.add_child(_reforge_button)
			_paint_secondary(_reforge_button)
		if fact.state == "ready":
			_claim_button = _action(_drawer_body, "领取", func(): return _planet.claim_build(_selected_id, _selected_facility, _publish))
			_claim_button.disabled = not fact.claim_allowed
			if not fact.claim_allowed: _caption(_drawer_body, describe_error(str(fact.claim_reason)))
		break

func _update_facility_detail_values() -> void:
	if _open_section != "facilities": return
	for fact in _facts:
		if str(fact.id) != _selected_facility: continue
		if fact.state == "building" and is_instance_valid(_work_bar) and is_instance_valid(_work_text):
			_work_text.text = "施工 %d / %d 次探索" % [fact.work, fact.required_work]
			_work_bar.value = float(fact.work_fraction) * 100.0
		elif fact.state == "locked" and is_instance_valid(_unlock_text):
			_unlock_text.text = "探索度 %d 开放 · 当前 %d" % [fact.unlock_exploration, _snapshot.exploration]
		if is_instance_valid(_factor_text): _update_factor_text(fact.source_factor)
		break

func _update_factor_text(factor) -> void:
	if not is_instance_valid(_factor_text): return
	_factor_text.visible = factor != null
	if factor != null:
		_factor_text.text = "设施因子  ×" + preload("res://src/ui/player_text.gd").number(str(factor))

func _build_crew_detail() -> void:
	if _crew == null or not _coordinate.is_valid():
		_caption(_drawer_body, "人员派遣尚未连接")
		return
	_member_picker = OptionButton.new()
	_track_picker(_member_picker)
	_drawer_body.add_child(_member_picker)
	_paint_secondary(_member_picker)
	for member in _crew.member_options():
		_member_picker.add_item(member.name)
		_member_picker.set_item_metadata(_member_picker.item_count - 1, member.id)
		if str(member.id) == _member_id: _member_picker.select(_member_picker.item_count - 1)
	_member_picker.item_selected.connect(func(index):
		_member_id = str(_member_picker.get_item_metadata(index))
		_rebuild_drawer())
	var selected_member: String = str(_picker_value(_member_picker))
	var member_facts: Array = _crew.member_facts([selected_member])
	var assigned_here := false
	if not member_facts.is_empty():
		var fact: Dictionary = member_facts[0]
		var occupation := str({"": "空闲", "planet_explore": "星球探索", "planet_build": "设施施工", "system_job": "岗位", "galaxy": "星系建设", "hyperspace": "超空间任务"}.get(fact.kind, fact.kind))
		_caption(_drawer_body, "当前：%s%s" % [occupation, " · " + str(fact.target) if not str(fact.target).is_empty() else ""])
		for option in _planet.assignment_options([_selected_id]):
			if fact.kind == option.kind and fact.target == option.target: assigned_here = true
	_assignment_picker = OptionButton.new()
	_track_picker(_assignment_picker)
	_drawer_body.add_child(_assignment_picker)
	_paint_secondary(_assignment_picker)
	for option in _planet.assignment_options([_selected_id]):
		_assignment_picker.add_item(option.label)
		_assignment_picker.set_item_metadata(_assignment_picker.item_count - 1, option)
		if str(option.target) == _assignment_target: _assignment_picker.select(_assignment_picker.item_count - 1)
	_assignment_picker.item_selected.connect(func(index): _assignment_target = str(_assignment_picker.get_item_metadata(index).target))
	_action(_drawer_body, "派遣", func():
		var option: Dictionary = _picker_value(_assignment_picker, {})
		if option.is_empty(): return {"ok": false, "reason": "PlanetBuildingUnavailable"}
		return _coordinate.call(str(_picker_value(_member_picker)), str(option.kind), str(option.target)))
	var release := _action(_drawer_body, "撤回本星球人员", func(): return _coordinate.call(str(_picker_value(_member_picker)), "", ""))
	_paint_button(release, Color("173747"), Color("285365"), Color("315f6c"), Color("4b7580"), Color("e8ebdf"))
	release.disabled = not assigned_here
	if not assigned_here: release.tooltip_text = "所选船员当前未在本星球任职"

func _picker_value(picker: OptionButton, fallback = ""):
	return fallback if picker.selected < 0 else picker.get_item_metadata(picker.selected)

func _caption(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 226
	parent.add_child(label)
	return label

func _action(parent: Control, text: String, action: Callable) -> Button:
	var perform := func() -> Dictionary:
		# Read IDs at activation; preserve the host's existing command admission.
		var result: Dictionary = action.call()
		_feedback.text = str(result.get("message", "完成")) if result.get("ok", false) else describe_error(str(result.get("reason", result.get("error", "操作失败"))))
		_feedback_seconds = 4.0
		refresh()
		return result
	var button: Button
	if _host.is_valid():
		button = _host.call(parent, text, perform)
	else:
		button = Button.new()
		button.text = text
		parent.add_child(button)
		button.pressed.connect(perform)
	_paint_button(button, Color("c9a364"), Color("e4ba76"), Color("f1d398"), Color("f2d293"), Color("183849"))
	return button

static func describe_error(reason: String) -> String:
	return str(ERRORS.get(reason, preload("res://src/ui/player_text.gd").error(reason)))
