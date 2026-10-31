extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
const BridgeTheme = preload("res://src/ui/bridge_theme.gd")
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const ICON_ATLAS = preload("res://assets/ui/reactor/b01/control-icons.png")
const METER_FRAME = preload("res://assets/ui/reactor/b01/meter-frame.png")
const SLIDER_SHELL = preload("res://assets/ui/reactor/b01/slider-shell.png")
const SLIDER_CHANNEL = preload("res://assets/ui/reactor/b01/slider-channel.png")
const SLIDER_GLASS_FILL = preload("res://assets/ui/reactor/b01/slider-glass-fill.png")
const SLIDER_KNOB = preload("res://assets/ui/reactor/b01/slider-knob.png")
const NAMES := {"weapons":"武器", "defence":"盾甲", "smelting":"铁产出", "condensation":"碎片"}
const BAR_COLORS := {"weapons":Color("ffc533"), "defence":Color("33b9ff"), "smelting":Color("ff7d37"), "condensation":Color("ae53ef")}
const COMPACT_ROW_TOPS := {1:[698.0], 2:[670.0, 726.0], 3:[642.0, 698.0, 754.0]}
const ERRORS := {"ReactorPlanOverCapacity":"分配超过可调容量", "ReactorModuleSetChanged":"设备范围已变化，请重新调整", "ReactorLocked":"反应炉尚未开放", "InsufficientFunds":"铀不足"}
var _owner
var _inputs: Callable
var _pay: Callable
var _can_pay: Callable
var _publish: Callable
var _read: Callable
var _read_quote: Callable
var _clock: Callable
var _ui_font_regular: FontVariation
var _ui_font_medium: FontVariation
var _ui_font_bold: FontVariation
var _light_plate_style: StyleBox
var _left_plate: Panel
var _left_heading: Label
class AllocationBar extends Control:
	var ratios: Dictionary = {}
	func update_ratios(next: Dictionary) -> void:
		if ratios == next: return
		ratios = next.duplicate()
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), Color("041019"), true)
		var left: float = 5.0
		for id in ["weapons", "defence", "smelting", "condensation"]:
			var width: float = minf(size.x - 5.0 - left, (size.x - 10.0) * clampf(float(ratios.get(id, 0.0)), 0.0, 1.0))
			if width <= 0.0: continue
			var color: Color = BAR_COLORS[id]
			draw_rect(Rect2(left, 5, width, 21), color.darkened(0.39), true)
			draw_rect(Rect2(left, 8, width, 11), color, true)
			draw_rect(Rect2(left, 8, width, 3), color.lightened(0.48), true)
			draw_rect(Rect2(left, 19, width, 6), color.darkened(0.17), true)
			if left > 5.0: draw_rect(Rect2(left, 5, 2, 21), Color("10202d"), true)
			left += width
		draw_texture(METER_FRAME, Vector2.ZERO)
class PowerTrack extends Control:
	var fraction: float = 0.0
	var tint: Color = Color.WHITE
	func update_fraction(value: float) -> void:
		var next: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(fraction, next): return
		fraction = next
		queue_redraw()
	func _draw() -> void:
		# One 148×13 glass cavity gives filled and empty spans identical depth.
		draw_texture(SLIDER_CHANNEL, Vector2(11, 10))
		var width: float = 148.0 * fraction
		if width > 0.0:
			draw_texture_rect_region(SLIDER_GLASS_FILL, Rect2(11, 10, width, 13), Rect2(0, 0, width, 13), tint)
		draw_texture(SLIDER_SHELL, Vector2.ZERO)
