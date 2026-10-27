extends VBoxContainer
const EconomyView = preload("res://src/ui/economy_view.gd")

const ERRORS := {"EnhancementLocked": "强化尚未解锁", "EnhancementBranchLocked": "强化分支尚未开放"}
var _host_command: Callable

var effect_picker: OptionButton
var branch_node: SpinBox
var branch_choice: OptionButton
var _tree:=VBoxContainer.new()
var _groups:Dictionary={}
var _branches:Dictionary={}
var _summary:=Label.new()
var _enhancement
var _inputs:Callable
var _can_pay:Callable
var _elapsed:float=0.0
const EFFECT_IDS := ["proficiency", "repeat", "critical", "adaptation", "memory", "deferred"]
const EFFECT_NAMES := ["熟练", "连发", "暴击", "适应", "记忆材料", "延迟伤害"]

func _init(enhancement, inputs: Callable, can_pay: Callable, publish: Callable, command: Callable) -> void:
	_host_command = command
	_enhancement=enhancement;_inputs=inputs;_can_pay=can_pay
	preload("res://src/ui/module_widgets.gd").heading(self,"强化回路","六种效果 · 实际顺序与三节点分支")
	_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_summary)
	add_child(_tree)
	for category in ["weapon","defence"]:
		preload("res://src/ui/module_widgets.gd").label(_tree,"武器效果顺位" if category=="weapon" else "防御效果顺位",22)
		var grid:=GridContainer.new();grid.columns=2;_tree.add_child(grid);_groups[category]=grid
	for index in EFFECT_IDS.size():
		var id:String=EFFECT_IDS[index]
		var card=preload("res://src/ui/module_widgets.gd").plate(_groups["weapon" if index<3 else "defence"])
		card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var title=preload("res://src/ui/module_widgets.gd").label(card,EFFECT_NAMES[index],22)
		var descriptions:Dictionary={"proficiency":["随规范攻击历史增强伤害","A：提高伤害，节点叠加","持续追踪同一目标成长","缩短攻击周期","降低匹配抗性的减伤"],"repeat":["触发延时额外攻击，连发不递归","A：提高连发概率与伤害","提高连发和连锁数量","只保留选择，不产生二代连发","让主攻击产生额外攻击"],"critical":["提供暴击机会并随等级提高爆伤","A：提高暴击率","累计攻击后获得强化一击","暴击累积暂时暴击标记","保底触发，爆伤机会仍按原始率"],"adaptation":["随全局来袭历史提高防御","A：提高防御值，节点叠加","同来源连续来袭叠加减伤","周期生成无抗性护罩","增强已有匹配抗性"],"memory":["周期修复，满额后积累记忆保护","A：提高恢复与保护容量","恢复跳概率触发共享减伤","同类保护与异类锁定","盾模块增强充能，装甲增强容量"],"deferred":["部分伤害分期结算，并判定清除余队","A：提高全局清队概率","清队后短时降低原始伤害","禁用随机清队并转换减伤","强制清队但增加来袭伤害"]}
		preload("res://src/ui/module_widgets.gd").label(card,descriptions[id][0],16)
		preload("res://src/ui/module_widgets.gd").label(card,descriptions[id][1],15)
		var nodes:Array=[]
		for node in 3:
			preload("res://src/ui/module_widgets.gd").label(card,"B%d：%s"%[node+1,descriptions[id][node+2]],15)
			var row:=HBoxContainer.new();card.add_child(row)
			var gate=preload("res://src/ui/module_widgets.gd").label(row,"",15);gate.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var choices:Array=[]
			for choice in ["A","B"]:
				var button:Button=_command(row,choice,func():return enhancement.set_branch(id,node,choice,inputs.call(),publish))
				button.toggle_mode=true;choices.append(button)
			nodes.append({"label":gate,"buttons":choices})
		_command(card,"顺序前移",func():return enhancement.move_forward(id,inputs.call(),publish))
		_branches[id]={"container":card.get_parent(),"title":title,"nodes":nodes}
	var box: Control = self
	var enhancement_buttons := _row(box)
	move_child(enhancement_buttons,3)
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

func _process(dt:float)->void:
	if not is_visible_in_tree():return
	_elapsed+=dt
	if _elapsed<0.2:return
	_elapsed=0
	var model:Dictionary=_enhancement.presentation_model(_inputs.call(),_can_pay)
	if model.is_empty():return
	_summary.text="购级 %d + 附加 %d = 有效等级 %d\n下一级 %s%s"%[model.paid,model.bonus,model.level,model.price," · 余额不足" if not model.affordable else ""]
	for effect in model.effects:
		var card:Dictionary=_branches[effect.id]
		_groups[effect.category].move_child(card.container,effect.position-1)
		card.title.text="%s · 序位 %d · %s"%[EFFECT_NAMES[EFFECT_IDS.find(effect.id)],effect.position,"生效" if effect.active else "未生效"]
		for index in 3:
			var node:Dictionary=effect.nodes[index]
			card.nodes[index].label.text="节点 %d · %d级"%[index+1,node.level]
			for choice in 2:
				var button:Button=card.nodes[index].buttons[choice]
				button.disabled=not node.enabled
				button.set_pressed_no_signal(node.choice==("A" if choice==0 else "B"))

func _ready()->void:
	resized.connect(func():
		for group in _groups.values():group.columns=2 if size.x>=700 else 1)
