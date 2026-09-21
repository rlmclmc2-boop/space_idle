extends Panel
## Charge presentation only. BattleGame remains the sole owner of jobs/resources.
const Circuit = preload("res://scripts/charge_circuit.gd")
const Network = preload("res://scripts/charge_network.gd")
const CYAN := Color("35e6fa")
const MUTED := Color("81a4bf")
const INK := Color("ddf7ff")
const ORANGE := Color("ffb65c")
const STATE_COLORS := {"charging":Color("49f3ff"),"paused":Color("70879c"),"insufficient":ORANGE,"available":Color("57b8c8"),"locked":Color("485a6b")}
const STATE_LABELS := {"charging":"charge.state.charging","paused":"charge.state.paused","insufficient":"charge.state.insufficient","available":"charge.state.available","locked":"charge.state.locked"}
var host: Node
var cards: Dictionary = {}
var selected := ""
var modules: HBoxContainer
var scroll: ScrollContainer
var detail: Dictionary
var energy_rows: Dictionary = {}
var energy_list: VBoxContainer
var core_feed: Control
var reactor: Control
var page_label: Label
var total: Label
var extension: Button
var hint: Label
var previous_button: Button
var next_button: Button
var sample_elapsed := 0.0
var sampled_pause := false
var geometry_queued := false
var visible_keys: Array = []
var sample_count := 0
var geometry_scans := 0

func refresh_sample(delta := 0.0) -> void:
	if not is_visible_in_tree():
		return
	sample_elapsed+=delta
	if delta>0 and sample_elapsed<0.1 and sampled_pause==host.game.paused:
		return
	sample_elapsed=0.0
	sampled_pause=host.game.paused
	sample_count+=1
	refresh_core()
	for key in visible_keys:
		if cards.has(key):
			refresh_card(key)
	if not selected in visible_keys:
		refresh_detail()

func invalidate_geometry() -> void:
	if geometry_queued:
		return
	geometry_queued=true
	flush_geometry.call_deferred()

func flush_geometry() -> void:
	geometry_queued=false
	if is_visible_in_tree():
		refresh_animation_visibility()
		refresh_sample()

func visibility_updated() -> void:
	sample_elapsed=0
	if is_visible_in_tree():
		invalidate_geometry()

func _draw() -> void:
	# Recessed deck, structural shoulders and highlights are a static layer.
	var plate := PackedVector2Array([Vector2(20,96),Vector2(42,76),Vector2(988,76),Vector2(1010,96),Vector2(1010,240),Vector2(986,258),Vector2(42,258),Vector2(20,240)])
	draw_colored_polygon(plate,Color("091b2b"))
	draw_polyline(plate,Color("1e3a4e"),1,true)
	draw_line(Vector2(44,77),Vector2(982,77),Color("405d6c"),1,true)
	var recess := PackedVector2Array([Vector2(348,96),Vector2(982,96),Vector2(982,238),Vector2(368,238),Vector2(348,218)])
	draw_colored_polygon(recess,Color("071421"))
	draw_line(Vector2(368,238),Vector2(981,238),Color("1c3445"),1,true)
	for x in [28.0,1002.0]:
		draw_line(Vector2(x,300),Vector2(x,555),Color("142c3c"),1,true)
		draw_line(Vector2(x,555),Vector2(x+(-15 if x>500 else 15),573),Color("355366"),2,true)
	draw_line(Vector2(20,588),Vector2(1010,588),Color("294659"),1,true)