var _stage: Control
var _stage_viewport: SubViewport
var _allocation_bar: AllocationBar
var _rows: Dictionary = {}
var _ids: Array = []
var _model: Dictionary = {}
var _shares: Dictionary = {}
var _quote: Dictionary = {}
var _quote_cost_ids: Array = []
var _purchase_count: int = 1
var _purchase_max: bool = false
var _quantity: Button
var _dirty: bool = true
var _quote_dirty: bool = true
var _running: bool = false
var _message_until: int = 0
var _notice_initialized: bool = false
var _notice_rejected: bool = false
var _budget: Label
var _cost: Label
var _cost_details: Label
var _cost_icon: TextureRect
var _cost_badge: Control
var _upgrade_heading: Label
var _notice: Label
var _notice_panel: Panel
var _level: Label
var _purchase: Button
var _equal: Button
var last_result: Dictionary = {}
var presentation_counts := {"model_reads":0, "quote_reads":0, "preview_reads":0, "commands":0, "visible_frames":0}

func _init(owner = null, inputs: Callable = Callable(), payment: Callable = Callable(), publish: Callable = Callable(), can_pay: Callable = Callable()) -> void:
	_owner = owner
	_inputs = inputs
	_pay = payment
	_can_pay = can_pay
	_publish = publish
	size = Vector2(808, 900)
	custom_minimum_size = size
	clip_contents = true
	# Bind the variable CJK font and actual weights locally, as in the equipment workbench.
	_ui_font_regular = FontVariation.new()
	_ui_font_regular.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	_ui_font_regular.variation_opentype = {2003265652: 400.0}
	_ui_font_medium = FontVariation.new()
	_ui_font_medium.base_font = _ui_font_regular.base_font
	_ui_font_medium.variation_opentype = {2003265652: 500.0}
	_ui_font_bold = FontVariation.new()
	_ui_font_bold.base_font = _ui_font_regular.base_font
	_ui_font_bold.variation_opentype = {2003265652: 600.0}
	theme = Theme.new()
	theme.default_font = _ui_font_regular
	theme.default_font_size = 15
	theme.set_font("font", "Button", _ui_font_bold)
	_light_plate_style = BridgeTheme.operation_plate()
	var surface := SubViewportContainer.new()
	surface.position = Vector2(0, 65)
	surface.size = Vector2(808, 835)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_stage_viewport = SubViewport.new()
	_stage_viewport.size = Vector2i(808,835)
	_stage_viewport.disable_3d = true
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	surface.add_child(_stage_viewport)
	_stage = Stage.new()
	_stage.size = Vector2(808, 835)
	_stage_viewport.add_child(_stage)
	_build()

## Reader is the owner's read-only presentation; context is host display time.
func bind_presentation(reader: Callable, context: Callable) -> void:
	_read = reader
	_clock = context
	invalidate()

func bind_purchase_quote(reader: Callable) -> void:
	_read_quote = reader
	_quote_dirty = true

func invalidate() -> void:
	_dirty = true
	_quote_dirty = true

func invalidate_presentation(changes: PackedStringArray) -> void:
	_dirty = true
	if "level" in changes or "availability" in changes:
		_quote_dirty = true

func invalidate_budget(resource_ids: PackedStringArray) -> void:
	for id in resource_ids:
		if id in _quote_cost_ids:
			_quote_dirty = true
			return

func _label(point: Vector2, width: float, font_size: int = 16, parent: Control = null) -> Label:
	var label := Label.new()
	label.position = point
	label.size = Vector2(width, 28)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _ui_font_bold if font_size >= 18 else _ui_font_regular)
	label.add_theme_color_override("font_color", Color("dcebe4"))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label

func _button(text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 18 if primary else 17)
	BridgeTheme.apply_operation_button(button, "commit" if primary else "secondary")
	button.pressed.connect(action)
	add_child(button)
	return button

func _panel(rect: Rect2, opacity: float = 0.90) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.16, 0.22, opacity)
	box.border_color = Color(0.62, 0.77, 0.75, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	return panel

func _light_panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _light_plate_style)
	add_child(panel)
	return panel

