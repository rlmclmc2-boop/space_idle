extends Control
## Whole reactor scene. Domain amounts, effects and acceptance stay with Reactor.
signal command_finished(result: Dictionary)
const Stage = preload("res://src/ui/reactor_stage.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
const BridgeTheme = preload("res://src/ui/bridge_theme.gd")
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const ICON_ATLAS = preload("res://assets/ui/reactor/b01/faceted-module-icons.svg")
const SLIDER_KNOB = preload("res://assets/ui/reactor/b01/faceted-slider-knob.svg")
const NAMES := {"weapons":"武器", "defence":"盾甲", "smelting":"铁产出", "condensation":"碎片"}
const BAR_COLORS := {"weapons":Color("ffc533"), "defence":Color("33b9ff"), "smelting":Color("ff7d37"), "condensation":Color("ae53ef")}
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
var _console_layouts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/reactor/b01/faceted-layout.json")).console
var _footer_shift: float=0.0
var _left_heading: Label
class AllocationBar extends Control:
	var ratios: Dictionary={}
	func update_ratios(next: Dictionary) -> void:
		if ratios==next:return
		ratios=next.duplicate()
		queue_redraw()
	func _draw() -> void:
		var channel:=StyleBoxFlat.new()
		channel.bg_color=Color("071c2b")
		channel.border_color=Color("4a6a7b")
		channel.set_border_width_all(2)
		channel.set_corner_radius_all(6)
		draw_style_box(channel,Rect2(Vector2.ZERO,size))
		var left: float=4.0
		for id in ["weapons","defence","smelting","condensation"]:
			var width: float=minf(size.x-4.0-left,(size.x-8.0)*clampf(float(ratios.get(id,0.0)),0.0,1.0))
			if width<=0.0:continue
			draw_rect(Rect2(left,4,width,size.y-8),BAR_COLORS[id].darkened(.18))
			draw_line(Vector2(left,5),Vector2(left+width,5),BAR_COLORS[id].lightened(.35),2)
			left+=width
class PowerTrack extends Control:
	var fraction: float=0.0
	var tint: Color=Color.WHITE
	func update_fraction(value: float) -> void:
		var next: float=clampf(value,0.0,1.0)
		if is_equal_approx(fraction,next):return
		fraction=next
		queue_redraw()
	func _draw() -> void:
		var track:=StyleBoxFlat.new()
		track.bg_color=Color("102d43")
		track.border_color=Color("071521")
		track.set_border_width_all(2)
		track.set_corner_radius_all(7)
		draw_style_box(track,Rect2(0,9,size.x,24))
		var fill_width: float=(size.x-8)*fraction
		if fill_width>0.0:
			var fill:=StyleBoxFlat.new()
			fill.bg_color=tint.darkened(.13)
			fill.set_corner_radius_all(4)
			draw_style_box(fill,Rect2(4,13,fill_width,16))
			draw_line(Vector2(6,14),Vector2(maxf(6,fill_width+2),14),tint.lightened(.32),2)
var _stage: Control
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
	_stage=Stage.new()
	_stage.position=Vector2(0,65)
	_stage.size=Vector2(808,835)
	_stage.clip_contents=true
	add_child(_stage)
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
	var box: StyleBox=BridgeTheme.operation_plate(6.0,"dark")
	panel.add_theme_stylebox_override("panel",box)
	add_child(panel)
	return panel

func _source_ui_rect(x: float,y: float,w: float,h: float) -> Rect2:
	var rect: Rect2=Stage.source_rect(Rect2(x,y,w,h))
	rect.position.y+=65.0
	return rect

func _build() -> void:
	_left_heading=_label(Vector2.ZERO,120,18)
	_left_heading.text="供能分配"
	_left_heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_allocation_bar=AllocationBar.new()
	_allocation_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_allocation_bar)
	_budget=_label(Vector2.ZERO,145,18)
	_budget.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_budget.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	BridgeTheme.apply_number_role(_budget,"current","dark")
	for id in Stage.IDS:
		var index: int=Stage.IDS.find(id)
		var icon_texture:=AtlasTexture.new()
		icon_texture.atlas=ICON_ATLAS
		icon_texture.region=Rect2(index*40,0,40,40)
		var icon:=TextureRect.new()
		icon.size=Vector2(28,30)
		icon.texture=icon_texture
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var name:=_label(Vector2.ZERO,99,18)
		name.text=NAMES[id]
		name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var strip:=Control.new()
		strip.size=Vector2(348,44)
		strip.mouse_filter=Control.MOUSE_FILTER_PASS
		add_child(strip)
		var track:=PowerTrack.new()
		track.size=strip.size
		track.tint=BAR_COLORS[id]
		track.mouse_filter=Control.MOUSE_FILTER_IGNORE
		strip.add_child(track)
		var slider:=HSlider.new()
		slider.name="Allocation_"+id
		slider.size=strip.size
		slider.max_value=10000
		slider.step=100
		slider.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["slider","grabber_area","grabber_area_highlight"]:
			slider.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for state in ["grabber","grabber_highlight","grabber_disabled"]:slider.add_theme_icon_override(state,SLIDER_KNOB)
		slider.value_changed.connect(_slide.bind(id))
		strip.add_child(slider)
		var ratio:=_label(Vector2(258,8),76,17,strip)
		ratio.size.y=26
		ratio.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		ratio.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		ratio.add_theme_font_override("font",BridgeTheme.public_font())
		ratio.add_theme_color_override("font_color",Color("f5f4df"))
		ratio.add_theme_color_override("font_outline_color",Color("102334"))
		ratio.add_theme_constant_override("outline_size",3)
		var effect:=_label(Vector2.ZERO,94,19)
		effect.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		effect.add_theme_font_override("font",BridgeTheme.public_font())
		BridgeTheme.apply_number_role(effect,"gain","dark")
		_rows[id]={"effect":effect,"name":name,"slider":slider,"track":track,"ratio":ratio,"control":strip,"icon":icon}
		for control in _rows[id].values():control.visible=false
	_equal=_button("均分",Rect2(),func():_command(func():return _owner.distribute(_inputs.call(),_publish)))
	_equal.tooltip_text="均分供能"
	_upgrade_heading=_label(Vector2.ZERO,60,18)
	_upgrade_heading.text="等级"
	_upgrade_heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_level=_label(Vector2.ZERO,70,21)
	_level.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_level.add_theme_font_override("font",BridgeTheme.public_font())
	BridgeTheme.apply_number_role(_level,"current","dark")
	_cost=_label(Vector2.ZERO,220,17)
	_cost.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_cost_badge=Control.new()
	_cost_badge.size=Vector2(28,28)
	_cost_badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)
	_cost_icon=TextureRect.new()
	_cost_icon.size=Vector2(26,26)
	_cost_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_cost_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_cost_badge.add_child(_cost_icon)
	_cost_details=_label(Vector2.ZERO,190,18)
	_cost_details.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_cost_details.add_theme_font_override("font",BridgeTheme.public_font())
	BridgeTheme.apply_number_role(_cost_details,"cost","dark")
	_quantity=_button("×1",Rect2(),_cycle_quantity)
	_quantity.tooltip_text="选择升级数量：×1 / ×10 / MAX"
	_purchase=_button("升级",Rect2(),func():_command(_purchase_action,true),true)
	_notice_panel=_panel(Rect2(268,519,272,32),.95)
	_notice=_label(Vector2(279,521),250,17)
	_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_set_notice("")
	for button in [_purchase,_equal]:button.disabled=true
	_layout_enabled_rows([])
	_select_quantity(1,false)

