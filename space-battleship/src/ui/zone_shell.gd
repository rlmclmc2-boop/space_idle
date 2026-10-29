extends Control
## Public presentation around the existing 808px workspace and unchanged battle projection.
signal route_requested(id: String)

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
	theme = preload("res://src/ui/bridge_theme.gd").create()
	theme.default_font = font
	theme.default_font_size = 15
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("102b39", 0.98)
	popup_style.border_color = Color("8baaa3")
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(5)
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 13
	popup_style.content_margin_bottom = 13
	theme.set_stylebox("panel", "PopupPanel", popup_style)
	_context = _label("装备", Rect2(18, 12, 118, 41), 18, TEXT)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for spec in [[164, 138], [312, 138], [460, 174]]:
		var cell := _label("", Rect2(spec[0] + 10, 12, spec[1] - 20, 41), 14, TEXT)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_balances.append(cell)
	_status = _button("·", Rect2(650, 16, 28, 32), false)
	_status.tooltip_text = "保存与会话状态"
	_status.pressed.connect(_show_status)
	var resources := _button("资源", Rect2(690, 12, 78, 41), false)
	resources.pressed.connect(_show_balances)
	for index in ROUTES.size():
		var spec: Array = ROUTES[index]
		var button := _button(str(spec[1]), Rect2(813, 105 + index * 105, 37, 54), true)
		button.tooltip_text = str(spec[2])
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
	draw_rect(Rect2(0, 0, 808, 65), Color("122f3e"))
	# The approved hangar art starts at y=85; this shallow public lip covers its blank top margin.
	draw_rect(Rect2(0, 65, 808, 20), Color("183746"))
	draw_rect(Rect2(0, 84, 808, 1), Color("819d9b", 0.45))
	draw_rect(Rect2(0, 0, 808, 1), Color("779a9b", 0.55))
	draw_rect(Rect2(0, 64, 808, 1), Color("89aaa4", 0.75))
	draw_rect(Rect2(18, 12, 118, 41), Color("294e5b"))
	draw_rect(Rect2(18, 12, 118, 41), EDGE, false, 1.0)
	for rect in [Rect2(164, 12, 138, 41), Rect2(312, 12, 138, 41), Rect2(460, 12, 174, 41)]:
		draw_rect(rect, DARK)
		draw_rect(rect, Color("426a76"), false, 1.0)

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
	button.add_theme_font_size_override("font_size", 12 if selectable else 14)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("254a5b") if state == "hover" else Color("0f3040") if state == "pressed" else Color("183848")
		style.border_color = Color("b9d8cb") if state == "focus" else EDGE
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(5)
		style.shadow_color = Color("06141d", 0.45)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("132f3d"))
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
		button.set_pressed_no_signal(key == id)
		button.add_theme_color_override("font_color", Color("173e4c") if key == id else TEXT)
		for state in ["normal", "pressed"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.bg_color = Color("e9e1cb") if key == id else Color("0f3040") if state == "pressed" else Color("183848")
			style.border_color = Color("e1c68d") if key == id else EDGE
			button.add_theme_stylebox_override(state, style)
	for spec in ROUTES:
		if str(spec[0]) == id:
			_context.text = str(spec[2]) if id != "ship" else "舰船"
			break

func set_status(message: String, warning: bool = false) -> void:
	_status_message = message
	_status.text = "!" if warning else "·"
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