func _build() -> void:
	_left_plate = _light_panel(Rect2(73, 607, 493, 225))
	_left_plate.visible = false
	_left_heading = _label(Vector2(88, 615), 170, 17)
	_left_heading.add_theme_font_override("font", BridgeTheme.public_font())
	_left_heading.add_theme_color_override("font_color", Color("315b64"))
	_left_heading.text = "供能分配"
	_left_heading.visible = false
	_light_panel(Rect2(582, 607, 196, 225))
	_allocation_bar = AllocationBar.new()
	_allocation_bar.position = Vector2(82, 562)
	_allocation_bar.size = Vector2(545, 31)
	add_child(_allocation_bar)
	_budget = _label(Vector2(84, 560), 540, 21)
	_budget.size.y = 35
	_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_budget.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_budget.add_theme_font_override("font", BridgeTheme.public_font())
	_budget.add_theme_color_override("font_color", Color("f8f8f0"))
	_budget.add_theme_color_override("font_shadow_color", Color("102c3c"))
	_budget.add_theme_constant_override("shadow_offset_x", 1)
	_budget.add_theme_constant_override("shadow_offset_y", 2)
	for id in Stage.IDS:
		var index: int = Stage.IDS.find(id)
		var top: float = 614.0 + 55.0 * index
		var accent := ColorRect.new()
		accent.position = Vector2(73, top + 8)
		accent.size = Vector2(6, 33)
		accent.color = BAR_COLORS[id]
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(accent)
		var icon_texture := AtlasTexture.new()
		icon_texture.atlas = ICON_ATLAS
		icon_texture.region = Rect2(index * 543, 75, 543, 565)
		var icon := TextureRect.new()
		icon.position = Vector2(81, top + 6)
		icon.size = Vector2(34, 36)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var name := _label(Vector2(116, top + 6), 79, 19)
		name.size.y = 36
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.add_theme_font_override("font", _ui_font_bold)
		name.add_theme_color_override("font_color", Color("173c48"))
		name.text = NAMES[id]
		var row_face := Panel.new()
		row_face.position = Vector2(190, top + 4)
		row_face.size = Vector2(370, 41)
		row_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_rule := StyleBoxFlat.new()
		row_rule.bg_color = Color.TRANSPARENT
		row_rule.border_color = Color("91a9a6")
		row_rule.border_width_bottom = 1
		row_face.add_theme_stylebox_override("panel", row_rule)
		add_child(row_face)
		var strip := Control.new()
		strip.position = Vector2(194, top + 4)
		strip.size = Vector2(265, 41)
		strip.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(strip)
		var track_visual := PowerTrack.new()
		track_visual.position = Vector2(0, 4)
		track_visual.size = Vector2(170, 33)
		track_visual.tint = BAR_COLORS[id]
		track_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(track_visual)
		var slider := HSlider.new()
		slider.name = "Allocation_" + id
		slider.position = Vector2(0, 4)
		slider.size = Vector2(170, 33)
		slider.max_value = 10000
		slider.step = 100
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.tooltip_text = "拖动后直接分配供能"
		for state in ["slider", "grabber_area", "grabber_area_highlight"]:
			var hidden_track := StyleBoxFlat.new()
			hidden_track.bg_color = Color.TRANSPARENT
			hidden_track.content_margin_top = 9
			hidden_track.content_margin_bottom = 9
			slider.add_theme_stylebox_override(state, hidden_track)
		slider.add_theme_icon_override("grabber", SLIDER_KNOB)
		slider.add_theme_icon_override("grabber_highlight", SLIDER_KNOB)
		slider.add_theme_icon_override("grabber_disabled", SLIDER_KNOB)
		slider.value_changed.connect(_slide.bind(id))
		strip.add_child(slider)
		var ratio := _label(Vector2(178, 5), 78, 21, strip)
		ratio.add_theme_font_override("font", BridgeTheme.public_font())
		ratio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ratio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		BridgeTheme.apply_number_role(ratio, "gain")
		var effect := _label(Vector2(476, top + 9), 83, 19)
		effect.size.y = 30
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect.add_theme_font_override("font", BridgeTheme.public_font())
		BridgeTheme.apply_number_role(effect, "current")
		_rows[id] = {"effect":effect, "name":name, "slider":slider, "track":track_visual, "ratio":ratio, "control":strip, "accent":accent, "icon":icon, "row_face":row_face}
		for control in _rows[id].values(): control.visible = false
	_equal = _button("均分", Rect2(670, 565, 60, 26), func(): _command(func(): return _owner.distribute(_inputs.call(), _publish)))
	_equal.tooltip_text = "均分供能"
	_upgrade_heading = _label(Vector2(612, 630), 74, 20)
	_upgrade_heading.text = "等级"
	_upgrade_heading.add_theme_color_override("font_color", Color("173c48"))
	_level = _label(Vector2(702, 625), 65, 29)
	_level.size.y = 39
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.add_theme_font_override("font", BridgeTheme.public_font())
	BridgeTheme.apply_number_role(_level, "gain")
	_cost = _label(Vector2(612, 688), 68, 17)
	_cost.add_theme_color_override("font_color", Color("173c48"))
	_cost_badge = Control.new()
	_cost_badge.position = Vector2(612, 686)
	_cost_badge.size = Vector2(26, 27)
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.visible = false
	add_child(_cost_badge)
	_cost_icon = TextureRect.new()
	_cost_icon.position = Vector2(2, 2)
	_cost_icon.size = Vector2(22, 22)
	_cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.add_child(_cost_icon)
	_cost_details = _label(Vector2(642, 688), 118, 17)
	_cost_details.add_theme_font_size_override("font_size", 16)
	_cost_details.add_theme_font_override("font", BridgeTheme.public_font())
	BridgeTheme.apply_number_role(_cost_details, "cost")
	_quantity = _button("×1", Rect2(602, 741, 74, 51), _cycle_quantity)
	_quantity.tooltip_text = "选择升级数量：×1 / ×10 / MAX"
	_purchase = _button("升级", Rect2(685, 741, 89, 51), func(): _command(_purchase_action, true), true)
	_purchase.add_theme_font_size_override("font_size", 22)
	_notice_panel = _panel(Rect2(268, 515, 272, 33), 0.95)
	_notice = _label(Vector2(279, 518), 250, 17)
	_notice.size.y = 27
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_notice("")
	for button in [_purchase, _equal]: button.disabled = true
	_select_quantity(1, false)

