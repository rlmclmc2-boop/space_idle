extends Control
## Public presentation around the existing 808px workspace and unchanged battle projection.
signal route_requested(id: String)
const BridgeTheme = preload("res://src/ui/bridge_theme.gd")
const TOP_RAIL = preload("res://assets/ui/public_shell/command-rail.svg")
const STATUS_IDLE = preload("res://assets/ui/public_shell/status-idle.svg")
const STATUS_ALERT = preload("res://assets/ui/public_shell/status-alert.svg")
const RESOURCE_MARK = preload("res://assets/ui/public_shell/resource-mark.svg")

const ROUTES := [
	["equipment", "装备", "装备"], ["ship", "舰船", "舰船与航程"],
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
var _route_available: Dictionary = {}
var _navigation_blocked: bool = false
var _status: Button
var _status_message: String = ""
var _details: PopupPanel
var _detail_text: Label
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
	context_back.texture = preload("res://assets/ui/public_shell/button-idle.svg")
	context_back.set_patch_margin(SIDE_LEFT, 12)
	context_back.set_patch_margin(SIDE_RIGHT, 12)
	context_back.set_patch_margin(SIDE_TOP, 12)
	context_back.set_patch_margin(SIDE_BOTTOM, 12)
	context_back.position = Vector2(18, 12)
	context_back.size = Vector2(118, 41)
	context_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(context_back)
	_context = _label("装备", Rect2(18, 12, 118, 41), 20, TEXT)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for spec in [[164, 138], [312, 138], [460, 174]]:
		var cell := _label("", Rect2(spec[0] + 10, 12, spec[1] - 20, 41), 16, TEXT)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_balances.append(cell)
	_status = _button("", Rect2(650, 16, 28, 32), false)
	_status.icon = STATUS_IDLE
	_status.tooltip_text = "保存与会话状态"
	_status.pressed.connect(_show_status)
	var resources := _button("资源", Rect2(684, 12, 92, 41), false)
	resources.icon = RESOURCE_MARK
	resources.pressed.connect(_show_balances)
	for index in ROUTES.size():
		var spec: Array = ROUTES[index]
		var button := _button(str(spec[1]), Rect2(813, 105 + index * 105, 37, 54), true)
		button.pressed.connect(func(): route_requested.emit(str(spec[0])))
		_route_buttons[str(spec[0])] = button
	_details = PopupPanel.new()
	_details.theme = theme
	add_child(_details)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(430, 130)
	_details.add_child(content)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size.x = 400
	content.add_child(_detail_text)
	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size.y = 38
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
	draw_texture_rect(TOP_RAIL, Rect2(0, 0, 808, 85), false)
	for x in [154, 303, 451, 640]:
		draw_rect(Rect2(x, 17, 1, 30), Color("6e9697", 0.65))

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
		label.text = str(by_id.get(ids[index], names[index] + "：0"))
		label.tooltip_text = label.text

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
			button.add_theme_stylebox_override(state, BridgeTheme.public_button("selected" if selected else state, 1))
	for spec in ROUTES:
		if str(spec[0]) == id:
			_context.text = str(spec[2])
			break

func set_status(message: String, warning: bool = false) -> void:
	_status_message = message
	_status.icon = STATUS_ALERT if warning else STATUS_IDLE
	_status.tooltip_text = message if not message.is_empty() else "保存与会话状态"

func set_navigation_blocked(blocked: bool) -> void:
	_navigation_blocked = blocked
	for id in _route_buttons: _route_buttons[id].disabled = blocked or not bool(_route_available.get(id, true))

func set_route_available(id: String, available: bool) -> void:
	_route_available[id] = available
	if _route_buttons.has(id): _route_buttons[id].disabled = _navigation_blocked or not available

func is_route_available(id: String) -> bool:
	return bool(_route_available.get(id, true))

func has_exclusive_ui() -> bool:
	return _details.visible

func close_details() -> void:
	_details.hide()

func _show_status() -> void:
	_detail_text.text = _status_message if not _status_message.is_empty() else "会话运行中。保存和恢复操作在设置中。"
	_details.popup(Rect2i(330, 66, 470, 190))

func _show_balances() -> void:
	var lines := PackedStringArray()
	for label in _balances: lines.append(label.text)
	for row in _economy.balance_rows():
		if str(row.id) not in ["1", "2", "chrono"]: lines.append(str(row.text))
	_detail_text.text = "完整资源余额\n" + "\n".join(lines)
	_details.popup(Rect2i(330, 66, 470, 190))
