extends VBoxContainer
const Appearance=preload("res://scripts/hyperspace_appearance.gd")
const Widgets=preload("res://src/ui/module_widgets.gd")
const PlayerText = preload("res://src/ui/player_text.gd")

var _session
var _command: Callable
var _route: OptionButton
var _warehouse: ItemList
var _warehouse_area: OptionButton
var _warehouse_summary: Label
var _preset_name: LineEdit
var _operation: OptionButton
var _pending_refresh: float = 0.0
var _ids: Array = []
var _status: Label
var _forecast: Label
var _modules: ItemList
var _module_ids: Array = []
var _filter_type: OptionButton
var _filter_value: OptionButton
var _filter_number: SpinBox
var _crew_picker: OptionButton
var _detail: Label
var _filter_summary: Label
var _page: VBoxContainer
var _section_tabs: TabContainer
var _catalog: Dictionary = {}
var _filter_mode: OptionButton
var _filter_action: OptionButton
var _filter_enabled: CheckBox
var _legend_option: OptionButton
var _forge_target: OptionButton
var _forge_guaranteed: CheckBox
var _forge_preview: Dictionary = {}
var _forge_sequence: int = 0
var _route_cards:Dictionary={}
var _route_grid:=GridContainer.new()
var _route_editor:=VBoxContainer.new()
var _route_progress:=ProgressBar.new()
var _materials:=Label.new()
var _drone_icon:=TextureRect.new()
var _forge_subject:=Label.new()
var _preset_summary:=Label.new()
var _loadout_preview:=Label.new()

func _init(session, command: Callable) -> void:
	_session = session
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	_command = command

const NAMES := {"laser": "脉冲激光", "missile": "导弹", "cannon": "舰炮", "longLaser": "长激光",
	"alpha": "阿尔法", "beta": "贝塔", "gamma": "伽马", "delta": "德尔塔",
	"degenerate_matter": "简并物质", "glueball": "胶球", "antiproton": "反质子", "zero_point_energy": "零点能", "dark_matter": "暗物质", "strange_matter": "奇异物质", "antimatter": "反物质",
	"white": "普通", "blue": "精良", "gold": "稀有", "legendary": "传说", "ultimate_core": "究极核心", "ultimate": "究极",
	"damage_laser": "激光伤害", "damage_missile": "导弹伤害", "damage_cannon": "舰炮伤害", "damage_longLaser": "长激光伤害",
	"global_damage": "全局伤害", "global_critical_damage": "暴击伤害", "global_defence": "全局防御", "critical_chance": "暴击率",
	"repeat_chance": "连发概率", "attack_speed": "攻击速度", "chain_count": "链式数量", "armour_capacity": "装甲容量", "shield_capacity": "护盾容量",
	"higgs_cannon": "希格斯炮", "scatter_pulse": "散射脉冲", "precise_guidance": "精确制导", "prism_tower": "棱镜塔",
	"laser_charge": "激光充能", "wild_missile": "狂野导弹", "endless_beam": "无尽光束", "dodge_counter": "闪避反击",
	"drone_master": "无人机大师", "black_hole": "黑洞", "drone_rebuild": "无人机重建",
	"resource_collector": "资源采集器", "distributed_algorithm": "分布式算法", "extra_storage": "扩展存储", "gem_refiner": "微粒精炼", "hyperspace_charge": "超空间充能"}
const OPERATIONS := {"add_affix": "增加词缀", "replace_affix": "替换词缀", "add_hanging_slot": "增加挂槽", "lock_affix": "锁定词缀", "promote_affix": "词缀升阶", "reroll_values": "重抽数值", "enable_omen": "开启预兆", "disable_omen": "关闭预兆", "legendary": "升为传说", "modernize": "现代化", "ultimate": "究极化", "restore_ultimate": "还原究极"}
const FIELDS := {"weapon": "武器类型", "quality": "品质", "minimum_level": "最低等级", "affix": "词缀强度", "legendary_effect": "传说效果"}

func _name(id) -> String:
	return str(NAMES.get(str(id), "未知类型"))

func _option(picker: OptionButton, title: String, value) -> void:
	picker.add_item(title)
	picker.set_item_metadata(picker.item_count - 1, value)

func _value(picker: OptionButton, fallback = ""):
	return picker.get_item_metadata(picker.selected) if picker != null and picker.selected >= 0 else fallback

