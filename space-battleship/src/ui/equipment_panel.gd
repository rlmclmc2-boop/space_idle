extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"EquipmentSwitchLocked": "换装冷却尚未结束", "EquipmentLocked": "装备尚未解锁", "EvolutionMaterialLocked": "进化材料尚未开放"}
var _host_command: Callable

var slot_picker: OptionButton
var equipment_picker: OptionButton
var upgrade_price: Label
var _equipment
var _inputs: Callable
var _slot_cards:=GridContainer.new()
var _card_views:Dictionary={}
var _comparison:=Label.new()
var _editor:=VBoxContainer.new()
var _editor_title:=Label.new()
var _refit_button:Button
var _presentation_elapsed:float=0.0
var _pending_full: bool = false
var _presentation_pending:bool=true
var _presentation_inputs_key:Dictionary={}
var _cooldown_active:bool=false
var _cooldown_rows:Array=[]
var _candidate_slot:String=""
var _pending_options: bool = false
var _pending_slots: Dictionary = {}

func _init(equipment, inputs: Callable, can_pay: Callable, pay: Callable, publish_levels: Callable, publish_refit: Callable, command: Callable) -> void:
	_host_command = command
	_equipment = equipment
	_inputs = inputs
	preload("res://src/ui/module_widgets.gd").heading(self,"舰载设备整备")
	_slot_cards.columns=2;add_child(_slot_cards)
	add_child(_editor)
	_editor_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_editor.add_child(_editor_title)
	_comparison.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_editor.add_child(_comparison)
	var box: Control = _editor
	slot_picker = OptionButton.new()
	add_child(slot_picker);slot_picker.hide()
	slot_picker.item_selected.connect(func(_index): _queue_options())
	upgrade_price = Label.new()
	upgrade_price.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(upgrade_price)
	var upgrades := _row(box)
	_command(upgrades, "+1", func(): return equipment.buy_levels(_selected_slot(), 1, inputs.call(), pay, publish_levels))
	_command(upgrades, "+10", func(): return equipment.buy_levels(_selected_slot(), 10, inputs.call(), pay, publish_levels))
	_command(upgrades, "MAX", func(): return equipment.buy_max_levels(_selected_slot(), inputs.call(), can_pay, pay, publish_levels))
	_command(self, "全体槽位 +1", func(): return equipment.buy_all_levels(1, false, inputs.call(), can_pay, pay, publish_levels))
	equipment_picker = OptionButton.new()
	box.add_child(equipment_picker)
	equipment_picker.item_selected.connect(func(_index):_refresh_presentation())
	_refit_button=_command(box, "更换所选装备", func(): return equipment.equip_slot(_selected_slot(), str(equipment_picker.get_item_metadata(equipment_picker.selected)), inputs.call(), publish_refit))
	_equipment.slots_changed.connect(_queue_slots)
	_equipment.loadout_changed.connect(refresh)
	_equipment.options_changed.connect(_queue_options)
	refresh()

func _selected_slot() -> String:
	return "" if slot_picker.selected < 0 else str(slot_picker.get_item_metadata(slot_picker.selected))

func refresh() -> void:
	_pending_full = true
	_presentation_pending=true

func _queue_slots(ids: Array) -> void:
	for id in ids: _pending_slots[id] = true
	_presentation_pending=true

func _queue_options() -> void:
	_pending_options = true
	_presentation_pending=true

func _refresh_all() -> void:
	var selected: String = _selected_slot()
	slot_picker.clear()
	for option in _equipment.panel_slots(_inputs.call().mounts):
		var index: int = slot_picker.item_count
		slot_picker.add_item(option.label)
		slot_picker.set_item_metadata(index, option.id)
		if str(option.id) == selected: slot_picker.select(index)
	_populate_equipment_picker()
	_refresh_presentation()

func _refresh_slot_prices(ids: Array, update_price: bool = true) -> void:
	for option in _equipment.panel_slots(_inputs.call().mounts, ids):
		for index in slot_picker.item_count:
			if slot_picker.get_item_metadata(index) == option.id:
				slot_picker.set_item_text(index, option.label)
		if update_price and _selected_slot() == str(option.id): _refresh_upgrade_price()

func _refresh_upgrade_price() -> void:
	upgrade_price.text = _equipment.price_text(_selected_slot())

func _populate_equipment_picker() -> void:
	var chosen:String=""
	if _candidate_slot==_selected_slot() and equipment_picker.selected>=0:chosen=str(equipment_picker.get_item_metadata(equipment_picker.selected))
	else:
		for slot in _equipment.panel_slots(_inputs.call().mounts):
			if str(slot.id)==_selected_slot():chosen=str(slot.key)
	_candidate_slot=_selected_slot()
	_refresh_upgrade_price()
	equipment_picker.clear()
	for option in _equipment.panel_equipment(_selected_slot()):
		var index: int = equipment_picker.item_count
		equipment_picker.add_item(option.name)
		equipment_picker.set_item_metadata(index, option.id)
		equipment_picker.set_item_disabled(index, not option.enabled)
		if str(option.id)==chosen:equipment_picker.select(index)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _command(parent: Control, text: String, action: Callable):
	return _host_command.call(parent, text, func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "")))
		if not result.get("ok", false) and not result.has("message"):
			var message: String = str(ERRORS.get(reason, EconomyView.describe_error(reason)))
			if not message.is_empty(): result.message = message
		if result.get("ok",false):
			for row in _equipment.panel_slots(_inputs.call().mounts):
				if str(row.id)==_selected_slot():result.message=str(row.label)+" · 已生效"
		return result)

