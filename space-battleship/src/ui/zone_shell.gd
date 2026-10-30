extends Control
## Public presentation around the existing 808px workspace and unchanged battle projection.
signal route_requested(id: String)
const BridgeTheme = preload("res://src/ui/bridge_theme.gd")
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const TOP_RAIL = preload("res://assets/ui/public_shell/command-rail.svg")
const STATUS_IDLE = preload("res://assets/ui/public_shell/status-idle.svg")
const STATUS_ALERT = preload("res://assets/ui/public_shell/status-alert.svg")
const RESOURCE_MARK = preload("res://assets/ui/public_shell/resource-mark.svg")
const ROUTE_ICONS := [
	preload("res://assets/ui/public_shell/nav-equipment.svg"),
	preload("res://assets/ui/public_shell/nav-ship.svg"),
	preload("res://assets/ui/public_shell/nav-reactor.svg"),
	preload("res://assets/ui/public_shell/nav-planet.svg"),
	preload("res://assets/ui/public_shell/nav-growth.svg"),
	preload("res://assets/ui/public_shell/nav-universe.svg"),
	preload("res://assets/ui/public_shell/nav-hyperspace.svg"),
	preload("res://assets/ui/public_shell/nav-archive.svg"),
	preload("res://assets/ui/public_shell/nav-settings.svg")]

const ROUTES := [
	["equipment", "装备", "装备"], ["ship", "舰船", "舰船与航程"],
	["reactor", "供能", "反应堆"], ["planet", "星球", "星球"],
	["growth", "成长", "成长"], ["universe", "星图", "星图"],
	["hyperspace", "超空", "超空间"], ["archive", "档案", "档案"],
	["settings", "设置", "设置"]]
const TEXT := Color("f0f2e9")
const MUTED := Color("b7cec9")
const DARK := Color("0d2533")
const EDGE := Color("6e9697")
var _economy
var _dirty: bool = true
var _context: Label
var _balances: Array = []
var _route_buttons: Dictionary = {}
var _route_captions: Dictionary = {}
var _route_marks: Dictionary = {}
var _route_available: Dictionary = {}
var _navigation_blocked: bool = false
var _status: Button
var _status_message: String = ""
var _details: PopupPanel
var _detail_text: Label
var _resource_rows: VBoxContainer
var _resource_row_labels: Dictionary = {}
var _active_route: String = ""

