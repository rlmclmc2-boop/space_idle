extends VBoxContainer
const EconomyView=preload("res://src/ui/economy_view.gd")
var module_picker:=OptionButton.new()
var allocation_input:=LineEdit.new()
var _reactor
var _inputs:Callable
var _context:Callable
var _host_command:Callable
var _stage
var _quote:=Label.new()
var _detail:=Label.new()
var _pending_choices:bool=true
var _elapsed:float=0.0
var _model:Dictionary={}
var _display_pending:bool=true
var _selection_open:bool=false
func _init(reactor,inputs:Callable,pay:Callable,publish:Callable,command:Callable,context:Callable=Callable())->void:
	_reactor=reactor;_inputs=inputs;_context=context;_host_command=command
	preload("res://src/ui/module_widgets.gd").heading(self,"反应炉机房")
	_stage=preload("res://src/ui/reactor_stage.gd").new();add_child(_stage)
	add_child(module_picker);module_picker.hide()
	var core:=VBoxContainer.new();_stage.add_child(core);_stage.core_controls=core
	_quote.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;core.add_child(_quote)
	_command(core,"核心升级 1 级",func():return reactor.purchase(1,false,inputs.call(),pay,publish))
	_command(core,"所有设备均分",func():return reactor.distribute(inputs.call(),publish))
	var frame:=PanelContainer.new();_stage.add_child(frame);_stage.editor=frame
	var box:=VBoxContainer.new();frame.add_child(box)
	var close:=Button.new();close.text="收起供能控制";box.add_child(close);close.pressed.connect(func():_selection_open=false)
	_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(_detail)
	var allocation:=HBoxContainer.new();box.add_child(allocation)
	allocation_input.placeholder_text="候选手动量";allocation_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;allocation.add_child(allocation_input)
	_command(allocation,"应用",func():return reactor.allocate_text(_selected(),allocation_input.text,inputs.call(),publish))
	var adjust:=HBoxContainer.new();box.add_child(adjust)
	_command(adjust,"减少",func():return reactor.adjust_allocation(_selected(),-1,inputs.call(),publish))
	_command(adjust,"增加",func():return reactor.adjust_allocation(_selected(),1,inputs.call(),publish))
	_command(adjust,"清零",func():return reactor.allocate_text(_selected(),"0",inputs.call(),publish))
	var preview:=HSlider.new();preview.min_value=0;preview.max_value=1;preview.step=0.01;preview.tooltip_text="候选比例，应用后才生效";box.add_child(preview)
	preview.value_changed.connect(func(ratio:float):allocation_input.text=reactor.allocation_preview(ratio,inputs.call()))
	_stage.module_selected.connect(func(id:String):
		_selection_open=true
		for index in module_picker.item_count:
			if str(module_picker.get_item_metadata(index))==id:module_picker.select(index)
		allocation_input.clear();_elapsed=1.0)
	_reactor.choices_changed.connect(refresh_choices)
	_reactor.presentation_changed.connect(_queue_presentation)
func _selected()->String:
	return str(module_picker.get_item_metadata(module_picker.selected)) if module_picker.selected>=0 else ""
func refresh_choices()->void:_pending_choices=true
func _refresh_choices()->void:
	var previous:String=_selected();module_picker.clear()
	for row in _reactor.panel_options():
		if row.id=="condensation" and not row.enabled:continue
		module_picker.add_item(row.name);module_picker.set_item_metadata(module_picker.item_count-1,row.id)
		module_picker.set_item_disabled(module_picker.item_count-1,not row.enabled)
		if row.id==previous:module_picker.select(module_picker.item_count-1)
func _command(parent:Control,title:String,action:Callable)->Button:
	return _host_command.call(parent,title,func():
		var result:Dictionary=action.call()
		if not result.get("ok",false) and not result.has("message"):
			var explanation:String=EconomyView.describe_error(str(result.get("reason","")))
			if not explanation.is_empty():result.message=explanation
		elif result.get("ok",false):
			var current:Dictionary=_reactor.presentation_model(_inputs.call())
			result.message="核心 Lv.%d · 可分配 %s"%[current.get("level",0),current.get("remaining","—")]
			if title in ["应用","增加","减少","清零"]:
				for row in current.get("modules",[]):
					if row.id==_selected():result.message="%s · 手动 %s · 有效 %s"%[row.name,row.allocation,row.effective]
		_elapsed=1.0
		return result)
func _ready()->void:process_priority=1
func _flush_pending()->void:
	if is_visible_in_tree() and _pending_choices:_pending_choices=false;_refresh_choices()
func _process(dt:float)->void:
	_flush_pending()
	if not is_visible_in_tree():
		if _stage._core!=null:_stage._core.set_process(false)
		return
	if _display_pending:
		_model=_reactor.presentation_model(_inputs.call());_display_pending=false
	var model:Dictionary=_model
	var context:Dictionary=_context.call() if _context.is_valid() else {}
	_stage.selected=_selected() if _selection_open else "";_stage.set_model(model,not bool(context.get("paused",false)),float(context.get("time",0)))
	_quote.text="核心下一级："+str(model.get("price","—"))
	for row in model.get("modules",[]):
		if row.id==_selected():_detail.text=row.name+" · 手动量";_stage.editor.visible=row.enabled and _selection_open

func _queue_presentation()->void:_display_pending=true
