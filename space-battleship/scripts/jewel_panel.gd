extends Panel

# Owns only presentation selection and its controls; inventory is always game.profile.
var host: Node
var game: BattleGame
var selected: Array = []
var category := ""
var equipment_index := -1
var equipment_identity: Dictionary = {}
var cells: Array[Button] = []
var socket_buttons: Array[Button] = []
var inventory_list: GridContainer
var gem_buttons: Dictionary = {}
var textures: Dictionary = {}
var socket_row: HBoxContainer
var summary: Label
var detail: Label
var fragments: Label
var equipment_title: Label
var combine_all: Button
var bulk_summary := ""
var bulk_rewards := ""
var socket_action: Button
var detail_icon: TextureRect
var detail_heading: Label
var preview: Label
var feedback: Label
var empty_hint: Label
var detail_scroll: ScrollContainer
var metrics_timer: Timer
var target_socket := -1
var result_token := -1
# Presentation-only acknowledgement and animation state, never saved or used as inventory.
var new_tokens: Dictionary = {}
var observed_serial := 0
var generated_count := 0
var acting := false
var palettes: Dictionary = {}
var effect_layer: Control
var flights: Array[TextureRect] = []
var flight_cursor := 0
var animations: Dictionary = {}
var metric_state: Array = []
var module_buttons: Dictionary = {}
var module_list: VBoxContainer
var module_scroll: ScrollContainer
var inventory_scroll: ScrollContainer
var remove_action: Button
var upgrade_action: Button
var action_reason: Label
var hero_caption: Label
var workshop_art: TextureRect
var module_heading: Label


func _init() -> void:
	hide()
	set_process(false)

func setup(owner_node: Node) -> void:
	host=owner_node
	game=host.game
	observed_serial=game.jewel_serial
	create_palettes()
	position=Vector2(50,127)
	size=Vector2(1340,1180)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	workshop_art=TextureRect.new()
	workshop_art.texture=preload("res://assets/jewels/premium/workshop-frame.svg")
	workshop_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	workshop_art.stretch_mode=TextureRect.STRETCH_SCALE
	workshop_art.size=size
	workshop_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(workshop_art)
	for region in [Rect2(18,102,224,1008),Rect2(254,102,612,1008),Rect2(890,102,426,1008)]:
		var frame:=Panel.new()
		frame.position=region.position
		frame.size=region.size
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",surface(Color("0b1a29cc"),Color("315166")))
		add_child(frame)
	add_theme_font_override("font",host.font)
	label(UIText.t("gem.center.title"),Rect2(28,21,280,32),26)
	combine_all=add_button(UIText.t("gem.setup.text_07"),Rect2(1016,26,198,38),combine_all_selected)
	combine_all.tooltip_text=UIText.t("gem.setup.text_08")
	module_heading=label(UIText.t("gem.center.modules"),Rect2(36,116,190,26),17)
	module_scroll=ScrollContainer.new()
	module_scroll.position=Vector2(30,152)
	module_scroll.size=Vector2(202,946)
	module_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(module_scroll)
	module_list=VBoxContainer.new()
	module_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	module_list.add_theme_constant_override("separation",9)
	module_scroll.add_child(module_list)
	equipment_title=label("",Rect2(268,114,580,28),17)
	socket_row=HBoxContainer.new()
	socket_row.position=Vector2(266,150)
	socket_row.size=Vector2(586,74)
	socket_row.add_theme_constant_override("separation",8)
	add_child(socket_row)
	summary=label("",Rect2(268,246,580,32),14)
	inventory_scroll=ScrollContainer.new()
	inventory_scroll.position=Vector2(266,286)
	inventory_scroll.size=Vector2(588,812)
	inventory_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(inventory_scroll)
	inventory_list=GridContainer.new()
	inventory_list.columns=5
	inventory_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("h_separation",8)
	inventory_list.add_theme_constant_override("v_separation",8)
	inventory_scroll.add_child(inventory_list)
	empty_hint=label("",Rect2(282,422,536,100),18)
	empty_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	empty_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_icon=TextureRect.new()
	detail_icon.position=Vector2(1034,112)
	detail_icon.size=Vector2(136,136)
	detail_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(detail_icon)
	detail_heading=label("",Rect2(906,249,390,32),20)
	detail_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hero_caption=label("",Rect2(910,282,386,20),12)
	hero_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hero_caption.add_theme_color_override("font_color",Color("8ca8be"))
	detail_scroll=ScrollContainer.new()
	detail_scroll.position=Vector2(908,309)
	detail_scroll.size=Vector2(394,635)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	detail_scroll.add_child(content)
	detail=label("",Rect2(0,0,370,0),14)
	preview=label("",Rect2(0,0,370,0),14)
	for control in [detail,preview]:
		control.reparent(content,false)
		control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		control.clip_text=false
		control.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
		control.custom_minimum_size.x=370
	preview.add_theme_color_override("font_color",Color("95ddc7"))
	action_reason=label("",Rect2(908,951,394,27),13)
	socket_action=add_button(UIText.t("gem.setup.text_13"),Rect2(908,986,190,40),func():operate_socket(target_socket))
	remove_action=add_button(UIText.t("gem.refresh_detail.text_27"),Rect2(1108,986,194,40),remove_selected)
	upgrade_action=add_button(UIText.t("gem.center.upgrade_installed"),Rect2(908,1034,394,34),upgrade_installed)
	fragments=label("",Rect2(36,1119,826,48),13)
	fragments.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fragments.add_theme_font_size_override("font_size",12)
	feedback=label(UIText.t("gem.center.welcome"),Rect2(900,1119,406,48),13)
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size",12)
	feedback.add_theme_color_override("font_color",host.CYAN)
	metrics_timer=Timer.new()
	metrics_timer.wait_time=1.0
	metrics_timer.timeout.connect(refresh_metrics)
	add_child(metrics_timer)
	skin_controls()
	create_effect_pool()
	visibility_changed.connect(on_visibility_changed)
	hide()
	set_process(false)

