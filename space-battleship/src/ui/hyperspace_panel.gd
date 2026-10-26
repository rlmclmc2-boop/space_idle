extends VBoxContainer

var _session
var _command: Callable
var _route: OptionButton
var _warehouse: ItemList
var _preset_name: LineEdit
var _operation: OptionButton
var _pending_refresh: float = 0.0
var _ids: Array = []
var _status: Label
var _forecast: Label
var _modules: ItemList
var _module_ids: Array = []

func _init(session, command: Callable) -> void:
	_session = session
	_command = command

func _ready() -> void:
	var heading := Label.new()
	heading.text = "超空间 · 编队 / 挂机 / 无人机"
	add_child(heading)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_route = OptionButton.new()
	for route in _session.hyperspace_system.routes():
		_route.add_item("%s · %s" % [route.route, route.weapon])
		_route.set_item_metadata(_route.item_count - 1, route.route)
	add_child(_route)
	_button("开始手动挑战", func(): return _session.start_hyperspace_manual(_route_id()))
	_button("退出手动挑战", _session.exit_hyperspace_manual)
	_button("单次挂机", func(): return _session.start_hyperspace_single(_route_id()))
	var crew_id := LineEdit.new()
	crew_id.placeholder_text = "自动挂机船员 ID"
	add_child(crew_id)
	_button("开始自动挂机", func(): return _session.start_hyperspace_auto(_route_id(), crew_id.text))
	_button("停止自动挂机", _session.stop_hyperspace_auto)
	_button("领取手动奖励", func(): return _claim("manual"))
	_button("领取挂机奖励", func(): return _claim("idle"))
	var filter_text := LineEdit.new()
	filter_text.placeholder_text = "SPACE-FILTER-v2 分享字符串"
	add_child(filter_text)
	_button("导入过滤规则", func(): return _session.hyperspace_system.import_filter(filter_text.text))
	_button("导出过滤规则", func():
		filter_text.text = _session.hyperspace_system.export_filter()
		return {"ok": true})
	_warehouse = ItemList.new()
	_warehouse.custom_minimum_size = Vector2(350, 130)
	_warehouse.select_mode = ItemList.SELECT_MULTI
	add_child(_warehouse)
	_button("装备所选无人机", func(): return _session.equip_hyperspace_drones(_selected_ids()))
	_button("整理仓库", func(): return {"ok": true, "moved": _session.hyperspace_system.organize()})
	_modules = ItemList.new()
	_modules.custom_minimum_size = Vector2(350, 90)
	_modules.select_mode = ItemList.SELECT_MULTI
	add_child(_modules)
	_button("为所选无人机安装挂设", func():
		var ids: Array = _selected_ids()
		if ids.size() != 1: return {"ok": false, "reason": "SelectOneDrone"}
		var modules: Array = []
		for index in _modules.get_selected_items(): modules.append(_module_ids[index])
		return _session.set_hyperspace_hangings(str(ids[0]), modules))
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "预设名称"
	add_child(_preset_name)
	_button("保存预设", func(): return _session.save_hyperspace_preset(_preset_name.text))
	_button("应用预设", func(): return _session.apply_hyperspace_preset(_preset_name.text))
	_operation = OptionButton.new()
	for operation in ["add_affix", "replace_affix", "add_hanging_slot", "lock_affix", "promote_affix", "reroll_values", "enable_omen", "disable_omen", "legendary", "ultimate", "restore_ultimate"]:
		_operation.add_item(operation)
	add_child(_operation)
	_forecast = Label.new()
	_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_forecast)
	_button("预览所选改造", func(): return _forge(true))
	_button("确认所选改造", func(): return _forge(false))
	_refresh()

func _button(title: String, action: Callable) -> void:
	_command.call(self, title, action)

func _route_id() -> String:
	return str(_route.get_item_metadata(_route.selected))

func _selected_ids() -> Array:
	var selected: Array = []
	for index in _warehouse.get_selected_items(): selected.append(_ids[index])
	return selected

func _claim(mode: String) -> Dictionary:
	var status: Dictionary = _session.hyperspace_system.manual_receipt() if mode == "manual" else _session.hyperspace_system.online_status().idle
	if status.is_empty(): return {"ok": false, "reason": "NoReward"}
	return _session.claim_hyperspace(int(status.run_id))

func _forge(preview: bool) -> Dictionary:
	var ids: Array = _selected_ids()
	if ids.size() != 1: return {"ok": false, "reason": "SelectOneDrone"}
	var operation: String = _operation.get_item_text(_operation.selected)
	if preview:
		var forecast: Dictionary = _session.preview_hyperspace_forge(str(ids[0]), operation)
		_forecast.text = "费用 %s · 抽数 %d" % [JSON.stringify(forecast.costs), int(forecast.draws)] if forecast.ok else str(forecast.get("reason", "操作失败"))
		return forecast
	return _session.forge(str(ids[0]), operation, {}, str(Time.get_ticks_usec()))

func _process(dt: float) -> void:
	_pending_refresh += dt
	if _pending_refresh >= 1.0:
		_pending_refresh = 0.0
		if is_visible_in_tree(): _refresh()

func _refresh() -> void:
	if _warehouse == null: return
	var online: Dictionary = _session.hyperspace_system.online_status()
	var manual: Dictionary = _session.hyperspace_system.manual_receipt()
	_status.text = "手动 %s · 挂机 %s (%.1f/%.1f 秒) · 能源 %.0f" % [
		str(manual.get("status", "无")), str(online.idle.get("status", "无")),
		float(online.idle.get("work", 0.0)), float(online.idle.get("duration", 0.0)), float(online.energy)]
	var selected: Array = _selected_ids()
	_warehouse.clear()
	_ids.clear()
	var state: Dictionary = _session.hyperspace_system.warehouse()
	for drone in state.main:
		var id: String = str(drone.id)
		_ids.append(id)
		_warehouse.add_item("%s · %s · Lv%d%s" % [id, drone.weapon, int(drone.level), " · 已装备" if id in state.equipped else ""])
		if id in selected: _warehouse.select(_ids.size() - 1, false)
	var selected_modules: Array = []
	for index in _modules.get_selected_items(): selected_modules.append(_module_ids[index])
	_modules.clear()
	_module_ids.clear()
	for module_id in _session.hyperspace_system.module_growth():
		var growth: Dictionary = _session.hyperspace_system.module_growth()[module_id]
		if not growth.unlocked: continue
		_module_ids.append(module_id)
		_modules.add_item("%s · Lv%d" % [module_id, int(growth.level)])
		if module_id in selected_modules: _modules.select(_module_ids.size() - 1, false)
