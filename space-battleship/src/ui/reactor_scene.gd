extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const WORK_FACE = preload("res://assets/ui/reactor/ship-hub-r9/device_work.gdshader")
const WORK_PULSE = preload("res://assets/ui/reactor/ship-hub-r9/device_pulse.gdshader")
const EconomyView = preload("res://src/ui/economy_view.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const NAMES := {"weapons":"武器", "defence":"盾甲", "smelting":"铁产出", "condensation":"碎片"}
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
var _stage: Control
var _stage_viewport: SubViewport
var _rows: Dictionary = {}
var _ids: Array = []
var _model: Dictionary = {}
var _shares: Dictionary = {}
var _quote: Dictionary = {}
var _quote_cost_ids: Array = []
var _purchase_count: int = 1
var _purchase_max: bool = false
var _quantity: Button
var _active_work_ids: Array = []
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
var _cost_badge: Panel
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
	button.add_theme_font_override("font", _ui_font_bold)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("8c6b45") if primary else Color("344d56")
		if state == "hover": box.bg_color = Color("a17d50") if primary else Color("45636a")
		elif state == "pressed": box.bg_color = Color("73583c") if primary else Color("263f48")
		elif state == "disabled": box.bg_color = Color("77746e") if primary else Color("58676c")
		elif state == "focus": box.bg_color = Color.TRANSPARENT
		box.border_color = Color("d6c18e") if primary else Color("648b8d")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(3)
		if state != "focus":
			box.shadow_color = Color(0.05,0.11,0.14,0.20)
			box.shadow_size = 1
			box.shadow_offset = Vector2(0,1)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("f3f0df"))
	button.add_theme_color_override("font_hover_color", Color("fff2db"))
	button.add_theme_color_override("font_pressed_color", Color("f3f0df"))
	button.add_theme_color_override("font_focus_color", Color("f3f0df"))
	button.add_theme_color_override("font_disabled_color", Color("8da5ac"))
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