func _ready() -> void:
	resized.connect(func():_slot_cards.columns=2 if size.x>=700 else 1)
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()
	if not is_visible_in_tree():return
	_presentation_elapsed+=_dt
	var inputs:Dictionary=_inputs.call()
	var key:Dictionary={"mounts":inputs.mounts,"ai":inputs.get("ai",{}),"reactor":inputs.get("reactor",{}),"bonus":inputs.get("extra_bonus",0)}
	if key!=_presentation_inputs_key:_presentation_inputs_key=key.duplicate(true);_presentation_pending=true
	if _presentation_pending:
		_presentation_elapsed=0;_refresh_presentation()
	elif _cooldown_active and _presentation_elapsed>=0.2:
		_presentation_elapsed=0;_refresh_cooldowns()

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	if not _pending_full and not _pending_options and _pending_slots.is_empty(): return
	var full: bool = _pending_full
	var options: bool = _pending_options
	var ids: Array = _pending_slots.keys()
	_pending_full = false
	_pending_options = false
	_pending_slots = {}
	if full:
		_refresh_all()
		return
	if not ids.is_empty(): _refresh_slot_prices(ids, not options)
	if options: _populate_equipment_picker()

func _refresh_presentation()->void:
	_presentation_pending=false;_cooldown_active=false
	var rows:Array=_equipment.presentation_slots(_inputs.call());_cooldown_rows=rows
	for row in rows:
		if not _card_views.has(row.id):
			var card=preload("res://src/ui/module_widgets.gd").plate(_slot_cards)
			card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var top:=HBoxContainer.new();card.add_child(top)
			var icon=preload("res://src/ui/module_widgets.gd").image(top,"res://assets/ui/equipment/cartoon_%s.svg"%row.key,Vector2(80,80))
			var info=preload("res://src/ui/module_widgets.gd").label(top,"",17);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var choose:=Button.new();choose.toggle_mode=true;choose.text="整备此槽位";card.add_child(choose)
			choose.pressed.connect(func():
				for i in slot_picker.item_count:
					if str(slot_picker.get_item_metadata(i))==str(row.id):slot_picker.select(i);_populate_equipment_picker();_refresh_presentation())
			_card_views[row.id]={"body":card,"card":card.get_parent(),"icon":icon,"info":info,"choose":choose}
		if row.cooldown>0:_cooldown_active=true
		var view:Dictionary=_card_views[row.id]
		view.icon.texture=preload("res://src/ui/module_widgets.gd").visible_texture(load("res://assets/ui/equipment/cartoon_%s.svg"%row.key)) if not row.key.is_empty() else null
		view.info.text="%s\n%s\n%s%s"%[row.label,row.primary,"未启用 · 等级与配装保留" if row.dormant else row.price,"\n换装冷却 %.1f秒"%row.cooldown if row.cooldown>0 else ""]
		view.choose.disabled=row.dormant
		view.choose.set_pressed_no_signal(str(row.id)==_selected_slot() and not row.dormant)
		if str(row.id)==_selected_slot():
			if _editor.get_parent()!=view.body:_editor.reparent(view.body)
			_editor_title.text="正在整备："+str(row.label)
			view.choose.text="当前整备槽位"
		else:view.choose.text="整备此槽位"
		if str(row.id)==_selected_slot() and equipment_picker.selected>=0:
			var same:bool=str(equipment_picker.get_item_metadata(equipment_picker.selected))==str(row.key)
			_refit_button.disabled=row.cooldown>0 or same
			_refit_button.text="当前已装备" if same else "换装冷却 %.1f秒"%row.cooldown if row.cooldown>0 else "更换所选装备"
	var active:Dictionary={}
	for row in rows:active[row.id]=true
	for key in _card_views:_card_views[key].card.visible=active.has(key)
	if equipment_picker.selected>=0:_comparison.text=_equipment.equipment_comparison(_selected_slot(),str(equipment_picker.get_item_metadata(equipment_picker.selected)),_inputs.call())

func _refresh_cooldowns()->void:
	_cooldown_active=false
	var time:float=float(_inputs.call().game_time)
	for row in _cooldown_rows:
		row.cooldown=maxf(0.0,float(row.ready_at)-time)
		if row.cooldown>0:_cooldown_active=true
		var view:Dictionary=_card_views[row.id]
		view.info.text="%s\n%s\n%s%s"%[row.label,row.primary,"未启用 · 等级与配装保留" if row.dormant else row.price,"\n换装冷却 %.1f秒"%row.cooldown if row.cooldown>0 else ""]
		if str(row.id)==_selected_slot() and equipment_picker.selected>=0:
			var same:bool=str(equipment_picker.get_item_metadata(equipment_picker.selected))==str(row.key)
			_refit_button.disabled=row.cooldown>0 or same
			_refit_button.text="当前已装备" if same else "换装冷却 %.1f秒"%row.cooldown if row.cooldown>0 else "更换所选装备"