func _section(title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 370
	_section_tabs.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page)

func _help(title:String,text:String)->void:
	var button:=Button.new();button.text=title;_page.add_child(button)
	var label:Label=_note(text);label.hide();button.pressed.connect(func():label.visible=not label.visible)
func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(label)
	return label

func _ready() -> void:
	Widgets.heading(self,"超空间指挥台")
	_catalog = _session.hyperspace_system.player_catalog()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_section_tabs = TabContainer.new()
	_section_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(_section_tabs)
	_section("路线")
	_help("挑战与挂机说明","手动挑战刷新最高层与最佳时间；通关后可单次挂机，指派船员可持续探索。")
	_route = OptionButton.new()
	for route in _session.hyperspace_system.routes():
		_option(_route, "%s · %s · 已通过 %d 层" % [_name(route.route), _name(route.weapon), route.cleared], route.route)
	add_child(_route);_route.hide()
	_route_grid.columns=2;_page.add_child(_route_grid)
	for route in _session.hyperspace_system.routes():
		var card:VBoxContainer=Widgets.plate(_route_grid)
		card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var icon:=TextureRect.new();icon.texture=Appearance.icon(str(route.weapon));icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(0,88);card.add_child(icon)
		var info:Label=Widgets.label(card,"",18)
		var choose:=Button.new();choose.text="查看路线";choose.toggle_mode=true;card.add_child(choose)
		choose.pressed.connect(func():
			for index in _route.item_count:
				if _route.get_item_metadata(index)==route.route:_route.select(index)
			_refresh_routes())
		_route_cards[route.route]={"body":card,"info":info,"button":choose}
	_page.add_child(_route_editor)
	_page=_route_editor
	_route_progress.max_value=1;_route_progress.show_percentage=false;_route_editor.add_child(_route_progress)
	_button("开始手动挑战", func(): return _session.start_hyperspace_manual(_route_id()))
	_button("退出手动挑战", _session.exit_hyperspace_manual)
	_button("单次挂机", func(): return _session.start_hyperspace_single(_route_id()))
	_crew_picker = OptionButton.new()
	_page.add_child(_crew_picker)
	_button("开始自动挂机", func(): return _session.start_hyperspace_auto(_route_id(), str(_value(_crew_picker))))
	_button("停止自动挂机", _session.stop_hyperspace_auto)
	_button("领取手动奖励", func(): return _claim("manual"))
	_button("领取挂机奖励", func(): return _claim("idle"))
	_section("仓库")
	_help("编队选择说明","Ctrl多选；应用时未选的原编队将卸下。单架详情、改造与拆解需要只选择一架。")
	_warehouse_summary = _note("")
	_warehouse_area = OptionButton.new()
	for entry in [["主仓", "main"], ["溢出仓", "overflow"], ["封存无人机", "sealed"]]: _option(_warehouse_area, entry[0], entry[1])
	_warehouse_area.item_selected.connect(func(_index): _refresh())
	_page.add_child(_warehouse_area)
	_warehouse = ItemList.new()
	_warehouse.custom_minimum_size = Vector2(0, 250)
	_warehouse.fixed_icon_size=Vector2i(64,64)
	_warehouse.icon_mode=ItemList.ICON_MODE_LEFT
	_warehouse.select_mode = ItemList.SELECT_MULTI
	_warehouse.item_selected.connect(func(_index): _refresh_detail())
	_warehouse.multi_selected.connect(func(_index, _selected): _refresh_detail())
	_page.add_child(_warehouse)
	var inspection:VBoxContainer=Widgets.plate(_page)
	_drone_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_drone_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_drone_icon.custom_minimum_size=Vector2(0,110);inspection.add_child(_drone_icon)
	_detail=Widgets.label(inspection,"选择一架无人机查看词缀与挂设。",17)
	_loadout_preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_page.add_child(_loadout_preview)
	_button("应用所选编队", func(): return _session.equip_hyperspace_drones(_selected_ids()))
	_button("收藏所选无人机", func(): return _favorite(true))
	_button("取消所选收藏", func(): return _favorite(false))
	_button("拆解所选无人机", func():
		var ids: Array = _selected_ids()
		return _session.dismantle_hyperspace_drone(str(ids[0])) if ids.size() == 1 else {"ok": false, "reason": "SelectOneDrone"})
	_button("领取所选封存无人机", _release_sealed)
	_button("整理溢出仓库", _organize_storage)
	_modules = ItemList.new()
	_modules.custom_minimum_size = Vector2(0, 100)
	_modules.select_mode = ItemList.SELECT_MULTI
	_page.add_child(_modules)
	_button("为所选无人机安装挂设", func():
		var ids: Array = _selected_ids()
		if ids.size() != 1: return {"ok": false, "reason": "SelectOneDrone"}
		var modules: Array = []
		for index in _modules.get_selected_items(): modules.append(_module_ids[index])
		return _session.set_hyperspace_hangings(str(ids[0]), modules))
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "编队预设名称"
	_page.add_child(_preset_name)
	_button("保存当前编队预设", func(): return _session.save_hyperspace_preset(_preset_name.text))
	_button("应用同名预设", func(): return _session.apply_hyperspace_preset(_preset_name.text))
	_preset_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_page.add_child(_preset_summary)
	_section("改造")
	_forge_subject.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_page.add_child(_forge_subject)
	_materials.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_page.add_child(_materials)
	_help("改造规则","预览不扣费；确认执行所显示的操作与费用。锁定词缀受保护。")
	_operation = OptionButton.new()
	for operation in OPERATIONS: _option(_operation, OPERATIONS[operation], operation)
	_operation.item_selected.connect(func(_index):
		_invalidate_forge_preview()
		_refresh_targets())
	_page.add_child(_operation)
	_forge_target = OptionButton.new()
	_forge_target.item_selected.connect(func(_index): _invalidate_forge_preview())
	_page.add_child(_forge_target)
	_forge_guaranteed = CheckBox.new()
	_forge_guaranteed.text = "数值重抽时保底最大值"
	_forge_guaranteed.toggled.connect(func(_pressed): _invalidate_forge_preview())
	_page.add_child(_forge_guaranteed)
	_forecast = _note("未预览当前改造")
	_button("预览所选改造", func(): return _forge(true))
	_button("确认所选改造", func(): return _forge(false))
	_legend_option = OptionButton.new()
	_page.add_child(_legend_option)
	_button("收藏所选传说", func(): return _set_legend(true))
	_button("取消所选传说收藏", func(): return _set_legend(false))
	_note("材料兑换：输入收到的目标数量，消耗两倍源材料。")
	var exchange_source := OptionButton.new()
	var exchange_target := OptionButton.new()
	for material in _session.hyperspace_system.material_ids():
		_option(exchange_source, _name(material), material)
		_option(exchange_target, _name(material), material)
	_page.add_child(exchange_source)
	_page.add_child(exchange_target)
	if exchange_target.item_count > 1: exchange_target.select(1)
	var exchange_amount := LineEdit.new()
	exchange_amount.placeholder_text = "收到的目标材料数量"
	_page.add_child(exchange_amount)
	_button("兑换材料 2:1", func(): return _session.exchange_hyperspace_materials(str(_value(exchange_source)), str(_value(exchange_target)), exchange_amount.text))
	_section("过滤")
	_help("过滤规则","只影响新奖励，最多五个条件；已装备、收藏、封存与预设引用受到保护。")
	_filter_enabled = CheckBox.new()
	_filter_enabled.text = "启用新奖励过滤"
	_page.add_child(_filter_enabled)
	_filter_mode = OptionButton.new()
	_option(_filter_mode, "满足全部条件", "all")
	_option(_filter_mode, "满足任一条件", "any")
	_page.add_child(_filter_mode)
	_filter_action = OptionButton.new()
	_option(_filter_action, "保留匹配的奖励", "keep_matches")
	_option(_filter_action, "拆解匹配的奖励", "clear_matches")
	_page.add_child(_filter_action)
	_filter_type = OptionButton.new()
	for field in FIELDS: _option(_filter_type, FIELDS[field], field)
	_filter_type.item_selected.connect(func(_index): _refresh_filter_values())
	_page.add_child(_filter_type)
	_filter_value = OptionButton.new()
	_page.add_child(_filter_value)
	_filter_number = SpinBox.new()
	_filter_number.min_value = 1
	_filter_number.max_value = 2147483647
	_filter_number.step = 1
	_page.add_child(_filter_number)
	_button("加入过滤条件", _append_filter)
	_button("应用过滤开关", _apply_filter)
	_button("清空过滤条件", _clear_filter)
	_filter_summary = _note("")
	var filter_text := LineEdit.new()
	filter_text.placeholder_text = "粘贴过滤分享码"
	_page.add_child(filter_text)
	_button("导入过滤规则", func(): return _import_filter(filter_text.text))
	_button("导出过滤规则", func():
		filter_text.text = _session.hyperspace_system.export_filter()
		return {"ok": true})
	resized.connect(func():_route_grid.columns=2 if size.x>=700 else 1)
	_sync_filter_controls()
	_refresh_filter_values()
	_refresh_targets()
	_refresh()

