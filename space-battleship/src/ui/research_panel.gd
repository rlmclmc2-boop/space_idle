extends VBoxContainer

const ERRORS := {"ResearchLocked": "科研前置条件未满足"}
var _host_command: Callable

var research_picker: OptionButton
var _research

func _init(research, command: Callable) -> void:
	_host_command = command
	_research = research
	var box: Control = self
	var model: Dictionary = research.panel_model()
	_caption(box, "AI 科研（切换保留各项工作量）")
	research_picker = OptionButton.new()
	box.add_child(research_picker)
	for option in model.options:
		var index: int = research_picker.item_count
		research_picker.add_item(option.name)
		research_picker.set_item_metadata(index, option.id)
	_command(box, "选择研究", func(): return research.select(str(research_picker.get_item_metadata(research_picker.selected))))
	for resource in ["1", "2"]:
		var investment := _row(box)
		_caption(investment, "铁/秒" if resource == "1" else "铀/秒")
		var input := LineEdit.new()
		input.text = "0"
		input.custom_minimum_size.x = 140
		investment.add_child(input)
		_command(investment, "设置投入", func():
			return research.set_investment_text(resource, input.text))
	var automatic := _row(box)
	var toggle := CheckBox.new()
	toggle.text = "自动投入"
	automatic.add_child(toggle)
	var ratio := SpinBox.new()
	ratio.min_value = float(model.minimum_ratio) * 100.0
	ratio.max_value = 100.0
	ratio.step = 0.1
	ratio.value = float(model.ratio) * 100.0
	ratio.suffix = "%"
	automatic.add_child(ratio)
	_command(automatic, "应用", func(): return research.set_automatic(toggle.button_pressed, ratio.value / 100.0))
	_research.choices_changed.connect(refresh_choices)
	refresh_choices()

func refresh_choices() -> void:
	var choices: Dictionary = _research.choices()
	for index in research_picker.item_count:
		research_picker.set_item_disabled(index, not choices[str(research_picker.get_item_metadata(index))])

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
		if not result.get("ok", false) and ERRORS.has(reason): result.message = ERRORS[reason]
		return result)