func label(value: String, rect: Rect2, font_size: int) -> Label:
	return host.equipment_card_label(self, value, rect, font_size, host.INK)

func add_button(value: String, rect: Rect2, action: Callable) -> Button:
	var control: Button = host.button(value, rect, action)
	control.reparent(self, false)
	apply_palette(control,"normal")
	return control

func open(for_category := "", index := -1) -> void:
	if not game.jewels_unlocked():return
	show()
	host.ui.move_child(self,-1)
	if index>=0:
		choose_module(for_category,index)
	else:
		refresh()
	animate(self,"modulate",Color(1,1,1,0.35),Color.WHITE,0.16)

func choose_module(value: String, index: int) -> void:
	category=value
	equipment_index=index
	equipment_identity=game.module_entry(category,index)
	target_socket=0 if game.equipment_socket_count(equipment_identity)>0 or not equipment_identity.get("sockets",[]).is_empty() else -1
	selected.clear()
	result_token=-1
	bulk_summary=""
	metric_state.clear()
	refresh()

func select_socket(index: int) -> void:
	target_socket=index
	selected.clear()
	result_token=-1
	bulk_summary=""
	refresh_sockets()
	refresh_inventory()
	refresh_detail()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if host.equipment_tabs.current_tab==4:
		host.return_to_first_system()
	else:
		hide()

func select_cell(index: int) -> void:
	if index<0 or index>=game.profile.jewels.size():return
	var token:=int(game.profile.jewels[index].token)
	bulk_summary=""
	result_token=-1
	new_tokens.erase(token)
	selected=[] if selected.has(token) else [token]
	refresh_inventory()
	refresh_detail()
	pulse(gem_buttons.get(token),host.CYAN)

func quick_socket(token: int) -> void:
	var gem:=game.jewel_inventory(token)
	if gem.is_empty():return
	var entry:=game.module_entry(category,equipment_index)
	if not is_same(entry,equipment_identity):refresh();return
	var destination:=target_socket
	if destination<0 or destination>=game.equipment_socket_count(entry) or not socket_gem(destination).is_empty():
		destination=-1
		for index in game.equipment_socket_count(entry):
			if socket_gem(index).is_empty():
				destination=index
				break
	if destination<0:
		show_feedback(UIText.t("gem.center.choose_empty_socket"),false)
		return
	var error:=game.jewel_socket_error_key(category,equipment_index,token,destination)
	if not error.is_empty():
		show_feedback(UIText.t(error),false)
		return
	bulk_summary=""
	result_token=-1
	new_tokens.erase(token)
	target_socket=destination
	selected=[token]
	operate_socket(destination)

func gem_name(gem: Dictionary) -> String:
	return UIText.t("gem.name_level", {"item_name":"%s" % (UIText.data_text("jewel",str(gem.id))), "level":"%d" % (int(gem.level))})

func gem_description(gem: Dictionary) -> String:
	var id := str(gem.id)
	var text_key := UIText.data_key("jewel",id,"des")
	var formulas := UIText.formulas(text_key)
	var values := {}
	for i in formulas.size():
		values["effect_%d" % (i+1)] = gem_formula(gem,str(formulas[i]))
	return UIText.t(text_key,values)

func gem_formula(gem: Dictionary, description: String) -> String:
	var id := str(gem.id)
	var regex := RegEx.new()
	regex.compile("\\{([^{}]+)\\}")
	for match_value in regex.search_all(description):
		var block := match_value.get_string(1).split(",")
		var expression := block[0].replace("等级", str(int(gem.level)))
		for n in [2,4,5,6]:
			expression = expression.replace("para%d" % n, str(game.db.jewel_parameter(id,n)))
		var counter := "武器攻击次数" if expression.contains("武器攻击次数") else "承受攻击次数"
		if expression.contains(counter):
			var entry := game.module_entry(category,equipment_index) if equipment_index >= 0 else {}
			var count := maxi(1,int(entry.get("attacks" if counter == "武器攻击次数" else "hits",0)))
			expression = expression.replace("log10(%s)" % counter, str(log(float(count))/log(10.0)))
		var arithmetic := Expression.new()
		var allowed := RegEx.new()
		allowed.compile("^[0-9.eE+*/() -]+$")
		var value := "？"
		if allowed.search(expression) != null and arithmetic.parse(expression) == OK:
			var result = arithmetic.execute([],null,false)
			if not arithmetic.has_execute_failed() and (result is int or result is float):
				value = ("%s%%" % host.number(roundf(float(result)*100))) if block.size()>1 else host.number(float(result))
		description = description.replace(match_value.get_string(),value)
	return description

