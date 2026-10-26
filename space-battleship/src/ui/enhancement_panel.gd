extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"EnhancementLocked": "强化尚未解锁", "EnhancementBranchLocked": "强化分支尚未开放"}
var _host_command: Callable

var effect_picker: OptionButton
var branch_node: SpinBox
var branch_choice: OptionButton
const EFFECT_IDS := ["proficiency", "repeat", "critical", "adaptation", "memory", "deferred"]
const EFFECT_NAMES := ["熟练", "连发", "暴击", "适应", "记忆材料", "延迟伤害"]

func _init(enhancement, inputs: Callable, can_pay: Callable, publish: Callable, command: Callable) -> void:
	_host_command = command
	var box: Control = self
	_caption(box, "全局强化")
	var enhancement_buttons := _row(box)
	_command(enhancement_buttons, "购买 1 级", func(): return enhancement.purchase(1, inputs.call(), can_pay, publish))
	_command(enhancement_buttons, "最多购买 10 级", func(): return enhancement.purchase(10, inputs.call(), can_pay, publish))
	var branches := _row(box)
	effect_picker = OptionButton.new()
	for label in EFFECT_NAMES: effect_picker.add_item(label)
	branches.add_child(effect_picker)
	branch_node = SpinBox.new()
	branch_node.min_value = 1
	branch_node.max_value = 3
	branch_node.step = 1
	branches.add_child(branch_node)
	branch_choice = OptionButton.new()
	branch_choice.add_item("A")
	branch_choice.add_item("B")
	branches.add_child(branch_choice)
	_command(box, "设置分支", func(): return enhancement.set_branch(EFFECT_IDS[effect_picker.selected], int(branch_node.value) - 1, "A" if branch_choice.selected == 0 else "B", inputs.call(), publish))
	_command(box, "将所选效果前移一位", func():
		return enhancement.move_forward(EFFECT_IDS[effect_picker.selected], inputs.call(), publish))
	_caption(box, "连发第二节点 B 仅保留选择，不产生第二代连发。")

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
