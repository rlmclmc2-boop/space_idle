extends Control
var host
var game
var selected := ""
var selector := OptionButton.new()
var state_label := Label.new()
var start_button := Button.new()
var map := preload("res://scripts/galaxy_map.gd").new()
var crew_rows := {}
var cards := {}
var details := Label.new()
var detail_slot := -1
var list_snapshot: Array=[]
var sample_elapsed := 0.0
var battle_modulate := Color.WHITE
var battle_dimmed := false

func setup(owner) -> void:
	host=owner
	game=owner.game
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation",8)
	add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(selector)
	heading.add_child(state_label)
	heading.add_child(start_button)
	start_button.text=UIText.t("galaxy.start")
	start_button.pressed.connect(func():game.galaxy.start(game,selected);refresh())
	selector.item_selected.connect(func(index):selected=str(selector.get_item_metadata(index));detail_slot=-1;game.galaxy.set_visible(selected);refresh())
	var grid := GridContainer.new()
	grid.columns=6
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	box.add_child(grid)
	for key in ["exploration","buildings","max_level","crew","explorers","traffic","crew_exp","equipment_value","charge_max","gem_fragment","iron","uranium"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color=Color("112535")
		style.border_color=Color("25475a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left=10
		style.content_margin_right=10
		style.content_margin_top=5
		style.content_margin_bottom=5
		panel.add_theme_stylebox_override("panel",style)
		grid.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",2)
		panel.add_child(column)
		var label := Label.new()
		label.text=UIText.t("galaxy.card_"+key)
		label.add_theme_color_override("font_color",Color("90aebf"))
		column.add_child(label)
		var value := Label.new()
		value.text="—"
		value.add_theme_color_override("font_color",Color("a5e7f2"))
		column.add_child(value)
		cards[key]=value
	var crew_box := HFlowContainer.new()
	box.add_child(crew_box)
	for member in game.profile.crew:
		var button := Button.new()
		button.name="GalaxyCrew_"+str(member.crewId)
		button.toggle_mode=true
		crew_box.add_child(button)
		crew_rows[member.crewId]=button
		button.pressed.connect(func():
			var current: Dictionary=game.crew.entry(game,member.crewId)
			var assigned: bool=current.assignmentType=="galaxy_explore" and current.targetId==selected
			game.assign_crew(member.crewId,"" if assigned else "galaxy_explore","" if assigned else selected)
			refresh())
	map.custom_minimum_size=Vector2(300,300)
	map.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(map)
	map.configure(game.db.data.galaxy_config)
	map.slot_selected.connect(func(id):detail_slot=id;refresh_detail())
	details.custom_minimum_size.y=44
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	details.text=UIText.t("galaxy.map_hint")
	box.add_child(details)
	visibility_changed.connect(sync_visibility)
	set_process(false)
	sync_visibility()
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
	set_text(state_label,UIText.t("galaxy.state_"+str(region.state.status)))
	set_text(cards.exploration,"%.1f%%"%(region.progress()*100))
	set_text(cards.buildings,"%d / %d"%[region.occupied_count,region.slots.size()])
	set_text(cards.max_level,str(region.max_level_count))
	set_text(cards.crew,str(map.crew_count))
	set_text(cards.explorers,str(map.crew_count*int(region.row.ship_per_crew) if region.state.status=="exploring" else 0))
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
		set_text(details,UIText.t("galaxy.map_hint"));return
	var region=game.galaxy.regions[selected]
	var slot: Dictionary=region.slots[detail_slot]
	if slot.status=="empty":return
	var info: Dictionary=game.galaxy.effects.building_detail(region,slot)
	var phase := UIText.t("galaxy.slot_"+str(slot.status))
	var progress := 1.0
	if slot.status=="constructing":progress=1.0-float(slot.construction)/maxf(0.001,float(region.row.construction_time))
	elif slot.status=="upgrading":progress=float(slot.upgrade_progress)/region.upgrade_cost(slot)
	set_text(details,UIText.t("galaxy.detail",{"name":region.builds[slot.type].name,"level":slot.level,"effect":UIText.t("galaxy.effect_"+str(info.type)),"value":"%.0f%%"%(float(info.amount)*100),"state":phase,"progress":"%.0f"%(progress*100)}))