func refresh() -> void:
	if not visible:return
	if not game.jewels_unlocked():
		hide()
		return
	selected=selected.filter(func(token):return not game.jewel_inventory(int(token)).is_empty())
	refresh_modules()
	refresh_sockets()
	refresh_inventory()
	refresh_detail()
	refresh_metrics()

func refresh_modules() -> void:
	if game.module_entry(category,equipment_index).is_empty():
		category="weapons"
		equipment_index=0 if not game.module_entries(category).is_empty() else -1
	var live: Dictionary={}
	var module_position:=0
	for kind in ["weapons","defence"]:
		for index in game.module_entries(kind).size():
			var key:=game.slot_id(kind,index)
			live[key]=true
			var entry:=game.module_entry(kind,index)
			if not module_buttons.has(key):
				var button:=add_button("",Rect2(0,0,190,74),func():choose_module(kind,index))
				button.custom_minimum_size=Vector2(190,74)
				button.add_theme_font_size_override("font_size",14)
				button.reparent(module_list,false)
				module_buttons[key]=button
			var button: Button=module_buttons[key]
			if button.get_index()!=module_position:module_list.move_child(button,module_position)
			module_position+=1
			var active: bool=index<game.active_slot_count(kind)
			var occupied: int=entry.get("sockets",[]).filter(func(gem):return not gem.is_empty()).size()
			host.set_ui_value(button,"text",UIText.t("gem.center.module",{"kind":UIText.t("weapon.tab" if kind=="weapons" else "defense.tab"),"index":str(index+1),"name":host.NAMES.get(str(entry.key),UIText.t("equipment.vacant")),"level":str(entry.level),"used":str(occupied),"count":str(game.equipment_socket_count(entry)),"state":UIText.t("gem.center.active" if active else "gem.center.inactive")}))
			apply_palette(button,"selected" if kind==category and index==equipment_index else "normal" if active else "blocked")
	for key in module_buttons.keys():
		if not live.has(key):
			module_buttons[key].queue_free()
			module_buttons.erase(key)
	var current:=game.module_entry(category,equipment_index)
	if not is_same(current,equipment_identity):
		equipment_identity=current
		selected.clear()
		target_socket=0 if game.equipment_socket_count(current)>0 or not current.get("sockets",[]).is_empty() else -1

func candidate_error(gem: Dictionary) -> String:
	if target_socket<0:return "gem.center.choose_socket"
	if target_socket>=game.equipment_socket_count(game.module_entry(category,equipment_index)):return "gem.socket_error.text_02"
	return game.jewel_socket_error_key(category,equipment_index,int(gem.token),target_socket)

func refresh_inventory() -> void:
	if not visible:return
	var counts:=inventory_counts(true)
	apply_palette(combine_all,"ready" if counts.values().any(func(count):return game.jewel_combine_count()>=2 and count>=game.jewel_combine_count()) else "normal")
	var live: Dictionary={}
	var ordered: Array=game.profile.jewels.duplicate()
	ordered.sort_custom(func(a,b):
		if int(a.level)!=int(b.level):return int(a.level)>int(b.level)
		if str(a.id)!=str(b.id):return int(a.id)<int(b.id)
		return int(a.token)<int(b.token))
	cells.clear()
	for gem in ordered:
		var token:=int(gem.token)
		live[token]=true
		if not gem_buttons.has(token):
			var button:=add_button("",Rect2(0,0,108,151),func():
				var current:=game.jewel_inventory(token)
				if not current.is_empty():select_cell(game.profile.jewels.find(current)))
			button.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
					quick_socket(token))
			button.custom_minimum_size=Vector2(108,151)
			button.clip_text=true
			button.add_theme_font_size_override("font_size",12)
			button.add_theme_constant_override("icon_max_width",80)
			button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
			button.alignment=HORIZONTAL_ALIGNMENT_CENTER
			button.expand_icon=true
			button.reparent(inventory_list,false)
			gem_buttons[token]=button
		var cell: Button=gem_buttons[token]
		var error:=candidate_error(gem)
		var shown:=game.jewel_allowed(str(gem.id),category)
		host.set_ui_value(cell,"visible",shown)
		if shown:
			if cell.get_index()!=cells.size():inventory_list.move_child(cell,cells.size())
			cells.append(cell)
		var maxed:=int(gem.level)>=game.db.jewel_max_level(str(gem.id))
		var ready:=game.jewel_combine_eligible(gem) and game.jewel_combine_count()>=2 and int(counts.get(gem_key(gem),0))>=game.jewel_combine_count()
		var reason_key: String={"gem.jewel_socket_error.text_02":"gem.center.wrong_category","gem.jewel_socket_error.text_03":"gem.center.duplicate"}.get(error,"gem.center.unavailable")
		var protected: bool=gem.get("locked",false) or gem.get("disabled",false)
		var badge:=UIText.t(reason_key) if not error.is_empty() else UIText.t("gem.center.protected") if protected else UIText.t("gem.max_badge") if maxed else UIText.t("gem.merge_badge") if ready else UIText.t("gem.center.available")
		apply_palette(cell,"selected" if selected.has(token) else "blocked" if not error.is_empty() else "max" if maxed else "ready" if ready else "new" if new_tokens.has(token) else "normal")
		host.set_ui_value(cell,"text",UIText.t("gem.grid_name_level",{"item_name":UIText.data_text("jewel",str(gem.id)),"level":str(gem.level)})+"\n"+badge)
		host.set_ui_value(cell,"icon",gem_texture(str(gem.id)))
		host.set_ui_value(cell,"tooltip_text",gem_name(gem)+"\n"+gem_description(gem)+"\n"+badge)
	for token in gem_buttons.keys():
		if not live.has(token):
			var removed: Button=gem_buttons[token]
			inventory_list.remove_child(removed)
			removed.queue_free()
			gem_buttons.erase(token)
	host.set_ui_value(empty_hint,"visible",cells.is_empty())
	host.set_ui_value(empty_hint,"text",UIText.t("gem.center.empty" if game.profile.jewels.is_empty() else "gem.center.no_category"))
	host.set_ui_value(summary,"text",UIText.t("gem.center.results",{"count":str(cells.size())})+UIText.t("gem.center.socket_hint"))

