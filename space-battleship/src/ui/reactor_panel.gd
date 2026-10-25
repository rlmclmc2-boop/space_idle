extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"ReactorLocked": "反应炉尚未解锁", "ReactorModuleLocked": "反应炉模块尚未开放"}
var _host_command: Callable

var module_picker: OptionButton
var allocation_input: LineEdit
var _reactor

var _pending_choices: bool = false

func _init(reactor, inputs: Callable, publish: Callable, command: Callable) -> void:
	_host_command = command
	_reactor = reactor
	var box: Control = self
	_caption(box, "反应炉")
	var reactor_buttons := _row(box)
	_command(reactor_buttons, "购买 1 级", func(): return reactor.purchase(1, false, inputs.call(), publish))
	_command(reactor_buttons, "平均分配", func(): return reactor.distribute(inputs.call(), publish))
	var allocation := _row(box)
	module_picker = OptionButton.new()
	allocation.add_child(module_picker)
	allocation_input = LineEdit.new()
	allocation_input.placeholder_text = "分配能源"
	allocation_input.custom_minimum_size.x = 120
	allocation.add_child(allocation_input)
	_command(allocation, "分配", func():
		return reactor.allocate_text(str(module_picker.get_item_metadata(module_picker.selected)), allocation_input.text, inputs.call(), publish))
	_reactor.choices_changed.connect(refresh_choices)
	refresh_choices()

func refresh_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
	var selected: String = "" if module_picker.selected < 0 else str(module_picker.get_item_metadata(module_picker.selected))
	module_picker.clear()
	for option in _reactor.panel_options():
		var index: int = module_picker.item_count
		module_picker.add_item(option.name)
		module_picker.set_item_metadata(index, option.id)
		module_picker.set_item_disabled(index, not option.enabled)
		if str(option.id) == selected: module_picker.select(index)

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
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()