func _select_quantity(count: int, maximum: bool) -> void:
	_purchase_count = count
	_purchase_max = maximum
	_quote = {}
	_quote_dirty = true
	_cost.text = "报价读取中"
	_cost_details.text = ""
	_cost_badge.visible = false
	_cost.size.x = 335
	_cost.position.y = 688
	_cost_badge.position = Vector2(612, 686)
	_cost_details.position.y = 688
	_cost_details.position.x = 642
	_purchase.text = "升级"
	_quantity.text = "MAX" if maximum else "×" + str(count)
	_update_buttons()

func _cycle_quantity() -> void:
	if _purchase_max:
		_select_quantity(1, false)
	elif _purchase_count == 1:
		_select_quantity(10, false)
	else:
		_select_quantity(1, true)

func _purchase_action() -> Dictionary:
	if _purchase_max:
		return _owner.purchase_max(_inputs.call(),_can_pay,_pay,_publish)
	return _owner.purchase(_purchase_count,false,_inputs.call(),_pay,_publish)

func _ready() -> void:
	visibility_changed.connect(func():
		set_process(is_visible_in_tree())
		_stage.reset_clock()
		_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
		if is_visible_in_tree(): invalidate())
	set_process(is_visible_in_tree())

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	presentation_counts.visible_frames += 1
	if _dirty: _refresh()
	if _quote_dirty: _refresh_quote()
	if _clock.is_valid():
		var context: Dictionary = _clock.call()
		if not context.has("running") or not context.has("paused") or not context.has("game_time"):
			_set_running(false)
			return
		_set_running(bool(context.running))
		if _stage.advance_visual_clock(float(context.game_time),bool(context.paused)):
			_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _message_until > 0 and Time.get_ticks_msec() >= _message_until:
		_message_until = 0
		_set_notice("")