func _button(title: String, action: Callable) -> void:
	_command.call(_page, title, func():
		var result: Dictionary = action.call()
		if not result.get("ok", false):
			var messages := {"DroneNotSealed": "所选无人机当前没有封存。", "ClaimStageLocked": "尚未通关封存门槛关卡，请先完成关卡后再领取。", "SelectOneDrone": "请先在仓库中选择一架无人机。", "WarehouseFull": "主仓和溢出仓均已满，请先拆解未保护的无人机再领取奖励。", "ProtectedDrone": "已装备、收藏、封存或被预设引用的无人机不可拆解。", "DroneUnavailable": "所选无人机不可用于此操作；溢出项需先整理入主仓，封存项需先领取。"}
			if messages.has(str(result.get("reason", ""))): result.message = messages[str(result.reason)]
		_refresh()
		return result)

func _favorite(enabled: bool) -> Dictionary:
	var ids: Array = _selected_ids()
	return _session.hyperspace_system.set_favorite(str(ids[0]), enabled) if ids.size() == 1 else {"ok": false, "reason": "SelectOneDrone"}

func _refresh_targets() -> void:
	var chosen: String = str(_value(_forge_target))
	_forge_target.clear()
	_option(_forge_target, "随机结果", "")
	var operation: String = str(_value(_operation))
	var ids: Array = _catalog.affixes if operation == "replace_affix" else []
	if operation == "legendary": ids = _session.hyperspace_system.legend_collection().collection.keys()
	for id in ids: _option(_forge_target, _name(id), id)
	for index in _forge_target.item_count:
		if str(_forge_target.get_item_metadata(index)) == chosen: _forge_target.select(index)
	_forge_target.visible = operation in ["replace_affix", "legendary"]
	_forge_guaranteed.visible = operation == "reroll_values"

