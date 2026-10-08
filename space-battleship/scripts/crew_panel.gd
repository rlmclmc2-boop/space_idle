extends Control
## Event-driven page. Rows/options survive ordinary changes, including hidden updates.
## Selection changes row highlights and the detail; crew changes update dependent labels/actions.
## Exploration samples update only the selected countdown. Unlocks add/remove affected rows.
## Equipment slots remain a crew_system/profile interface with no presentation on this page.
var host: Node
var rows: Dictionary = {}
var selected := ""
var list: VBoxContainer
var scroll: ScrollContainer
var detail_scroll: ScrollContainer
var title: Label
var description: Label
var status: Label
var jobs: OptionButton
var target_picker: OptionButton
var target_label: Label
var upgrade_picker: OptionButton
var mode_ids: Array[String] = []
var assign_button: Button
var assignment_reason: Label
var assignment_preview: Label
var release_button: Button
var job_ids: Array = []
var target_ids: Array = []
var dirty := true
var locked_preview: Button
var job_label: Label
var exploration_samples: Dictionary = {}

const SPACE_PERMISSION := preload("res://scripts/hyperspace_permissions.gd")

const SKIN := preload("res://scripts/dialog_presentation.gd")
const SURFACE := Color("ecebdc")
const ACCENT := Color("83cfcb")
const BORDER := Color("243d50")
const INK := Color("243d50")
const MUTED := Color("506878")
const GENERIC_PORTRAIT := "res://assets/ui/crew.svg"
const JOB_ICONS := {"equipment":preload("res://assets/ui/shell/equipment.svg"),"hightech":preload("res://assets/ui/shell/research.svg"),"reactor":preload("res://assets/ui/shell/reactor.svg"),"jewel":preload("res://assets/ui/shell/jewel.svg"),"galaxy":preload("res://assets/ui/shell/galaxy.svg")}
const ENHANCEMENT_BADGE := "res://assets/ui/shell/enhancement.svg"
const IDLE_ICON := preload("res://assets/ui/shell/crew.svg")
const EXPLORATION_ICON := preload("res://assets/ui/shell/planet.svg")
var row_fields: Dictionary = {}
var portrait: TextureRect
var experience: ProgressBar
var exp_label: Label
var list_heading: Label
var effect_section: VBoxContainer
var effect_title: Label
var assignment_section: VBoxContainer
var detail_body: VBoxContainer
var level_effect_label: Label
var parameter_column: VBoxContainer
var empty_label: Label
var level_section: VBoxContainer
var assignment_badge: TextureRect

func label(parent: Node, value: String, font_size := 22, color := INK) -> Label:
	var control:=Label.new()
	control.text=value
	control.add_theme_font_size_override("font_size",font_size)
	control.add_theme_font_override("font",SKIN.SHELL.face(600 if font_size>=24 else 500))
	control.add_theme_color_override("font_color",color)
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func section(parent: Node, key: String) -> VBoxContainer:
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	parent.add_child(box)
	var heading:=HBoxContainer.new()
	heading.add_theme_constant_override("separation",16)
	box.add_child(heading)
	var marker:=ColorRect.new()
	marker.color=ACCENT
	marker.custom_minimum_size=Vector2(4,24)
	marker.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	heading.add_child(marker)
	label(heading,UIText.t(key),24,INK)
	var line:=HSeparator.new()
	var divider:=StyleBoxLine.new()
	divider.color=BORDER
	divider.thickness=2
	line.add_theme_stylebox_override("separator",divider)
	line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	heading.add_child(line)
	return box

