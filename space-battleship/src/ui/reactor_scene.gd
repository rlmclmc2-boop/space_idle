extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const NAMES := {"weapons":"武器", "defence":"盾甲", "smelting":"铁产出", "condensation":"碎片"}
const ERRORS := {"ReactorPlanOverCapacity":"草稿超过可调容量", "ReactorModuleSetChanged":"设备范围已变化，请重新调整", "ReactorLocked":"反应炉尚未开放", "InsufficientFunds":"铀不足"}
var _owner
var _inputs: Callable
var _pay: Callable
var _publish: Callable
var _read: Callable
var _clock: Callable
var _stage: Control
var _rows: Dictionary = {}
var _ids: Array = []
var _model: Dictionary = {}
var _shares: Dictionary = {}
var _preview: Dictionary = {}
var _kind: String = "none"
var _selected: String = ""
var _dirty: bool = true
var _message_until: int = 0
var _budget: Label
var _notice: Label
var _level: Label
var _purchase: Button
var _apply: Button
var _equal: Button
var _restore: Button
var last_result: Dictionary = {}
var presentation_counts := {"model_reads":0, "preview_reads":0, "commands":0, "visible_frames":0}

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
	_stage = Stage.new()
	_stage.size = size
	add_child(_stage)
	_build()
	if _owner != null: _owner.choices_changed.connect(invalidate)

## Reader is the owner's read-only presentation; context is host display time.
func bind_presentation(reader: Callable, context: Callable) -> void:
	_read = reader
	_clock = context
	invalidate()

func invalidate() -> void:
	_dirty = true

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

func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("245963") if state in ["hover","pressed"] else Color("173e4b")
		if state == "disabled": box.bg_color = Color("344b50")
		box.border_color = Color("89bfb6") if state == "focus" else Color("58767a")
		box.set_border_width_all(1)
		box.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("e9eee0"))
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
		var x: float = 38.0 if id in ["weapons","smelting"] else 552.0
		var y: float = 321.0 if id in ["weapons","defence"] else 713.0
		var effect := _label(Vector2(x,y), 218, 19)
		var supply := _label(Vector2(x,y+27), 218, 14)
		supply.add_theme_color_override("font_color", Color("a5c3bf"))
		var slider := HSlider.new()
		slider.name = "Allocation_" + id
		slider.position = Vector2(x,y+58)
		slider.size = Vector2(218,30)
		slider.max_value = 10000
		slider.step = 100
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
		grabber.width = 28
		grabber.height = 28
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
	_budget = _label(Vector2(28,815),754,17)
	_purchase = _button("升级",Rect2(28,850,210,38),func(): _command(func(): return _owner.purchase(1,false,_inputs.call(),_pay,_publish)))
	_equal = _button("均分",Rect2(250,850,112,38),func(): _kind = "equal"; _preview_draft())
	_apply = _button("确认调配",Rect2(374,850,176,38),func(): _command(_submit))
	_restore = _button("还原",Rect2(562,850,96,38),_reset)
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
		if is_visible_in_tree(): invalidate())
	set_process(is_visible_in_tree())

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	presentation_counts.visible_frames += 1
	if _dirty: _refresh()
	if _clock.is_valid():
		var context: Dictionary = _clock.call()
		_stage.advance_visual_clock(float(context.get("game_time",0.0)),bool(context.get("paused",true)))
	if _message_until > 0 and Time.get_ticks_msec() >= _message_until:
		_message_until = 0
		_notice.text = ""

