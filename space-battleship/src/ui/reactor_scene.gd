extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const WORK_FACE = preload("res://assets/ui/reactor/ship-hub-r9/device_work.gdshader")
const WORK_PULSE = preload("res://assets/ui/reactor/ship-hub-r9/device_pulse.gdshader")
const EconomyView = preload("res://src/ui/economy_view.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
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
var _selected: String = ""
var _dirty: bool = true
var _quote_dirty: bool = true
var _running: bool = false
var _message_until: int = 0
var _budget: Label
var _cost: Label
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

func _label(point: Vector2, width: float, font_size: int = 16) -> Label:
	var label := Label.new()
	label.position = point
	label.size = Vector2(width, 28)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _ui_font_bold if font_size >= 18 else _ui_font_regular)
	label.add_theme_color_override("font_color", Color("dcebe4"))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 20 if primary else 17)
	button.add_theme_font_override("font", _ui_font_bold)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("286365") if primary else Color("234b5b")
		box.border_color = Color("9baea9")
		if state == "hover":
			box.bg_color = Color("3c6e76")
			box.border_color = Color("d4f3e4")
		elif state == "pressed":
			box.bg_color = Color("122f3d")
			box.border_color = Color("7bb6b1")
		elif state == "disabled":
			box.bg_color = Color("31434a")
			box.border_color = Color("62747a")
		elif state == "focus":
			box.bg_color = Color(0,0,0,0)
			box.border_color = Color("b3ead8")
		box.set_border_width_all(1)
		box.border_width_top = 2
		box.border_width_bottom = 1 if state == "pressed" else 2
		box.set_corner_radius_all(6)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 5
		box.content_margin_bottom = 5
		box.shadow_size = 0
		if state == "focus":
			box.set_border_width_all(2)
			box.shadow_size = 0
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("f3f0df"))
	button.add_theme_color_override("font_hover_color", Color("c4fff0"))
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
	_level = _label(Vector2(91, 784), 190, 18)
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
		var name := _label(layout.title + offset,92,17)
		name.add_theme_font_override("font",_ui_font_bold)
		name.add_theme_color_override("font_color",Color("eff4ee"))
		name.add_theme_color_override("font_shadow_color",Color(0.015, 0.07, 0.10, 0.9))
		name.add_theme_constant_override("shadow_offset_x",1)
		name.add_theme_constant_override("shadow_offset_y",1)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.text = NAMES[id] + "供能"
		var effect := _label(layout.factor + offset,58,19)
		effect.add_theme_font_override("font", _ui_font_bold)
		effect.add_theme_color_override("font_color",Color("ffd393") if id in ["weapons","smelting"] else Color("a9edfa"))
		effect.add_theme_color_override("font_shadow_color",Color(0.015, 0.07, 0.10, 0.9))
		effect.add_theme_constant_override("shadow_offset_x",1)
		effect.add_theme_constant_override("shadow_offset_y",1)
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect.mouse_filter = Control.MOUSE_FILTER_PASS
		var slider := HSlider.new()
		slider.name = "Allocation_" + id
		slider.position = layout.slider + offset
		slider.size = Vector2(float(layout.track),28)
		slider.max_value = 10000
		slider.step = 100
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.tooltip_text = "拖动后直接分配供能"
		for style in ["slider","grabber_area","grabber_area_highlight"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("62bcb2") if style != "slider" else Color("173642")
			box.set_corner_radius_all(4)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			slider.add_theme_stylebox_override(style, box)
		var gradient := Gradient.new()
		gradient.set_color(0, Color("eff2e5"))
		gradient.set_color(1, Color("64b9af",0.0))
		gradient.add_point(0.62, Color("eff2e5"))
		gradient.add_point(0.72, Color("64b9af"))
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
		slider.focus_entered.connect(func(): _selected = id; _update_stage())
		add_child(slider)
		var ratio := _label(layout.ratio + offset, 38, 15)
		ratio.add_theme_font_override("font", _ui_font_bold)
		ratio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ratio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ratio.add_theme_color_override("font_color", Color("dce9e5"))
		_rows[id] = {"effect":effect, "name":name, "work":work, "pulse":pulse, "slider":slider, "ratio":ratio}
		for control in _rows[id].values(): control.visible = false
	_budget = _label(Vector2(91,809),190,16)
	_budget.add_theme_color_override("font_color",Color("203f50"))
	_budget.mouse_filter = Control.MOUSE_FILTER_PASS
	_upgrade_heading = _label(Vector2(288,759),475,17)
	_upgrade_heading.text = "核心升级"
	_upgrade_heading.add_theme_color_override("font_color",Color("203f50"))
	_cost = _label(Vector2(288, 786), 475, 18)
	_cost.add_theme_color_override("font_color",Color("203f50"))
	_quantity = _button("×1",Rect2(288,845,105,42),_cycle_quantity)
	_quantity.tooltip_text = "选择升级数量：×1 / ×10 / MAX"
	_purchase = _button("升级 ×1",Rect2(407,845,358,42),func(): _command(_purchase_action),true)
	_equal = _button("均分供能",Rect2(43,845,175,42),func(): _command(func(): return _owner.distribute(_inputs.call(),_publish)))
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
	_purchase.text = "升级 MAX" if maximum else "升级 ×" + str(count)
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
			for id in _ids:
				_rows[id].work.material.set_shader_parameter("phase",_stage.visual_phase())
				_rows[id].pulse.material.set_shader_parameter("phase",_stage.visual_phase())
	if _message_until > 0 and Time.get_ticks_msec() >= _message_until:
		_message_until = 0
		_set_notice("")

func _set_notice(message: String, rejected: bool = false) -> void:
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
	_purchase.disabled = not _running or _model.is_empty() or not bool(_quote.get("can_purchase", false))
	_equal.disabled = not _running or _ids.is_empty() or not bool(_model.get("can_allocate", false))

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
	var ids: Array = []
	for row in model.get("modules",[]):
		if row.get("enabled",true): ids.append(str(row.id))
	if ids != _ids and _selected not in ids: _selected = ""
	_ids = ids
	_model = model
	for id in _rows:
		for control in _rows[id].values(): control.visible = id in _ids
		if id not in _ids: _shares.erase(id)
	_show_current_readings()
	_update_buttons()
	_update_stage()

func _show_current_readings() -> void:
	if _model.is_empty(): return
	for row in _model.modules:
		var id: String = str(row.id)
		if id not in _ids: continue
		_shares[id] = int(roundf(float(row.ratio)*10000.0))
		_rows[id].slider.set_value_no_signal(_shares[id])
		_rows[id].ratio.text = str(int(roundf(float(row.ratio) * 100.0))) + "%"
		_rows[id].slider.editable = _running and bool(_model.can_allocate)
		_rows[id].effect.text = "×" + PlayerText.number(str(row.factor))
		_rows[id].effect.tooltip_text = "增益 ×" + str(row.factor)
		_rows[id].slider.tooltip_text = "分配 " + str(int(roundf(float(row.ratio) * 100.0))) + "% · 手动 " + str(row.manual) + " / 免费 " + str(row.free) + " / 有效 " + str(row.effective)
	_level.text = "等级 " + str(_model.level) + " · 容量 " + PlayerText.number(str(_model.capacity))
	_budget.text = "已配 " + PlayerText.number(str(_model.allocated)) + " · 剩余 " + PlayerText.number(str(_model.remaining))
	_budget.tooltip_text = "容量 " + str(_model.capacity) + " / 已分配 " + str(_model.allocated) + " / 剩余 " + str(_model.remaining)
	_level.tooltip_text = _budget.tooltip_text

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
	for id in _rows:
		for control in _rows[id].values(): control.visible = false
	_budget.text = "供能状态未知"
	_cost.text = "费用 —"
	_level.text = "等级 —"
	_set_notice(message,true)
	_stage.clear_snapshot()
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_buttons()

func _refresh_quote() -> void:
	_quote_dirty = false
	if not _read_quote.is_valid():
		_quote = {}
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
			_cost.text = "费用 —"
			_update_buttons()
			return
		_quote_cost_ids.append(resource_id)
	var labels: Array = []
	for id in quote.costs:
		if not quote.costs[id] is String:
			_quote = {}
			_cost.text = "费用 —"
			_update_buttons()
			return
		labels.append(PlayerText.number(str(quote.costs[id])) + " " + PlayerText.resource(str(id)))
	var cost_text: String = " + ".join(labels)
	var mode_text := "MAX 可购 " + str(quote.count) + " 级" if _purchase_max else "×" + str(_purchase_count)
	_cost.text = mode_text + " · " + ("费用 " + cost_text if not labels.is_empty() else "资金不足")
	_cost.tooltip_text = _cost.text
	var reason: String = str(quote.get("reason", ""))
	var exact_costs: Array = []
	for id in quote.costs: exact_costs.append(str(quote.costs[id]) + " " + PlayerText.resource(str(id)))
	_purchase.tooltip_text = " + ".join(exact_costs) + (" · " + str(ERRORS.get(reason, PlayerText.error(reason))) if not reason.is_empty() else "")
	_update_buttons()

func _slide(value: float,id: String) -> void:
	if id not in _ids or not _running: return
	_selected = id
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

func _command(action: Callable) -> void:
	presentation_counts.commands += 1
	last_result = action.call()
	if last_result.get("ok",false):
		_set_notice("供能已更新")
		_message_until = Time.get_ticks_msec() + 1800
		_refresh()
		_quote_dirty = true
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
		_stage.clear_snapshot()
		return
	var loads := {"core":float(_model.load)}
	for row in _model.modules: loads[str(row.id)] = float(row.load)
	_stage.show_snapshot(_ids,loads,_selected)
	for id in _ids:
		_rows[id].work.material.set_shader_parameter("power",float(loads.get(id,0.0)))
		_rows[id].pulse.material.set_shader_parameter("power",float(loads.get(id,0.0)))
	if is_visible_in_tree(): _stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