func _set_notice(message: String, rejected: bool = false) -> void:
	if _notice_initialized and _notice.text == message and _notice_rejected == rejected: return
	_notice_initialized = true
	_notice_rejected = rejected
	_notice.text = message
	_notice.visible = not message.is_empty()
	_notice_panel.visible = _notice.visible
	var box: StyleBoxFlat = _notice_panel.get_theme_stylebox("panel").duplicate()
	box.bg_color = Color("4d2630",0.97) if rejected else Color("193b42",0.95)
	box.border_color = Color("f1a997") if rejected else Color("80c7ad")
	_notice_panel.add_theme_stylebox_override("panel",box)
	_notice.add_theme_color_override("font_color",Color("ffe1d7") if rejected else Color("e0f5e9"))

func _set_running(running: bool) -> void:
	if _running == running: return
	_running = running
	_update_buttons()
	for id in _rows:
		_rows[id].slider.editable = running and bool(_model.get("can_allocate", false))

func _update_buttons() -> void:
	var budget_rejection: bool = str(_quote.get("reason", "")) in ["InsufficientResources", "InsufficientFunds"]
	var purchase_disabled: bool = not _running or _model.is_empty() or (_quote.is_empty() or (not bool(_quote.get("can_purchase", false)) and not budget_rejection))
	var equal_disabled: bool = not _running or _ids.is_empty() or not bool(_model.get("can_allocate", false))
	if _purchase.disabled != purchase_disabled: _purchase.disabled = purchase_disabled
	if _equal.disabled != equal_disabled: _equal.disabled = equal_disabled

func _visual_loads(model: Dictionary, ids: Array) -> Dictionary:
	if model.is_empty(): return {}
	var loads := {"core":float(model.load)}
	for row in model.modules:
		var id: String = str(row.id)
		if id in ids: loads[id] = float(row.load)
	return loads

func _ratio_text(owner_ratio: float) -> String:
	if owner_ratio <= 0.0: return "0%"
	if owner_ratio < 0.01: return "<1%"
	return str(int(roundf(owner_ratio * 100.0))) + "%"

func _refresh() -> void:
	_dirty = false
	if not _read.is_valid():
		_unknown("供能状态暂不可用")
		return
	presentation_counts.model_reads += 1
	var model: Dictionary = _read.call()
	if not _valid_model(model):
		_unknown(str(model.get("message", "供能状态暂不可用")))
		return
	if _message_until == 0: _set_notice("")
	var previous: Dictionary = _model
	var previous_ids: Array = _ids.duplicate()
	var previous_loads: Dictionary = _visual_loads(previous, previous_ids)
	var ids: Array = []
	for row in model.get("modules",[]):
		if row.get("enabled",true): ids.append(str(row.id))
	_ids = ids
	_model = model
	if ids != previous_ids: _layout_enabled_rows(ids)
	for id in _rows:
		var now_enabled: bool = id in ids
		if now_enabled != (id in previous_ids):
			for control in _rows[id].values(): control.visible = now_enabled
		if not now_enabled: _shares.erase(id)
	_show_current_readings(previous, previous_ids)
	_update_buttons()
	if ids != previous_ids or _visual_loads(model, ids) != previous_loads: _update_stage()

