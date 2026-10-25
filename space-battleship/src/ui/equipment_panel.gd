extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"EquipmentSwitchLocked": "换装冷却尚未结束", "EquipmentLocked": "装备尚未解锁", "EvolutionMaterialLocked": "进化材料尚未开放"}
var _host_command: Callable

var slot_picker: OptionButton
var equipment_picker: OptionButton
var upgrade_price: Label
var _equipment
var _inputs: Callable
var _watch_visibility: bool = false
var _pending_full: bool = false
var _pending_options: bool = false
var _pending_slots: Dictionary = {}

func _init(equipment, inputs: Callable, can_pay: Callable, pay: Callable, publish_levels: Callable, publish_refit: Callable, command: Callable) -> void:
	_host_command = command
	_equipment = equipment
	_inputs = inputs
	var box: Control = self
	_caption(box, "槽位升级（换装备保留等级）")
	slot_picker = OptionButton.new()
	box.add_child(slot_picker)
	slot_picker.item_selected.connect(func(_index): _populate_equipment_picker())
	upgrade_price = Label.new()
	box.add_child(upgrade_price)
	var upgrades := _row(box)
	_command(upgrades, "+1", func(): return equipment.buy_levels(_selected_slot(), 1, inputs.call(), pay, publish_levels))
	_command(upgrades, "+10", func(): return equipment.buy_levels(_selected_slot(), 10, inputs.call(), pay, publish_levels))
	_command(upgrades, "MAX", func(): return equipment.buy_max_levels(_selected_slot(), inputs.call(), can_pay, pay, publish_levels))
	_command(upgrades, "全体 +1", func(): return equipment.buy_all_levels(1, false, inputs.call(), can_pay, pay, publish_levels))
	equipment_picker = OptionButton.new()
	box.add_child(equipment_picker)
	_command(box, "更换所选装备", func(): return equipment.equip_slot(_selected_slot(), str(equipment_picker.get_item_metadata(equipment_picker.selected)), inputs.call(), publish_refit))
	_equipment.slots_changed.connect(_refresh_slot_prices)
	_equipment.loadout_changed.connect(refresh)
	_equipment.options_changed.connect(_populate_equipment_picker)
	refresh()

func _selected_slot() -> String:
	return "" if slot_picker.selected < 0 else str(slot_picker.get_item_metadata(slot_picker.selected))

func refresh() -> void:
	if _watch_visibility and not is_visible_in_tree():
		_pending_full = true
		return
	var selected: String = _selected_slot()
	slot_picker.clear()
	for option in _equipment.panel_slots(_inputs.call().mounts):
		var index: int = slot_picker.item_count
		slot_picker.add_item(option.label)
		slot_picker.set_item_metadata(index, option.id)
		if str(option.id) == selected: slot_picker.select(index)
	_populate_equipment_picker()

func _refresh_slot_prices(ids: Array, update_price: bool = true) -> void:
	if _watch_visibility and not is_visible_in_tree():
		for id in ids: _pending_slots[id] = true
		return
	for option in _equipment.panel_slots(_inputs.call().mounts, ids):
		for index in slot_picker.item_count:
			if slot_picker.get_item_metadata(index) == option.id:
				slot_picker.set_item_text(index, option.label)
		if update_price and _selected_slot() == str(option.id): _refresh_upgrade_price()

func _refresh_upgrade_price() -> void:
	upgrade_price.text = _equipment.price_text(_selected_slot())

func _populate_equipment_picker() -> void:
	if _watch_visibility and not is_visible_in_tree():
		_pending_options = true
		return
	_refresh_upgrade_price()
	equipment_picker.clear()
	for option in _equipment.panel_equipment(_selected_slot()):
		var index: int = equipment_picker.item_count
		equipment_picker.add_item(option.name)
		equipment_picker.set_item_metadata(index, option.id)
		equipment_picker.set_item_disabled(index, not option.enabled)

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
		return result)

func _ready() -> void:
	_watch_visibility = true
	visibility_changed.connect(_flush_pending)
	_flush_pending()

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	var full: bool = _pending_full
	var options: bool = _pending_options
	var ids: Array = _pending_slots.keys()
	_pending_full = false
	_pending_options = false
	_pending_slots = {}
	if full:
		refresh()
		return
	if not ids.is_empty(): _refresh_slot_prices(ids, not options)
	if options: _populate_equipment_picker()