func _init(economy) -> void:
	_economy = economy
	_economy.display_changed.connect(func(): _dirty = true)
	size = Vector2(1440, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {2003265652: 450.0}
	theme = BridgeTheme.create()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_stylebox("panel", "PopupPanel", BridgeTheme.public_panel())
	var context_back := NinePatchRect.new()
	context_back.texture = preload("res://assets/ui/public_shell/title-plaque.svg")
	context_back.set_patch_margin(SIDE_LEFT, 12)
	context_back.set_patch_margin(SIDE_RIGHT, 12)
	context_back.set_patch_margin(SIDE_TOP, 12)
	context_back.set_patch_margin(SIDE_BOTTOM, 12)
	context_back.position = Vector2(18, 12)
	context_back.size = Vector2(148, 41)
	context_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(context_back)
	_context = _label("装备", Rect2(28, 12, 128, 41), 20, TEXT)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for index in 3:
		var spec: Array = [[190, 118], [326, 116], [460, 174]][index]
		var mark := TextureRect.new()
		var resource_id: String = ["1", "2", "chrono"][index]
		mark.texture = ResourceVisuals.icon(resource_id)
		mark.modulate = ResourceVisuals.icon_modulate(resource_id)
		mark.position = Vector2(spec[0] + 10, 24)
		mark.size = Vector2(17, 17)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mark)
		var cell := _label("", Rect2(spec[0] + 34, 12, spec[1] - 42, 41), 16, TEXT)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_balances.append(cell)
	_status = _button("", Rect2(650, 16, 28, 32), false)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_status.add_theme_stylebox_override(state, BridgeTheme.top_button(state))
	_status.icon = STATUS_IDLE
	_status.tooltip_text = "保存与会话状态"
	_status.pressed.connect(_show_status)
	var resources := _button("资源", Rect2(684, 12, 92, 41), false)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		resources.add_theme_stylebox_override(state, BridgeTheme.top_button(state))
	resources.icon = RESOURCE_MARK
	resources.pressed.connect(_show_balances)
	for index in ROUTES.size():
		var spec: Array = ROUTES[index]
		var button := _button("", Rect2(813, 93 + index * 90, 37, 70), true)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, BridgeTheme.route_button(state))
		var mark := TextureRect.new()
		mark.texture = ROUTE_ICONS[index]
		mark.position = Vector2(9, 10)
		mark.size = Vector2(19, 19)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mark)
		var caption := Label.new()
		caption.text = str(spec[1])
		caption.position = Vector2(3, 37)
		caption.size = Vector2(31, 22)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		button.pressed.connect(func(): route_requested.emit(str(spec[0])))
		_route_buttons[str(spec[0])] = button
		_route_captions[str(spec[0])] = caption
		_route_marks[str(spec[0])] = mark
	_details = PopupPanel.new()
	_details.theme = theme
	add_child(_details)
	var content := VBoxContainer.new()
	content.custom_minimum_size.y = 130
	_details.add_child(content)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size.x = 270
	content.add_child(_detail_text)
	_resource_rows = VBoxContainer.new()
	_resource_rows.hide()
	content.add_child(_resource_rows)
	for id in ["1", "2", "chrono", "jewel", "degenerate_matter"]:
		var row := HBoxContainer.new()
		var mark := TextureRect.new()
		mark.texture = ResourceVisuals.icon(id)
		mark.modulate = ResourceVisuals.icon_modulate(id)
		mark.custom_minimum_size = Vector2(20, 20)
		row.add_child(mark)
		var value := Label.new()
		value.custom_minimum_size.x = 235
		row.add_child(value)
		_resource_rows.add_child(row)
		_resource_row_labels[id] = value
		row.hide()
	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(108, 38)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		close.add_theme_stylebox_override(state, BridgeTheme.public_button(state, 8))
	content.add_child(close)
	close.pressed.connect(_details.hide)
	set_active_route("equipment")

func _draw() -> void:
	# No decorative battle extension: the right band remains available to its owner.
	draw_rect(Rect2(1392.125, 0, 47.875, 900), Color("112c43"))
	draw_rect(Rect2(1392, 0, 1, 900), EDGE)
	draw_rect(Rect2(808, 0, 47.875, 900), Color("102b3a"))
	draw_rect(Rect2(808, 0, 2, 900), EDGE)
	draw_rect(Rect2(854, 0, 2, 900), Color("63848d"))
	# The approved hangar art starts at y=85; the rail occupies only its blank top margin.
	draw_texture_rect(TOP_RAIL, Rect2(0, 0, 808, 85 if _active_route == "equipment" else 65), false)
	for x in [180, 316, 451, 640]:
		draw_rect(Rect2(x, 18, 1, 28), Color("6e9697", 0.42))

func _label(caption: String, rect: Rect2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(caption: String, rect: Rect2, selectable: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size
	button.toggle_mode = selectable
	button.add_theme_font_size_override("font_size", 14 if selectable else 15)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, BridgeTheme.public_button(state, 1 if selectable else 4))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("132f3d"))
	button.add_theme_color_override("font_hover_pressed_color", Color("132f3d"))
	button.add_theme_color_override("font_disabled_color", Color("869b9b"))
	add_child(button)
	return button