func refresh_sockets() -> void:
	var entry:=game.module_entry(category,equipment_index)
	var count:=game.equipment_socket_count(entry)
	var levels: Array=[]
	var socket_config=game.db.config.get("equipmentSocket",0)
	if socket_config is String:
		for part in socket_config.split(","):
			var pair=part.split("|")
			if pair.size()==2 and pair[0].is_valid_int() and pair[1].is_valid_int():
				while levels.size()<int(pair[1]):levels.append(int(pair[0]))
	var total:=maxi(maxi(count,entry.get("sockets",[]).size()),levels.size())
	if target_socket>=total:target_socket=-1
	while socket_buttons.size()>total:
		var removed: Button=socket_buttons.pop_back()
		socket_row.remove_child(removed)
		removed.queue_free()
	while socket_buttons.size()<total:
		var index:=socket_buttons.size()
		var button:=add_button("",Rect2(0,0,190,66),func():select_socket(index))
		button.custom_minimum_size=Vector2(190,66)
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_constant_override("icon_max_width",42)
		button.expand_icon=true
		button.reparent(socket_row,false)
		socket_buttons.append(button)
	for i in total:
		var gem:=socket_gem(i)
		var unlocked: bool=i<count
		var text:=UIText.t("gem.center.empty_socket",{"index":str(i+1)}) if gem.is_empty() else UIText.t("gem.center.socket_level",{"level":str(gem.level)})
		if not unlocked and gem.is_empty():text=UIText.t("gem.center.locked_socket",{"level":str(levels[i]) if i<levels.size() else "—"})
		host.set_ui_value(socket_buttons[i],"text",text)
		host.set_ui_value(socket_buttons[i],"icon",null if gem.is_empty() else gem_texture(str(gem.id)))
		host.set_ui_value(socket_buttons[i],"disabled",not unlocked and gem.is_empty())
		host.set_ui_value(socket_buttons[i],"tooltip_text",text if gem.is_empty() else gem_name(gem)+"\n"+gem_description(gem))
		apply_palette(socket_buttons[i],"selected" if target_socket==i else "installed" if not gem.is_empty() else "empty")
	var title:=UIText.t("gem.center.target",{"kind":UIText.t("weapon.tab" if category=="weapons" else "defense.tab"),"index":str(equipment_index+1),"name":host.NAMES.get(str(entry.get("key","")),UIText.t("equipment.vacant")),"level":str(entry.get("level",1))})
	host.set_ui_value(equipment_title,"text",title)

func operate_socket(index: int) -> void:
	if selected.size()!=1:return
	var entry:=game.module_entry(category,equipment_index)
	if not is_same(entry,equipment_identity):refresh();return
	var error:=socket_error_key(index)
	if not error.is_empty():show_feedback(UIText.t(error),false);return
	var token:=int(selected[0])
	var incoming:=game.jewel_inventory(token).duplicate()
	var before:=entry.duplicate(true)
	var origin:=bag_center(token)
	acting=true
	var ok:=game.socket_jewel(category,equipment_index,index,token)
	acting=false
	if not ok:show_feedback(UIText.t("gem.operate_socket.text_03"),false);return
	selected.clear()
	refresh_detail()
	fly(gem_texture(str(incoming.id)),origin,control_center(socket_buttons[index]))
	show_feedback(UIText.t("gem.center.socket_done")+"\n"+stat_comparison(before,entry))

func remove_selected() -> void:
	var gem:=socket_gem(target_socket)
	if gem.is_empty() or not is_same(game.module_entry(category,equipment_index),equipment_identity):return
	var token:=int(gem.token)
	acting=true
	var ok:=game.unsocket_jewel(category,equipment_index,target_socket,token)
	acting=false
	if not ok:show_feedback(UIText.t("gem.socket_error.text_04"),false);return
	selected.clear()
	result_token=-1
	refresh_detail()
	show_feedback(UIText.t("gem.center.removed"))

