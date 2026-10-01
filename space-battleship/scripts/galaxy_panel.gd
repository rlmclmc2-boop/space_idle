extends Control
const CHROME := preload("res://scripts/dialog_presentation.gd")
const PARAMETERS := preload("res://scripts/parameter_text.gd")
var host
var game
var selected := ""
var selector := OptionButton.new()
var state_label := Label.new()
var start_button := Button.new()
var map := preload("res://scripts/galaxy_map.gd").new()
var crew_rows := {}
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
	var crew_box := HFlowContainer.new()
	crew_box.add_theme_constant_override("h_separation",6)
	crew_box.add_theme_constant_override("v_separation",4)
	box.add_child(crew_box)
	for member in game.profile.crew:
		var button := Button.new()
		button.name="GalaxyCrew_"+str(member.crewId)
		button.toggle_mode=true
		button.custom_minimum_size.y=38
		button.add_theme_font_size_override("font_size",20)
		CHROME.button_skin(button)
		crew_box.add_child(button)
		crew_rows[member.crewId]=button
		button.pressed.connect(func():
			var current: Dictionary=game.crew.entry(game,member.crewId)
			var assigned: bool=current.assignmentType=="galaxy_explore" and current.targetId==selected
			game.assign_crew(member.crewId,"" if assigned else "galaxy_explore","" if assigned else selected)
			refresh())
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
	for key in ["explorers","traffic"]:
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
	details.custom_minimum_size.y=54
	details.bbcode_enabled=true
	details.scroll_active=false
	details.fit_content=true
	details.add_theme_font_override("normal_font",CHROME.SHELL.face(500))
	details.add_theme_font_size_override("normal_font_size",20)
	details.add_theme_color_override("default_color",CHROME.NAVY)
	details.mouse_filter=Control.MOUSE_FILTER_IGNORE
	details.text=PARAMETERS.escape(UIText.t("galaxy.map_hint"))
	box.add_child(details)
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
	column.add_child(value)
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
	else:game.galaxy.set_visible("")
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
	set_text(cards.crew,str(map.crew_count))
	set_text(cards.explorers,str(map.explorers.size()))
	set_text(cards.traffic,str(map.transports.filter(func(item):return item.node.visible).size()))
	game.galaxy.effects.refresh(game.galaxy)
	var effect: Dictionary=game.galaxy.effects.cache[selected]
	var rates: Dictionary=game.galaxy.effects.rates(game,game.galaxy,selected)
	for key in ["crew_exp","equipment_value","charge_max","gem_fragment"]:set_text(cards[key],"×%.2f"%float(effect[key]))
	for key in ["iron","uranium"]:set_text(cards[key],UIText.t("galaxy.rate",{"amount":NumberFormat.compact(rates[key])}))
	host.set_ui_value(start_button,"visible",region.state.status=="available")
	for id in crew_rows:
		var member: Dictionary=game.crew.entry(game,id)
		var assigned: bool=member.assignmentType=="galaxy_explore" and member.targetId==selected
		var button: Button=crew_rows[id]
		host.set_ui_value(button,"visible",game.crew.unlocked(game,id))
		set_text(button,str(game.db.data.crew[id].name))
		if button.button_pressed!=assigned:button.set_pressed_no_signal(assigned)
		host.set_ui_value(button,"tooltip_text",UIText.t("galaxy.recall" if assigned else "galaxy.assign",{"name":game.db.data.crew[id].name}))
		host.set_ui_value(button,"disabled",not assigned and (not game.idle_planet_crew(id) or not game.crew.can_assign(game,id,"galaxy_explore",selected)))
	refresh_detail()
func refresh_detail() -> void:
	if selected.is_empty() or detail_slot<0:
		set_text(details,PARAMETERS.escape(UIText.t("galaxy.map_hint")));return
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
