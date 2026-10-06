extends Control
const CHROME := preload("res://scripts/dialog_presentation.gd")
const PARAMETERS := preload("res://scripts/parameter_text.gd")
var host
var game
var selected := ""
var selector := OptionButton.new()
var state_label := Label.new()
var complete_crew_hint := Label.new()
var start_button := Button.new()
var map := preload("res://scripts/galaxy_map.gd").new()
var crew_rows := {}
var crew_status := {}
var crew_row_nodes := {}
var manage_button := Button.new()
var help_button := Button.new()
var crew_dialog := AcceptDialog.new()
var help_dialog := AcceptDialog.new()
var crew_summary := Label.new()
var crew_empty := Label.new()
var crew_scroll := ScrollContainer.new()
var detail_frame := PanelContainer.new()
var cards := {}
var details := RichTextLabel.new()
var detail_slot := -1
var list_snapshot: Array=[]
var sample_elapsed := 0.0
var battle_modulate := Color.WHITE
var battle_dimmed := false

func setup(owner) -> void:
	host=owner
	game=owner.game
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel",CHROME.surface(CHROME.PAPER,CHROME.NAVY,16))
	add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	frame.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",12)
	box.add_child(heading)
	var icon := TextureRect.new()
	icon.texture=preload("res://assets/ui/shell/galaxy.svg")
	icon.custom_minimum_size=Vector2(36,36)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon)
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.y=44
	selector.add_theme_font_size_override("font_size",27)
	CHROME.option(selector)
	heading.add_child(selector)
	state_label.add_theme_font_override("font",CHROME.SHELL.face(500))
	state_label.add_theme_font_size_override("font_size",21)
	state_label.add_theme_color_override("font_color",CHROME.MUTED)
	state_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	heading.add_child(state_label)
	help_button.text=UIText.t("galaxy.help")
	help_button.tooltip_text=UIText.t("galaxy.help_title")
	help_button.add_theme_font_size_override("font_size",21)
	CHROME.button_skin(help_button)
	heading.add_child(help_button)
	help_button.pressed.connect(show_help)
	CHROME.button_skin(start_button,true)
	heading.add_child(start_button)
	start_button.text=UIText.t("galaxy.start")
	start_button.pressed.connect(func():game.galaxy.start(game,selected);refresh())
	selector.item_selected.connect(func(index):selected=str(selector.get_item_metadata(index));detail_slot=-1;game.galaxy.set_visible(selected);refresh())
	var summary := GridContainer.new()
	summary.columns=4
	summary.add_theme_constant_override("h_separation",8)
	box.add_child(summary)
	for key in ["exploration","buildings","max_level","crew"]:make_card(summary,key,true)
	complete_crew_hint.text=UIText.t("galaxy.complete_crew_hint")
	complete_crew_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	complete_crew_hint.add_theme_font_size_override("font_size",21)
	complete_crew_hint.add_theme_color_override("font_color",CHROME.MUTED)
	complete_crew_hint.visible=false
	box.add_child(complete_crew_hint)
	setup_crew_dialog()
	var map_frame := PanelContainer.new()
	map_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel",CHROME.surface(CHROME.NAVY,CHROME.NAVY,3))
	box.add_child(map_frame)
	var map_stack := Control.new()
	map_stack.custom_minimum_size=Vector2(300,330)
	map_stack.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_frame.add_child(map_stack)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_stack.add_child(map)
	map.configure(game.db.data.galaxy_config)
	map.slot_selected.connect(func(id):detail_slot=id;refresh_detail())
	var activity_bar := HBoxContainer.new()
	activity_bar.position=Vector2(14,10)
	activity_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	activity_bar.add_theme_constant_override("separation",20)
	map_stack.add_child(activity_bar)
	for key in ["explorers"]:
		var caption := Label.new()
		caption.text=UIText.t("galaxy.card_"+key)
		caption.add_theme_font_size_override("font_size",18)
		caption.add_theme_color_override("font_color",Color("98b2b7"))
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		activity_bar.add_child(caption)
		var value := Label.new()
		value.add_theme_font_size_override("font_size",18)
		value.add_theme_color_override("font_color",Color("bdcdce"))
		value.mouse_filter=Control.MOUSE_FILTER_IGNORE
		activity_bar.add_child(value)
		cards[key]=value
	var effect_grid := GridContainer.new()
	effect_grid.columns=6
	effect_grid.add_theme_constant_override("h_separation",8)
	box.add_child(effect_grid)
	for key in ["crew_exp","equipment_value","charge_max","gem_fragment","iron","uranium"]:make_card(effect_grid,key,false)
	detail_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	detail_frame.offset_left=10;detail_frame.offset_right=-10
	detail_frame.offset_top=-54;detail_frame.offset_bottom=-10
	detail_frame.add_theme_stylebox_override("panel",CHROME.surface(CHROME.PAPER,CHROME.NAVY,7))
	detail_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	map_stack.add_child(detail_frame)
	details.custom_minimum_size.y=32
	details.bbcode_enabled=true
	details.scroll_active=false
	details.fit_content=true
	details.add_theme_font_override("normal_font",CHROME.SHELL.face(500))
	details.add_theme_font_size_override("normal_font_size",20)
	details.add_theme_color_override("default_color",CHROME.NAVY)
	details.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_frame.add_child(details)
	detail_frame.visible=false
	help_dialog.transient=true;help_dialog.exclusive=true
	help_dialog.title=UIText.t("galaxy.help_title")
	help_dialog.dialog_text=UIText.t("galaxy.map_hint")+"\n"+UIText.t("galaxy.crew_rule")
	help_dialog.ok_button_text=UIText.t("galaxy.close")
	CHROME.dialog(help_dialog)
	add_child(help_dialog)
	visibility_changed.connect(sync_visibility)
	set_process(false)
	sync_visibility()
