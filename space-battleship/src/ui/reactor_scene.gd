extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
const NAMES := {"weapons":"武器", "defence":"盾甲", "smelting":"铁产出", "condensation":"碎片"}
const ERRORS := {"ReactorPlanOverCapacity":"草稿超过可调容量", "ReactorModuleSetChanged":"设备范围已变化，请重新调整", "ReactorLocked":"反应炉尚未开放", "InsufficientFunds":"铀不足"}
var _owner
var _inputs: Callable
var _pay: Callable
var _publish: Callable
var _read: Callable
var _read_quote: Callable
var _clock: Callable
var _stage: Control
var _stage_viewport: SubViewport
var _rows: Dictionary = {}
var _ids: Array = []
var _model: Dictionary = {}
var _shares: Dictionary = {}
var _preview: Dictionary = {}
var _canonical: Dictionary = {}
var _quote: Dictionary = {}
var _quote_cost_ids: Array = []
var _kind: String = "none"
var _selected: String = ""
var _dirty: bool = true
var _quote_dirty: bool = true
var _running: bool = false
var _message_until: int = 0
var _budget: Label
var _notice: Label
var _level: Label
var _purchase: Button
var _apply: Button
var _equal: Button
var _restore: Button
var last_result: Dictionary = {}
var presentation_counts := {"model_reads":0, "quote_reads":0, "preview_reads":0, "commands":0, "visible_frames":0}

func _init(owner = null, inputs: Callable = Callable(), payment: Callable = Callable(), publish: Callable = Callable()) -> void:
	_owner = owner
	_inputs = inputs
	_pay = payment
	_publish = publish
	size = Vector2(808, 900)
	custom_minimum_size = size
	clip_contents = true
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansSC-Regular.tres")
	var surface := SubViewportContainer.new()
	surface.size = size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_stage_viewport = SubViewport.new()
	_stage_viewport.size = Vector2i(808,900)
	_stage_viewport.disable_3d = true
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	surface.add_child(_stage_viewport)
	_stage = Stage.new()
	_stage.size = size
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
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("245963") if state in ["hover","pressed"] else Color("173e4b")
		if primary: box.bg_color = Color("fff2d7") if state != "disabled" else Color("465e60")
		if state == "disabled" and not primary: box.bg_color = Color("163945", 0.55)
		box.border_color = Color("89bfb6") if state == "focus" else Color("58767a", 0.8)
		if primary: box.border_color = Color("d4b373")
		box.set_border_width_all(1)
		box.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("173d4a") if primary else Color("e9eee0"))
	button.add_theme_color_override("font_disabled_color", Color("849a9c"))
	button.pressed.connect(action)
	add_child(button)
	return button

