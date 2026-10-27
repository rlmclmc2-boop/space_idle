extends VBoxContainer

const ERRORS := {"ResearchLocked": "科研前置条件未满足"}
var _host_command: Callable

var research_picker: OptionButton
var _research

var _pending_choices: bool = false
var _pending_investment: bool = true
var investment_inputs: Dictionary = {}
var investment_current: Dictionary = {}
var automatic_toggle: CheckBox
var automatic_ratio: SpinBox
var automatic_current: Label
var _drafts: Dictionary = {}
var _automatic_draft: bool = false

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
		investment_inputs[resource] = input
		input.text_changed.connect(func(_text): _drafts[resource] = true)
		input.focus_exited.connect(refresh_investment)
		input.custom_minimum_size.x = 140
		investment.add_child(input)
		var current := Label.new()
		investment.add_child(current)
		investment_current[resource] = current
		_command(investment, "设置投入", func():
			var result: Dictionary = research.set_investment_text(resource, input.text)
			if result.get("ok", false): _drafts.erase(resource)
			refresh_investment()
			return result)
	var automatic := _row(box)
	var toggle := CheckBox.new()
	automatic_toggle = toggle
	toggle.toggled.connect(func(_value): _automatic_draft = true)
	toggle.text = "自动投入"
	automatic.add_child(toggle)
	var ratio := SpinBox.new()
	automatic_ratio = ratio
	ratio.value_changed.connect(func(_value): _automatic_draft = true)
	ratio.min_value = float(model.minimum_ratio) * 100.0
	ratio.max_value = 100.0
	ratio.step = 0.0
	ratio.set_value_no_signal(float(model.ratio) * 100.0)
	ratio.suffix = "%"
	automatic.add_child(ratio)
	ratio.get_line_edit().focus_exited.connect(refresh_investment)
	_command(automatic, "应用", func():
		var result: Dictionary = research.set_automatic(toggle.button_pressed, ratio.value / 100.0)
		if result.get("ok", false): _automatic_draft = false
		refresh_investment()
		return result)
	automatic_current = Label.new()
	box.add_child(automatic_current)
	_command(box, "还原当前投入设置", func():
		_drafts.clear()
		_automatic_draft = false
		refresh_investment()
		return {"ok": true})
	_caption(box, "AI 工厂岗位控制自动续研；自动投入开关仅控制预算刷新。")
	_caption(box, "岗位有人且启用自动投入时，每60游戏秒按近期收入与共同预算比例刷新铁、铀投入。")
	_caption(box, "应用比例不立即重算；未应用的编辑保留，旁列当前值为实际生效设置。")
	_research.investment_changed.connect(refresh_investment)
	_automatic_draft = false
	_refresh_investment()
	_research.choices_changed.connect(refresh_choices)
	refresh_choices()

func refresh_investment() -> void:
	_pending_investment = true

func _refresh_investment() -> void:
	var model: Dictionary = _research.panel_model()
	for resource in investment_inputs:
		var input: LineEdit = investment_inputs[resource]
		investment_current[resource].text = "当前：" + str(model.investment[resource]) + "/秒"
		if not _drafts.has(resource) and not input.has_focus(): input.text = model.investment[resource]
	automatic_current.text = "当前自动投入：%s · 铁铀共同预算比例 %s%%" % ["开启" if model.auto_invest else "关闭", str(float(model.ratio) * 100.0)]
	if not _automatic_draft and not automatic_ratio.get_line_edit().has_focus():
		automatic_toggle.set_pressed_no_signal(model.auto_invest)
		automatic_ratio.set_value_no_signal(float(model.ratio) * 100.0)

func refresh_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
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

func _ready() -> void:
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_investment:
		_pending_investment = false
		_refresh_investment()
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()