func _refresh_filter_values() -> void:
	var field: String = str(_value(_filter_type))
	_filter_value.clear()
	var values: Array = _catalog.get({"weapon": "weapons", "quality": "qualities", "affix": "affixes", "legendary_effect": "legends"}.get(field, ""), [])
	for id in values: _option(_filter_value, _name(id), id)
	_filter_value.visible = field != "minimum_level"
	_filter_number.visible = field in ["minimum_level", "affix"]
	_filter_number.max_value = 5 if field == "affix" else 2147483647
	_filter_number.prefix = "至少等级 " if field == "minimum_level" else "词缀阶数 ≤ "

func _sync_filter_controls() -> void:
	var candidate: Dictionary = _session.hyperspace_system.filter_configuration()
	_filter_enabled.button_pressed = candidate.enabled
	_filter_mode.select(0 if candidate.mode == "all" else 1)
	_filter_action.select(0 if candidate.action == "keep_matches" else 1)

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
	var condition: Dictionary = {"field": str(_value(_filter_type))}
	if condition.field == "affix":
		condition.key = str(_value(_filter_value))
		condition.tier = int(_filter_number.value)
	elif condition.field == "minimum_level": condition.value = int(_filter_number.value)
	else: condition.value = str(_value(_filter_value))
	return condition

func _filter_candidate() -> Dictionary:
	var candidate: Dictionary = _session.hyperspace_system.filter_configuration()
	candidate.enabled = _filter_enabled.button_pressed
	candidate.mode = str(_value(_filter_mode))
	candidate.action = str(_value(_filter_action))
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

