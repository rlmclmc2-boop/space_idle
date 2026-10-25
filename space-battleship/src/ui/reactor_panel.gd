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
	for option in reactor.panel_options(inputs.call()):
		var index: int = module_picker.item_count
		module_picker.add_item(option.name)
		module_picker.set_item_metadata(index, option.id)
		module_picker.set_item_disabled(index, not option.enabled)
	allocation.add_child(module_picker)
	allocation_input = LineEdit.new()
	allocation_input.placeholder_text = "分配能源"
	allocation_input.custom_minimum_size.x = 120
	allocation.add_child(allocation_input)
	command.call(allocation, "分配", func():
		return reactor.allocate_text(str(module_picker.get_item_metadata(module_picker.selected)), allocation_input.text, inputs.call(), publish))
	_reactor.choices_changed.connect(refresh_choices)

func refresh_choices() -> void:
	var selected: String = "" if module_picker.selected < 0 else str(module_picker.get_item_metadata(module_picker.selected))
	module_picker.clear()
	for option in _reactor.panel_options(_inputs.call()):
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