func make_card(parent: Node, key: String, primary: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style := CHROME.surface(Color("d5e5df") if primary else Color("f2f1e6"),CHROME.NAVY,8)
	style.set_border_width_all(2 if primary else 0)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",1)
	panel.add_child(column)
	var caption := Label.new()
	caption.text=UIText.t("galaxy.card_"+key)
	caption.add_theme_font_override("font",CHROME.SHELL.face(500))
	caption.add_theme_font_size_override("font_size",19 if primary else 17)
	caption.add_theme_color_override("font_color",CHROME.MUTED)
	column.add_child(caption)
	var value := Label.new()
	value.text="—"
	value.add_theme_font_override("font",CHROME.SHELL.face(600 if primary else 500))
	value.add_theme_font_size_override("font_size",30 if primary else 22)
	value.add_theme_color_override("font_color",CHROME.NAVY if primary else Color("005449"))
	if key=="crew":
		var row := HBoxContainer.new()
		column.add_child(row)
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(value)
		manage_button.text=UIText.t("galaxy.manage_crew")
		manage_button.add_theme_font_size_override("font_size",21)
		manage_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		CHROME.button_skin(manage_button,true)
		row.add_child(manage_button)
		manage_button.pressed.connect(show_crew_dialog)
	else:column.add_child(value)
	cards[key]=value

func sync_visibility() -> void:
	if game==null:return
	if is_instance_valid(host.battle_layer):
		if is_visible_in_tree() and not battle_dimmed:
			battle_modulate=host.battle_layer.modulate
			host.battle_layer.modulate=battle_modulate*Color(0.65,0.65,0.65,1)
			battle_dimmed=true
		elif not is_visible_in_tree() and battle_dimmed:
			host.battle_layer.modulate=battle_modulate
			battle_dimmed=false
	if is_visible_in_tree():refresh();game.galaxy.set_visible(selected)
	else:
		game.galaxy.set_visible("")
		crew_dialog.hide();help_dialog.hide()
	map.sync_visibility()
func set_text(control: Control, value: String) -> void:
	if control.text!=value:control.text=value
func refresh_sample(dt: float) -> void:
	if not is_visible_in_tree() or game==null:return
	map.set_running(not game.paused)
	if game.paused:return
	sample_elapsed+=dt
	if sample_elapsed<game.galaxy.setting(game,"visible_tick"):return
	sample_elapsed=0
	refresh()
func refresh() -> void:
	if not is_visible_in_tree() or game==null:return
	var keys: Array=game.galaxy.regions.keys().filter(func(key):return game.galaxy.regions[key].state.status!="locked")
	keys.sort_custom(func(a,b):return float(game.galaxy.regions[a].row.order)<float(game.galaxy.regions[b].row.order))
	if keys!=list_snapshot:
		list_snapshot=keys.duplicate()
		selector.clear()
		for key in keys:selector.add_item(str(game.galaxy.regions[key].row.name));selector.set_item_metadata(selector.item_count-1,key)
	if keys.is_empty():return
	if not keys.has(selected):selected=str(keys[0])
	if selector.selected!=keys.find(selected):selector.select(keys.find(selected))
	var region=game.galaxy.regions[selected]
	game.galaxy.set_visible(selected)
	map.select(region)
	map.set_running(not game.paused)
	map.crew_count=game.galaxy.crew_count(game,selected)
	map.refresh()
	set_text(state_label,UIText.t("galaxy.waiting_crew" if map.crew_count<=0 and region.state.status in ["exploring","developing"] else "galaxy.state_"+str(region.state.status)))
	set_text(cards.exploration,"%.1f%%"%(region.progress()*100))
	set_text(cards.buildings,"%d / %d"%[region.occupied_count,region.slots.size()])
	set_text(cards.max_level,str(region.max_level_count))
	set_text(cards.crew,UIText.t("galaxy.crew_count",{"count":map.crew_count}))
	host.set_ui_value(complete_crew_hint,"visible",region.state.status=="complete" and map.crew_count>0)
	set_text(cards.explorers,str(map.explorers.size()))
	game.galaxy.effects.refresh(game.galaxy)
	var effect: Dictionary=game.galaxy.effects.cache[selected]
	var rates: Dictionary=game.galaxy.effects.rates(game,game.galaxy,selected)
	for key in ["crew_exp","equipment_value","charge_max","gem_fragment"]:set_text(cards[key],"×%.2f"%float(effect[key]))
	for key in ["iron","uranium"]:set_text(cards[key],UIText.t("galaxy.rate",{"amount":NumberFormat.compact(rates[key])}))
	host.set_ui_value(start_button,"visible",region.state.status=="available")
	if crew_dialog.visible:refresh_crew_dialog()
	refresh_detail()

func refresh_detail() -> void:
	if selected.is_empty() or detail_slot<0:
		if detail_frame.visible:detail_frame.visible=false
		set_text(details,"");return
	if not detail_frame.visible:detail_frame.visible=true
	var region=game.galaxy.regions[selected]
	var slot: Dictionary=region.slots[detail_slot]
	if slot.status=="empty":
		set_text(details,PARAMETERS.escape(UIText.t("galaxy.plan_detail",{"name":region.builds[slot.type].name})))
		return
	var info: Dictionary=game.galaxy.effects.building_detail(region,slot)
	var phase := UIText.t("galaxy.slot_"+str(slot.status))
	var progress := 1.0
	if slot.status=="constructing":progress=region.node_progress(slot)
	elif slot.status=="upgrading":progress=float(slot.upgrade_progress)/region.upgrade_cost(slot)
	set_text(details,PARAMETERS.render("galaxy.detail",{"name":region.builds[slot.type].name,"level":slot.level,"effect":UIText.t("galaxy.effect_"+str(info.type)),"value":"+%.0f%%"%(float(info.amount)*100),"state":phase,"progress":"%.0f"%(progress*100)},{"value":{"role":"effect"},"progress":{"role":"time","unit":"%"}}))

func setup_crew_dialog() -> void:
	crew_dialog.transient=true;crew_dialog.exclusive=true
	crew_dialog.title=UIText.t("galaxy.manage_crew_title")
	crew_dialog.ok_button_text=UIText.t("galaxy.close")
	CHROME.dialog(crew_dialog)
	add_child(crew_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size=Vector2(460,330)
	content.add_theme_constant_override("separation",10)
	crew_dialog.add_child(content)
	crew_summary.add_theme_font_size_override("font_size",24)
	content.add_child(crew_summary)
	crew_scroll.custom_minimum_size.y=280
	crew_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	crew_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(crew_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",6)
	crew_scroll.add_child(rows)
	crew_empty.text=UIText.t("galaxy.crew_empty")
	rows.add_child(crew_empty)
	for member in game.profile.crew:
		var id := str(member.crewId)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		rows.add_child(row)
		crew_row_nodes[id]=row
		var name_label := Label.new()
		name_label.text=str(game.db.data.crew[id].name)
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var status := Label.new()
		status.custom_minimum_size.x=90
		row.add_child(status)
		crew_status[id]=status
		var button := Button.new()
		button.name="GalaxyCrew_"+id
		button.toggle_mode=true
		button.custom_minimum_size=Vector2(90,38)
		CHROME.button_skin(button)
		row.add_child(button)
		crew_rows[id]=button
		button.pressed.connect(func():
			var current: Dictionary=game.crew.entry(game,id)
			var assigned: bool=current.assignmentType=="galaxy_explore" and current.targetId==selected
			game.assign_crew(id,"" if assigned else "galaxy_explore","" if assigned else selected)
			refresh())
func show_crew_dialog() -> void:
	if selected.is_empty():return
	help_dialog.hide()
	refresh_crew_dialog()
	crew_dialog.popup_centered(Vector2i(520,410))
func refresh_crew_dialog() -> void:
	set_text(crew_summary,UIText.t("galaxy.crew_assigned",{"count":game.galaxy.crew_count(game,selected)}))
	var visible_rows := 0
	for id in crew_rows:
		var member: Dictionary=game.crew.entry(game,id)
		var assigned: bool=member.assignmentType=="galaxy_explore" and member.targetId==selected
		var unlocked: bool=game.crew.unlocked(game,id)
		var available: bool=game.idle_planet_crew(id) and game.crew.can_assign(game,id,"galaxy_explore",selected)
		var button: Button=crew_rows[id]
		host.set_ui_value(crew_row_nodes[id],"visible",unlocked)
		if not unlocked:continue
		visible_rows+=1
		set_text(button,UIText.t("galaxy.crew_recall_action" if assigned else "galaxy.crew_assign_action"))
		set_text(crew_status[id],UIText.t("galaxy.crew_selected" if assigned else "galaxy.crew_idle" if available else "galaxy.crew_busy"))
		host.set_ui_value(crew_status[id],"modulate",Color("005449") if assigned else CHROME.MUTED)
		if button.button_pressed!=assigned:button.set_pressed_no_signal(assigned)
		host.set_ui_value(button,"tooltip_text",UIText.t("galaxy.recall" if assigned else "galaxy.assign",{"name":game.db.data.crew[id].name}))
		host.set_ui_value(button,"disabled",not assigned and not available)
	host.set_ui_value(crew_empty,"visible",visible_rows==0)
func show_help() -> void:
	crew_dialog.hide()
	help_dialog.popup_centered()