func _forge_request() -> Dictionary:
	var ids: Array = _selected_ids()
	if ids.size() != 1: return {}
	var operation: String = str(_value(_operation))
	var args: Dictionary = {}
	if operation == "replace_affix" and not str(_value(_forge_target)).is_empty(): args.target_affix = str(_value(_forge_target))
	if operation == "legendary" and not str(_value(_forge_target)).is_empty(): args.target_effect = str(_value(_forge_target))
	if operation == "reroll_values" and _forge_guaranteed.button_pressed: args.guaranteed = true
	return {"id": str(ids[0]), "operation": operation, "args": args}

func _forge_source(request: Dictionary) -> String:
	if request.is_empty(): return ""
	var state: Dictionary = _session.hyperspace_system.warehouse()
	for drone in state.main + state.overflow:
		if str(drone.id) == str(request.id):
			return JSON.stringify({"drone": drone, "sealed": state.sealed.has(str(drone.id)),
				"equipped": state.equipped, "round": state.reforge_count,
				"stage": _session.campaign_system.progress_facts().cycle_reached}, "", true)
	return ""

func _invalidate_forge_preview() -> void:
	_forge_preview = {}
	if _forecast != null: _forecast.text = "选择或无人机状态已变化，请重新预览改造费用。"

func _sync_forge_preview() -> void:
	if _forge_preview.is_empty(): return
	var request: Dictionary = _forge_request()
	if JSON.stringify(request, "", true) != str(_forge_preview.fingerprint) or _forge_source(request) != str(_forge_preview.source):
		_invalidate_forge_preview()

