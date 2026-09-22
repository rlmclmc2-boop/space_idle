extends Control
## Event-driven page. Rows/options survive ordinary changes, including hidden updates.
var host: Node
var rows: Dictionary = {}
var selected := ""
var list: VBoxContainer
var scroll: ScrollContainer
var title: Label
var description: Label
var status: Label
var slots: Label
var jobs: OptionButton
var target_picker: OptionButton
var target_label: Label
var upgrade_picker: OptionButton
var mode_ids: Array[String] = []
var assign_button: Button
var release_button: Button
var job_ids: Array = []
var target_ids: Array = []
var dirty := true
var locked_preview: Button
var job_label: Label
var api_hint: Label
var detail_controls: Array[Control] = []

func setup(owner_ui: Node) -> void:
	host=owner_ui
	add_theme_font_override("font",host.font)
	host.equipment_card_label(self,UIText.t("crew.heading"),Rect2(24,14,850,40),27,host.CYAN)
	api_hint=host.equipment_card_label(self,UIText.t("crew.api_only"),Rect2(24,58,1200,30),14,host.MUTED)
	scroll=ScrollContainer.new()
	scroll.position=Vector2(24,105)
	scroll.size=Vector2(550,500)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	title=host.equipment_card_label(self,"",Rect2(620,108,650,40),24,host.CYAN)
	description=host.equipment_card_label(self,"",Rect2(620,158,650,60),15)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=host.equipment_card_label(self,"",Rect2(620,224,650,66),15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	job_label=host.equipment_card_label(self,UIText.t("crew.choose_job"),Rect2(620,306,640,24),14,host.MUTED)
	jobs=picker(Rect2(620,337,650,38))
	jobs.item_selected.connect(func(_index):refresh_targets();refresh_actions())
	target_label=host.equipment_card_label(self,UIText.t("crew.choose_target"),Rect2(620,388,640,24),14,host.MUTED)
	target_picker=picker(Rect2(620,419,650,38))
	target_picker.item_selected.connect(func(_index):refresh_actions())
	upgrade_picker=picker(Rect2(620,419,650,38))
	upgrade_picker.item_selected.connect(func(index):host.game.crew.set_upgrade_mode(host.game,selected,mode_ids[index]))
	assign_button=action("crew.assign",Rect2(620,479,305,40),func():
		if jobs.selected>=0 and target_picker.selected>=0:
			if not host.game.crew.assign(host.game,selected,job_ids[jobs.selected],target_ids[target_picker.selected]):refresh_actions())
	release_button=action("crew.release",Rect2(950,479,320,40),func():host.game.crew.assign(host.game,selected,"",""))
	slots=host.equipment_card_label(self,"",Rect2(620,552,650,48),15,host.MUTED)
	detail_controls.assign([title,description,status,slots,job_label,jobs,target_label,target_picker,upgrade_picker,assign_button,release_button])
	locked_preview=Button.new()
	locked_preview.custom_minimum_size=Vector2(520,116)
	locked_preview.disabled=true
	locked_preview.focus_mode=Control.FOCUS_NONE
	locked_preview.icon=preload("res://assets/ui/crew_locked.svg")
	locked_preview.add_theme_font_size_override("font_size",18)
	locked_preview.add_theme_color_override("font_disabled_color",host.MUTED)
	locked_preview.add_theme_stylebox_override("disabled",host.style(host.PANEL,host.LINE))
	list.add_child(locked_preview)
	visibility_changed.connect(func():
		if is_visible_in_tree():refresh())
	refresh()

func picker(rect: Rect2) -> OptionButton:
	var control:=OptionButton.new()
	control.position=rect.position
	control.size=rect.size
	control.fit_to_longest_item=false
	add_child(control)
	return control

func action(key: String, rect: Rect2, callback: Callable) -> Button:
	var control: Button=host.button(UIText.t(key),rect,callback)
	control.reparent(self,false)
	return control

func invalidate() -> void:
	dirty=true
	if is_visible_in_tree():refresh()

func refresh() -> void:
	if not is_visible_in_tree():
		dirty=true
		return
	var g=host.game
	var ids: Array=[]
	var next_gate := -1
	for item in g.profile.crew:
		if not g.crew.unlocked(g,item.crewId):
			var gate: Dictionary=g.db.data.get("unlock",{}).get(str(g.crew.definitions(g)[item.crewId].get("unlockId","")),{})
			var level := int(gate.get("level",-1))
			if level>=0 and (next_gate<0 or level<next_gate):next_gate=level
			continue
		var id: String=item.crewId
		ids.append(id)
		var definition: Dictionary=g.crew.definitions(g)[id]
		if not rows.has(id):
			var button:=Button.new()
			button.custom_minimum_size=Vector2(520,116)
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size",16)
			button.add_theme_stylebox_override("normal",host.style(host.PANEL,host.LINE))
			button.add_theme_stylebox_override("focus",host.style(host.PANEL,host.CYAN))
			button.pressed.connect(func():select(id))
			list.add_child(button)
			rows[id]=button
			if ResourceLoader.exists(str(definition.icon)):
				button.icon=load(str(definition.icon))
		var job: Dictionary=g.crew.assignments(g).get(item.assignmentType,{})
		var role:=job_title(job) if not job.is_empty() else UIText.t("crew.idle")
		host.set_ui_value(rows[id],"text",UIText.t("crew.row",{"name":definition.name,"level":item.level,"job":role,"target":g.crew.target_name(g,item),"effect":g.crew.effect_text(g,item)}))
		host.set_ui_value(rows[id],"tooltip_text",str(definition.description))
	for id in rows.keys():
		if not ids.has(id):
			rows[id].queue_free()
			rows.erase(id)
	if not ids.has(selected):selected=str(ids[0]) if not ids.is_empty() else ""
	host.set_ui_value(locked_preview,"visible",next_gate>=0)
	host.set_ui_value(locked_preview,"text",UIText.t("crew.unlock_at",{"level":next_gate}) if next_gate>=0 else "")
	if locked_preview.get_index()!=list.get_child_count()-1:list.move_child(locked_preview,list.get_child_count()-1)
	host.set_ui_value(api_hint,"visible",not ids.is_empty())
	refresh_jobs()
	refresh_detail()
	dirty=false

func select(id: String) -> void:
	if not host.game.crew.unlocked(host.game,id):return
	selected=id
	var item: Dictionary=host.game.crew.entry(host.game,id)
	var index:=job_ids.find(item.assignmentType)
	if index>=0:jobs.select(index)
	refresh_targets()
	index=target_ids.find(item.targetId)
	if index>=0:target_picker.select(index)
	refresh_detail()

func job_title(row: Dictionary) -> String:
	return UIText.t(str(row.titleTextId)) if not str(row.get("titleTextId","")).is_empty() else str(row.get("description",""))

func refresh_jobs() -> void:
	var definitions: Dictionary=host.game.crew.assignments(host.game)
	var ids: Array=definitions.keys()
	if ids != job_ids:
		var old: String=job_ids[jobs.selected] if jobs.selected>=0 else ""
		job_ids=ids
		jobs.clear()
		for id in ids:
			jobs.add_item(job_title(definitions[id]))
			jobs.set_item_disabled(jobs.item_count-1,not host.game.crew.supported(definitions[id]))
		if job_ids.has(old):jobs.select(job_ids.find(old))
	refresh_targets()

func refresh_targets() -> void:
	var options: Array=host.game.crew.available_targets(host.game,job_ids[jobs.selected]) if jobs.selected>=0 else []
	var ids: Array=options.map(func(item):return item.id)
	var names: Array=options.map(func(item):return item.name)
	if target_ids==ids and target_picker.get_meta("names",[])==names:return
	var old: String=target_ids[target_picker.selected] if target_picker.selected>=0 else ""
	target_ids=ids
	target_picker.clear()
	for item in options:target_picker.add_item(item.name)
	target_picker.set_meta("names",names)
	if ids.has(old):target_picker.select(ids.find(old))

func refresh_detail() -> void:
	var g=host.game
	var item: Dictionary=g.crew.entry(g,selected)
	for control in detail_controls:
		if item.is_empty() or control not in [target_picker,upgrade_picker]:
			host.set_ui_value(control,"visible",not item.is_empty())
	if item.is_empty():
		host.set_ui_value(title,"text","")
		for field in [description,status,slots]:host.set_ui_value(field,"text","")
		return
	var row: Dictionary=g.crew.definitions(g)[selected]
	var next: Dictionary=g.crew.growth(g,selected,int(item.level)+1)
	var needed: String=host.number(float(next.get("needExp",0))) if int(item.level)<int(row.maxLevel) else UIText.t("crew.max_level")
	host.set_ui_value(title,"text",UIText.t("crew.name_level",{"name":row.name,"level":item.level}))
	host.set_ui_value(description,"text",str(row.description))
	host.set_ui_value(status,"text",UIText.t("crew.progress",{"exp":host.number(float(item.exp)),"needed":needed,"effect":g.crew.effect_text(g,item)}))
	host.set_ui_value(slots,"text",UIText.t("crew.equipment_reserved",{"count":item.equipmentSlots.size()}))
	refresh_actions()

func refresh_actions() -> void:
	var g=host.game
	var item: Dictionary=g.crew.entry(g,selected)
	var row: Dictionary=g.crew.assignments(g).get(job_ids[jobs.selected],{}) if jobs.selected>=0 else {}
	var equipment: bool=row.get("targetType")=="equipment" and row.get("effectType")=="AUTO_UPGRADE"
	host.set_ui_value(target_label,"text",UIText.t("crew.upgrade_amount" if equipment else "crew.choose_target"))
	host.set_ui_value(target_picker,"visible",not equipment)
	host.set_ui_value(upgrade_picker,"visible",equipment)
	var modes: Array[String]=g.crew.upgrade_modes(g)
	if modes!=mode_ids:
		mode_ids=modes
		upgrade_picker.clear()
		for mode in modes:upgrade_picker.add_item(g.crew.upgrade_mode_text(mode))
	host.set_ui_value(upgrade_picker,"selected",mode_ids.find(str(item.get("upgradeMode",""))))
	host.set_ui_value(upgrade_picker,"disabled",item.is_empty())
	var valid:=jobs.selected>=0 and target_picker.selected>=0
	host.set_ui_value(assign_button,"disabled",not valid or not g.crew.can_assign(g,selected,job_ids[jobs.selected] if valid else "",target_ids[target_picker.selected] if valid else ""))
	host.set_ui_value(release_button,"disabled",item.is_empty() or str(item.get("assignmentType","")).is_empty())
	if jobs.selected>=0:
		host.set_ui_value(jobs,"tooltip_text",str(row.description) if g.crew.supported(row) else UIText.t("crew.unsupported"))
