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

func _init(galaxy, visual_context: Callable = Callable()) -> void:
	_galaxy = galaxy
	_visual_context = visual_context
	_galaxy.status_changed.connect(_queue_status)
	_galaxy.availability_changed.connect(_queue_status)
	_queue_status()

func _queue_status(keys: Array = []) -> void:
	if keys.is_empty(): _pending_full = true
	for key in keys: _pending_keys[key] = true

func _refresh_status(keys: Array = []) -> void:
	for row in _galaxy.status_rows(keys):
		if not _labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(label)
			_labels[row.id] = label
		_labels[row.id].text = row.text

static func describe_error(reason: String) -> String:
	return "星系尚未开放" if reason == "GalaxyUnavailable" else ""

func _ready() -> void:
	process_priority = 1
	add_child(_picker)
	_picker.item_selected.connect(func(_index): _select_map())
	if DisplayServer.get_name() != "headless":
		_map = preload("res://scripts/galaxy_map.gd").new()
		_map.custom_minimum_size = Vector2(0, 420)
		_map.slot_selected.connect(_show_slot)
		add_child(_map)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail)
	var help := Label.new()
	help.text = "拖动平移 · 滚轮缩放 · 点击设施查看详情
在船员页派遣星系建设船员，探索、施工与升级会持续推进。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)

func _process(dt: float) -> void:
	_flush_pending()
	if _map == null or not is_visible_in_tree(): return
	var context: Dictionary = _visual_context.call() if _visual_context.is_valid() else {}
	_map.set_running(not bool(context.get("paused", false)))
	_map.crew_count = int(context.get("galaxy_crew", {}).get(_map_key, 0))
	_visual_refresh += dt
	if _visual_refresh >= 0.2:
		_visual_refresh = 0.0
		_sync_map()

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
	if _map.selected_slot >= 0: _show_slot(_map.selected_slot)

func _show_slot(id: int) -> void:
	if _map == null or _map.region == null or not _map.region.nodes.has(str(id)): return
	var slot: Dictionary = _map.region.nodes[str(id)]
	var status: String = str({"empty": "未探索", "exploring": "探索中", "constructing": "施工中", "active": "运行中"}.get(slot.state, "建设中"))
	var name: String = str(_map.buildings.get(str(slot.building), {}).get("name", "未知区域"))
	_detail.text = "%s · %s · 等级 %d" % [name, status, int(slot.level)]
	if float(slot.upgrade_remaining) > 0.0: _detail.text += " · 升级剩余 %.1f" % float(slot.upgrade_remaining)
