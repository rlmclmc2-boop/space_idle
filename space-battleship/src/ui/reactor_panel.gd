extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"ReactorLocked": "反应炉尚未解锁", "ReactorModuleLocked": "反应炉模块尚未开放"}
var _host_command: Callable

var module_picker: OptionButton
var allocation_input: LineEdit
var _reactor

var _pending_choices: bool = false
var _inputs:Callable
var _context:Callable
var _stage
var _quote:Label
var _elapsed:float=0.0

func _init(reactor, inputs: Callable, pay: Callable, publish: Callable, command: Callable, context:Callable=Callable()) -> void:
	_host_command = command
	_reactor = reactor
	_inputs=inputs;_context=context
	preload("res://src/ui/module_widgets.gd").heading(self,"反应炉机房","核心 → 主管 → 设备舱 · 点击设备选择供能模块")
	_stage=preload("res://src/ui/reactor_stage.gd").new();add_child(_stage)
	_stage.module_selected.connect(func(id:String):
		for i in module_picker.item_count:
			if str(module_picker.get_item_metadata(i))==id:module_picker.select(i))
	_quote=Label.new();add_child(_quote)
	var box: Control = self
	_caption(box, "反应炉")
	var reactor_buttons := _row(box)
	_command(reactor_buttons, "购买 1 级", func(): return reactor.purchase(1, false, inputs.call(), pay, publish))
	_command(reactor_buttons, "平均分配", func(): return reactor.distribute(inputs.call(), publish))
	var allocation := _row(box)
	module_picker = OptionButton.new()
	module_picker.custom_minimum_size.x=160
	allocation.add_child(module_picker)
	allocation_input = LineEdit.new()
	allocation_input.placeholder_text = "分配能源"
	allocation_input.custom_minimum_size.x = 120
	allocation.add_child(allocation_input)
	_command(allocation, "分配", func():
		return reactor.allocate_text(str(module_picker.get_item_metadata(module_picker.selected)), allocation_input.text, inputs.call(), publish))
	var adjust:=_row(box)
	_command(adjust,"减少",func():return reactor.adjust_allocation(str(module_picker.get_item_metadata(module_picker.selected)),-1,inputs.call(),publish))
	_command(adjust,"增加",func():return reactor.adjust_allocation(str(module_picker.get_item_metadata(module_picker.selected)),1,inputs.call(),publish))
	_command(adjust,"清零",func():return reactor.allocate_text(str(module_picker.get_item_metadata(module_picker.selected)),"0",inputs.call(),publish))
	var preview:=HSlider.new();preview.min_value=0;preview.max_value=1;preview.step=0.01;preview.tooltip_text="仅预览分配比例，点击分配后提交";add_child(preview)
	preview.value_changed.connect(func(ratio:float):allocation_input.text=reactor.allocation_preview(ratio,inputs.call()))
	_caption(box,"比例条只填写候选量；点击分配后才生效。")
	move_child(_stage,get_child_count()-1)
	_reactor.choices_changed.connect(refresh_choices)
	refresh_choices()

func refresh_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
	var selected: String = "" if module_picker.selected < 0 else str(module_picker.get_item_metadata(module_picker.selected))
	module_picker.clear()
	for option in _reactor.panel_options():
		var index: int = module_picker.item_count
		if option.id=="condensation" and not option.enabled:continue
		module_picker.add_item(option.name)
		module_picker.set_item_metadata(index, option.id)
		module_picker.set_item_disabled(index, not option.enabled)
		if str(option.id) == selected: module_picker.select(index)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _command(parent: Control, text: String, action: Callable):
	return _host_command.call(parent, text, func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "")))
		if not result.get("ok", false) and not result.has("message"):
			var message: String = str(ERRORS.get(reason, EconomyView.describe_error(reason)))
			if not message.is_empty(): result.message = message
		return result)

func _ready() -> void:
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()
	if not is_visible_in_tree():
		if _stage._core!=null:_stage._core.set_process(false)
		return
	_elapsed+=_dt
	if _elapsed>=0.2:
		_elapsed=0
		var model:Dictionary=_reactor.presentation_model(_inputs.call())
		var context:Dictionary=_context.call() if _context.is_valid() else {}
		_stage.set_model(model,not bool(context.get("paused",false)),float(context.get("time",0)))
		_stage.selected=str(module_picker.get_item_metadata(module_picker.selected)) if module_picker.selected>=0 else ""
		_quote.text="升至下一级："+str(model.get("price","—"))

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()