func _layout_enabled_rows(ids: Array) -> void:
	var tops: Array = COMPACT_ROW_TOPS.get(ids.size(), [])
	_left_plate.visible = not ids.is_empty()
	_left_heading.visible = not ids.is_empty() and ids.size() < 4
	if not ids.is_empty():
		var first_top: float = float(tops[0]) if not tops.is_empty() else 614.0
		_left_heading.position.y = maxf(615.0, first_top - 38.0)
	for index in ids.size():
		var id: String = str(ids[index])
		var top: float = float(tops[index]) if not tops.is_empty() else 614.0 + 55.0 * float(index)
		_rows[id].accent.position.y = top + 8.0
		_rows[id].icon.position.y = top + 6.0
		_rows[id].name.position.y = top + 6.0
		_rows[id].row_face.position.y = top + 4.0
		_rows[id].control.position.y = top + 4.0
		_rows[id].effect.position.y = top + 9.0

func _show_current_readings(previous: Dictionary, previous_ids: Array) -> void:
	if _model.is_empty(): return
	var previous_rows: Dictionary = {}
	if previous.has("modules"):
		for old_row in previous.modules: previous_rows[str(old_row.id)] = old_row
	for row in _model.modules:
		var id: String = str(row.id)
		if id not in _ids: continue
		var old_row: Dictionary = previous_rows.get(id, {})
		var new_row: bool = id not in previous_ids or old_row.is_empty()
		var adopted_share: int = int(roundf(float(row.ratio)*10000.0))
		if new_row or int(_shares.get(id,-1)) != adopted_share or old_row.get("ratio") != row.ratio:
			_shares[id] = adopted_share
			_rows[id].slider.set_value_no_signal(adopted_share)
			_rows[id].track.update_fraction(float(row.ratio))
			_rows[id].ratio.text = _ratio_text(float(row.ratio))
		if new_row or previous.get("can_allocate", false) != _model.can_allocate:
			_rows[id].slider.editable = _running and bool(_model.can_allocate)
		if new_row or old_row.get("factor") != row.factor:
			_rows[id].effect.text = "×" + PlayerText.number(str(row.factor))
			_rows[id].effect.tooltip_text = "增益 ×" + str(row.factor)
		if new_row or old_row.get("ratio") != row.ratio or old_row.get("manual") != row.manual or old_row.get("free") != row.free or old_row.get("effective") != row.effective:
			_rows[id].slider.tooltip_text = "分配 " + _ratio_text(float(row.ratio)) + " · 手动 " + str(row.manual) + " / 免费 " + str(row.free) + " / 有效 " + str(row.effective)
	var level_text := str(_model.level)
	var budget_text := PlayerText.number(str(_model.allocated)) + " / " + PlayerText.number(str(_model.capacity))
	var detail := "容量 " + str(_model.capacity) + " / 已分配 " + str(_model.allocated) + " / 剩余 " + str(_model.remaining)
	if _level.text != level_text: _level.text = level_text
	if _budget.text != budget_text: _budget.text = budget_text
	if _level.tooltip_text != detail: _level.tooltip_text = detail
	if _budget.tooltip_text != detail: _budget.tooltip_text = detail
	var ratios: Dictionary = {}
	for row in _model.modules:
		if str(row.id) in _ids: ratios[str(row.id)] = float(row.ratio)
	_allocation_bar.update_ratios(ratios)

func _valid_model(model: Dictionary) -> bool:
	if model.get("ok") != true: return false
	for key in ["level","capacity","allocated","remaining","load","can_allocate","modules"]:
		if not model.has(key): return false
	if not model.level is int or not model.capacity is String or not model.allocated is String or not model.remaining is String or not model.can_allocate is bool: return false
	if not model.modules is Array or not model.load is float or not is_finite(model.load) or model.load < 0.0 or model.load > 1.0: return false
	for row in model.modules:
		if not row is Dictionary: return false
		for key in ["id","enabled","manual","free","effective","factor","has_free","ratio","load"]:
			if not row.has(key): return false
		if not row.enabled is bool or not row.has_free is bool or not row.manual is String or not row.free is String or not row.effective is String or not row.factor is String: return false
		if not row.ratio is float or not row.load is float or not is_finite(row.ratio) or not is_finite(row.load) or row.ratio < 0.0 or row.ratio > 1.0 or row.load < 0.0 or row.load > 1.0: return false
		if not NAMES.has(str(row.id)): return false
	return true

