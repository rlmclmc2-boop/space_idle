extends VBoxContainer

const ERRORS := {"UnknownPlanet": "尚未选择星球", "PlanetLocked": "星球尚未开放", "PlanetStationRequired": "需先领取空间站", "PlanetBuildingUnavailable": "建筑当前不可派遣施工", "PlanetBuildingNotReady": "建筑尚未完工"}
var _host: Callable
var _planet
var _pending_full: bool = false
var _pending_all_status: bool = false
var _pending_status: Dictionary = {}
var _pending_buildings: Dictionary = {}
var world_planet_picker: OptionButton
var world_building_picker: OptionButton
var _status: VBoxContainer
var _labels: Dictionary = {}
var _visual
var _visual_context: Callable
var _visual_id: String = ""
var _visual_degree: int = -1
var _visual_refresh: float = 0.0
var _facility_cards:=VBoxContainer.new()
var _facilities:Dictionary={}
var _assignment
var _claim:Callable
var _exploration:=ProgressBar.new()
var _exploration_text:=Label.new()

func _init(planet, cancel: Callable, publish: Callable, command: Callable, visual_context: Callable = Callable(), crew=null, coordinate:Callable=Callable()) -> void:
	_host = command
	_planet = planet
	_visual_context = visual_context
	_claim=publish
	preload("res://src/ui/module_widgets.gd").heading(self,"行星探测与轨道设施","探索、施工、待领取与已生效设施分别显示")
	_exploration.max_value=1;_exploration.show_percentage=false;add_child(_exploration)
	_exploration_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_exploration_text)
	var box: Control = self
	_status = VBoxContainer.new()
	box.add_child(_status)
	world_planet_picker = OptionButton.new()
	world_planet_picker.item_selected.connect(func(_index): _queue_buildings([str(_picker_value(world_planet_picker))]))
	box.add_child(world_planet_picker)
	var automatic := _row(box)
	_command(automatic, "开启自动探索", func(): return planet.set_automatic(str(_picker_value(world_planet_picker)), true))
	_command(automatic, "本次完成后停止", func(): return planet.set_automatic(str(_picker_value(world_planet_picker)), false))
	_command(box, "立即取消探索", func(): return cancel.call(str(_picker_value(world_planet_picker))))
	world_building_picker = OptionButton.new()
	box.add_child(world_building_picker)
	var facilities:=ScrollContainer.new();facilities.custom_minimum_size.y=420;facilities.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(facilities)
	_facility_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;facilities.add_child(_facility_cards)
	if crew!=null and coordinate.is_valid():
		_assignment=preload("res://src/ui/assignment_controls.gd").new(crew,coordinate,command);add_child(_assignment)
	var construction := _row(box)
	_command(construction, "领取建筑", func(): return planet.claim_build(str(_picker_value(world_planet_picker)), str(_picker_value(world_building_picker)), publish))
	_planet.availability_changed.connect(refresh)
	_planet.status_changed.connect(_queue_status)
	_planet.buildings_changed.connect(_queue_buildings)
	refresh()

func refresh() -> void:
	_pending_full = true

func _queue_status(ids: Array = []) -> void:
	if ids.is_empty(): _pending_all_status = true
	for id in ids: _pending_status[id] = true

func _queue_buildings(ids: Array) -> void:
	for id in ids: _pending_buildings[id] = true

func _refresh_all() -> void:
	var selected: String = str(_picker_value(world_planet_picker))
	world_planet_picker.clear()
	for option in _planet.planet_options():
		var index: int = world_planet_picker.item_count
		world_planet_picker.add_item(option.name)
		world_planet_picker.set_item_metadata(index, option.id)
		if str(option.id) == selected: world_planet_picker.select(index)
	_refresh_world_buildings()
	_refresh_status()

func _refresh_world_buildings() -> void:
	var selected: String = str(_picker_value(world_building_picker))
	world_building_picker.clear()
	for option in _planet.building_options(str(_picker_value(world_planet_picker))):
		var index: int = world_building_picker.item_count
		world_building_picker.add_item(option.name)
		world_building_picker.set_item_metadata(index, option.id)
		if str(option.id) == selected: world_building_picker.select(index)
	_refresh_facilities()

func _buildings_changed(ids: Array) -> void:
	if str(_picker_value(world_planet_picker)) in ids: _refresh_world_buildings()

func _refresh_status(ids: Array = []) -> void:
	for row in _planet.status_rows(ids):
		if not _labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_status.add_child(label)
			_labels[row.id] = label
		_labels[row.id].text = row.text

func _picker_value(picker: OptionButton, fallback = ""):
	return fallback if picker.selected < 0 else picker.get_item_metadata(picker.selected)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _command(parent: Control, text: String, action: Callable):
	return _host.call(parent, text, func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "")))
		if not result.get("ok", false) and ERRORS.has(reason): result.message = ERRORS[reason]
		return result)