func _build() -> void:
	_level = _label(Vector2(112, 769), 190, 17)
	_level.add_theme_font_override("font",_ui_font_bold)
	_level.add_theme_color_override("font_color",Color("203f50"))
	for id in Stage.IDS:
		var layout: Dictionary = _stage.control_layout(id)
		var offset := Vector2(0, 65)
		var work := ColorRect.new()
		work.position = layout.work + offset
		work.size = layout.work_size
		work.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var work_material := ShaderMaterial.new()
		work_material.shader = WORK_FACE
		work_material.set_shader_parameter("module_kind", Stage.IDS.find(id))
		work_material.set_shader_parameter("tint", Color("f5a84e") if id in ["weapons","smelting"] else Color("78d9ea"))
		work.material = work_material
		add_child(work)
		var pulse := ColorRect.new()
		pulse.position = work.position
		pulse.size = work.size
		pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pulse_material := ShaderMaterial.new()
		pulse_material.shader = WORK_PULSE
		pulse_material.set_shader_parameter("module_kind", Stage.IDS.find(id))
		pulse_material.set_shader_parameter("tint", Color("f8ba5b") if id in ["weapons","smelting"] else Color("79ddfa"))
		pulse.material = pulse_material
		add_child(pulse)
		var name := _label(layout.title + offset,54 if id == "smelting" else 92,17)
		name.rotation_degrees = float(layout.read_tilt)
		name.add_theme_font_override("font",_ui_font_medium)
		name.add_theme_color_override("font_color",Color("f3f0df"))
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.text = NAMES[id]
		var effect := _label(layout.factor + offset,62 if id == "smelting" else 58,18)
		effect.rotation_degrees = float(layout.read_tilt)
		effect.add_theme_font_override("font", _ui_font_bold)
		effect.add_theme_color_override("font_color",Color("e9c98b") if id in ["weapons","smelting"] else Color("b5d9d8"))
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect.mouse_filter = Control.MOUSE_FILTER_PASS
		var strip := Control.new()
		strip.position = layout.control + offset
		strip.size = Vector2(98,20)
		strip.rotation_degrees = float(layout.tilt)
		strip.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(strip)
		var slider := HSlider.new()
		slider.name = "Allocation_" + id
		slider.position = Vector2(9,-4)
		slider.size = Vector2(46,28)
		slider.max_value = 10000
		slider.step = 100
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.tooltip_text = "拖动后直接分配供能"
		for style in ["slider","grabber_area","grabber_area_highlight"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("4aaea2") if style != "slider" else Color("173642")
			box.set_corner_radius_all(4)
			if style == "slider":
				box.border_color = Color("658d91")
				box.set_border_width_all(1)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			slider.add_theme_stylebox_override(style, box)
		var gradient := Gradient.new()
		gradient.set_color(0, Color("fff0c5"))
		gradient.set_color(1, Color("75b9a8",0.0))
		gradient.add_point(0.62, Color("fff0c5"))
		gradient.add_point(0.72, Color("75b9a8"))
		var grabber := GradientTexture2D.new()
		grabber.gradient = gradient
		grabber.width = 14
		grabber.height = 14
		grabber.fill = GradientTexture2D.FILL_RADIAL
		grabber.fill_from = Vector2(0.5,0.5)
		grabber.fill_to = Vector2(0.5,1.0)
		slider.add_theme_icon_override("grabber",grabber)
		slider.add_theme_icon_override("grabber_highlight",grabber)
		slider.value_changed.connect(_slide.bind(id))
		strip.add_child(slider)
		var ratio := _label(Vector2(55,-7), 34, 16, strip)
		ratio.add_theme_font_override("font", _ui_font_bold)
		ratio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ratio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ratio.add_theme_color_override("font_color", Color("e9c98b") if id in ["weapons","smelting"] else Color("b5d9d8"))
		_rows[id] = {"effect":effect, "name":name, "work":work, "pulse":pulse, "slider":slider, "ratio":ratio, "control":strip}
		for control in _rows[id].values(): control.visible = false
	_budget = _label(Vector2(91,791),190,16)
	_budget.add_theme_color_override("font_color",Color("203f50"))
	_budget.mouse_filter = Control.MOUSE_FILTER_PASS
	_upgrade_heading = _label(Vector2(343,775),82,17)
	_upgrade_heading.text = "核心升级"
	_upgrade_heading.add_theme_color_override("font_color",Color("203f50"))
	_cost = _label(Vector2(430, 775), 335, 18)
	_cost.add_theme_color_override("font_color",Color("203f50"))
	_cost_badge = Panel.new()
	_cost_badge.position = Vector2(476,772)
	_cost_badge.size = Vector2(32,30)
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("214b55")
	badge_style.set_corner_radius_all(6)
	_cost_badge.add_theme_stylebox_override("panel",badge_style)
	_cost_badge.visible = false
	add_child(_cost_badge)
	_cost_icon = TextureRect.new()
	_cost_icon.position = Vector2(4,3)
	_cost_icon.size = Vector2(24,24)
	_cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.add_child(_cost_icon)
	_cost_details = _label(Vector2(504,775),259,18)
	_cost_details.add_theme_color_override("font_color",Color("203f50"))
	_quantity = _button("×1",Rect2(324,822,74,34),_cycle_quantity)
	_quantity.tooltip_text = "选择升级数量：×1 / ×10 / MAX"
	_purchase = _button("升级",Rect2(406,822,152,34),func(): _command(_purchase_action,true),true)
	_equal = _button("均分",Rect2(246,822,72,34),func(): _command(func(): return _owner.distribute(_inputs.call(),_publish)))
	_equal.tooltip_text = "均分供能"
	_notice_panel = _panel(Rect2(282,728,244,34),0.95)
	_notice = _label(Vector2(295,730),218,18)
	_notice.size.y = 30
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_notice("")
	for button in [_purchase,_equal]: button.disabled = true
	_select_quantity(1,false)

func _select_quantity(count: int, maximum: bool) -> void:
	_purchase_count = count
	_purchase_max = maximum
	_quote = {}
	_quote_dirty = true
	_cost.text = "报价读取中"
	_cost_details.text = ""
	_cost_badge.visible = false
	_cost.size.x = 335
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
			for id in _active_work_ids:
				_rows[id].work.material.set_shader_parameter("phase",_stage.visual_phase())
				_rows[id].pulse.material.set_shader_parameter("phase",_stage.visual_phase())
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
	var purchase_disabled: bool = not _running or _model.is_empty() or not bool(_quote.get("can_purchase", false))
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
	for id in _rows:
		var now_enabled: bool = id in ids
		if now_enabled != (id in previous_ids):
			for control in _rows[id].values(): control.visible = now_enabled
		if not now_enabled: _shares.erase(id)
	_show_current_readings(previous, previous_ids)
	_update_buttons()
	if ids != previous_ids or _visual_loads(model, ids) != previous_loads: _update_stage()

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
			_rows[id].ratio.text = _ratio_text(float(row.ratio))
		if new_row or previous.get("can_allocate", false) != _model.can_allocate:
			_rows[id].slider.editable = _running and bool(_model.can_allocate)
		if new_row or old_row.get("factor") != row.factor:
			_rows[id].effect.text = "×" + PlayerText.number(str(row.factor))
			_rows[id].effect.tooltip_text = "增益 ×" + str(row.factor)
		if new_row or old_row.get("ratio") != row.ratio or old_row.get("manual") != row.manual or old_row.get("free") != row.free or old_row.get("effective") != row.effective:
			_rows[id].slider.tooltip_text = "分配 " + _ratio_text(float(row.ratio)) + " · 手动 " + str(row.manual) + " / 免费 " + str(row.free) + " / 有效 " + str(row.effective)
	var level_text := "等级 " + str(_model.level) + " · 容量 " + PlayerText.number(str(_model.capacity))
	var budget_text := "已配 " + PlayerText.number(str(_model.allocated)) + " · 剩余 " + PlayerText.number(str(_model.remaining))
	var detail := "容量 " + str(_model.capacity) + " / 已分配 " + str(_model.allocated) + " / 剩余 " + str(_model.remaining)
	if _level.text != level_text: _level.text = level_text
	if _budget.text != budget_text: _budget.text = budget_text
	if _level.tooltip_text != detail: _level.tooltip_text = detail
	if _budget.tooltip_text != detail: _budget.tooltip_text = detail

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
	_shares.clear()
	_active_work_ids.clear()
	for id in _rows:
		for control in _rows[id].values(): control.visible = false
	_cost.text = "费用 —"
	_cost_details.text = ""
	_cost_badge.visible = false
	_level.text = "等级 —"
	_budget.text = ""
	_set_notice(message,true)
	_stage.clear_snapshot()
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_buttons()

func _refresh_quote() -> void:
	_quote_dirty = false
	_cost_details.text = ""
	_cost_badge.visible = false
	_cost.add_theme_color_override("font_color",Color("203f50"))
	_cost.add_theme_font_override("font",_ui_font_bold)
	_cost_details.add_theme_color_override("font_color",Color("203f50"))
	_cost_details.add_theme_font_override("font",_ui_font_bold)
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
	for id in quote.costs:
		if not quote.costs[id] is String:
			_quote = {}
			_quote_cost_ids.clear()
			_cost.text = "费用 —"
			_update_buttons()
			return
		labels.append(PlayerText.number(str(quote.costs[id])) + " " + PlayerText.resource(str(id)))
	var cost_text: String = " + ".join(labels)
	var mode_text := "MAX 可购 " + str(quote.count) + " 级" if _purchase_max else "×" + str(_purchase_count)
	var affordable: bool = bool(quote.can_purchase)
	var reason: String = str(quote.get("reason", ""))
	var failure_text: String = "资金不足" if reason in ["InsufficientResources", "InsufficientFunds"] else str(ERRORS.get(reason, PlayerText.error(reason))) if not reason.is_empty() else "不可购买"
	if labels.is_empty():
		_cost.text = mode_text
		_cost_details.text = failure_text
		_cost_details.position.x = 590
		_cost_details.add_theme_color_override("font_color",Color("a1593b"))
		_cost_details.add_theme_font_override("font",_ui_font_medium)
	else:
		_cost.text = "费用" if affordable else failure_text
		_cost_details.text = cost_text + " · " + mode_text
		if not affordable:
			_cost.size.x = 80
			_cost.add_theme_color_override("font_color",Color("a1593b"))
			_cost.add_theme_font_override("font",_ui_font_medium)
		if affordable and quote.costs.size() == 1:
			var resource_id: String = str(quote.costs.keys()[0])
			_cost_icon.texture = ResourceVisuals.icon(resource_id)
			_cost_icon.modulate = ResourceVisuals.icon_modulate(resource_id)
			_cost_badge.visible = _cost_icon.texture != null
		_cost_details.position.x = 512 if _cost_badge.visible or not affordable else 480
	_cost.tooltip_text = _cost.text + " " + _cost_details.text
	_cost_details.tooltip_text = _cost.tooltip_text
	var exact_costs: Array = []
	for id in quote.costs: exact_costs.append(str(quote.costs[id]) + " " + PlayerText.resource(str(id)))
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
		_set_notice("供能已更新")
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
	var message: String = str(result.get("message",ERRORS.get(reason,EconomyView.describe_error(reason))))
	_set_notice(message if not message.is_empty() else "分配未生效，请重试",true)
	_message_until = Time.get_ticks_msec() + 2200

func _update_stage() -> void:
	if _model.is_empty():
		_active_work_ids.clear()
		_stage.clear_snapshot()
		return
	var loads: Dictionary = _visual_loads(_model, _ids)
	_stage.show_snapshot(_ids,loads)
	_active_work_ids.clear()
	for id in _ids:
		var power: float = float(loads.get(id,0.0))
		_rows[id].work.material.set_shader_parameter("power",Stage.visibility_power(power))
		_rows[id].pulse.material.set_shader_parameter("power",Stage.visibility_power(power))
		if power > 0.0: _active_work_ids.append(id)
	if is_visible_in_tree(): _stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
