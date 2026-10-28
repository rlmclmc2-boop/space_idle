extends Control
## Shared presentation only: routes, safe region, wallet text and input ownership.
## Every route keeps its existing view instance and domain commands.
signal route_requested(id: String)
signal collapse_requested
const PRIMARY := [["equipment", "装备", 80], ["reactor", "反应炉", 96],
	["research", "科研", 80], ["enhancement", "强化", 80], ["crew", "船员", 80],
	["planet", "星球", 80], ["galaxy", "星系", 80], ["hyperspace", "超空间", 96]]
const SECONDARY := [["ship", "舰船"], ["campaign", "航程"], ["attributes", "属性"],
	["archive", "档案"], ["notifications", "通知"], ["settings", "设置"], ["reforge", "重铸"]]
var routes: Dictionary = {}
var _titles: Dictionary = {}
var _collapsed_area: Control
var _collapsed_background: TextureRect
var _collapsed_label: Label
var _restore_button: Button
var contexts: Dictionary = {}
var active: String = "equipment"
var collapsed: bool = false
var _buttons: Dictionary = {}
var _more_buttons: Dictionary = {}
var _wallet: Dictionary = {}
var _economy
var _wallet_dirty: bool = true
var _more: PopupPanel
var _details: PopupPanel
var _detail_text: Label
var _status: Button
var _context_root: Control
var _collapse: Button
var _availability: Dictionary = {}
var _navigation_blocked: bool = false
var _feedback: String = ""
var _save_message: String = ""

func _init(economy) -> void:
	_economy = economy
	_economy.budget_changed.connect(func(_ids): _wallet_dirty = true)
	size = Vector2(1440, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://src/ui/bridge_theme.gd").create()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {2003265652: 450.0}
	theme.default_font = font
	var bar := ColorRect.new()
	bar.size = Vector2(808, 65)
	bar.color = Color("102c3b")
	add_child(bar)
	_context_root = Control.new()
	_context_root.position = Vector2(12, 3)
	_context_root.size = Vector2(96, 26)
	_context_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_context_root)
	for spec in [["1", 116, 160], ["2", 284, 160], ["chrono", 452, 208]]:
		var label := Label.new()
		label.text = {"1": "铁：0", "2": "铀：0", "chrono": "时空微粒：0"}[spec[0]]
		label.position = Vector2(spec[1], 3)
		label.size = Vector2(spec[2], 26)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(label)
		_wallet[spec[0]] = label
	_status = _button("", Rect2(668, 3, 32, 26))
	_status.tooltip_text = "查看保存与会话状态"
	_status.pressed.connect(_show_status)
	var detail := _button("资源", Rect2(708, 3, 88, 26))
	detail.pressed.connect(_show_balances)
	var x := 12.0
	for spec in PRIMARY:
		var id: String = spec[0]
		var button := _button(spec[1], Rect2(x, 34, spec[2], 30))
		button.toggle_mode = true
		button.pressed.connect(func(): route_requested.emit(id))
		_buttons[id] = button
		x += float(spec[2]) + 4
	var more := _button("更多", Rect2(x, 34, 80, 30))
	more.toggle_mode = true
	_buttons.more = more
	more.pressed.connect(func():
		_more.position = Vector2i(576, 67)
		_more.popup())
	_more = PopupPanel.new()
	add_child(_more)
	_more.visibility_changed.connect(func(): _buttons.more.set_pressed_no_signal(_more.visible or not _buttons.has(active)))
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 218
	_more.add_child(menu)
	for spec in SECONDARY:
		var id: String = spec[0]
		var button := Button.new()
		button.text = spec[1]
		button.custom_minimum_size.y = 34
		menu.add_child(button)
		button.pressed.connect(func():
			_more.hide()
			route_requested.emit(id))
		_more_buttons[id] = button
	_collapse = Button.new()
	_collapse.text = "收起模块"
	_collapse.custom_minimum_size.y = 34
	menu.add_child(_collapse)
	_collapse.pressed.connect(func():
		_more.hide()
		collapse_requested.emit())
	_details = PopupPanel.new()
	add_child(_details)
	var stack := VBoxContainer.new()
	_details.add_child(stack)
	_detail_text = Label.new()
	_detail_text.custom_minimum_size = Vector2(500, 130)
	stack.add_child(_detail_text)
	var close := Button.new()
	close.text = "关闭"
	stack.add_child(close)
	close.pressed.connect(_details.hide)
	_collapsed_area = Control.new()
	_collapsed_area.position = Vector2(0, 65)
	_collapsed_area.size = Vector2(808, 835)
	_collapsed_area.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_collapsed_area)
	_collapsed_background = TextureRect.new()
	_collapsed_background.size = _collapsed_area.size
	_collapsed_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapsed_area.add_child(_collapsed_background)
	var dim := ColorRect.new()
	dim.size = _collapsed_area.size
	dim.color = Color(0.025, 0.07, 0.10, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapsed_area.add_child(dim)
	var card := PanelContainer.new()
	card.position = Vector2(220, 315)
	card.size = Vector2(368, 180)
	_collapsed_area.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)
	_collapsed_label = Label.new()
	_collapsed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapsed_label.add_theme_font_size_override("font_size", 22)
	content.add_child(_collapsed_label)
	var caption := Label.new()
	caption.text = "返回后查看最新状态"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(caption)
	_restore_button = Button.new()
	_restore_button.custom_minimum_size.y = 42
	_restore_button.pressed.connect(func(): collapse_requested.emit())
	content.add_child(_restore_button)
	_collapsed_area.hide()