func upgrade_installed() -> void:
	var gem:=socket_gem(target_socket)
	if gem.is_empty() or not is_same(game.module_entry(category,equipment_index),equipment_identity):return
	acting=true
	var ok:=game.upgrade_socket_jewel(category,equipment_index,target_socket,int(gem.token))
	acting=false
	if not ok:show_feedback(UIText.t("gem.center.upgrade_unavailable"),false);return
	selected.clear()
	refresh_detail()
	show_feedback(UIText.t("gem.center.upgraded"))

func gem_key(gem: Dictionary) -> String:
	return "%s:%d" % [gem.id,int(gem.level)]

func inventory_counts(eligible_only := false) -> Dictionary:
	var counts := {}
	for gem in game.profile.jewels:
		if eligible_only and not game.jewel_combine_eligible(gem):continue
		var key := gem_key(gem)
		counts[key]=int(counts.get(key,0))+1
	return counts

func socket_gem(index: int) -> Dictionary:
	var sockets: Array=game.module_entry(category,equipment_index).get("sockets",[])
	return sockets[index] if index >= 0 and index < sockets.size() else {}

func socket_error_key(index: int) -> String:
	if index<0 or game.module_entry(category,equipment_index).is_empty():return "gem.socket_error.text_01"
	if index>=game.equipment_socket_count(game.module_entry(category,equipment_index)):return "gem.socket_error.text_02"
	if selected.is_empty():return "gem.center.choose_gem"
	return game.jewel_socket_error_key(category,equipment_index,int(selected[0]),index)

func refresh_detail(_counts: Dictionary = {}) -> void:
	if not visible:return
	var candidate:=game.jewel_inventory(int(selected[0])) if not selected.is_empty() else {}
	var installed:=socket_gem(target_socket)
	var first: Dictionary=game.jewel_inventory(result_token) if not bulk_summary.is_empty() else candidate if not candidate.is_empty() else installed
	var heading:=UIText.t("gem.center.choose_gem")
	var description:=UIText.t("gem.center.socket_help")
	var comparison:=""
	var reason:=""
	var maxed:=not first.is_empty() and int(first.level)>=game.db.jewel_max_level(str(first.id))
	var required:=game.jewel_combine_count()
	var decreases:=false
	if not first.is_empty():
		heading=gem_name(first)
		description=gem_description(first)
	if not candidate.is_empty():
		reason=socket_error_key(target_socket)
		comparison=UIText.t("gem.center.preview",{"index":str(target_socket+1)})+"\n"
		comparison+=UIText.t(reason) if not reason.is_empty() else preview_socket(candidate,target_socket)
		comparison+="\n\n"+UIText.t("gem.center.old")+"\n"+(UIText.t("gem.center.none") if installed.is_empty() else gem_name(installed)+"\n"+gem_description(installed))
		comparison+="\n\n"+UIText.t("gem.center.new")+"\n"+gem_name(candidate)+"\n"+gem_description(candidate)
		if reason.is_empty():
			var before:=game.module_entry(category,equipment_index)
			var after:=before.duplicate(true)
			var slots: Array=after.get("sockets",[])
			while slots.size()<=target_socket:slots.append({})
			slots[target_socket]=candidate.duplicate()
			after.sockets=slots
			decreases=GrowthNumber.compare(game.jewel_equipment_stat(after),game.jewel_equipment_stat(before))<0 or (category=="weapons" and game.jewel_critical(after).x<game.jewel_critical(before).x)
			if decreases:reason="gem.center.decrease"
	elif not installed.is_empty():
		description=UIText.t("gem.center.installed")+"\n\n"+description
		var materials:=game.socket_upgrade_materials(category,equipment_index,target_socket)
		comparison=UIText.t("gem.center.installed_materials",{"have":str(materials.size()),"required":str(maxi(0,required-1))})
		if not maxed:
			var next:=installed.duplicate()
			next.level=int(next.level)+1
			comparison+="\n\n"+UIText.t("gem.center.upgrade_preview")+"\n"+gem_description(next)
		if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY:reason="gem.center.full_hint"
	else:reason="gem.center.choose_gem" if target_socket>=0 else "gem.center.choose_socket"
	if equipment_index>=game.active_slot_count(category) or str(equipment_identity.get("key","")).is_empty():description+="\n\n"+UIText.t("gem.center.inactive_hint")
	if not bulk_summary.is_empty():
		heading=UIText.t("gem.refresh_detail.text_20")
		description=bulk_summary
		comparison=bulk_rewards
		reason=""
	host.set_ui_value(detail_heading,"text",heading)
	var kind:=int(game.db.jewel_parameter(str(first.id),1)) if not first.is_empty() else 0
	host.set_ui_value(hero_caption,"text",UIText.t("gem.visual.weapon" if kind==1 else "gem.visual.defence" if kind==2 else "gem.visual.universal") if not first.is_empty() else UIText.t("gem.visual.empty_display"))
	host.set_ui_value(detail_icon,"texture",null if first.is_empty() else gem_texture(str(first.id)))
	host.set_ui_value(detail,"text",description)
	host.set_ui_value(preview,"text",comparison)
	var preview_color: Color=host.ORANGE if decreases else Color("95ddc7")
	if preview.get_theme_color("font_color")!=preview_color:preview.add_theme_color_override("font_color",preview_color)
	host.set_ui_value(action_reason,"text",UIText.t(reason) if not reason.is_empty() else "")
	host.set_ui_value(action_reason,"tooltip_text",action_reason.text)
	host.set_ui_value(socket_action,"visible",bulk_summary.is_empty())
	host.set_ui_value(remove_action,"visible",bulk_summary.is_empty())
	host.set_ui_value(socket_action,"disabled",candidate.is_empty() or not socket_error_key(target_socket).is_empty())
	host.set_ui_value(socket_action,"text",UIText.t("gem.setup.text_13" if installed.is_empty() else "gem.refresh_detail.text_28"))
	host.set_ui_value(socket_action,"tooltip_text",UIText.t(reason) if not reason.is_empty() else UIText.t("gem.center.explicit"))
	host.set_ui_value(remove_action,"disabled",installed.is_empty() or game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY)
	host.set_ui_value(remove_action,"tooltip_text",UIText.t("gem.socket_error.text_04") if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY else UIText.t("gem.center.remove_hint"))
	host.set_ui_value(upgrade_action,"visible",not installed.is_empty() and bulk_summary.is_empty())
	host.set_ui_value(upgrade_action,"disabled",not candidate.is_empty() or not game.can_upgrade_socket_jewel(category,equipment_index,target_socket))
	host.set_ui_value(upgrade_action,"tooltip_text",UIText.t("gem.center.clear_candidate") if not candidate.is_empty() else UIText.t("gem.center.upgrade_unavailable") if upgrade_action.disabled else UIText.t("gem.center.upgrade_help"))
	for button in [socket_action,upgrade_action]:apply_palette(button,"normal" if button.disabled else "ready")