func _process(_delta: float) -> void:
	if not _dirty: return
	_dirty = false
	var rows: Array = _economy.balance_rows()
	var by_id := {}
	for row in rows: by_id[str(row.id)] = str(row.text)
	var ids := ["1", "2", "chrono"]
	var names := ["铁", "铀", "时空微粒"]
	for index in _balances.size():
		var label: Label = _balances[index]
		var next_text: String = str(by_id.get(ids[index], names[index] + "：0"))
		if label.text != next_text:
			label.text = next_text
			label.tooltip_text = next_text
	if _details.visible and _resource_rows.visible: _update_resource_rows(rows)

func set_active_route(id: String) -> void:
	if _active_route == id: return
	_active_route = id
	for key in _route_buttons:
		var button: Button = _route_buttons[key]
		var selected: bool = key == id
		button.set_pressed_no_signal(selected)
		for color_state in ["font_color", "font_hover_color"]:
			button.add_theme_color_override(color_state, Color("173e4c") if selected else TEXT)
		for color_state in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(color_state, Color("173e4c"))
		button.add_theme_color_override("font_disabled_color", Color("173e4c") if selected else Color("869b9b"))
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, BridgeTheme.route_button("selected" if selected else state))
		_route_captions[key].add_theme_color_override("font_color", DARK if selected else MUTED if button.disabled else TEXT)
		_route_marks[key].modulate = DARK if selected else Color("839d9d") if button.disabled else TEXT
	for spec in ROUTES:
		if str(spec[0]) == id:
			_context.text = str(spec[2])
			break
	queue_redraw()

func set_status(message: String, warning: bool = false) -> void:
	_status_message = message
	_status.icon = STATUS_ALERT if warning else STATUS_IDLE
	_status.tooltip_text = message if not message.is_empty() else "保存与会话状态"

func set_navigation_blocked(blocked: bool) -> void:
	if _navigation_blocked == blocked: return
	_navigation_blocked = blocked
	for id in _route_buttons:
		_route_buttons[id].disabled = blocked or not bool(_route_available.get(id, true))
		_refresh_route_ink(id)

func set_route_available(id: String, available: bool) -> void:
	if _route_available.get(id, true) == available: return
	_route_available[id] = available
	if _route_buttons.has(id):
		_route_buttons[id].disabled = _navigation_blocked or not available
		_refresh_route_ink(id)

func _refresh_route_ink(id: String) -> void:
	var selected: bool = id == _active_route
	var disabled: bool = _route_buttons[id].disabled
	_route_captions[id].add_theme_color_override("font_color", DARK if selected else MUTED if disabled else TEXT)
	_route_marks[id].modulate = DARK if selected else Color("839d9d") if disabled else TEXT

func is_route_available(id: String) -> bool:
	return bool(_route_available.get(id, true))

func has_exclusive_ui() -> bool:
	return _details.visible

func close_details() -> void:
	_details.hide()

func _show_status() -> void:
	_resource_rows.hide()
	_detail_text.show()
	_detail_text.text = _status_message if not _status_message.is_empty() else "会话运行中。保存和恢复操作在设置中。"
	_details.popup(Rect2i(330, 66, 470, 190))

func _show_balances() -> void:
	_detail_text.text = "资源余额"
	_detail_text.show()
	_resource_rows.show()
	_update_resource_rows(_economy.balance_rows())
	_details.popup(Rect2i(450, 66, 330, 190))

func _update_resource_rows(rows: Array) -> void:
	var shown := {"1": "铁：0", "2": "铀：0", "chrono": "时空微粒：0", "jewel": "强化碎片：0"}
	for row in rows:
		var id: String = str(row.id)
		if _resource_row_labels.has(id): shown[id] = str(row.text)
	for id in _resource_row_labels:
		var value: Label = _resource_row_labels[id]
		var next_text: String = str(shown.get(id, ""))
		if value.text != next_text: value.text = next_text
		var row_visible: bool = shown.has(id)
		if value.get_parent().visible != row_visible: value.get_parent().visible = row_visible