func _unknown(message: String) -> void:
	_model = {}
	_ids.clear()
	_left_plate.visible = false
	_left_heading.visible = false
	_shares.clear()
	for id in _rows:
		for control in _rows[id].values(): control.visible = false
	_cost.text = "费用 —"
	_cost_details.text = ""
	_cost_badge.visible = false
	_level.text = "等级 —"
	_budget.text = ""
	_set_notice(message,true)
	_stage.clear_snapshot()
	_allocation_bar.update_ratios({})
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_buttons()

func _refresh_quote() -> void:
	_quote_dirty = false
	_cost_details.text = ""
	_cost_badge.visible = false
	_cost.size.x = 148
	_cost.position.y = 688
	_cost_badge.position = Vector2(612, 686)
	_cost_details.position.y = 688
	_cost_details.position.x = 642
	_cost.add_theme_color_override("font_color",Color("173c48"))
	_cost.add_theme_font_override("font",_ui_font_bold)
	BridgeTheme.apply_number_role(_cost_details, "cost")
	_cost_details.add_theme_font_override("font",BridgeTheme.public_font())
	if not _read_quote.is_valid():
		_quote = {}
		_quote_cost_ids.clear()
		_cost.text = "费用 —"
		_update_buttons()
		return
	presentation_counts.quote_reads += 1
	var quote: Dictionary = _read_quote.call(_purchase_count,_purchase_max)
	if quote.get("ok") != true or not quote.has("count") or not quote.count is int or not quote.has("costs") or not quote.costs is Dictionary or not quote.has("cost_resource_ids") or not quote.cost_resource_ids is PackedStringArray or not quote.has("can_purchase") or not quote.can_purchase is bool or (not _purchase_max and int(quote.count) != _purchase_count) or (_purchase_max and int(quote.count) < 0):
		_quote = {}
		_quote_cost_ids.clear()
		_cost.text = "费用 —"
		_purchase.tooltip_text = str(quote.get("reason", "报价暂不可用"))
		_update_buttons()
		return
	_quote = quote
	_quote_cost_ids.clear()
	for resource_id in quote.cost_resource_ids:
		if not resource_id is String:
			_quote = {}
			_quote_cost_ids.clear()
			_cost.text = "费用 —"
			_update_buttons()
			return
		_quote_cost_ids.append(resource_id)
	var labels: Array = []
	var integer_costs: Dictionary = quote.get("cost_integer_texts", {}) if quote.get("cost_integer_texts", {}) is Dictionary else {}
	for id in quote.costs:
		if not quote.costs[id] is String:
			_quote = {}
			_quote_cost_ids.clear()
			_cost.text = "费用 —"
			_update_buttons()
			return
		var cost_text: String = str(integer_costs[id]) if integer_costs.get(id) is String else PlayerText.resource_number(str(quote.costs[id]))
		labels.append(cost_text + " " + PlayerText.resource(str(id)))
	var affordable: bool = bool(quote.can_purchase)
	var reason: String = str(quote.get("reason", ""))
	if labels.is_empty():
		# A zero MAX quote has no priced resource to mark; rejection appears on click.
		_cost.text = "—"
	else:
		_cost.text = ""
		_cost_details.text = " + ".join(labels)
		# The current Reactor quote contains one uranium resource; its affordability
		# is therefore the quote's affordability, with no Amount string round-trip.
		var poor: bool = not affordable and reason in ["InsufficientResources", "InsufficientFunds"]
		BridgeTheme.apply_number_role(_cost_details, "insufficient" if poor else "cost")
		if quote.costs.size() == 1:
			var resource_id: String = str(quote.costs.keys()[0])
			_cost_icon.texture = ResourceVisuals.icon(resource_id)
			_cost_icon.modulate = ResourceVisuals.icon_modulate(resource_id)
			_cost_badge.visible = _cost_icon.texture != null
		_cost_details.position.x = 642 if _cost_badge.visible else 612
	_cost.tooltip_text = "升级费用 " + _cost_details.text
	_cost_details.tooltip_text = _cost.tooltip_text
	var exact_costs: Array = []
	for id in quote.costs:
		exact_costs.append((str(integer_costs[id]) if integer_costs.get(id) is String else str(quote.costs[id])) + " " + PlayerText.resource(str(id)))
	_purchase.tooltip_text = " + ".join(exact_costs) + (" · " + str(ERRORS.get(reason, PlayerText.error(reason))) if not reason.is_empty() else "")
	_update_buttons()