func preview_socket(gem: Dictionary, index: int) -> String:
	var entry := game.module_entry(category,equipment_index)
	if entry.is_empty() or index < 0:return ""
	var copy := entry.duplicate(true)
	var sockets: Array=copy.get("sockets",[])
	while sockets.size()<=index:sockets.append({})
	sockets[index]=gem.duplicate()
	copy.sockets=sockets
	return stat_comparison(entry,copy)

func stat_comparison(before: Dictionary, after: Dictionary) -> String:
	var old = game.jewel_equipment_stat(before)
	var value = game.jewel_equipment_stat(after)
	var lines: PackedStringArray=[]
	if GrowthNumber.compare(old,value)!=0:
		lines.append(UIText.t("gem.stat_comparison.text_01", {"else":"%s" % (UIText.t("gem.stat_comparison.text_02") if category=="defence" else UIText.t("gem.stat_comparison.text_03")), "old":"%s" % (host.number(old)), "value":"%s" % (host.number(value)), "old_4":NumberFormat.signed_difference(value,old)}))
	if category=="weapons":
		var old_crit := game.jewel_critical(before)
		var new_crit := game.jewel_critical(after)
		if not is_equal_approx(old_crit.x,new_crit.x):
			lines.append(UIText.t("gem.stat_comparison.text_04", {"x":"%.2f" % (old_crit.x*100), "x_2":"%.2f" % (new_crit.x*100), "x_3":"%+.2f" % ((new_crit.x-old_crit.x)*100)}))
	return "\n".join(lines) if not lines.is_empty() else UIText.t("gem.stat_comparison.text_05")

func refresh_metrics() -> void:
	if not visible:return
	var entry := game.module_entry(category,equipment_index)
	if equipment_index >= 0 and not is_same(entry,equipment_identity):
		refresh()
		return
	var state: Array=[game.profile.jewelFragments,game.resource_minute_total("jewel"),game.jewel_create_cost(),game.jewel_ratio(),game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY,entry.get("attacks",0),entry.get("hits",0),entry.get("level",0)]
	if metric_state==state:return
	var changed: bool = not metric_state.is_empty() and metric_state[0]!=state[0]
	metric_state=state
	var text := UIText.t("gem.refresh_metrics.text_01", {"else":"%s" % (UIText.t("gem.refresh_metrics.text_02") if state[4] else ""), "state":"%.2f" % (state[0]), "state_3":"%.2f" % (state[1])})
	text+=UIText.t("gem.refresh_metrics.text_03", {"state":"%.0f" % (state[2]), "state_2":"%.2f" % (state[3]), "else":"%s" % (UIText.t("gem.refresh_metrics.text_04") if state[4] else UIText.t("gem.refresh_metrics.text_05"))})
	host.set_ui_value(fragments,"text",text)
	if changed:pulse(fragments,host.ORANGE if state[4] else host.CYAN)
	refresh_detail()

