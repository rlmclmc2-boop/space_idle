extends VBoxContainer
## Page-local access to the existing crew coordinator. No assignment rules live here.
var _crew
var _coordinate:Callable
var _host:Callable
var member:=OptionButton.new()
var target:=OptionButton.new()
var _message:=Label.new()
var _options:Array=[]
var _elapsed:float=0.0
func _init(crew,coordinate:Callable,host:Callable)->void:
	_crew=crew;_coordinate=coordinate;_host=host
	preload("res://src/ui/module_widgets.gd").label(self,"船员派遣",20)
	add_child(member);add_child(target)
	var actions:=HBoxContainer.new();add_child(actions)
	_host.call(actions,"派遣至所选任务",func():
		if member.selected<0 or target.selected<0:return {"ok":false,"message":"请选择船员与可用任务"}
		var job:Dictionary=target.get_item_metadata(target.selected)
		var result:Dictionary=_coordinate.call(str(member.get_item_metadata(member.selected)),job.kind,job.target,"1")
		if result.ok:_message.text="派遣已生效，当前岗位与进度见上方"
		return result)
	_host.call(actions,"撤回所选船员",func():
		if member.selected<0:return {"ok":false,"message":"没有可选船员"}
		return _coordinate.call(str(member.get_item_metadata(member.selected)),"",""))
	_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_message)
func set_targets(options:Array)->void:
	if options==_options:return
	var previous:String=str(target.get_item_metadata(target.selected).target) if target.selected>=0 else ""
	_options=options.duplicate(true);target.clear()
	for job in options:
		target.add_item(job.label);target.set_item_metadata(target.item_count-1,job)
		if str(job.target)==previous:target.select(target.item_count-1)
	if options.is_empty():_message.text="当前没有可派遣任务"
func select_target(id:String)->void:
	for i in target.item_count:
		if str(target.get_item_metadata(i).target)==id:target.select(i);return
func _process(dt:float)->void:
	if not is_visible_in_tree():return
	_elapsed+=dt
	if _elapsed<0.5:return
	_elapsed=0
	var previous:String=str(member.get_item_metadata(member.selected)) if member.selected>=0 else ""
	var options:Array=_crew.member_options()
	var ids:Array=[]
	for option in options:ids.append(str(option.id))
	var old:Array=[]
	for i in member.item_count:old.append(str(member.get_item_metadata(i)))
	if ids!=old:
		member.clear()
		for option in options:
			member.add_item(option.name);member.set_item_metadata(member.item_count-1,option.id)
			if str(option.id)==previous:member.select(member.item_count-1)
	else:
		for i in options.size():member.set_item_text(i,options[i].name)
