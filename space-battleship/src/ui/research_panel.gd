extends VBoxContainer
const PlayerText = preload("res://src/ui/player_text.gd")

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
var _visual_context:Callable
var _stage:Control
var _art
var _drawer:PanelContainer
var _worklist:VBoxContainer
var _research_title:Label
var _research_progress:ProgressBar
var _research_detail:Label
var _machine_rows:Dictionary={}
var _stage_elapsed:float=0.0

func _init(research, command: Callable, context:Callable=Callable()) -> void:
	_host_command = command
	_research = research
	_visual_context=context
	_build_stage()
	var box: Control = self
	var model: Dictionary = research.panel_model()
	research_picker = OptionButton.new()
	box.add_child(research_picker)
	research_picker.hide()
	for option in model.options:
		var index: int = research_picker.item_count
		research_picker.add_item(option.name)
		research_picker.set_item_metadata(index, option.id)
	_command(box, "选择研究", func(): return research.select(str(research_picker.get_item_metadata(research_picker.selected)))).hide()
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
		PlayerText.wrap(current)
		box.add_child(current)
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
	PlayerText.wrap(automatic_current)
	box.add_child(automatic_current)
	_command(box, "还原当前投入设置", func():
		_drafts.clear()
		_automatic_draft = false
		refresh_investment()
		return {"ok": true})
	_caption(box, "AI 工厂岗位控制自动续研；\n自动投入开关仅控制预算刷新。")
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
		investment_current[resource].text = "当前：" + PlayerText.number(str(model.investment[resource])) + "/秒"
		if not _drafts.has(resource) and not input.has_focus(): input.text = model.investment[resource]
	automatic_current.text = "当前自动投入：%s · 铁铀共同预算比例 %s%%" % ["开启" if model.auto_invest else "关闭", str(float(model.ratio) * 100.0)]
	if not _automatic_draft and not automatic_ratio.get_line_edit().has_focus():
		automatic_toggle.set_pressed_no_signal(model.auto_invest)
		automatic_ratio.set_value_no_signal(float(model.ratio) * 100.0)

func refresh_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
	var choices:Dictionary=_research.choices()
	var current:String=str(research_picker.get_item_metadata(research_picker.selected)) if research_picker.selected>=0 else ""
	research_picker.clear()
	for option in _research.panel_model().options:
		if not bool(choices.get(option.id,false)):continue
		research_picker.add_item(option.name);research_picker.set_item_metadata(research_picker.item_count-1,option.id)
		if str(option.id)==current:research_picker.select(research_picker.item_count-1)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	PlayerText.wrap(label)
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
	if not is_visible_in_tree():return
	_stage_elapsed+=_dt
	if _stage_elapsed>=0.2:
		_stage_elapsed=0.0
		_refresh_stage()

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_investment:
		_pending_investment = false
		_refresh_investment()
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()

func _art_key(id:String)->String:
	return str({"singularity":"ai_singularity","equipment_finishing":"equipment_precision","unification":"joint_integration"}.get(id,id))
func _build_stage()->void:
	var widgets=preload("res://src/ui/module_widgets.gd")
	widgets.heading(self,"AI 科技工厂","当前研究与投入管理")
	var top:=HBoxContainer.new();add_child(top)
	_research_title=widgets.label(top,"选择研究设备",22)
	_research_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var choose:=Button.new();choose.text="研究设备抽屉";top.add_child(choose)
	choose.pressed.connect(func():_set_drawer(not _drawer.visible))
	_stage=Control.new();_stage.custom_minimum_size.y=360;add_child(_stage)
	_stage.resized.connect(func():_stage.custom_minimum_size.y=maxf(240,_stage.size.x*701.0/1284.0))
	_art=preload("res://scripts/ai_tech_factory_art.gd").new()
	_stage.add_child(_art);_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer=PanelContainer.new();_stage.add_child(_drawer);_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();_drawer.add_child(column)
	var title:=HBoxContainer.new();column.add_child(title)
	widgets.label(title,"研究设备 · 切换保留工作量",20).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="收起";title.add_child(close);close.pressed.connect(func():_set_drawer(false))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	_worklist=VBoxContainer.new();_worklist.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_worklist)
	_drawer.hide()
	_research_progress=ProgressBar.new();_research_progress.max_value=1;_research_progress.custom_minimum_size.y=18;_research_progress.show_percentage=false;add_child(_research_progress)
	_research_detail=widgets.label(self,"工作量与当前进度",17)
	move_child(_research_progress,3);move_child(_research_detail,4)
func _set_drawer(open:bool)->void:
	_drawer.visible=open
	_refresh_stage()
func _refresh_stage()->void:
	var model:Dictionary=_research.presentation_model()
	var active:Dictionary={}
	for row in model.rows:
		if row.active:active=row
		if not row.available:
			if _machine_rows.has(row.id):_machine_rows[row.id].line.hide()
			continue
		if active.is_empty():active=row
		if _drawer.visible:
			if not _machine_rows.has(row.id):
				var line:=HBoxContainer.new();_worklist.add_child(line)
				var icon=preload("res://scripts/ai_tech_factory_art.gd").new();icon.icon_mode=true;icon.technology_id=_art_key(row.id);icon.custom_minimum_size=Vector2(84,84);line.add_child(icon)
				var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
				var choose:Button=_command(line,"开始研究",func():
					var result:Dictionary=_research.select(row.id)
					if result.ok:_set_drawer(false)
					return result)
				_machine_rows[row.id]={"line":line,"label":label,"button":choose}
			var view:Dictionary=_machine_rows[row.id]
			view.line.show()
			view.label.text="%s · Lv.%d\n工作量 %s / %s%s"%[row.name,row.level,PlayerText.number(str(row.work)),PlayerText.number(str(row.required))," · 研究中" if row.active else ""]
			view.button.disabled=not row.available or row.active
			view.button.text="研究中" if row.active else "开始研究" if row.available else "前置未满足"
	var context:Dictionary=_visual_context.call() if _visual_context.is_valid() else {}
	var paused:bool=bool(context.get("paused",false))
	var advancing:bool=not paused
	if active.is_empty():
		_research_title.text="暂无可研究设备";_art.hide();_research_detail.text="满足前置条件后显示对应设备";return
	_art.show()
	if not active.is_empty():
		_research_title.text="%s · Lv.%d"%[active.name,active.level]
		_research_progress.value=active.progress
		_research_detail.text="%s · 工作量 %s / %s · %.1f%%"%["正在研究" if active.active and advancing else "已暂停" if paused else "等待选择研究",PlayerText.number(str(active.work)),PlayerText.number(str(active.required)),float(active.progress)*100.0]
		_art.set_display(_art_key(active.id),active.level,active.active and advancing,active.progress)
	_art.set_obscured(_drawer.visible or paused)