func gem_texture(id: String) -> Texture2D:
	if not textures.has(id):
		var authored:=str(game.db.jewel(id).get("image",""))
		if not authored.is_empty() and authored!="res://assets/jewels/%s.svg" % id and ResourceLoader.exists(authored):
			textures[id]=load(authored)
		elif id.is_valid_int() and int(id)>=1 and int(id)<=6:
			var atlas: Texture2D=preload("res://assets/jewels/premium/crystal-atlas.png")
			var item:=AtlasTexture.new()
			item.atlas=atlas
			var cell:=Vector2(atlas.get_width()/5.0,atlas.get_height()/2.0)
			# New IDs 3–6 retain the visual identity of their original effects.
			var index: int=[0,1,4,5,6,9][int(id)-1]
			item.region=Rect2(Vector2(index%5,floori(index/5.0))*cell,cell)
			item.filter_clip=true
			textures[id]=item
		else:
			var path:="res://assets/jewels/%s.svg" % id
			textures[id]=load(path) if ResourceLoader.exists(path) else null
	return textures[id]

func surface(fill: Color, edge: Color, radius := 8) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=fill
	box.border_color=edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left=10
	box.content_margin_right=10
	box.content_margin_top=8
	box.content_margin_bottom=8
	return box

func create_palettes() -> void:
	var colors:={"normal":Color("30465d"),"selected":Color("84d6d1"),"ready":Color("579eaa"),"installed":Color("476a87"),"max":Color("b89b67"),"new":Color("776a9f"),"blocked":Color("24364a"),"empty":Color("294355"),"danger":Color("ae7c75")}
	for key in colors:
		var accent: Color=colors[key]
		var fill:=Color("14253a").lerp(accent,0.13 if key in ["selected","ready"] else 0.03)
		var normal:=surface(fill,accent)
		if key=="selected":
			normal.border_width_top=2
			normal.shadow_color=Color(accent,0.12)
			normal.shadow_size=8
		var focus:=surface(Color(0,0,0,0),Color("a4e4e5"))
		palettes[key]={"normal":normal,"hover":surface(fill.lightened(0.09),accent.lightened(0.2)),"pressed":surface(fill.lightened(0.14),Color("d0f0ee")),"disabled":surface(Color("101e2f"),Color("273a4d")),"focus":focus}

func apply_palette(control: Button, key: String) -> void:
	if control.get_meta("jewel_palette","")==key:return
	control.set_meta("jewel_palette",key)
	for state in palettes[key]:control.add_theme_stylebox_override(state,palettes[key][state])
	control.add_theme_color_override("font_color",Color("73899e") if key in ["blocked","empty"] else Color("deebf5"))
	control.add_theme_color_override("font_hover_color",Color("efffff"))
	control.add_theme_color_override("font_pressed_color",Color.WHITE)
	control.add_theme_color_override("font_disabled_color",Color("526b83"))
	control.add_theme_color_override("icon_normal_color",Color(0.65,0.72,0.82,0.55) if key=="blocked" else Color.WHITE)
	control.add_theme_color_override("icon_hover_color",Color(0.8,0.85,0.9,0.7) if key=="blocked" else Color.WHITE)

func skin_controls() -> void:
	for scroll in [module_scroll,inventory_scroll,detail_scroll]:
		var bar: VScrollBar=scroll.get_v_scroll_bar()
		for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
			var color:=Color("0b1726") if state=="scroll" else Color("334d64") if state=="grabber" else Color("5c8799")
			var skin:=surface(color,color,3)
			skin.content_margin_left=3
			skin.content_margin_right=3
			skin.content_margin_top=0
			skin.content_margin_bottom=0
			bar.add_theme_stylebox_override(state,skin)

func create_effect_pool() -> void:
	effect_layer=Control.new()
	effect_layer.name="JewelFeedback"
	effect_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	effect_layer.z_index=100
	host.ui.add_child(effect_layer)
	for i in 8:
		var icon:=TextureRect.new()
		icon.size=Vector2(32,32)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.hide()
		effect_layer.add_child(icon)
		flights.append(icon)

func control_center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func bag_center(token: int) -> Vector2:
	var control: Control=gem_buttons.get(token)
	var scroll: Control=inventory_list.get_parent()
	if is_instance_valid(control) and scroll.get_global_rect().encloses(control.get_global_rect()):return control_center(control)
	return control_center(summary)

func fly(texture: Texture2D, origin: Vector2, destination: Vector2) -> void:
	var icon := flights[flight_cursor%flights.size()]
	flight_cursor+=1
	var old: Tween=icon.get_meta("flight") if icon.has_meta("flight") else null
	if old!=null:old.kill()
	icon.texture=texture
	icon.global_position=origin-Vector2(16,16)
	icon.modulate=Color.WHITE
	icon.show()
	var tween:=icon.create_tween()
	icon.set_meta("flight",tween)
	tween.tween_property(icon,"global_position",destination-Vector2(16,16),0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon,"modulate:a",0.0,0.1).set_delay(0.18)
	tween.tween_callback(icon.hide)

func animate(control: Control, property: String, from: Variant, to: Variant, duration: float) -> void:
	if not is_instance_valid(control):return
	var key := "%s:%s" % [control.get_instance_id(),property]
	if animations.has(key):animations[key].tween.kill()
	control.set(property,from)
	var tween := control.create_tween()
	animations[key]={"control":control,"property":property,"rest":to,"tween":tween}
	tween.tween_property(control,property,to,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():animations.erase(key))

