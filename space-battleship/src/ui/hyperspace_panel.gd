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
var _filter_type: OptionButton
var _filter_value: LineEdit
var _filter_mode: OptionButton
var _filter_action: OptionButton
var _filter_enabled: CheckBox
var _legend_option: OptionButton
var _forge_target: LineEdit
var _forge_guaranteed: CheckBox

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
	_filter_enabled = CheckBox.new()
	_filter_enabled.text = "启用新奖励过滤"
	add_child(_filter_enabled)
	_filter_mode = OptionButton.new()
	for item in ["all", "any"]: _filter_mode.add_item(item)
	add_child(_filter_mode)
	_filter_action = OptionButton.new()
	for item in ["keep_matches", "clear_matches"]: _filter_action.add_item(item)
	add_child(_filter_action)
	_filter_type = OptionButton.new()
	for item in ["weapon", "quality", "minimum_level", "affix", "legendary_effect"]: _filter_type.add_item(item)
	add_child(_filter_type)
	_filter_value = LineEdit.new()
	_filter_value.placeholder_text = "条件值；词缀用 ID:阶级"
	add_child(_filter_value)
	_button("加入过滤条件", func(): return _append_filter())
	_button("应用过滤开关", func(): return _apply_filter())
	_button("清空过滤条件", func(): return _clear_filter())
	var filter_text := LineEdit.new()
	filter_text.placeholder_text = "SPACE-FILTER-v2 分享字符串"
	add_child(filter_text)
	_button("导入过滤规则", func(): return _import_filter(filter_text.text))
	_button("导出过滤规则", func():
		filter_text.text = _session.hyperspace_system.export_filter()
		return {"ok": true})
	_warehouse = ItemList.new()
	_warehouse.custom_minimum_size = Vector2(350, 130)
	_warehouse.select_mode = ItemList.SELECT_MULTI
	add_child(_warehouse)
	_button("装备所选无人机", func(): return _session.equip_hyperspace_drones(_selected_ids()))
	_button("收藏所选无人机", func():
		var ids: Array = _selected_ids()
		return _session.hyperspace_system.set_favorite(str(ids[0]), true) if ids.size() == 1 else {"ok": false, "reason": "SelectOneDrone"})
	_button("取消所选收藏", func():
		var ids: Array = _selected_ids()
		return _session.hyperspace_system.set_favorite(str(ids[0]), false) if ids.size() == 1 else {"ok": false, "reason": "SelectOneDrone"})
	_button("拆解所选无人机", func():
		var ids: Array = _selected_ids()
		return _session.dismantle_hyperspace_drone(str(ids[0])) if ids.size() == 1 else {"ok": false, "reason": "SelectOneDrone"})
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
	var exchange_source := OptionButton.new()
	var exchange_target := OptionButton.new()
	for material in _session.hyperspace_system.material_ids():
		exchange_source.add_item(material)
		exchange_target.add_item(material)
	add_child(exchange_source)
	add_child(exchange_target)
	var exchange_amount := LineEdit.new()
	exchange_amount.placeholder_text = "兑换目标数量"
	add_child(exchange_amount)
	_button("兑换材料 2:1", func():
		return _session.exchange_hyperspace_materials(exchange_source.get_item_text(exchange_source.selected),
			exchange_target.get_item_text(exchange_target.selected), exchange_amount.text))
	_legend_option = OptionButton.new()
	add_child(_legend_option)
	_button("收藏所选传说", func(): return _set_legend(true))
	_button("取消所选传说收藏", func(): return _set_legend(false))
	_operation = OptionButton.new()
	for operation in ["add_affix", "replace_affix", "add_hanging_slot", "lock_affix", "promote_affix", "reroll_values", "enable_omen", "disable_omen", "legendary", "modernize", "ultimate", "restore_ultimate"]:
		_operation.add_item(operation)
	add_child(_operation)
	_forge_target = LineEdit.new()
	_forge_target.placeholder_text = "定向词缀/传说 ID，或现代化目标层"
	add_child(_forge_target)
	_forge_guaranteed = CheckBox.new()
	_forge_guaranteed.text = "数值重抽保底最大值"
	add_child(_forge_guaranteed)
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

