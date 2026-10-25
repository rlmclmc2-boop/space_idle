extends VBoxContainer
const PlanetPanel = preload("res://src/ui/planet_panel.gd")
const GalaxyPanel = preload("res://src/ui/galaxy_panel.gd")
const ERRORS := {"HyperspaceCrewReserved": "船员仍被超空间任务占用", "CrewAssignmentUnavailable": "岗位暂不可用", "CrewLocked": "船员尚未解锁", "CrewTargetOccupied": "目标人数已满", "CrewJobLocked": "岗位尚未开放"}
var _host: Callable
var _crew
var _planet
var _galaxy
var _watch_visibility: bool = false
var _pending_full: bool = false
var _pending_targets: bool = false
var _pending_members: Dictionary = {}
var _pending_construction: Dictionary = {}
var world_status: VBoxContainer
var world_labels: Dictionary = {}
var world_crew_picker: OptionButton
var world_assignment_picker: OptionButton
var world_mode_picker: OptionButton

func _init(crew, planet, galaxy, coordinate: Callable, command: Callable) -> void:
	_crew = crew
	_planet = planet
	_galaxy = galaxy
	_host = command
	var box: Control = self
	_caption(box, "船员与星球")
	_caption(box, "随进度逐步开放星球与星系。")
	world_status = VBoxContainer.new()
	box.add_child(world_status)
	world_crew_picker = OptionButton.new()
	box.add_child(world_crew_picker)
	world_assignment_picker = OptionButton.new()
	box.add_child(world_assignment_picker)
	world_mode_picker = OptionButton.new()
	for mode in ["1", "10", "max"]:
		world_mode_picker.add_item("装备自动购买 " + mode.to_upper())
		world_mode_picker.set_item_metadata(world_mode_picker.item_count - 1, mode)
	box.add_child(world_mode_picker)
	_command(box, "派遣所选船员", func():
		var assignment: Dictionary = _picker_value(world_assignment_picker, {"kind": "", "target": ""})
		return coordinate.call(str(_picker_value(world_crew_picker)), assignment.kind, assignment.target, str(_picker_value(world_mode_picker, "1"))))
	_command(box, "撤回所选船员", func(): return coordinate.call(str(_picker_value(world_crew_picker)), "", ""))
	_command(box, "刷新发展列表", func():
		refresh()
		return {"ok": true})
	_crew.members_changed.connect(_members_changed)
	_crew.options_changed.connect(refresh)
	_planet.assignment_options_changed.connect(_refresh_construction_choices)
	_planet.availability_changed.connect(_refresh_assignments)
	_galaxy.availability_changed.connect(_refresh_assignments)
	refresh()

func _picker_value(picker: OptionButton, fallback = ""):
	return fallback if picker.selected < 0 else picker.get_item_metadata(picker.selected)

func refresh() -> void:
	if _watch_visibility and not is_visible_in_tree():
		_pending_full = true
		return
	var selected: String = str(_picker_value(world_crew_picker))
	world_crew_picker.clear()
	for option in _crew.member_options():
		var index: int = world_crew_picker.item_count
		world_crew_picker.add_item(option.name)
		world_crew_picker.set_item_metadata(index, option.id)
		if str(option.id) == selected: world_crew_picker.select(index)
	_refresh_assignments()
	_refresh_status()

func _members_changed(ids: Array) -> void:
	if _watch_visibility and not is_visible_in_tree():
		for id in ids: _pending_members[id] = true
		return
	for option in _crew.member_options(ids):
		for index in world_crew_picker.item_count:
			if world_crew_picker.get_item_metadata(index) == option.id: world_crew_picker.set_item_text(index, option.name)
	_refresh_status(ids)

func _append_assignment(option: Dictionary, previous: Dictionary) -> void:
	var value: Dictionary = option.duplicate()
	value.erase("label")
	var index: int = world_assignment_picker.item_count
	world_assignment_picker.add_item(option.label)
	world_assignment_picker.set_item_metadata(index, value)
	if value == previous: world_assignment_picker.select(index)

func _refresh_assignments() -> void:
	if _watch_visibility and not is_visible_in_tree():
		_pending_targets = true
		return
	var previous: Dictionary = _picker_value(world_assignment_picker, {})
	world_assignment_picker.clear()
	for option in _crew.job_options() + _planet.assignment_options() + _galaxy.assignment_options():
		_append_assignment(option, previous)

func _refresh_construction_choices(ids: Array) -> void:
	if _watch_visibility and not is_visible_in_tree():
		for id in ids: _pending_construction[id] = true
		return
	var previous: Dictionary = _picker_value(world_assignment_picker, {})
	for index in range(world_assignment_picker.item_count - 1, -1, -1):
		var value: Dictionary = world_assignment_picker.get_item_metadata(index)
		if value.kind == "planet_build" and value.get("group") in ids: world_assignment_picker.remove_item(index)
	for option in _planet.assignment_options(ids, true): _append_assignment(option, previous)

func _refresh_status(ids: Array = []) -> void:
	for row in _crew.status_rows(ids):
		if not world_labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			world_status.add_child(label)
			world_labels[row.id] = label
		world_labels[row.id].text = row.text

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _command(parent: Control, text: String, action: Callable):
	return _host.call(parent, text, func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "")))
		if not result.get("ok", false):
			var message: String = str(ERRORS.get(reason, PlanetPanel.describe_error(reason)))
			if message.is_empty(): message = GalaxyPanel.describe_error(reason)
			if not message.is_empty(): result.message = message
		return result)

func _ready() -> void:
	_watch_visibility = true
	visibility_changed.connect(_flush_pending)
	_flush_pending()

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	var full: bool = _pending_full
	var targets: bool = _pending_targets
	var members: Array = _pending_members.keys()
	var construction: Array = _pending_construction.keys()
	_pending_full = false
	_pending_targets = false
	_pending_members = {}
	_pending_construction = {}
	if full:
		refresh()
		return
	if targets: _refresh_assignments()
	elif not construction.is_empty(): _refresh_construction_choices(construction)
	if not members.is_empty(): _members_changed(members)