func pulse(control: Control, color: Color) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():return
	animate(control,"self_modulate",Color(1+color.r*0.4,1+color.g*0.4,1+color.b*0.4),Color.WHITE,0.3)

func on_visibility_changed() -> void:
	if not is_instance_valid(metrics_timer):return
	if visible:
		metrics_timer.start()
		return
	metrics_timer.stop()
	for item in animations.values():
		item.tween.kill()
		if is_instance_valid(item.control):item.control.set(item.property,item.rest)
	animations.clear()
	for icon in flights:
		var tween: Tween=icon.get_meta("flight") if icon.has_meta("flight") else null
		if tween!=null:tween.kill()
		icon.hide()

func _exit_tree() -> void:
	if is_instance_valid(effect_layer):effect_layer.queue_free()

func inventory_changed() -> void:
	bulk_summary=""
	for key in animations.keys():
		if not is_instance_valid(animations[key].control):
			animations[key].tween.kill()
			animations.erase(key)
	generated_count=0
	var live := {}
	for gem in game.profile.jewels:
		live[int(gem.token)]=true
		if int(gem.token)>observed_serial:
			new_tokens[int(gem.token)]=true
			generated_count+=1
	for token in new_tokens.keys():
		if not live.has(token):new_tokens.erase(token)
	observed_serial=game.jewel_serial
	refresh()
	if generated_count>0 and not acting:
		var text := UIText.t("gem.inventory_changed.text_01", {"generated_count":"%d" % (generated_count)})
		if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY:text+=UIText.t("gem.inventory_changed.text_02")
		show_feedback(text)
		var shown:=0
		for token in new_tokens:
			var control: Control=gem_buttons.get(token)
			if visible and is_instance_valid(control) and inventory_list.get_parent().get_global_rect().intersects(control.get_global_rect()):
				pulse(control,host.PURPLE)
				shown+=1
				if shown>=6:break

func pickup_feedback(info: Dictionary) -> void:
	var tab_bar: TabBar=host.equipment_tabs.get_tab_bar()
	var target: Vector2 = control_center(fragments) if visible else tab_bar.global_position+tab_bar.get_tab_rect(4).get_center()
	fly(gem_texture("1"),host.battle_layer.to_global(host.drop_render_position(info)),target)
	var text := UIText.t("gem.pickup_feedback.text_01", {"amount":"%.2f" % (float(info.amount))})
	if generated_count>0:text+=UIText.t("gem.pickup_feedback.text_02", {"generated_count":"%d" % (generated_count)})
	if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY:text+=UIText.t("gem.pickup_feedback.text_03")
	show_feedback(text)
	if visible:pulse(fragments,host.CYAN)

func show_feedback(text: String, success := true) -> void:
	host.toast(text)
	host.beep(880 if success else 180)
	if visible:
		host.set_ui_value(feedback,"text",text)
		host.set_ui_value(feedback,"tooltip_text",text)
		pulse(feedback,host.CYAN if success else host.ORANGE)

func combine_all_selected() -> void:
	if acting:return
	acting=true
	var result := game.combine_all_jewels()
	acting=false
	if not result.ok:
		show_feedback(str(result.message),false)
		return
	if int(result.count)==0 and int(result.deleted)==0:
		show_feedback(UIText.t("merge.combine_all_selected.text_01"),false)
		return
	selected.clear()
	var cleaned:=UIText.t("gem.center.cleaned",{"count":str(result.deleted)}) if int(result.deleted)>0 else ""
	bulk_summary=UIText.t("merge.combine_all_selected.text_02", {"count":"%d" % (int(result.count)), "consumed":"%d" % (int(result.consumed))}) if int(result.count)>0 else ""
	if not cleaned.is_empty():bulk_summary+=("\n" if not bulk_summary.is_empty() else "")+cleaned
	var lines: PackedStringArray=[UIText.t("merge.combine_all_selected.text_03")]
	for reward in result.results:
		lines.append(UIText.t("merge.combine_all_selected.text_04", {"reward":"%s" % (gem_name(reward)), "count":"%d" % (int(reward.count))}))
	bulk_rewards="\n".join(lines) if int(result.count)>0 else ""
	result_token=-1
	for token in result.tokens:
		var gem := game.jewel_inventory(int(token))
		if result_token<0 or int(gem.level)>int(game.jewel_inventory(result_token).level):result_token=int(token)
		pulse(gem_buttons.get(token),host.ORANGE)
	refresh_detail()
	detail_scroll.scroll_vertical=0
	var message:=UIText.t("merge.combine_all_selected.text_05", {"count":"%d" % (int(result.count)), "consumed":"%d" % (int(result.consumed)), "slice":"%s" % ("、".join(lines.slice(1)))}) if int(result.count)>0 else ""
	show_feedback(message+("\n" if not message.is_empty() and not cleaned.is_empty() else "")+cleaned)
	pulse(detail_icon,host.ORANGE)