func _button(caption: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.custom_minimum_size = rect.size
	button.size = rect.size
	# Compact bar has measured 24px text line; do not inherit 8px body margins.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("225265") if state in ["hover", "pressed"] else Color("143444")
		style.border_color = Color("79c9c6") if state == "focus" else Color("355e6b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	add_child(button)
	return button

func register_route(id: String, title: String, view: Control) -> void:
	routes[id] = view
	_titles[id] = title
	var slot := Control.new()
	slot.size = Vector2(96, 26)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_root.add_child(slot)
	contexts[id] = slot
	if view.has_method("set_shared_host"):
		view.set_shared_host(true, slot)
	else:
		var label := Label.new()
		label.text = title
		label.size = slot.size
		label.clip_text = true
		slot.add_child(label)

func show_route(id: String, is_collapsed: bool = false) -> void:
	active = id
	collapsed = is_collapsed
	for key in routes:
		routes[key].visible = key == id and not collapsed
		contexts[key].visible = key == id
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == id or (key == "more" and not _buttons.has(id)))
	_collapse.text = "恢复模块" if collapsed else "收起模块"
	_collapsed_area.visible = collapsed
	_collapsed_label.text = "%s已收起" % _titles[id]
	_restore_button.text = "恢复%s" % _titles[id]
	if not collapsed: _collapsed_background.texture = null

func set_collapsed_background(image: Image) -> void:
	_collapsed_background.texture = ImageTexture.create_from_image(image)

func set_availability(values: Dictionary) -> void:
	_availability = values
	for id in _buttons:
		_buttons[id].disabled = _navigation_blocked or not bool(values.get(id, true))
	for id in _more_buttons:
		_more_buttons[id].disabled = _navigation_blocked or not bool(values.get(id, true))

func set_navigation_blocked(blocked: bool) -> void:
	if _navigation_blocked == blocked: return
	_navigation_blocked = blocked
	set_availability(_availability)

func set_status(message: String) -> void:
	_save_message = message
	_update_status()

func show_feedback(message: String) -> void:
	_feedback = message
	_update_status()

func _update_status() -> void:
	var message := _save_message if not _save_message.is_empty() else _feedback
	_status.text = "!" if not message.is_empty() else "·"
	_status.tooltip_text = message if not message.is_empty() else "保存与会话状态"

func _show_status() -> void:
	var message := _save_message if not _save_message.is_empty() else _feedback
	_detail_text.text = message if not message.is_empty() else "会话运行中。保存、恢复和个人选项位于更多→设置。"
	_details.popup_centered()

func _process(_delta: float) -> void:
	if not _wallet_dirty: return
	_wallet_dirty = false
	var rows: Array = _economy.balance_rows()
	for row in rows:
		if str(row.id) in _wallet:
			_wallet[str(row.id)].text = str(row.text)
			_wallet[str(row.id)].tooltip_text = str(row.text)

func _show_balances() -> void:
	var lines := PackedStringArray()
	for row in _economy.balance_rows(): lines.append(str(row.text))
	_detail_text.text = "完整资源余额\n" + "\n".join(lines)
	_details.popup_centered()

func has_exclusive_ui() -> bool:
	return _more.visible or _details.visible

func prepare_release() -> void:
	_more.hide()
	_details.hide()
	hide()
