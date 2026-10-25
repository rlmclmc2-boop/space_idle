extends VBoxContainer

const ERRORS := {"UnknownPlanet": "尚未选择星球", "PlanetLocked": "星球尚未开放", "PlanetStationRequired": "需先领取空间站", "PlanetBuildingUnavailable": "建筑当前不可派遣施工", "PlanetBuildingNotReady": "建筑尚未完工"}
var _host: Callable
var _planet
var world_planet_picker: OptionButton
var world_building_picker: OptionButton
var _status: VBoxContainer
var _labels: Dictionary = {}

func _init(planet, cancel: Callable, publish: Callable, command: Callable) -> void:
	_host = command
	_planet = planet
	var box: Control = self
	_status = VBoxContainer.new()
	box.add_child(_status)
	world_planet_picker = OptionButton.new()
	world_planet_picker.item_selected.connect(func(_index): _refresh_world_buildings())
	box.add_child(world_planet_picker)
	var automatic := _row(box)
	_command(automatic, "开启自动探索", func(): return planet.set_automatic(str(_picker_value(world_planet_picker)), true))
	_command(automatic, "本次完成后停止", func(): return planet.set_automatic(str(_picker_value(world_planet_picker)), false))
	_command(box, "立即取消探索", func(): return cancel.call(str(_picker_value(world_planet_picker))))
	world_building_picker = OptionButton.new()
	box.add_child(world_building_picker)
	var construction := _row(box)
	_command(construction, "领取建筑", func(): return planet.claim_build(str(_picker_value(world_planet_picker)), str(_picker_value(world_building_picker)), publish))
	_planet.availability_changed.connect(refresh)
	_planet.status_changed.connect(_refresh_status)
	_planet.buildings_changed.connect(_buildings_changed)
	refresh()

func refresh() -> void:
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