static func describe_error(reason: String) -> String:
	return str(ERRORS.get(reason, ""))

func _ready() -> void:
	process_priority = 1
	if DisplayServer.get_name() != "headless":
		_visual = preload("res://scripts/planet_visual.gd").new()
		_visual.custom_minimum_size = Vector2(0, 260)
		_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_visual)
		move_child(world_planet_picker,2)
		move_child(_visual,3)

func _process(dt: float) -> void:
	_flush_pending()
	if _visual == null or not is_visible_in_tree(): return
	var context: Dictionary = _visual_context.call() if _visual_context.is_valid() else {}
	_visual_refresh += dt
	var id: String = str(_picker_value(world_planet_picker))
	if id != _visual_id or _visual_refresh >= 0.2:
		_visual_refresh = 0.0
		_refresh_facilities()
		var snapshot: Dictionary = _planet.visual_snapshot(id)
		if not snapshot.is_empty():
			_exploration.value=float(snapshot.elapsed)/maxf(0.0001,float(snapshot.duration))
			_exploration_text.text="探索度 %d · %s · %.1f / %.1f秒"%[snapshot.exploration,"正在探索" if snapshot.running else "等待派遣或任务停止",snapshot.elapsed,snapshot.duration]
		_visual.visible = not snapshot.is_empty()
		if not snapshot.is_empty():
			var degree: int = int(snapshot.exploration)
			if id != _visual_id:
				_visual.clear_transients()
				_visual_degree = degree
			_visual.configure(id, snapshot.row)
			_visual.set_exploration(snapshot.running, degree, snapshot.elapsed)
			if degree > _visual_degree and _visual.globe.material_ready: _visual.complete()
			_visual_degree = degree
		_visual_id = id
	_visual.advance(dt * float(context.get("speed", 1.0)), bool(context.get("paused", false)))

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	if not _pending_full and not _pending_all_status and _pending_status.is_empty() and _pending_buildings.is_empty(): return
	var full: bool = _pending_full
	var all_status: bool = _pending_all_status
	var status: Array = _pending_status.keys()
	var buildings: Array = _pending_buildings.keys()
	_pending_full = false
	_pending_all_status = false
	_pending_status = {}
	_pending_buildings = {}
	if full:
		_refresh_all()
		return
	if not buildings.is_empty(): _buildings_changed(buildings)
	if all_status: _refresh_status()
	elif not status.is_empty(): _refresh_status(status)

func _refresh_facilities()->void:
	var planet:String=str(_picker_value(world_planet_picker))
	var active:Dictionary={}
	for row in _planet.building_options(planet):
		var key:String=planet+":"+str(row.id);active[key]=true
		if not _facilities.has(key):
			var card=preload("res://src/ui/module_widgets.gd").plate(_facility_cards)
			var line:=HBoxContainer.new();card.add_child(line)
			var icons:Dictionary={"space_station":"station","auto_explore":"scout","refinery":"refinery","equipment":"equipment","shipyard":"shipyard"}
			preload("res://src/ui/module_widgets.gd").image(line,"res://assets/planets/orbital/%s-v1.png"%str(icons.get(row.type,"station")),Vector2(90,90))
			var info=preload("res://src/ui/module_widgets.gd").label(line,"",18);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var bar:=ProgressBar.new();bar.max_value=1;bar.show_percentage=false;card.add_child(bar)
			var claim:Button=_command(card,"领取设施",func():return _planet.claim_build(planet,str(row.id),_claim))
			var staff:Button=_command(card,"选择施工派遣",func():
				if _assignment!=null:_assignment.select_target(key)
				return {"ok":true,"message":"在船员派遣区选择成员并提交施工任务"})
			_facilities[key]={"card":card.get_parent(),"info":info,"bar":bar,"claim":claim,"staff":staff}
		var view:Dictionary=_facilities[key]
		view.info.text=str(row.name)+"\n探索门槛 %d · 额外施工人员 %d\n%s\n%s"%[row.unlock,row.extra_crew,row.description,"领取后生效" if row.state!="built" else "已领取并生效"]
		view.bar.value=float(row.work)/maxf(1,float(row.required))
		view.claim.disabled=row.state!="ready"
		view.claim.text="领取设施" if row.state=="ready" else "已领取" if row.state=="built" else "施工未完成" if row.state=="building" else "尚未达到探索门槛"
		view.staff.visible=row.state=="building" and row.extra_crew>0 and _assignment!=null
	for key in _facilities:_facilities[key].card.visible=active.has(key)
	if _assignment!=null:_assignment.set_targets(_planet.assignment_options([planet]))