func text(parent: Control, value: String, rect: Rect2, font_size := 14, color := INK) -> Label:
	var label: Label = host.equipment_card_label(parent,value,rect,font_size,color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func setup(owner_ui: Node) -> void:
	host = owner_ui
	add_theme_stylebox_override("panel",host.style(Color("040e19"),Color("1a3142")))
	text(self,UIText.t("charge.heading"),Rect2(24,15,720,36),26,CYAN)
	text(self,UIText.t("charge.eyebrow"),Rect2(26,49,700,20),11,MUTED)
	core_feed = Network.new()
	core_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(core_feed)
	var core_panel := Panel.new()
	core_panel.position = Vector2(20,82)
	core_panel.size = Vector2(990,174)
	core_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	add_child(core_panel)
	reactor = Circuit.new()
	reactor.core = true
	reactor.position = Vector2(52,-6)
	reactor.size = Vector2(236,188)
	core_panel.add_child(reactor)
	text(core_panel,UIText.t("charge.core"),Rect2(366,9,380,32),27,CYAN)
	text(core_panel,UIText.t("charge.core_note"),Rect2(366,44,595,24),13,MUTED)
	for index in range(4):
		var field: String = ["available","consumption","production","net"][index]
		var caption := text(core_panel,UIText.t({"available":"charge.energy.available","consumption":"charge.energy.consumption","production":"charge.energy.production","net":"charge.energy.net"}[field]),Rect2(366+index*150,79,146,24),12,MUTED)
		caption.mouse_filter = Control.MOUSE_FILTER_PASS
		caption.tooltip_text = UIText.t("charge.energy_basis")
	var supply_scroll := ScrollContainer.new()
	supply_scroll.position = Vector2(366,108)
	supply_scroll.size = Vector2(610,54)
	supply_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	core_panel.add_child(supply_scroll)
	energy_list = VBoxContainer.new()
	energy_list.custom_minimum_size.x = 600
	supply_scroll.add_child(energy_list)
	text(self,UIText.t("charge.bus"),Rect2(380,249,530,20),13,MUTED)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(20,274)
	scroll.size = Vector2(990,310)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	modules = HBoxContainer.new()
	modules.add_theme_constant_override("separation",0)
	scroll.add_child(modules)
	extension = host.button(UIText.t("charge.add"),Rect2(0,0,160,294),func():
		host.set_ui_value(hint,"text",UIText.t("charge.extension_hint")))
	extension.custom_minimum_size = Vector2(160,294)
	extension.reparent(modules,false)
	extension.tooltip_text = UIText.t("charge.extension_hint")
	total = text(self,"",Rect2(26,596,220,24),14,CYAN)
	hint = text(self,UIText.t("charge.navigation"),Rect2(228,596,575,36),13,MUTED)
	previous_button = host.button("‹",Rect2(815,592,36,32),func():turn_page(-1))
	previous_button.reparent(self,false)
	next_button = host.button("›",Rect2(970,592,36,32),func():turn_page(1))
	next_button.reparent(self,false)
	page_label = text(self,"",Rect2(855,596,110,24),14,INK)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.get_h_scroll_bar().changed.connect(refresh_paging)
	scroll.get_h_scroll_bar().value_changed.connect(func(_value):refresh_paging())
	detail = build_detail()
	visibility_changed.connect(visibility_updated)
	resized.connect(invalidate_geometry)
	scroll.resized.connect(invalidate_geometry)
	modules.sort_children.connect(invalidate_geometry)
	modules.item_rect_changed.connect(invalidate_geometry)
	reactor.item_rect_changed.connect(invalidate_geometry)
	reactor.port.item_rect_changed.connect(invalidate_geometry)
	sync_modules()
	refresh_core()

func page_capacity() -> int:
	return maxi(1,mini(6,int(floorf(scroll.size.x/maxf(1,extension.custom_minimum_size.x)))))

func page_count() -> int:
	return maxi(1,ceili(float(cards.size()+1)/page_capacity()))

func current_page() -> int:
	var bar := scroll.get_h_scroll_bar()
	if bar.max_value-bar.page > 0 and bar.value >= bar.max_value-bar.page-1:
		return page_count()
	return mini(page_count(),1+int(floorf(bar.value/(page_capacity()*extension.custom_minimum_size.x))))

func turn_page(direction: int) -> void:
	var page := clampi(current_page()+direction,1,page_count())
	scroll.scroll_horizontal = roundi((page-1)*page_capacity()*extension.custom_minimum_size.x)

func refresh_paging() -> void:
	var bar := scroll.get_h_scroll_bar()
	host.set_ui_value(previous_button,"disabled",bar.value<=bar.min_value)
	host.set_ui_value(next_button,"disabled",bar.value>=bar.max_value-bar.page)
	host.set_ui_value(page_label,"text",UIText.t("charge.page",{"current":str(current_page()),"total":str(page_count())}))
	invalidate_geometry()

func refresh_animation_visibility() -> void:
	if not is_instance_valid(reactor) or not is_instance_valid(reactor.port):
		return
	geometry_scans+=1
	visible_keys.clear()
	var ports := {}
	var clip := scroll.get_global_rect()
	for key in cards:
		var instrument: Control = cards[key].circuit
		ports[key]=instrument.port
		var socket: Vector2 = instrument.port.get_global_transform()*(instrument.port.size*0.5)
		instrument.set_viewport_active(clip.has_point(socket))
		if instrument.viewport_active:
			visible_keys.append(key)
	core_feed.sync_geometry(reactor.port,ports,scroll)
	for key in ports:
		var state := state_for(key)
		core_feed.set_status(key,state,state=="charging" and not host.game.paused)

func sync_modules() -> void:
	for key in cards.keys():
		if not host.db.data.get("charge",{}).has(key):
			var card: Control = cards[key].title.get_parent()
			modules.remove_child(card)
			card.queue_free()
			cards.erase(key)
	for key in host.db.data.get("charge",{}):
		if not cards.has(key):
			cards[key] = build_module(key)
	modules.move_child(extension,modules.get_child_count()-1)
	var width := clampf(floorf(986.0/(cards.size()+1)),164,248)
	host.set_ui_value(extension,"custom_minimum_size",Vector2(width,294))
	for c in cards.values():
		var card: Control = c.title.get_parent()
		if card.custom_minimum_size.x != width:
			card.custom_minimum_size.x = width
			c.circuit.size.x = width
			c.circuit.queue_redraw()
			c.select.size.x = width-8
			for field in ["title","percent","status","progress","level_progress","cost"]:
				c[field].size.x = width-18
			for field in ["charge_bar","level_bar"]:
				c[field].size.x = width-18
			if c.title.has_meta("refresh_state"):
				c.title.remove_meta("refresh_state")
	if not cards.has(selected):
		selected = str(cards.keys()[0]) if not cards.is_empty() else ""
	for key in cards:
		refresh_card(key)
	host.set_ui_value(total,"text",UIText.t("charge.system_count",{"count":str(cards.size())}))
	refresh_detail()
	refresh_core()
	refresh_paging()

func build_module(key: String) -> Dictionary:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(164,294)
	card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	modules.add_child(card)
	var circuit := Circuit.new()
	circuit.size = Vector2(164,180)
	# Existing display bindings select artwork; unknown systems use the generic module.
	var display_key := UIText.data_key("charge",key)
	circuit.icon_kind = {"upgrade.charge.item_01.name":"attack","upgrade.charge.item_02.name":"shield"}.get(display_key,"module")
	card.add_child(circuit)
	card.item_rect_changed.connect(invalidate_geometry)
	circuit.item_rect_changed.connect(invalidate_geometry)
	circuit.port.item_rect_changed.connect(invalidate_geometry)
	var choose: Button = host.button("",Rect2(4,4,156,286),func():select_module(key))
	choose.reparent(card,false)
	var transparent := StyleBoxEmpty.new()
	choose.add_theme_stylebox_override("normal",transparent)
	choose.add_theme_stylebox_override("hover",transparent)
	choose.add_theme_stylebox_override("focus",transparent)
	choose.mouse_entered.connect(func():circuit.set_hovered(true))
	choose.mouse_exited.connect(func():circuit.set_hovered(false))
	choose.add_theme_stylebox_override("pressed",transparent)
	choose.tooltip_text = UIText.data_text("charge",key)
	var result := {"circuit":circuit,"select":choose}
	result.title = text(card,"",Rect2(9,180,146,24),14,CYAN)
	result.percent = text(card,"",Rect2(9,104,146,35),26,INK)
	result.status = text(card,"",Rect2(9,206,146,21),13,CYAN)
	result.progress = text(card,"",Rect2(9,231,146,18),12,MUTED)
	result.charge_bar = host.charge_progress_bar(card,Vector2(9,247),146,CYAN)
	result.level_progress = text(card,"",Rect2(9,251,146,18),12,MUTED)
	result.level_bar = host.charge_progress_bar(card,Vector2(9,270),146,Color("ae8df4"))
	result.level_bar.size.y = 3
	result.charge_bar.visible = false
	result.cost = text(card,"",Rect2(9,278,146,17),11,MUTED)
	circuit.percent_label = result.percent
	circuit.write_value = Callable(host,"set_ui_value")
	for field in ["title","percent","status","progress","level_progress","cost"]:
		result[field].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result

func build_detail() -> Dictionary:
	var panel := Panel.new()
	panel.position = Vector2(1030,82)
	panel.size = Vector2(306,544)
	panel.add_theme_stylebox_override("panel",host.style(Color("0a1c2b"),CYAN))
	add_child(panel)
	text(panel,UIText.t("charge.detail"),Rect2(18,15,270,24),13,MUTED)
	var result := {}
	result.title = text(panel,"",Rect2(18,49,270,65),23,CYAN)
	result.title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.status = text(panel,"",Rect2(18,115,270,24),16,CYAN)
	result.percent = text(panel,"",Rect2(18,149,270,48),38,INK)
	result.progress = text(panel,"",Rect2(18,211,270,24),14,INK)
	result.charge_bar = host.charge_progress_bar(panel,Vector2(18,243),270,CYAN)
	result.level_progress = text(panel,"",Rect2(18,264,270,24),14,MUTED)
	result.level_bar = host.charge_progress_bar(panel,Vector2(18,296),270,Color("ae8df4"))
	text(panel,UIText.t("charge.effect"),Rect2(18,320,270,24),15,CYAN)
	result.description = text(panel,"",Rect2(18,350,270,62),15,INK)
	result.description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.description.mouse_filter = Control.MOUSE_FILTER_PASS
	result.cost = text(panel,"",Rect2(18,426,270,28),15,MUTED)
	result.button = host.button("",Rect2(18,478,270,46),activate_selected,true)
	result.button.reparent(panel,false)
	return result

func state_for(key: String) -> String:
	if not host.game.charge_unlocked(key):
		return "locked"
	var job: Dictionary = host.game.charge_job(key)
	var row: Dictionary = host.db.data.charge[key]
	if host.game.charge_resource_rate(key)>0 and floorf(float(host.game.profile.resources.get(str(int(row.para_1)),0)))<=0 and float(job.credit)<=0:
		return "insufficient"
	if job.active:
		return "charging"
	return "paused" if int(job.started)>0 else "available"

func select_module(key: String) -> void:
	var previous := selected
	selected = key
	if cards.has(previous):
		refresh_card(previous)
	refresh_card(key)
	refresh_detail()

func activate_selected() -> void:
	if selected.is_empty() or state_for(selected) in ["locked","insufficient"]:
		return
	host.game.toggle_charge(selected)
	refresh_card(selected)
	refresh_detail()
	refresh_core()

func refresh_card(key: String) -> void:
	if not cards.has(key):
		return
	var c: Dictionary = cards[key]
	var job: Dictionary = host.game.charge_job(key)
	var row: Dictionary = host.db.data.charge[key]
	var state := state_for(key)
	var flow: bool = state == "charging" and not host.game.paused
	c.circuit.set_state(state)
	c.circuit.set_selected(selected==key)
	c.circuit.set_frozen(host.game.paused)
	c.circuit.set_flow(flow)
	core_feed.set_status(key,state,flow)
	if not host.ui_state_changed(c.title,[job,row,state,selected==key]):
		return
	var color: Color = STATE_COLORS[state]
	var card: Panel = c.title.get_parent()
	if host.ui_state_changed(card,[state,selected==key]):
		# The chassis and selection live on the instrument, not a rectangular card.
		card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		for label in [c.title,c.percent,c.status]:
			label.add_theme_color_override("font_color",color)
		c.charge_bar.get_child(0).color = color
	host.set_ui_value(c.title,"text",UIText.t("gem.name_level",{"item_name":UIText.data_text("charge",key),"level":str(int(job.level))}))
	host.set_ui_value(c.title,"tooltip_text",c.title.text)
	if c.status.get_theme_color("font_color") != color:
		c.status.add_theme_color_override("font_color",color)
	host.set_ui_value(c.status,"text",UIText.t(STATE_LABELS[state]))
	update_progress(c,key)
	host.set_ui_value(c.select,"tooltip_text","\n".join([c.title.text,c.status.text,c.progress.text,c.level_progress.text,c.cost.text]))
	if selected==key:
		refresh_detail()

func update_progress(c: Dictionary, key: String) -> void:
	var job: Dictionary = host.game.charge_job(key)
	var row: Dictionary = host.db.data.charge[key]
	var fraction := clampf(float(job.elapsed)/maxf(0.001,float(row.para_4)),0,1)
	if c.has("circuit"):
		c.circuit.set_job_progress(fraction,int(job.level),float(job.count))
	else:
		host.set_ui_value(c.percent,"text","%d%%" % roundi(fraction*100))
	host.set_ui_value(c.progress,"text",UIText.t("charge.time" if c.has("circuit") else "upgrade.refresh_charge_card.text_02",{"elapsed":host.number(job.elapsed),"para_4":host.number(row.para_4)}))
	host.set_ui_value(c.level_progress,"text",UIText.t("charge.upgrades" if c.has("circuit") else "upgrade.refresh_charge_card.text_03",{"count":host.number(job.count),"key":host.number(host.game.charge_required(key))}))
	host.set_ui_value(c.charge_bar.get_child(0),"size",Vector2(c.charge_bar.size.x*fraction,c.charge_bar.size.y))
	host.set_ui_value(c.level_bar.get_child(0),"size",Vector2(c.level_bar.size.x*clampf((float(job.count)+fraction)/maxf(1,host.game.charge_required(key)),0,1),c.level_bar.size.y))
	host.set_ui_value(c.cost,"text",UIText.t("charge.cost" if c.has("circuit") else "upgrade.refresh_charge_card.text_04",{"para_1":UIText.data_text("resources",str(int(row.para_1))),"key":host.number(host.game.charge_resource_rate(key))}))
	host.set_ui_value(c.cost,"tooltip_text",c.cost.text)

func refresh_detail() -> void:
	if selected.is_empty() or not cards.has(selected):
		return
	var job: Dictionary = host.game.charge_job(selected)
	var state := state_for(selected)
	var row: Dictionary = host.db.data.charge[selected]
	if not host.ui_state_changed(detail.title,[selected,job,row,state]):
		return
	host.set_ui_value(detail.title,"text",UIText.t("gem.name_level",{"item_name":UIText.data_text("charge",selected),"level":str(int(job.level))}))
	host.set_ui_value(detail.description,"text",host.game.charge_description(selected))
	host.set_ui_value(detail.description,"tooltip_text",detail.description.text)
	host.set_ui_value(detail.status,"text",UIText.t(STATE_LABELS[state]))
	var color: Color = STATE_COLORS[state]
	if detail.status.get_theme_color("font_color") != color:
		detail.status.add_theme_color_override("font_color",color)
	if host.ui_state_changed(detail.button,[state]):
		var skin: StyleBoxFlat = host.style(Color(color,0.16),color)
		for variant in ["normal","disabled"]:
			detail.button.add_theme_stylebox_override(variant,skin)
		detail.button.add_theme_stylebox_override("hover",host.style(Color(color,0.3),color))
		detail.button.add_theme_stylebox_override("pressed",host.style(Color(color,0.45),color))
		for variant in ["font_color","font_disabled_color","font_hover_color","font_pressed_color"]:
			detail.button.add_theme_color_override(variant,color)
		detail.title.get_parent().add_theme_stylebox_override("panel",host.style(Color("0a1c2b"),color.darkened(0.2)))
		detail.charge_bar.get_child(0).color = color
	update_progress(detail,selected)
	var action: String = {"charging":"upgrade.refresh_charge_card.text_09","paused":"upgrade.refresh_charge_card.text_12","available":"upgrade.refresh_charge_card.text_13","insufficient":"charge.state.insufficient","locked":"upgrade.refresh_charge_card.text_06"}[state]
	host.set_ui_value(detail.button,"text",UIText.t(action,{"unlock":str(int(row.unlock))}) if state=="locked" else UIText.t(action))
	host.set_ui_value(detail.button,"disabled",state in ["locked","insufficient"])

func core_metrics() -> Dictionary:
	# Display projection only: keep distinct resources separate, never create a balance.
	var result := {}
	for key in host.db.data.get("charge",{}):
		var id := str(int(host.db.data.charge[key].para_1))
		if not result.has(id):
			result[id] = {"available":float(host.game.profile.resources.get(id,0)),"consumption":0.0,"production":host.game.resource_minute_total(id)/60.0}
		if not host.game.paused and state_for(key)=="charging":
			result[id].consumption += host.game.charge_resource_rate(key)*host.game.speed
	for id in result:
		result[id].net = result[id].production-result[id].consumption
	return result

func refresh_core() -> void:
	var metrics := core_metrics()
	for id in energy_rows.keys():
		if not metrics.has(id):
			var row: Control = energy_rows[id].available.get_parent()
			energy_list.remove_child(row)
			row.queue_free()
			energy_rows.erase(id)
	for id in metrics:
		if not energy_rows.has(id):
			var row := Control.new()
			row.custom_minimum_size = Vector2(600,44)
			energy_list.add_child(row)
			var controls := {}
			for index in range(4):
				var field: String = ["available","consumption","production","net"][index]
				controls[field] = text(row,"",Rect2(index*150,0,146,38),22,INK)
				controls[field].mouse_filter = Control.MOUSE_FILTER_PASS
			energy_rows[id] = controls
		for field in metrics[id]:
			var value: String = host.number(metrics[id][field]) if field=="available" else host.NUMBER_FORMAT.rate(absf(metrics[id][field]))
			if field=="available":
				value = UIText.t("charge.energy_amount",{"name":UIText.data_text("resources",id),"amount":value})
			elif field=="net" and metrics[id][field]>0:
				value = "+"+value
			elif field=="net" and metrics[id][field]<0:
				value = "−"+value
			var label: Label = energy_rows[id][field]
			host.set_ui_value(label,"text",value)
			host.set_ui_value(label,"tooltip_text",value+"\n"+UIText.t("charge.energy_basis"))
			var color := ORANGE if field=="net" and metrics[id][field]<0 else (CYAN if field=="production" else INK)
			if label.get_theme_color("font_color")!=color:
				label.add_theme_color_override("font_color",color)
	reactor.set_frozen(host.game.paused)
	reactor.set_flow(not host.game.paused)