func _refresh() -> void:
	_dirty = false
	if not _read.is_valid():
		_notice.text = "供能状态暂不可用"
		return
	presentation_counts.model_reads += 1
	var model: Dictionary = _read.call()
	if not model.get("ok",true):
		_apply.disabled = true
		_purchase.disabled = true
		_equal.disabled = true
		_error(model)
		return
	var ids: Array = []
	for row in model.get("modules",[]):
		if row.get("enabled",true): ids.append(str(row.id))
	if ids != _ids:
		_kind = "none"
		_preview = {}
		if _selected not in ids: _selected = ""
	_ids = ids
	_model = model
	for id in _rows:
		for control in _rows[id].values(): control.visible = id in _ids
		if id not in _ids: _shares.erase(id)
	for row in model.get("modules",[]):
		var id: String = str(row.id)
		if id not in _ids: continue
		if _kind == "none":
			_shares[id] = int(roundf(clampf(float(row.get("ratio",0.0)),0.0,1.0)*10000.0))
			_rows[id].slider.set_value_no_signal(_shares[id])
		_rows[id].slider.editable = model.get("can_allocate",true)
		_rows[id].effect.text = NAMES[id] + " ×" + str(row.get("factor","—"))
		_rows[id].supply.text = "有效 " + str(row.get("effective","—"))
		if row.get("has_free",false): _rows[id].supply.text += "  免费 +" + str(row.get("free",""))
	_level.text = "等级 " + str(model.get("level","—"))
	_budget.text = "可调容量 " + str(model.get("capacity","—")) + "     剩余 " + str(model.get("remaining","—"))
	var quote: Dictionary = model.get("purchase_quote",{})
	_purchase.text = "升级 · " + str(quote.get("cost_text","—"))
	_purchase.disabled = not quote.get("can_purchase",false)
	_purchase.tooltip_text = str(quote.get("message",""))
	_equal.disabled = _ids.is_empty() or not model.get("can_allocate",true)
	_restore.disabled = _kind == "none"
	if _kind != "none": _preview_draft()
	else: _apply.disabled = true
	_update_stage()

func _slide(value: float,id: String) -> void:
	if id not in _ids: return
	_selected = id
	_shares[id] = int(value)
	_kind = "shares"
	_preview_draft()
	_update_stage()

func _reset() -> void:
	_kind = "none"
	_preview = {}
	_notice.text = ""
	invalidate()

func _preview_draft() -> void:
	presentation_counts.preview_reads += 1
	var draft := {"kind":_kind}
	if _kind == "shares": draft.shares_bp = _shares.duplicate()
	_preview = _owner.allocation_plan_preview(draft,_inputs.call())
	_restore.disabled = false
	_apply.disabled = not _preview.get("ok",false) or not _preview.get("can_apply",true)
	if not _preview.get("ok",false): _error(_preview); return
	_notice.text = "调配草稿"
	_message_until = 0
	_budget.text = "草稿分配 " + str(_preview.target.allocated) + "     剩余 " + str(_preview.target.remaining)
	for row in _preview.target.modules:
		var id: String = str(row.id)
		var current: Dictionary = {}
		for old in _preview.current.get("modules",[]):
			if str(old.id) == id: current = old; break
		var a: String = str(current.get("factor","—"))
		var b: String = str(row.factor)
		_rows[id].effect.text = NAMES[id] + " ×" + a + (" → " + b if a != b else "")
		a = str(current.get("effective","—")); b = str(row.effective)
		_rows[id].supply.text = "有效 " + a + (" → " + b if a != b else "")
		if _kind == "equal" and row.has("ratio"):
			_shares[id] = int(roundf(clampf(float(row.ratio),0.0,1.0)*10000.0))
			_rows[id].slider.set_value_no_signal(_shares[id])

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
		_notice.text = "供能已更新"
		_message_until = Time.get_ticks_msec() + 1800
		invalidate()
	else: _error(last_result)
	command_finished.emit(last_result)

func _error(result: Dictionary) -> void:
	var reason: String = str(result.get("reason",result.get("error","")))
	var message: String = str(result.get("message",ERRORS.get(reason,EconomyView.describe_error(reason))))
	_notice.text = message if not message.is_empty() else "调配未生效，请检查草稿"
	_message_until = 0

func _update_stage() -> void:
	var loads := {"core":float(_model.get("load",0.0))}
	for row in _model.get("modules",[]): loads[str(row.id)] = float(row.get("load",0.0))
	_stage.show_snapshot(_ids,loads,_selected)