func _forge(preview: bool) -> Dictionary:
	var request: Dictionary = _forge_request()
	if request.is_empty():
		_invalidate_forge_preview()
		return {"ok": false, "reason": "SelectOneDrone"}
	if preview:
		_invalidate_forge_preview()
		var forecast: Dictionary = _session.preview_hyperspace_forge(request.id, request.operation, request.args)
		if forecast.ok:
			_forge_sequence += 1
			_forge_preview = {"request": request.duplicate(true), "fingerprint": JSON.stringify(request, "", true),
				"source": _forge_source(request), "forecast": JSON.stringify(forecast, "", true),
				"operation_id": "forge-ui:%s:%s" % [get_instance_id(), _forge_sequence], "completed": false,"before_text":_selected_description()}
			_forecast.text = "原形态：\n%s\n候选操作：%s · 费用 %s · 抽数 %d\n锁定词缀受保护；随机结果尚未获得。确认仅执行本次预览。" % [_selected_description(),OPERATIONS.get(request.operation, "改造"), _cost_text(forecast.costs), int(forecast.draws)]
		else: _forecast.text = "当前条件不满足，请检查无人机形态、收藏与材料。"
		return forecast
	_sync_forge_preview()
	if _forge_preview.is_empty():
		return {"ok": false, "reason": "ForgePreviewRequired", "message": "请先预览当前选择，再确认改造。"}
	# A completed preview remains the same command, even if its callback fires again.
	# Repeating an intentional modification requires a new explicit preview.
	if _forge_preview.completed:
		var repeated: Dictionary = _session.hyperspace_system.forge_repeat(_forge_preview.operation_id, _forge_preview.fingerprint)
		return repeated if not repeated.is_empty() else _forge_preview.result.duplicate(true)
	var current: Dictionary = _session.preview_hyperspace_forge(request.id, request.operation, request.args)
	if not current.ok or JSON.stringify(current, "", true) != str(_forge_preview.forecast):
		_invalidate_forge_preview()
		return {"ok": false, "reason": "ForgePreviewChanged", "message": "改造条件或费用已变化，请重新预览。"}
	var result: Dictionary = _session.forge(request.id, request.operation, request.args, _forge_preview.operation_id)
	if result.ok:
		_forge_preview.completed = true
		_forge_preview.result = result.duplicate(true)
		_forge_preview.source = _forge_source(request)
		_forecast.text = "改造前：\n"+str(_forge_preview.before_text)+"\n改造后：\n"+_selected_description()+"\n已完成本次改造；再次确认不会重复扣费。继续改造请重新预览。"
	return result

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
		_status_name(str(manual.get("status", ""))), _status_name(str(online.idle.get("status", ""))),
		float(online.idle.get("work", 0.0)), float(online.idle.get("duration", 0.0)), float(online.energy)]
	_refresh_routes()
	_route_progress.value=clampf(float(online.idle.get("work",0.0))/maxf(0.001,float(online.idle.get("duration",1.0))),0,1)
	var selected: Array = _selected_ids()
	_warehouse.clear()
	_ids.clear()
	var state: Dictionary = _session.hyperspace_system.warehouse()
	var area: String = str(_value(_warehouse_area, "main"))
	_warehouse_summary.text = "主仓 %d 架 · 溢出 %d 架 · 封存 %d 架。" % [state.main.size(), state.overflow.size(), state.sealed.size()]
	for drone in state.main + state.overflow:
		var id: String = str(drone.id)
		if area == "main" and drone not in state.main: continue
		if area == "overflow" and drone not in state.overflow: continue
		if area == "sealed" and not state.sealed.has(id): continue
		_ids.append(id)
		_warehouse.add_item("%s · %s · Lv%d%s%s" % [_name(drone.weapon), _name("ultimate" if drone.ultimate else "legendary" if drone.legendary else drone.origin_quality), int(drone.level), " · 已装备" if id in state.equipped else "", " · 已收藏" if id in state.favorites else ""],Appearance.thumbnail(Appearance.project(drone)))
		if state.sealed.has(id): _warehouse.set_item_text(_ids.size() - 1, _warehouse.get_item_text(_ids.size() - 1) + " · 封存至关卡 " + str(state.sealed[id]))
		if id in selected: _warehouse.select(_ids.size() - 1, false)
	var preset_names:PackedStringArray=[]
	for preset in state.presets:preset_names.append(str(preset.name))
	_preset_summary.text="已存编队："+("、".join(preset_names) if not preset_names.is_empty() else "暂无")
	var balances:PackedStringArray=[]
	var wallet:Dictionary=_session.economy.budget()
	for id in _session.hyperspace_system.material_ids():balances.append(_name(id)+" "+str(_session.amount_api.apply("to_display",[wallet.get(id,_session.amount_api.apply("zero",[]).value)]).text))
	_materials.text="当前材料："+" · ".join(balances)
	var selected_modules: Array = []
	for index in _modules.get_selected_items(): selected_modules.append(_module_ids[index])
	_modules.clear()
	_module_ids.clear()
	for module_id in _session.hyperspace_system.module_growth():
		var growth: Dictionary = _session.hyperspace_system.module_growth()[module_id]
		if not growth.unlocked: continue
		_module_ids.append(module_id)
		_modules.add_item("%s · Lv%d" % [_name(module_id), int(growth.level)])
		if module_id in selected_modules: _modules.select(_module_ids.size() - 1, false)
	var selected_legend: String = str(_legend_option.get_item_metadata(_legend_option.selected)) if _legend_option.item_count > 0 else ""
	_legend_option.clear()
	var legends: Dictionary = _session.hyperspace_system.legend_collection()
	for effect_id in legends.seen:
		_legend_option.add_item("%s%s" % [_name(effect_id), " · 收藏" if legends.collection.has(effect_id) else ""])
		_legend_option.set_item_metadata(_legend_option.item_count - 1, effect_id)
		if str(effect_id) == selected_legend: _legend_option.select(_legend_option.item_count - 1)

	_refresh_detail()
	_refresh_targets()
	_sync_forge_preview()
	var crew_selected: String = str(_value(_crew_picker))
	_crew_picker.clear()
	for option in _session.crew_system.member_options():
		_option(_crew_picker, option.name, option.id)
		if str(option.id) == crew_selected: _crew_picker.select(_crew_picker.item_count - 1)
	var filter:Dictionary=_session.hyperspace_system.filter_configuration()
	_filter_summary.text = "当前规则："+("已启用" if filter.enabled else "未启用")+" · "+("全部条件" if filter.mode=="all" else "任一条件")+" · "+("保留匹配" if filter.action=="keep_matches" else "拆解匹配")
	for condition in _session.hyperspace_system.filter_configuration().conditions:
		_filter_summary.text += "\n• " + str(FIELDS.get(condition.field, "条件")) + "：" + (str(condition.value) if condition.field == "minimum_level" else _name(condition.key) + " ≤ " + str(condition.tier) + " 阶" if condition.field == "affix" else _name(condition.value))