func avatar(parent: Node, extent: float) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=IDLE_ICON
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2.ONE*extent
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func setup(owner_ui: Node) -> void:
	host=owner_ui
	add_theme_font_override("font",SKIN.SHELL.face(500))
	theme=SKIN.theme()
	var header:=label(self,UIText.t("crew.heading"),32,ACCENT)
	header.position=Vector2(24,18)
	var subtitle:=label(self,UIText.t("crew.page_hint"),18,SURFACE)
	subtitle.position=Vector2(24,62)
	for region in [Rect2(16,112,476,1046),Rect2(508,112,824,1046)]:
		var frame:=Panel.new()
		frame.position=region.position
		frame.size=region.size
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",SKIN.surface(SURFACE,BORDER,0))
		add_child(frame)
	list_heading=label(self,UIText.t("crew.list_heading"),24,INK)
	list_heading.position=Vector2(34,130)
	scroll=ScrollContainer.new()
	scroll.position=Vector2(30,178)
	scroll.size=Vector2(448,954)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	detail_scroll=ScrollContainer.new()
	detail_scroll.position=Vector2(536,140)
	detail_scroll.size=Vector2(768,990)
	empty_label=label(self,UIText.t("crew.empty"),24,MUTED)
	empty_label.position=Vector2(560,180)
	empty_label.size=Vector2(712,120)
	empty_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	detail_body=VBoxContainer.new()
	detail_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail_body.add_theme_constant_override("separation",28)
	detail_scroll.add_child(detail_body)
	var identity:=HBoxContainer.new()
	identity.add_theme_constant_override("separation",24)
	detail_body.add_child(identity)
	portrait=avatar(identity,96)
	var identity_text:=VBoxContainer.new()
	identity_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	identity_text.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	identity_text.add_theme_constant_override("separation",10)
	identity.add_child(identity_text)
	title=label(identity_text,"",30)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var status_row:=HBoxContainer.new()
	status_row.add_theme_constant_override("separation",10)
	identity_text.add_child(status_row)
	assignment_badge=avatar(status_row,28)
	status=label(status_row,"",20,MUTED)
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	effect_section=section(detail_body,"crew.current_effect")
	var effect_body:=VBoxContainer.new()
	effect_body.add_theme_constant_override("separation",8)
	effect_section.add_child(effect_body)
	effect_title=label(effect_body,"",26)
	description=label(effect_body,"",22,MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	assignment_section=section(detail_body,"crew.assignment_settings")
	var settings:=HBoxContainer.new()
	settings.add_theme_constant_override("separation",24)
	assignment_section.add_child(settings)
	var job_column:=VBoxContainer.new()
	job_column.add_theme_constant_override("separation",10)
	job_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings.add_child(job_column)
	job_label=label(job_column,UIText.t("crew.assign_to"),20,MUTED)
	jobs=picker(job_column)
	jobs.item_selected.connect(func(_index):refresh_targets();refresh_actions())
	parameter_column=VBoxContainer.new()
	parameter_column.add_theme_constant_override("separation",10)
	parameter_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings.add_child(parameter_column)
	target_label=label(parameter_column,"",20,MUTED)
	target_picker=picker(parameter_column)
	target_picker.item_selected.connect(func(_index):refresh_actions())
	upgrade_picker=picker(parameter_column)
	upgrade_picker.item_selected.connect(func(index):host.game.crew.set_upgrade_mode(host.game,selected,mode_ids[index],job_ids[jobs.selected]))
	assignment_preview=label(assignment_section,"",20,MUTED)
	assignment_preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var buttons:=HBoxContainer.new()
	buttons.add_theme_constant_override("separation",24)
	assignment_section.add_child(buttons)
	assign_button=action("crew.confirm_assign",func():
		if jobs.selected>=0 and target_picker.selected>=0:
			if not host.game.crew.assign(host.game,selected,job_ids[jobs.selected],target_ids[target_picker.selected]):refresh_actions(),buttons,true)
	release_button=action("crew.release",func():host.game.crew.assign(host.game,selected,"",""),buttons)
	assignment_reason=label(assignment_section,UIText.t("crew.hyperspace_busy_reason"),20,MUTED)
	assignment_reason.visible=false
	locked_preview=Button.new()
	locked_preview.custom_minimum_size=Vector2(0,74)
	locked_preview.disabled=true
	locked_preview.focus_mode=Control.FOCUS_NONE
	locked_preview.alignment=HORIZONTAL_ALIGNMENT_LEFT
	locked_preview.icon=preload("res://assets/ui/crew/locked.svg")
	locked_preview.add_theme_constant_override("icon_max_width",42)
	locked_preview.add_theme_constant_override("h_separation",16)
	locked_preview.add_theme_font_size_override("font_size",20)
	locked_preview.add_theme_color_override("font_disabled_color",MUTED)
	var locked_style=SKIN.surface(Color("d6ded4"),Color("80949a"),16)
	locked_style.content_margin_left=16
	locked_preview.add_theme_stylebox_override("disabled",locked_style)
	list.add_child(locked_preview)
	visibility_changed.connect(func():
		if is_visible_in_tree():refresh())
	refresh()

func picker(parent: Control) -> OptionButton:
	var control:=OptionButton.new()
	control.custom_minimum_size=Vector2(0,56)
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	control.fit_to_longest_item=false
	control.add_theme_font_size_override("font_size",22)
	SKIN.option(control)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var skin: StyleBoxFlat=control.get_theme_stylebox(state).duplicate()
		skin.content_margin_left=16
		skin.content_margin_right=38
		control.add_theme_stylebox_override(state,skin)
	parent.add_child(control)
	return control

func action(key: String, callback: Callable, parent: Control, primary := false) -> Button:
	var control: Button=host.button(UIText.t(key),Rect2(0,0,0,60),callback)
	control.custom_minimum_size=Vector2(0,60)
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size",24)
	SKIN.button_skin(control,primary)
	control.reparent(parent,false)
	return control

func invalidate() -> void:
	dirty=true
	if is_visible_in_tree():refresh()

func refresh_member(item: Dictionary) -> void:
	# Experience payouts can update every crew member in one simulation step.
	# Only the changed row and selected inspector depend on this member's level.
	if not is_visible_in_tree():
		dirty=true
		return
	if dirty or not rows.has(str(item.crewId)):
		refresh()
		return
	refresh_row(item)
	if selected==str(item.crewId):refresh_detail()

func exploration_remaining(id: String) -> int:
	var progress: Dictionary=host.game.planet_progress(id)
	return ceili(maxf(0.0,host.game.planet_duration(id)-float(progress.get("elapsed",0))))

func exploration_name(id: String) -> String:
	return UIText.data_text("planet",id,"name",str(host.game.planet_row(id).get("name",id)))

func refresh_exploration_sample() -> void:
	if not is_visible_in_tree():return
	if dirty:
		refresh()
		return
	for planet_id in host.game.profile.planets:
		var crew_id: String=str(host.game.profile.planets[planet_id].get("crewId",""))
		if crew_id.is_empty():continue
		var remaining:=exploration_remaining(str(planet_id))
		if exploration_samples.get(crew_id,-1)==remaining:continue
		exploration_samples[crew_id]=remaining
		var item: Dictionary=host.game.crew.entry(host.game,crew_id)
		if not item.is_empty() and rows.has(crew_id):refresh_row(item)
		if selected==crew_id:refresh_detail_status(item)

func hyperspace_reserved(id: String) -> bool:
	return not id.is_empty() and SPACE_PERMISSION.reserved_crew(host.game.profile.hyperspace)==id

func refresh_row(item: Dictionary) -> void:
	var g=host.game
	var id: String=item.crewId
	var definition: Dictionary=g.crew.definitions(g)[id]
	var planet_id: String=g.crew_exploration(id)
	var assigned:=not str(item.assignmentType).is_empty()
	var fields: Dictionary=row_fields[id]
	host.set_ui_value(fields.name,"text",g.crew.display_name(g,item))
	var role:=UIText.t("crew.free")
	if hyperspace_reserved(id):role=UIText.t("crew.hyperspace_reserved_short")
	elif not planet_id.is_empty():role=UIText.t("crew.exploring" if str(g.planet_progress(planet_id).crewId)==id else "planet.builder_role")
	elif assigned:
		role=job_title(g.crew.assignments(g).get(item.assignmentType,{}))
	host.set_ui_value(fields.role,"text",role)
	var state:=UIText.t("crew.paused") if assigned and not g.crew.active(g,item) else ""
	host.set_ui_value(fields.state,"text",state)
	host.set_ui_value(fields.avatar,"texture",member_portrait(item))
	host.set_ui_value(fields.badge,"texture",job_icon(item))
	var tooltip: String=g.crew.display_name(g,item)+"\n"+role+(" · "+state if not state.is_empty() else "")
	if hyperspace_reserved(id):tooltip+="\n"+UIText.t("crew.hyperspace_busy_reason")
	if g.crew.levels_unlocked(g):tooltip+="\n"+experience_text(item,true)
	host.set_ui_value(rows[id],"tooltip_text",tooltip)

func refresh() -> void:
	if not is_visible_in_tree():
		dirty=true
		return
	var g=host.game
	var ids: Array=[]
	var next_gate := -1
	var next_number := 0
	var ordinal := 0
	for item in g.profile.crew:
		ordinal+=1
		if not g.crew.unlocked(g,item.crewId):
			var gate: Dictionary=g.db.data.get("unlock",{}).get(str(g.crew.definitions(g)[item.crewId].get("unlockId","")),{})
			var level := int(gate.get("level",-1))
			if level>=0 and (next_gate<0 or level<next_gate):
				next_gate=level
				next_number=ordinal
			continue
		var id: String=item.crewId
		ids.append(id)
		var definition: Dictionary=g.crew.definitions(g)[id]
		if not rows.has(id):
			var button:=Button.new()
			button.custom_minimum_size=Vector2(0,116)
			SKIN.button_skin(button)
			button.add_theme_stylebox_override("hover",SKIN.surface(Color("d6e9df"),BORDER,4))
			button.pressed.connect(func():select(id))
			list.add_child(button)
			rows[id]=button
			var marker:=ColorRect.new()
			marker.color=Color.TRANSPARENT
			marker.position=Vector2(7,18)
			marker.size=Vector2(6,80)
			marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(marker)
			var image:=avatar(button,64)
			image.position=Vector2(22,22)
			image.size=Vector2(64,64)
			var name_label:=label(button,"",24)
			name_label.position=Vector2(104,16)
			name_label.size=Vector2(312,36)
			name_label.clip_text=true
			name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			var badge:=avatar(button,26)
			badge.position=Vector2(104,65)
			badge.size=Vector2(26,26)
			var role_label:=label(button,"",21,MUTED)
			role_label.position=Vector2(138,59)
			role_label.size=Vector2(182,40)
			role_label.clip_text=true
			role_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			var state_label:=label(button,"",18,MUTED)
			state_label.position=Vector2(324,61)
			state_label.size=Vector2(96,36)
			state_label.clip_text=true
			state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			row_fields[id]={"name":name_label,"role":role_label,"state":state_label,"avatar":image,"badge":badge,"marker":marker}
		refresh_row(item)
	for id in rows.keys():
		if not ids.has(id):
			rows[id].queue_free()
			rows.erase(id)
			row_fields.erase(id)
	var changed_selection:=not ids.has(selected)
	if changed_selection:selected=str(ids[0]) if not ids.is_empty() else ""
	refresh_selection()
	host.set_ui_value(locked_preview,"visible",next_gate>=0)
	host.set_ui_value(locked_preview,"text",UIText.t("crew.locked_row",{"number":"%02d" % next_number,"level":next_gate}) if next_gate>=0 else "")
	if locked_preview.get_index()!=list.get_child_count()-1:list.move_child(locked_preview,list.get_child_count()-1)

	refresh_jobs()
	if changed_selection and not selected.is_empty():select(selected)
	else:refresh_detail()
	dirty=false

func select(id: String) -> void:
	if not host.game.crew.unlocked(host.game,id):return
	selected=id
	refresh_selection()
	var item: Dictionary=host.game.crew.entry(host.game,id)
	var index:=job_ids.find(item.assignmentType)
	if index>=0:jobs.select(index)
	refresh_targets()
	index=target_ids.find(item.targetId)
	if index>=0:target_picker.select(index)
	refresh_detail()

func refresh_selection() -> void:
	for id in rows:
		var button: Button=rows[id]
		var active: bool=id==selected
		if button.get_meta("selected",false)==active:continue
		button.set_meta("selected",active)
		button.add_theme_stylebox_override("normal",SKIN.surface(Color("b7ddd2") if active else Color("f7f4e6"),BORDER,4))
		row_fields[id].marker.color=INK if active else Color.TRANSPARENT

func job_title(row: Dictionary) -> String:
	return UIText.t(str(row.titleTextId)) if not str(row.get("titleTextId","")).is_empty() else str(row.get("description",""))

func refresh_jobs() -> void:
	var definitions: Dictionary=host.game.crew.assignments(host.game)
	var ids: Array=definitions.keys().filter(func(id):return definitions[id].targetType!="galaxy" or host.game.galaxy.available())
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

func refresh_job_availability() -> void:
	# Crew selection/assignment changes only option flags and an invalidated draft.
	# The owner may keep its own system; other crew must choose a free target.
	var g=host.game
	for index in job_ids.size():
		var job: String=job_ids[index]
		var available: bool=g.crew.available_targets(g,job).any(func(target):return g.crew.can_assign(g,selected,job,str(target.id)))
		if jobs.is_item_disabled(index)==available:jobs.set_item_disabled(index,not available)
	if jobs.selected<0 or jobs.is_item_disabled(jobs.selected):
		var next := -1
		for index in job_ids.size():
			if not jobs.is_item_disabled(index):
				next=index
				break
		if jobs.selected!=next:jobs.select(next)
		if next<0:host.set_ui_value(jobs,"text",UIText.t("crew.no_available_system"))
	refresh_targets()

func refresh_detail() -> void:
	var g=host.game
	var item: Dictionary=g.crew.entry(g,selected)
	host.set_ui_value(detail_body,"visible",not item.is_empty())
	host.set_ui_value(empty_label,"visible",item.is_empty())
	if item.is_empty():return
	var row: Dictionary=g.crew.definitions(g)[selected]
	host.set_ui_value(title,"text",g.crew.display_name(g,item))
	host.set_ui_value(portrait,"texture",member_portrait(item))
	host.set_ui_value(assignment_badge,"texture",job_icon(item))
	refresh_detail_status(item)
	refresh_actions()

func experience_text(item: Dictionary, exact := false) -> String:
	var g=host.game
	var required: float=g.crew.required_exp(g,int(item.level))
	var current: float=float(item.exp)
	var shown: String=NumberFormat.precise(current) if exact else host.number(current)
	var needed: String=NumberFormat.precise(required) if exact else host.number(required)
	# Equal abbreviations must not imply an upgrade before the actual threshold.
	if not exact and current<required and shown==needed:shown="<"+shown
	return g.crew.format_text(g,"exp_bar",{"exp":shown,"needed":needed})

func refresh_detail_status(item: Dictionary) -> void:
	var g=host.game
	ensure_level_ui()
	if is_instance_valid(level_section):host.set_ui_value(level_section,"visible",g.crew.levels_unlocked(g))
	if g.crew.levels_unlocked(g):
		var required: float=g.crew.required_exp(g,int(item.level))
		host.set_ui_value(exp_label,"text",experience_text(item))
		var exact: String=experience_text(item,true)
		host.set_ui_value(exp_label,"tooltip_text",exact)
		host.set_ui_value(experience,"tooltip_text",exact)
		host.set_ui_value(experience,"value",clampf(float(item.exp)/required*100.0,0,100))
		var effects: String=g.crew.level_description(g,item)
		host.set_ui_value(level_effect_label,"text",effects)
		host.set_ui_value(level_effect_label,"visible",not effects.is_empty())
	var planet_id: String=g.crew_exploration(str(item.crewId))
	var assigned:=not str(item.assignmentType).is_empty()
	var state:=UIText.t("crew.assigned") if assigned else UIText.t("crew.free")
	if hyperspace_reserved(str(item.crewId)):
		state=UIText.t("crew.hyperspace_reserved")
	elif not planet_id.is_empty():
		state=UIText.t("crew.exploring_brief",{"planet":exploration_name(planet_id),"remaining":exploration_remaining(planet_id)}) if str(g.planet_progress(planet_id).crewId)==str(item.crewId) else UIText.t("planet.builder_status",{"planet":exploration_name(planet_id)})
	elif assigned and not g.crew.active(g,item):state=UIText.t("crew.paused")
	host.set_ui_value(status,"text",state)
	host.set_ui_value(status,"tooltip_text",UIText.t("crew.hyperspace_busy_reason") if hyperspace_reserved(str(item.crewId)) else "")
	host.set_ui_value(effect_section,"visible",assigned and planet_id.is_empty())
	if not assigned:return
	var job: Dictionary=g.crew.assignments(g).get(item.assignmentType,{})
	var kind:=str(job.get("effectType",""))
	var effect_key: String={"AUTO_UPGRADE":"equipment","AUTO_SCIENTIST":"scientist","AUTO_COMBINE":"jewel","AUTO_REACTOR":"reactor","OUTPUT":"output"}.get(kind,"")
	host.set_ui_value(effect_title,"text",UIText.t("crew.core_title."+effect_key) if not effect_key.is_empty() else job_title(job))
	var text: String=g.crew.effect_text(g,item)
	if g.crew.active(g,item) and not effect_key.is_empty():
		var value: float=g.crew.effect_value(g,item)
		var interval: String="%.1f" % (float(job.interval)/value if value>0 else 0.0)
		var mode: String=str(item.get("upgradeMode","1"))
		if kind=="AUTO_UPGRADE":
			text=UIText.t("crew.core_equipment",{"interval":interval,"amount":UIText.t("crew.amount_max") if mode=="max" else UIText.t("crew.amount_levels",{"count":mode})})
		elif kind=="AUTO_SCIENTIST":text=UIText.t("crew.core_scientist",{"interval":interval,"amount":g.crew.upgrade_mode_text(mode,kind)})
		elif kind=="AUTO_COMBINE":text=UIText.t("crew.core_jewel",{"interval":interval})
		elif kind=="OUTPUT":text=UIText.t("crew.effect.output",{"value":"%.1f" % (value*100)})
	host.set_ui_value(description,"text",text)

func assignment_preview_text(item: Dictionary, row: Dictionary) -> String:
	var kind:=str(row.get("effectType",""))
	var key: String={"AUTO_UPGRADE":"equipment","AUTO_SCIENTIST":"scientist","AUTO_COMBINE":"enhancement","AUTO_REACTOR":"reactor"}.get(kind,"")
	if key.is_empty() or jobs.selected<0:return ""
	var g=host.game
	var value: float=g.crew.effect_value(g,{"crewId":item.crewId,"assignmentType":job_ids[jobs.selected]})
	if value<=0:return ""
	var values: Dictionary={"interval":"%.1f" % (float(row.interval)/value)}
	var mode:=str(item.get("upgradeMode","1"))
	if kind=="AUTO_UPGRADE":
		values.amount=UIText.t("crew.preview.maximum") if mode=="max" else g.crew.upgrade_mode_text(mode,kind)
	elif kind=="AUTO_SCIENTIST":
		values.amount=g.crew.upgrade_mode_text(mode,kind)
		var resources:=PackedStringArray()
		for id in g.scientist_cost():resources.append(UIText.data_text("resources",str(id)))
		values.resources="、".join(resources)
	return UIText.t("crew.preview."+key,values)

func refresh_actions() -> void:
	var g=host.game
	var item: Dictionary=g.crew.entry(g,selected)
	refresh_job_availability()
	var exploring: bool=not g.crew_exploration(selected).is_empty()
	host.set_ui_value(assignment_section,"visible",not exploring and not item.is_empty())
	if exploring or item.is_empty():return
	var row: Dictionary=g.crew.assignments(g).get(job_ids[jobs.selected],{}) if jobs.selected>=0 else {}
	var equipment: bool=row.get("targetType")=="equipment" and row.get("effectType")=="AUTO_UPGRADE"
	var scientist: bool=row.get("targetType")=="hightech" and row.get("effectType")=="AUTO_SCIENTIST"
	var automatic:=equipment or scientist
	var choose_target: bool=not automatic and target_ids.size()>1
	host.set_ui_value(target_label,"text",UIText.t("crew.amount_label" if equipment else "crew.ai_amount_label" if scientist else "crew.choose_target"))
	host.set_ui_value(parameter_column,"visible",automatic or choose_target)
	host.set_ui_value(target_picker,"visible",choose_target)
	host.set_ui_value(upgrade_picker,"visible",automatic)
	var modes: Array[String]=[]
	if jobs.selected>=0:modes=g.crew.upgrade_modes(g,job_ids[jobs.selected])
	if modes!=mode_ids or upgrade_picker.get_meta("effect_type","")!=str(row.get("effectType","")):
		mode_ids=modes
		upgrade_picker.clear()
		for mode in modes:
			upgrade_picker.add_item((UIText.t("crew.amount_max") if mode=="max" else UIText.t("crew.amount_levels",{"count":mode})) if equipment else g.crew.upgrade_mode_text(mode,str(row.effectType)))
		upgrade_picker.set_meta("effect_type",str(row.get("effectType","")))
	host.set_ui_value(upgrade_picker,"selected",mode_ids.find(str(item.get("upgradeMode",""))))
	host.set_ui_value(upgrade_picker,"disabled",item.is_empty())
	var preview: String=assignment_preview_text(item,row)
	host.set_ui_value(assignment_preview,"text",preview)
	host.set_ui_value(assignment_preview,"visible",not preview.is_empty())
	var valid:=jobs.selected>=0 and target_picker.selected>=0
	var space_reserved:=hyperspace_reserved(selected)
	host.set_ui_value(assignment_reason,"visible",space_reserved)
	host.set_ui_value(assign_button,"tooltip_text",UIText.t("crew.hyperspace_busy_reason") if space_reserved else "")
	host.set_ui_value(assign_button,"disabled",space_reserved or not valid or not g.crew.can_assign(g,selected,job_ids[jobs.selected] if valid else "",target_ids[target_picker.selected] if valid else ""))
	var assigned:=not str(item.get("assignmentType","")).is_empty()
	host.set_ui_value(assign_button,"text",UIText.t("crew.confirm_change" if assigned else "crew.confirm_assign"))
	host.set_ui_value(release_button,"visible",assigned)
	host.set_ui_value(release_button,"disabled",not assigned)

func ensure_level_ui() -> void:
	if not host.game.crew.levels_unlocked(host.game) or is_instance_valid(experience):return
	var progress:=VBoxContainer.new()
	level_section=progress
	progress.add_theme_constant_override("separation",10)
	detail_body.add_child(progress)
	exp_label=label(progress,"",22,INK)
	exp_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	exp_label.mouse_filter=Control.MOUSE_FILTER_PASS
	experience=ProgressBar.new()
	experience.step=0.0
	experience.custom_minimum_size=Vector2(0,20)
	experience.show_percentage=false
	experience.add_theme_stylebox_override("background",SKIN.surface(Color("d4ded6"),BORDER,0))
	experience.add_theme_stylebox_override("fill",SKIN.surface(ACCENT,BORDER,0))
	progress.add_child(experience)
	detail_body.move_child(progress,1)
	level_effect_label=label(progress,"",20,MUTED)
	level_effect_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func job_icon(item: Dictionary) -> Texture2D:
	if hyperspace_reserved(str(item.crewId)) or not host.game.crew_exploration(str(item.crewId)).is_empty():return EXPLORATION_ICON
	var job: Dictionary=host.game.crew.assignments(host.game).get(str(item.assignmentType),{})
	var target_type:=str(job.get("targetType",""))
	# The enhancement rollout retains the legacy jewel assignment identity.
	# Its UI owns this icon; prefer it once that independently landed asset exists.
	if target_type=="jewel" and ResourceLoader.exists(ENHANCEMENT_BADGE):return load(ENHANCEMENT_BADGE)
	return JOB_ICONS.get(target_type,IDLE_ICON)

func member_portrait(item: Dictionary) -> Texture2D:
	var definition: Dictionary=host.game.crew.definitions(host.game)[str(item.crewId)]
	var path:=str(definition.get("icon",""))
	# The shipped generic silhouette has no character identity. Show the current
	# job badge for that fallback only; a configured custom portrait always wins.
	if not path.is_empty() and path!=GENERIC_PORTRAIT and ResourceLoader.exists(path):return load(path)
	return job_icon(item)
