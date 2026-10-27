extends VBoxContainer

var _galaxy
var _pending_full: bool = false
var _pending_keys: Dictionary = {}
var _labels: Dictionary = {}
var _picker := OptionButton.new()
var _map
var _map_key: String = ""
var _visual_context: Callable
var _detail := Label.new()
var _visual_refresh: float = 0.0
var _assignment
var _crew_provider
var _coordinate:Callable
var _host:Callable
var _scene:=Control.new()
var _readout:=PanelContainer.new()
var _summary:=VBoxContainer.new()
var _inspector:=PanelContainer.new()
var _operations:=PanelContainer.new()

func _init(galaxy, visual_context: Callable = Callable(), crew=null, coordinate:Callable=Callable(), command:Callable=Callable()) -> void:
	_galaxy = galaxy
	_visual_context = visual_context
	_crew_provider=crew;_coordinate=coordinate;_host=command
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	_galaxy.status_changed.connect(_queue_status)
	_galaxy.availability_changed.connect(_queue_status)
	if _crew_provider!=null:_crew_provider.members_changed.connect(_crew_changed)
	_queue_status()

func _crew_changed(_ids:Array) -> void:
	# The visible inspector reads its own selected region; no domain broadcast.
	_visual_refresh=1.0

func _queue_status(keys: Array = []) -> void:
	if keys.is_empty(): _pending_full = true
	for key in keys: _pending_keys[key] = true

func _refresh_status(keys: Array = []) -> void:
	for row in _galaxy.status_rows(keys):
		if not _labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_summary.add_child(label)
			_labels[row.id] = label
		_labels[row.id].text = row.text

static func describe_error(reason: String) -> String:
	return "星系尚未开放" if reason == "GalaxyUnavailable" else ""

func _ready()->void:
	process_priority=1
	_scene.custom_minimum_size.y=480;_scene.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(_scene);_scene.resized.connect(_layout_scene)
	if DisplayServer.get_name()!="headless":
		_map=preload("res://scripts/galaxy_map.gd").new();_scene.add_child(_map);_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_map.slot_selected.connect(_show_slot)
	_scene.add_child(_readout)
	var header:=VBoxContainer.new();_readout.add_child(header);header.add_child(_picker);header.add_child(_summary)
	_picker.item_selected.connect(func(_index):_inspector.hide();_select_map())
	var actions:=HBoxContainer.new();header.add_child(actions)
	var reset:=Button.new();reset.text="归中";actions.add_child(reset);reset.pressed.connect(func():
		if _map!=null:_map.zoom=1.0;_map.pan=Vector2.ZERO;_map.layout())
	var control:=Button.new();control.text="星系指挥";actions.add_child(control);control.pressed.connect(func():_operations.visible=not _operations.visible;_inspector.hide())
	_scene.add_child(_inspector);_inspector.hide()
	var details:=VBoxContainer.new();_inspector.add_child(details)
	var close:=Button.new();close.text="返回星系视图";details.add_child(close);close.pressed.connect(func():_inspector.hide())
	_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(_detail)
	_scene.add_child(_operations);_operations.hide()
	var command:=VBoxContainer.new();_operations.add_child(command)
	var back:=Button.new();back.text="返回星系视图";command.add_child(back);back.pressed.connect(func():_operations.hide())
	if _crew_provider!=null and _coordinate.is_valid():
		_assignment=preload("res://src/ui/assignment_controls.gd").new(_crew_provider,_coordinate,_host);command.add_child(_assignment)
	var help:=Label.new();help.text="拖动平移 · 滚轮缩放 · 点击地基或设施查看详情";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(help);help.hide()
	var manual:=Button.new();manual.text="地图操作说明";details.add_child(manual);manual.pressed.connect(func():help.visible=not help.visible)
	_layout_scene()
func _layout_scene()->void:
	_readout.position=Vector2(14,14);_readout.size=Vector2(minf(400,_scene.size.x-28),160)
	for panel in [_inspector,_operations]:
		panel.position=Vector2(maxf(14,_scene.size.x-354),188);panel.size=Vector2(minf(340,_scene.size.x-28),maxf(220,_scene.size.y-202))

func _process(dt: float) -> void:
	_flush_pending()
	if _map == null or not is_visible_in_tree(): return
	var context: Dictionary = _visual_context.call() if _visual_context.is_valid() else {}
	_map.set_running(not bool(context.get("paused", false)))
	_map.crew_count = int(context.get("galaxy_crew", {}).get(_map_key, 0))
	_visual_refresh+=maxf(dt,0.0)
	if _inspector.visible and _map.selected_slot>=0 and _visual_refresh>=0.25:
		_visual_refresh=0.0
		_show_slot(_map.selected_slot)

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	if not _pending_full and _pending_keys.is_empty(): return
	var full: bool = _pending_full
	var keys: Array = _pending_keys.keys()
	_pending_full = false
	_pending_keys = {}
	if full:
		_refresh_status()
		_refresh_picker()
	elif not keys.is_empty(): _refresh_status(keys)
	_sync_map()


func _refresh_picker() -> void:
	var selected: String = _map_key
	_picker.clear()
	for option in _galaxy.assignment_options():
		_picker.add_item(str(option.label))
		_picker.set_item_metadata(_picker.item_count - 1, option.target)
		if str(option.target) == selected: _picker.select(_picker.item_count - 1)
	_select_map()

func _select_map() -> void:
	if _picker.selected < 0 or _map == null: return
	var key: String = str(_picker.get_item_metadata(_picker.selected))
	if key == _map_key: return
	var snapshot: Dictionary = _galaxy.visual_snapshot(key)
	if snapshot.is_empty(): return
	_map_key = key
	if _assignment!=null:
		var jobs:Array=[]
		for job in _galaxy.assignment_options():
			if str(job.target)==key:jobs.append(job)
		_assignment.set_targets(jobs)
	var settings: Dictionary = {}
	for setting in snapshot.settings: settings[setting] = {"value": snapshot.settings[setting]}
	_map.configure(settings)
	_map.select(snapshot.region, snapshot.definition, snapshot.buildings)
	_detail.text = "点击星系设施查看建设状态与等级。"

func _sync_map() -> void:
	if _map_key.is_empty(): return
	var snapshot: Dictionary = _galaxy.visual_snapshot(_map_key)
	if snapshot.is_empty(): return
	_map.region = snapshot.region
	_map.refresh()
	if _map.selected_slot >= 0 and _inspector.visible: _show_slot(_map.selected_slot)

func _show_slot(id: int) -> void:
	var node:Dictionary=_galaxy.node_presentation(_map_key,id)
	_inspector.show();_operations.hide()
	if node.is_empty():_detail.text="请选择地图节点";return
	var status:String=str({"empty":"未探索","exploring":"探索中","constructing":"施工中","active":"运行中"}.get(node.state,"建设中"))
	_detail.text="%s · %s · 等级 %d\n%s +%s"%[node.name,status,node.level,node.effect,node.bonus]
	if not node.explored:_detail.text+="\n剩余探索工作量 %.1f · %s"%[node.explore_remaining,"当前可达" if node.reachable else "等待前置区域探索"]
	elif node.state=="constructing":_detail.text+="\n剩余施工工作量 %.1f"%node.construction_remaining
	if node.upgrade_remaining>0:_detail.text+="\n升级剩余工程量 %.1f · 当前级效果继续生效"%node.upgrade_remaining
	_detail.text+="\n星系人员 %d%s"%[_map.crew_count," · 缺人暂停" if _map.crew_count==0 and (node.state in ["exploring","constructing"] or node.upgrade_remaining>0) else ""]