func _filter_choice() -> Dictionary:
	var condition: Dictionary = {"field": _filter_type.get_item_text(_filter_type.selected)}
	if condition.field == "affix":
		var parts: PackedStringArray = _filter_value.text.split(":", false)
		if parts.size() != 2 or not parts[1].is_valid_int(): return {}
		condition.key = parts[0]
		condition.tier = int(parts[1])
	elif condition.field == "minimum_level":
		if not _filter_value.text.is_valid_int(): return {}
		condition.value = int(_filter_value.text)
	else: condition.value = _filter_value.text
	return condition

func _filter_candidate() -> Dictionary:
	var candidate: Dictionary = _session.hyperspace_system.filter_configuration()
	candidate.enabled = _filter_enabled.button_pressed
	candidate.mode = _filter_mode.get_item_text(_filter_mode.selected)
	candidate.action = _filter_action.get_item_text(_filter_action.selected)
	return candidate

func _append_filter() -> Dictionary:
	var condition: Dictionary = _filter_choice()
	if condition.is_empty(): return {"ok": false, "reason": "InvalidFilterCondition"}
	var candidate: Dictionary = _filter_candidate()
	candidate.conditions.append(condition)
	return _session.hyperspace_system.set_filter(candidate)

func _apply_filter() -> Dictionary:
	return _session.hyperspace_system.set_filter(_filter_candidate())

func _clear_filter() -> Dictionary:
	var candidate: Dictionary = _filter_candidate()
	candidate.enabled = false
	candidate.conditions = []
	_filter_enabled.button_pressed = false
	return _session.hyperspace_system.set_filter(candidate)

func _import_filter(value: String) -> Dictionary:
	var result: Dictionary = _session.hyperspace_system.import_filter(value)
	if result.ok:
		var candidate: Dictionary = _session.hyperspace_system.filter_configuration()
		_filter_enabled.button_pressed = candidate.enabled
		_filter_mode.select(0 if candidate.mode == "all" else 1)
		_filter_action.select(0 if candidate.action == "keep_matches" else 1)
	return result

func _forge(preview: bool) -> Dictionary:
	var ids: Array = _selected_ids()
	if ids.size() != 1: return {"ok": false, "reason": "SelectOneDrone"}
	var operation: String = _operation.get_item_text(_operation.selected)
	var args: Dictionary = {}
	if operation == "replace_affix" and not _forge_target.text.is_empty(): args.target_affix = _forge_target.text
	if operation == "legendary" and not _forge_target.text.is_empty(): args.target_effect = _forge_target.text
	if operation == "reroll_values" and _forge_guaranteed.button_pressed: args.guaranteed = true
	if preview:
		var forecast: Dictionary = _session.preview_hyperspace_forge(str(ids[0]), operation, args)
		_forecast.text = "费用 %s · 抽数 %d" % [JSON.stringify(forecast.costs), int(forecast.draws)] if forecast.ok else str(forecast.get("reason", "操作失败"))
		return forecast
	return _session.forge(str(ids[0]), operation, args, str(Time.get_ticks_usec()))

func _set_legend(collected: bool) -> Dictionary:
	if _legend_option.item_count == 0: return {"ok": false, "reason": "LegendNotSeen"}
	return _session.hyperspace_system.set_legend_collected(str(_legend_option.get_item_metadata(_legend_option.selected)), collected)

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
	var selected_legend: String = str(_legend_option.get_item_metadata(_legend_option.selected)) if _legend_option.item_count > 0 else ""
	_legend_option.clear()
	var legends: Dictionary = _session.hyperspace_system.legend_collection()
	for effect_id in legends.seen:
		_legend_option.add_item("%s%s" % [effect_id, " · 收藏" if legends.collection.has(effect_id) else ""])
		_legend_option.set_item_metadata(_legend_option.item_count - 1, effect_id)
		if str(effect_id) == selected_legend: _legend_option.select(_legend_option.item_count - 1)