func _layout_quote() -> void:
	_cost.position=_source_ui_rect(320,1207+_footer_shift,300,46).position
	_cost.size=Vector2(215,29)
	_cost_badge.position=_source_ui_rect(320,1209+_footer_shift,42,42).position
	_cost_details.position=_source_ui_rect(374 if _cost_badge.visible else 320,1207+_footer_shift,300,46).position
	_cost_details.size=Vector2(195,29)

func _select_quantity(count: int, maximum: bool) -> void:
	_purchase_count = count
	_purchase_max = maximum
	_quote = {}
	_quote_dirty = true
	_cost.text = "报价读取中"
	_cost_details.text = ""
	_cost_badge.visible = false
	_layout_quote()
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
		_stage.advance_visual_clock(float(context.game_time),bool(context.paused))
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
	var box: StyleBoxTexture = _notice_panel.get_theme_stylebox("panel").duplicate()
	box.modulate_color = Color(1.10,0.78,0.72) if rejected else Color.WHITE
	_notice_panel.add_theme_stylebox_override("panel",box)
	BridgeTheme.apply_number_role(_notice,"insufficient" if rejected else "current","dark")

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
	var layout: Dictionary=_console_layouts[str(maxi(ids.size(),1))]
	var header_y: float=float(layout.header_y)
	var offset: float=header_y-819.0
	_footer_shift=float(layout.footer_y)-1230.0
	_left_heading.position=_source_ui_rect(100,header_y-22,190,44).position
	_left_heading.size=Vector2(120,28)
	_left_heading.visible=not ids.is_empty()
	var meter_rect:=_source_ui_rect(320,header_y-18,350,36)
	_allocation_bar.position=meter_rect.position
	_allocation_bar.size=meter_rect.size
	_budget.position=_source_ui_rect(680,header_y-22,230,44).position
	_budget.size=Vector2(145,28)
	var equal_rect:=_source_ui_rect(940,header_y-35,166,70)
	_equal.position=equal_rect.position
	_equal.size=equal_rect.size
	for index in ids.size():
		var id: String=str(ids[index])
		var center_y: float=914.0+offset+float(index)*72.0
		_rows[id].icon.position=_source_ui_rect(94,center_y-24,44,48).position
		_rows[id].name.position=_source_ui_rect(160,center_y-22,160,44).position
		_rows[id].name.size=Vector2(100,28)
		_rows[id].control.position=_source_ui_rect(328,center_y-35,552,70).position
		_rows[id].effect.position=_source_ui_rect(958,center_y-22,148,44).position
		_rows[id].effect.size=Vector2(94,28)
	_upgrade_heading.position=_source_ui_rect(100,1207+_footer_shift,85,46).position
	_level.position=_source_ui_rect(205,1204+_footer_shift,75,50).position
	var quantity_rect:=_source_ui_rect(714,1195+_footer_shift,130,70)
	_quantity.position=quantity_rect.position
	_quantity.size=quantity_rect.size
	var purchase_rect:=_source_ui_rect(866,1195+_footer_shift,240,70)
	_purchase.position=purchase_rect.position
	_purchase.size=purchase_rect.size
	_layout_quote()

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
			_rows[id].ratio.position.x=12.0 if float(row.ratio)>0.7 else 258.0
			_rows[id].ratio.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if float(row.ratio)>0.7 else HORIZONTAL_ALIGNMENT_RIGHT
		if new_row or previous.get("can_allocate", false) != _model.can_allocate:
			_rows[id].slider.editable = _running and bool(_model.can_allocate)
		if new_row or old_row.get("factor") != row.factor:
			_rows[id].effect.text = "×" + PlayerText.number(str(row.factor))
			_rows[id].effect.tooltip_text = "增益 ×" + str(row.factor)
		if new_row or old_row.get("ratio") != row.ratio or old_row.get("manual") != row.manual or old_row.get("free") != row.free or old_row.get("effective") != row.effective:
			_rows[id].slider.tooltip_text = "分配 " + _ratio_text(float(row.ratio)) + " · 手动 " + str(row.manual) + " / 免费 " + str(row.free) + " / 有效 " + str(row.effective)
	var level_text := PlayerText.resource_number(str(_model.level))
	var budget_text := PlayerText.resource_number(str(_model.allocated)) + " / " + PlayerText.resource_number(str(_model.capacity))
	var detail := "容量 " + str(_model.capacity) + " / 已分配 " + str(_model.allocated) + " / 剩余 " + str(_model.remaining)
	if _level.text != level_text: _level.text = level_text
	if _budget.text != budget_text: _budget.text = budget_text
	var level_detail: String="等级 "+str(_model.level)+"\n"+detail
	if _level.tooltip_text != level_detail: _level.tooltip_text = level_detail
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
	_update_buttons()

func _refresh_quote() -> void:
	_quote_dirty = false
	_cost_details.text = ""
	_cost_badge.visible = false
	_layout_quote()
	_cost.add_theme_color_override("font_color",Color("dcebe4"))
	_cost.add_theme_font_override("font",_ui_font_bold)
	BridgeTheme.apply_number_role(_cost_details, "cost","dark")
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
		var cost_text: String = PlayerText.resource_number(str(integer_costs[id])) if integer_costs.get(id) is String else PlayerText.resource_number(str(quote.costs[id]))
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
		BridgeTheme.apply_number_role(_cost_details, "insufficient" if poor else "cost","dark")
		if quote.costs.size() == 1:
			var resource_id: String = str(quote.costs.keys()[0])
			_cost_icon.texture = ResourceVisuals.icon(resource_id)
			_cost_icon.modulate = ResourceVisuals.icon_modulate(resource_id)
			_cost_badge.visible = _cost_icon.texture != null
		_layout_quote()
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