func _build() -> void:
	var title := _label(Vector2(26,18), 170, 23)
	title.text = "反应炉"
	title.add_theme_color_override("font_color", Color("203f50"))
	_level = _label(Vector2(612,23), 170)
	_level.add_theme_color_override("font_color", Color("315662"))
	for id in Stage.IDS:
		var layout: Dictionary = _stage.control_layout(id)
		var effect := _label(layout.effect,float(layout.width),18)
		effect.mouse_filter = Control.MOUSE_FILTER_PASS
		var supply := _label(layout.supply,float(layout.width),14)
		supply.size.y = 24
		supply.add_theme_color_override("font_color", Color("c1dfd9"))
		var slider := HSlider.new()
		slider.name = "Allocation_" + id
		slider.position = layout.slider
		slider.size = Vector2(float(layout.track),18)
		slider.max_value = 10000
		slider.step = 100
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.tooltip_text = "拖动调整手动分配；实际供能在确认整组后变化"
		for style in ["slider","grabber_area","grabber_area_highlight"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("5db3aa") if style != "slider" else Color("244e58")
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
		grabber.width = 18
		grabber.height = 18
		grabber.fill = GradientTexture2D.FILL_RADIAL
		grabber.fill_from = Vector2(0.5,0.5)
		grabber.fill_to = Vector2(0.5,1.0)
		slider.add_theme_icon_override("grabber",grabber)
		slider.add_theme_icon_override("grabber_highlight",grabber)
		slider.value_changed.connect(_slide.bind(id))
		slider.focus_entered.connect(func(): _selected = id; _update_stage())
		add_child(slider)
		_rows[id] = {"effect":effect, "supply":supply, "slider":slider}
		for control in _rows[id].values(): control.visible = false
	_budget = _label(Vector2(45,833),365,16)
	_budget.mouse_filter = Control.MOUSE_FILTER_PASS
	_purchase = _button("升级",Rect2(427,828,151,44),func(): _command(func(): return _owner.purchase(1,false,_inputs.call(),_pay,_publish)),true)
	_equal = _button("均分",Rect2(586,833,62,36),func(): _kind = "equal"; _preview_draft())
	_apply = _button("确认",Rect2(656,833,66,36),func(): _command(_submit))
	_restore = _button("还原",Rect2(729,833,53,36),_reset)
	_notice = _label(Vector2(278,91),252,14)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.size.y = 68
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.clip_text = false
	for button in [_purchase,_equal,_apply,_restore]: button.disabled = true

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
		_notice.text = ""

func _set_running(running: bool) -> void:
	if _running == running: return
	_running = running
	_update_buttons()
	for id in _rows:
		_rows[id].slider.editable = running and bool(_model.get("can_allocate", false))

func _update_buttons() -> void:
	_purchase.disabled = not _running or _model.is_empty() or not bool(_quote.get("can_purchase", false))
	_equal.disabled = not _running or _ids.is_empty() or not bool(_model.get("can_allocate", false))
	_apply.disabled = not _running or _kind == "none" or not bool(_preview.get("ok", false)) or not bool(_preview.get("can_apply", false))
	_restore.disabled = _kind == "none"

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
	if _kind == "none" and _message_until == 0: _notice.text = ""
	var ids: Array = []
	for row in model.get("modules",[]):
		if row.get("enabled",true): ids.append(str(row.id))
	if ids != _ids:
		_kind = "none"
		_preview = {}
		_canonical = {}
		if _selected not in ids: _selected = ""
	_ids = ids
	_model = model
	for id in _rows:
		for control in _rows[id].values(): control.visible = id in _ids
		if id not in _ids: _shares.erase(id)
	_show_current_readings()
	if _kind != "none": _preview_draft(false)
	_update_buttons()
	_update_stage()

func _show_current_readings() -> void:
	if _model.is_empty(): return
	for row in _model.modules:
		var id: String = str(row.id)
		if id not in _ids: continue
		if _kind == "none":
			_shares[id] = int(roundf(float(row.ratio)*10000.0))
			_rows[id].slider.set_value_no_signal(_shares[id])
		_rows[id].slider.editable = _running and bool(_model.can_allocate)
		_rows[id].effect.text = NAMES[id] + " ×" + PlayerText.number(str(row.factor))
		_rows[id].effect.tooltip_text = "增益 ×" + str(row.factor)
		var manual_text: String = str(row.manual)
		_rows[id].supply.text = "手" + PlayerText.number(manual_text)
		if row.has_free: _rows[id].supply.text += "+免" + PlayerText.number(str(row.free))
		_rows[id].supply.text += "  效" + PlayerText.number(str(row.effective))
		_rows[id].supply.tooltip_text = "手动 " + manual_text + " / 免费 " + str(row.free) + " / 有效 " + str(row.effective)
		_rows[id].slider.tooltip_text = _rows[id].supply.tooltip_text
	_level.text = "等级 " + str(_model.level)
	_budget.text = "容量 " + PlayerText.number(str(_model.capacity)) + "   已配 " + PlayerText.number(str(_model.allocated)) + "   剩余 " + PlayerText.number(str(_model.remaining))
	_budget.tooltip_text = "容量 " + str(_model.capacity) + " / 已分配 " + str(_model.allocated) + " / 剩余 " + str(_model.remaining)

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
	_preview = {}
	for id in _rows:
		for control in _rows[id].values(): control.visible = false
	_budget.text = "供能状态未知"
	_level.text = "等级 —"
	_notice.text = message
	_stage.clear_snapshot()
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_buttons()

func _refresh_quote() -> void:
	_quote_dirty = false
	if not _read_quote.is_valid():
		_quote = {}
		_purchase.text = "升级 · —"
		_update_buttons()
		return
	presentation_counts.quote_reads += 1
	var quote: Dictionary = _read_quote.call()
	if quote.get("ok") != true or not quote.has("costs") or not quote.costs is Dictionary or not quote.has("can_purchase") or not quote.can_purchase is bool:
		_quote = {}
		_quote_cost_ids.clear()
		_purchase.text = "升级 · —"
		_purchase.tooltip_text = str(quote.get("reason", "报价暂不可用"))
		_update_buttons()
		return
	_quote = quote
	_quote_cost_ids = quote.costs.keys()
	var labels: Array = []
	for id in _quote_cost_ids:
		if not quote.costs[id] is String:
			_quote = {}
			_purchase.text = "升级 · —"
			_update_buttons()
			return
		labels.append(PlayerText.number(str(quote.costs[id])) + " " + PlayerText.resource(str(id)))
	_purchase.text = "升级 · " + " + ".join(labels)
	var reason: String = str(quote.get("reason", ""))
	var exact_costs: Array = []
	for id in _quote_cost_ids: exact_costs.append(str(quote.costs[id]) + " " + PlayerText.resource(str(id)))
	_purchase.tooltip_text = " + ".join(exact_costs) + (" · " + str(ERRORS.get(reason, PlayerText.error(reason))) if not reason.is_empty() else "")
	_update_buttons()

func _slide(value: float,id: String) -> void:
	if id not in _ids or not _running: return
	_selected = id
	_shares[id] = int(value)
	_kind = "shares"
	_preview_draft(true)
	_update_stage()

func _reset() -> void:
	_kind = "none"
	_preview = {}
	_canonical = {}
	_notice.text = ""
	_dirty = true

func _preview_draft(fresh_shares: bool = false) -> void:
	if _kind == "shares" and not fresh_shares and _canonical.is_empty():
		_update_buttons()
		return
	presentation_counts.preview_reads += 1
	var draft := {"kind":_kind}
	if _kind == "shares":
		if fresh_shares:
			draft.shares_bp = _shares.duplicate()
		else:
			draft = {"kind":"amounts", "amount_texts":_canonical.duplicate()}
	_preview = _owner.allocation_plan_preview(draft,_inputs.call())
	if not _preview.get("ok",false):
		if fresh_shares: _canonical.clear()
		_update_buttons()
		_error(_preview)
		return
	if not _valid_preview(_preview):
		_preview = {"ok":false,"reason":"ReactorSnapshotUnavailable"}
		if fresh_shares: _canonical.clear()
		_update_buttons()
		_error(_preview)
		return
	_update_buttons()
	if fresh_shares:
		_canonical.clear()
		for row in _preview.target.modules: _canonical[str(row.id)] = str(row.manual)
	_notice.text = "调配草稿"
	_message_until = 0
	_budget.text = "容量 " + PlayerText.number(str(_preview.target.capacity)) + "   草稿 " + PlayerText.number(str(_preview.target.allocated)) + "   剩余 " + PlayerText.number(str(_preview.target.remaining))
	_budget.tooltip_text = "草稿容量 " + str(_preview.target.capacity) + " / 已分配 " + str(_preview.target.allocated) + " / 剩余 " + str(_preview.target.remaining)
	for row in _preview.target.modules:
		var id: String = str(row.id)
		var current: Dictionary = {}
		for old in _preview.current.get("modules",[]):
			if str(old.id) == id: current = old; break
		var a: String = str(current.get("factor","—"))
		var b: String = str(row.factor)
		_rows[id].effect.text = NAMES[id] + " ×" + PlayerText.number(a) + (" → " + PlayerText.number(b) if a != b else "")
		_rows[id].effect.tooltip_text = "增益 " + a + " → " + b
		a = str(current.get("manual","—")); b = str(row.get("manual","—"))
		var supply_text: String = "手" + PlayerText.number(a) + ("→" + PlayerText.number(b) if a != b else "")
		if row.has_free: supply_text += "+免" + PlayerText.number(str(row.free))
		a = str(current.get("effective","—")); b = str(row.effective)
		_rows[id].supply.text = supply_text + "  效" + PlayerText.number(a) + ("→" + PlayerText.number(b) if a != b else "")
		_rows[id].supply.tooltip_text = "手动 " + str(current.get("manual","—")) + " → " + str(row.manual) + " / 免费 " + str(row.free) + " / 有效 " + a + " → " + b
		_rows[id].slider.tooltip_text = _rows[id].supply.tooltip_text
		if _kind == "equal" or (_kind == "shares" and not fresh_shares):
			_shares[id] = int(roundf(clampf(float(row.ratio),0.0,1.0)*10000.0))
			_rows[id].slider.set_value_no_signal(_shares[id])

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

func _submit() -> Dictionary:
	if _apply.disabled or not _preview.get("ok",false): return {"ok":false,"reason":"InvalidReactorPlan"}
	if _kind == "equal": return _owner.distribute(_inputs.call(),_publish)
	var amounts: Dictionary = {}
	for row in _preview.target.modules: amounts[str(row.id)] = str(row.manual)
	return _owner.apply_allocation_plan(amounts,_inputs.call(),_publish)

func _command(action: Callable) -> void:
	presentation_counts.commands += 1
	last_result = action.call()
	if last_result.get("ok",false):
		_kind = "none"
		_preview = {}
		_canonical = {}
		_notice.text = "供能已更新"
		_message_until = Time.get_ticks_msec() + 1800
		_show_current_readings()
		_update_buttons()
	else: _error(last_result)
	command_finished.emit(last_result)

func _error(result: Dictionary) -> void:
	var reason: String = str(result.get("reason",result.get("error","")))
	var message: String = str(result.get("message",ERRORS.get(reason,EconomyView.describe_error(reason))))
	_notice.text = message if not message.is_empty() else "调配未生效，请检查草稿"
	_message_until = 0

func _update_stage() -> void:
	if _model.is_empty():
		_stage.clear_snapshot()
		return
	var loads := {"core":float(_model.load)}
	for row in _model.modules: loads[str(row.id)] = float(row.load)
	_stage.show_snapshot(_ids,loads,_selected)
	if is_visible_in_tree(): _stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