func _slide(value: float,id: String) -> void:
	if id not in _ids or not _running: return
	_shares[id] = int(value)
	# The owner computes and accepts the entire allocation. No Amount is calculated here.
	presentation_counts.preview_reads += 1
	var preview: Dictionary = _owner.allocation_plan_preview({"kind":"shares", "shares_bp":_shares.duplicate()},_inputs.call())
	if not preview.get("ok",false) or not _valid_preview(preview) or not bool(preview.get("can_apply",false)):
		if preview.get("ok",false) and bool(preview.get("can_apply",false)) == false and _valid_preview(preview):
			_dirty = true
			return
		last_result = preview if not preview.get("ok",false) else {"ok":false,"reason":"InvalidReactorPlan"}
		_error(last_result)
		_dirty = true
		command_finished.emit(last_result)
		return
	var amounts: Dictionary = {}
	for row in preview.target.modules: amounts[str(row.id)] = str(row.manual)
	_command(func(): return _owner.apply_allocation_plan(amounts,_inputs.call(),_publish))

func _valid_preview(preview: Dictionary) -> bool:
	for side in ["current", "target"]:
		if not preview.has(side) or not preview[side] is Dictionary: return false
		var reading: Dictionary = preview[side]
		for key in ["capacity","allocated","remaining","modules"]:
			if not reading.has(key): return false
		if not reading.capacity is String or not reading.allocated is String or not reading.remaining is String or not reading.modules is Array: return false
		for row in reading.modules:
			if not row is Dictionary: return false
			for key in ["id","manual","free","effective","factor","ratio","load","has_free"]:
				if not row.has(key): return false
			if not row.manual is String or not row.free is String or not row.effective is String or not row.factor is String or not row.has_free is bool: return false
			if not row.ratio is float or not row.load is float or not is_finite(row.ratio) or not is_finite(row.load): return false
	return true

func _command(action: Callable, quote_may_change: bool = false) -> void:
	presentation_counts.commands += 1
	last_result = action.call()
	if last_result.get("ok",false):
		var notice := "供能已更新"
		if quote_may_change:
			notice = "已升级 " + str(int(last_result.get("count", _purchase_count))) + " 级"
		_set_notice(notice)
		_message_until = Time.get_ticks_msec() + 1800
		# The owner emits presentation_changed deferred. Coalesce that delivery
		# with this fallback read, including successful no-op commands.
		_dirty = true
		if quote_may_change: _quote_dirty = true
	else:
		_error(last_result)
		_dirty = true
	command_finished.emit(last_result)

func _error(result: Dictionary) -> void:
	var reason: String = str(result.get("reason",result.get("error","")))
	var message: String = "资源不足" if reason in ["InsufficientResources", "InsufficientFunds"] else str(result.get("message",ERRORS.get(reason,EconomyView.describe_error(reason))))
	_set_notice(message if not message.is_empty() else "分配未生效，请重试",true)
	_message_until = Time.get_ticks_msec() + 2200

func _update_stage() -> void:
	if _model.is_empty():
		_stage.clear_snapshot()
		return
	var loads: Dictionary = _visual_loads(_model, _ids)
	_stage.show_snapshot(_ids,loads)
	if is_visible_in_tree(): _stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