func _selected_description()->String:
	var selected:Array=_selected_ids()
	if selected.size()!=1:return "已选择 %d 架；单架详情、拆解与改造需要只选择一架。"%selected.size()
	var state:Dictionary=_session.hyperspace_system.warehouse()
	for drone in state.main+state.overflow:
		if str(drone.id)!=str(selected[0]):continue
		var flags:PackedStringArray=[]
		if str(drone.id) in state.equipped:flags.append("已装备，受保护")
		if str(drone.id) in state.favorites:flags.append("已收藏，受保护")
		if drone in state.overflow:flags.append("溢出仓，整理后可装备")
		if state.sealed.has(str(drone.id)):flags.append("封存至关卡 "+str(state.sealed[str(drone.id)]))
		for preset in state.presets:
			if str(drone.id) in preset.drone_ids:flags.append("预设「"+str(preset.name)+"」引用，受保护")
		var text:String="%s · %s · Lv%d · 挂槽 %d\n%s"%[_name(drone.weapon),_name("ultimate" if drone.ultimate else "legendary" if drone.legendary else drone.origin_quality),drone.level,drone.hanging_slots," · ".join(flags)]
		for affix in drone.affixes:text+="\n%s · %s阶 · %s%s"%[_name(affix.key),affix.tier,str(affix.value)," · 已锁定" if affix.locked else ""]
		if drone.legendary:text+="\n传说："+_name(drone.legendary_effect.effect_id)
		text+="\n已装挂设："+("、".join(drone.hangings.map(func(id):return _name(id))) if not drone.hangings.is_empty() else "无")
		return text
	return "对象已不存在，请重新选择。"
func _refresh_detail()->void:
	_sync_forge_preview()
	if _detail==null:return
	_detail.text=_selected_description()
	var state:Dictionary=_session.hyperspace_system.warehouse()
	var selected:Array=_selected_ids()
	var removed:PackedStringArray=[]
	for id in state.equipped:
		if id not in selected:removed.append(str(id))
	_loadout_preview.text="本次编队 %d 架 · 卸下 %d 架%s"%[selected.size(),removed.size(),"\n卸下："+"、".join(removed) if not removed.is_empty() else ""]
	_forge_subject.text="改造对象：\n"+_selected_description()
	_drone_icon.texture=null
	if selected.size()==1:
		for drone in state.main+state.overflow:
			if str(drone.id)==str(selected[0]):_drone_icon.texture=Appearance.thumbnail(Appearance.project(drone))
func _refresh_routes()->void:
	for route in _session.hyperspace_system.routes():
		if not _route_cards.has(route.route):continue
		var card:Dictionary=_route_cards[route.route]
		var selected:bool=str(route.route)==_route_id()
		card.info.text="%s · %s\n已通过 %d 层 · 下次挑战 %d 层\n最佳 %s"%[_name(route.route),_name(route.weapon),route.cleared,int(route.cleared)+1,"%.2f秒"%route.best if float(route.best)>0 else "暂无纪录"]
		card.button.set_pressed_no_signal(selected)
		card.button.text="当前路线" if selected else "查看路线"
		if selected and _route_editor.get_parent()!=card.body:_route_editor.reparent(card.body)

func _cost_text(costs: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in costs: parts.append(_name(key) + " " + PlayerText.number(str(costs[key])))
	return "、".join(parts)

func _status_name(value: String) -> String:
	return str({"Started": "进行中", "CompletedPending": "待领取", "Complete": "待领取", "Completed": "待领取", "Finished": "待领取", "Claimed": "已领取", "Failed": "失败", "Exited": "已退出"}.get(value, "待命"))

func _release_sealed() -> Dictionary:
	var ids: Array = _selected_ids()
	if ids.size() != 1: return {"ok": false, "reason": "SelectOneDrone"}
	var cleared: Array = []
	for stage in _session.campaign_system.progress_facts().cleared_stages: cleared.append(int(stage))
	var result: Dictionary = _session.hyperspace_system.release_sealed(str(ids[0]), cleared)
	if result.ok: result.message = "无人机已解封，可在主仓中装备。"
	return result

func _organize_storage() -> Dictionary:
	var moved: int = _session.hyperspace_system.organize()
	return {"ok": true, "moved": moved, "message": "已将 %d 架无人机移入主仓。%s" % [moved, "主仓已满时，请先腾出空间再整理。" if moved == 0 else ""]}
