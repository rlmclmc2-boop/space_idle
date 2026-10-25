extends VBoxContainer

var module_picker: OptionButton
var allocation_input: LineEdit
var _reactor
var _inputs: Callable

func _init(reactor, inputs: Callable, publish: Callable, command: Callable) -> void:
	_reactor = reactor
	_inputs = inputs
	var box: Control = self
	_caption(box, "反应炉")
	var reactor_buttons := _row(box)
	command.call(reactor_buttons, "购买 1 级", func(): return reactor.purchase(1, false, inputs.call(), publish))
	command.call(reactor_buttons, "平均分配", func(): return reactor.distribute(inputs.call(), publish))
	var allocation := _row(box)
	module_picker = OptionButton.new()
	var module_names := ["武器", "防御", "炼铁", "碎片凝聚"]
	var modules: PackedStringArray = reactor.module_ids()
	for i in modules.size():
		module_picker.add_item(module_names[i])
		module_picker.set_item_metadata(i, modules[i])
	allocation.add_child(module_picker)
	allocation_input = LineEdit.new()
	allocation_input.placeholder_text = "分配能源"
	allocation_input.custom_minimum_size.x = 120
	allocation.add_child(allocation_input)
	command.call(allocation, "分配", func():
		return reactor.allocate_text(str(module_picker.get_item_metadata(module_picker.selected)), allocation_input.text, inputs.call(), publish))

func refresh_choices() -> void:
	var enabled: Array = _reactor.enabled_modules(_inputs.call())
	for index in module_picker.item_count:
		module_picker.set_item_disabled(index, str(module_picker.get_item_metadata(index)) not in enabled)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
