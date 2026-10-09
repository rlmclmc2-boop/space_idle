extends Panel

const ROUTES := preload("res://scripts/reactor_routes.gd")
const PREVIEW := preload("res://scripts/reactor_upgrade_preview.gd")
const SKIN := preload("res://scripts/dialog_presentation.gd")
const ACCENT := Color("83cfcb")
const CYAN := Color("286b73")
const MUTED := Color("506878")
const INK := Color("243d50")
const MODULE_COLORS := {"weapons":Color("dba46c"),"defence":Color("83cfcb"),"smelting":Color("8cc6b4"),"condensation":Color("abc2db")}
const MODULE_ICONS := {"weapons":preload("res://assets/ui/reactor/weapon.svg"),"defence":preload("res://assets/ui/reactor/defence.svg"),"smelting":preload("res://assets/ui/reactor/smelting.svg"),"condensation":preload("res://assets/ui/reactor/condensation.svg")}
const BAY_HEIGHT := 220

var host: Node
var strong_font: FontVariation
var room: TextureRect
var core: Control
var network: Control
var footer_flow: Control
var module_scroll: ScrollContainer
var module_content: Control
var allocation_scroll: ScrollContainer
var level_label: Label
var energy_label: Label
var capacity_label: Label
var uranium_label: Label
var next_label: Label
var cost_label: Label
var benefit_label: Label
var affordable_count := 0
var scroll_hint: Label
var allocation_label: Label
var allocation_hint: Label
var remaining_label: Label
var total_track: Control
var upgrade_buttons: Dictionary = {}
var equalize_button: Button
var module_controls: Dictionary = {}
var refreshing := false
var dirty := true
var refresh_elapsed := 0.0
var animation_state: Array = []

func make_label(parent: Control, key: String, at: Vector2, width: float, font_size := 18, color := INK, height := 42.0) -> Label:
	var result: Label = host.equipment_card_label(parent,"" if key.is_empty() else UIText.t(key),Rect2(at,Vector2(width,height)),font_size,color)
	result.autowrap_mode = TextServer.AUTOWRAP_OFF
	result.clip_text = true
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size >= 18:result.add_theme_font_override("font",SKIN.SHELL.face(600))
	return result

func clipped_readout(parent: Control, at: Vector2, dimensions: Vector2, color: Color) -> Label:
	var slot := Control.new()
	slot.position = at
	slot.size = dimensions
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var label := make_label(slot,"",Vector2.ZERO,dimensions.x,16,color,dimensions.y)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func set_readout(label: Label, value: String) -> void:
	if label.text == value:return
	host.set_ui_value(label,"text",value)
	var font: Font = label.get_theme_font("font")
	var selected := 17
	var largest := 33 if label.size.y > 40.0 else 20 if label.size.y <= 30.0 else 23
	for font_size in range(largest,16,-1):
		if font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= label.size.x-8.0:
			selected = font_size
			break
	if label.get_theme_font_size("font_size") != selected:label.add_theme_font_size_override("font_size",selected)

func energy_text(value: float) -> String:
	# Keep modest pools exact: generic two-significant-digit compact formatting
	# otherwise turns capacity 207 into 200 and makes shares appear incorrect.
	if absf(value)<1000000.0:return ("%.1f" % value).trim_suffix(".0")
	return NumberFormat.compact(value)

func percent_text(value: float) -> String:
	return NumberFormat.percentage(value)

func purchase_cost_text(value: float, compact := true) -> String:
	if compact and value>=1000.0:return host.number(value)
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func supply_segment(parent: Control, color: Color) -> ColorRect:
	var segment := ColorRect.new()
	segment.position = Vector2(114,40)
	segment.size = Vector2(0,28)
	segment.color = color
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(segment)
	return segment

func update_supply_display(controls: Dictionary, manual_percent: String, power_ratio: float, free_ratio: float) -> void:
	set_readout(controls.share,UIText.t("reactor.flow.share_free",{"percent":manual_percent,"free":percent_text(free_ratio*100.0)}))
	# Supply colors include free power; the input remains an integer
	# allocation on the original capacity scale. Above 100%, fit both contributions.
	var scale := maxf(1.0,power_ratio+free_ratio)
	var manual_width := 346.0*clampf(power_ratio/scale,0.0,1.0)
	var free_width := 346.0*clampf(free_ratio/scale,0.0,1.0)
	host.set_ui_value(controls.manual_segment,"size",Vector2(manual_width,28))
	host.set_ui_value(controls.free_segment,"position",Vector2(114+manual_width,40))
	host.set_ui_value(controls.free_segment,"size",Vector2(free_width,28))

func glass_style(border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(0.025,0.075,0.125,0.82)
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(7)
	result.shadow_color = Color(0.0,0.02,0.08,0.48)
	result.shadow_size = 7
	return result

func card(parent: Control, at: Vector2, dimensions: Vector2, border: Color) -> Panel:
	var result := Panel.new()
	result.position = at
	result.size = dimensions
	result.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(result)
	return result

func static_chrome(parent: Control, texture: Texture2D, at: Vector2, dimensions: Vector2) -> TextureRect:
	var chrome := TextureRect.new()
	chrome.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chrome.texture = texture
	chrome.position = at
	chrome.size = dimensions
	chrome.stretch_mode = TextureRect.STRETCH_SCALE
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chrome)
	return chrome

func button_style(button: Button, _accent: Color, primary := false) -> void:
	SKIN.button_skin(button,primary)
	button.add_theme_font_size_override("font_size",21)

func readout_plate(parent: Control, at: Vector2, dimensions: Vector2) -> Panel:
	var plate := card(parent,at,dimensions,INK)
	plate.add_theme_stylebox_override("panel",SKIN.surface())
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate

func update_scroll_hint() -> void:
	if not is_instance_valid(scroll_hint):return
	var count := module_controls.size()
	var first: int = module_scroll.current_slot()+1
	var last := mini(count,first+2)
	var direction := UIText.t("reactor.scroll_more") if last<count else UIText.t("reactor.scroll_back") if first>1 else ""
	host.set_ui_value(scroll_hint,"text",UIText.t("reactor.scroll_range",{"first":first,"last":last,"total":count})+direction)

func image_region(parent: Control, texture: Texture2D, region: Rect2, at: Vector2, dimensions: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return static_chrome(parent,atlas,at,dimensions)

func visual(parent: Control, mode: String, at: Vector2, dimensions: Vector2, accent := ACCENT) -> Control:
	var layer := preload("res://scripts/reactor_visual.gd").new()
	layer.mode = mode
	layer.accent = accent
	layer.position = at
	layer.size = dimensions
	parent.add_child(layer)
	return layer

func route_visual(parent: Control, mode: String, at: Vector2, dimensions: Vector2, route: PackedVector2Array, start := 0.0) -> Control:
	var layer := preload("res://scripts/reactor_visual.gd").new()
	layer.mode=mode
	layer.position=at
	layer.size=dimensions
	layer.route=route
	layer.static_start=start
	parent.add_child(layer)
	return layer

func update_flow_offsets() -> void:
	if not is_instance_valid(module_scroll):return
	for key in module_controls:
		var controls: Dictionary = module_controls[key]
		var junction_y: float = module_scroll.position.y+controls.row.position.y-module_scroll.scroll_vertical+ROUTES.inlet(key).y
		var offset := ROUTES.junction_distance(junction_y)
		if not is_equal_approx(controls.branch.flow_offset,offset):
			controls.branch.flow_offset=offset
			controls.scene_fx.flow_offset=offset+controls.branch.network_length
			controls.branch.queue_redraw()
			controls.scene_fx.queue_redraw()

func module_icon(parent: Control, key: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	return static_chrome(parent,MODULE_ICONS.get(key,MODULE_ICONS.defence),at,dimensions)

func setup(owner_ui: Node) -> void:
	host = owner_ui
	strong_font = FontVariation.new()
	strong_font.base_font = host.font
	strong_font.variation_embolden = 0.6
	add_theme_stylebox_override("panel",glass_style(Color("27758d")))
	clip_contents = true
	room = static_chrome(self,preload("res://assets/ui/reactor/toon-console.svg"),Vector2.ZERO,Vector2(1364,1200))
	route_visual(self,"conduit",ROUTES.ORIGIN,Vector2(400,910),ROUTES.main_route(),105.0)
	core = visual(self,"core",Vector2(187,70),Vector2(350,350))
	var core_caption := make_label(self,"reactor.heading",Vector2(179,457),354,18,SKIN.PAPER)
	core_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network = visual(self,"network",ROUTES.ORIGIN,Vector2(400,910))
	core.flow_source=network
	readout_plate(self,Vector2(745,55),Vector2(580,360))
	level_label = make_label(self,"",Vector2(766,72),530,44,CYAN,60)
	energy_label = make_label(self,"",Vector2(766,153),272,28,CYAN)
	uranium_label = make_label(self,"",Vector2(1055,153),250,26,INK)
	next_label = make_label(self,"",Vector2(766,201),270,23,INK,32)
	cost_label = make_label(self,"",Vector2(1055,201),260,22,INK,32)
	var upgrade_group := Control.new()
	upgrade_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upgrade_group)
	for index in 3:
		var mode: String = ["x1","x10","MAX"][index]
		var button := Button.new()
		button.text = "" if mode == "MAX" else UIText.t("reactor.upgrade.x10" if mode == "x10" else "reactor.upgrade.x1")
		button.position = Vector2(763+index*181,240)
		button.size = Vector2(170,104)
		button.add_theme_font_size_override("font_size",23)
		button_style(button,MODULE_COLORS.weapons if mode == "MAX" else CYAN,mode == "MAX")
		button.add_theme_font_size_override("font_size",21)
		button.pressed.connect(upgrade.bind(mode))
		upgrade_group.add_child(button)
		upgrade_buttons[mode] = button
	benefit_label = make_label(self,"",Vector2(766,352),540,21,INK,64)
	readout_plate(self,Vector2(48,536),Vector2(546,196))
	make_label(self,"reactor.control_heading",Vector2(59,552),380,29,INK)
	make_label(self,"reactor.flow.manual_heading",Vector2(60,593),380,13,MUTED,24)
	equalize_button = Button.new()
	equalize_button.text = UIText.t("reactor.equalize")
	equalize_button.position = Vector2(447,552)
	equalize_button.size = Vector2(135,46)
	button_style(equalize_button,CYAN)
	equalize_button.pressed.connect(func():host.game.equalize_reactor_allocation();refresh())
	add_child(equalize_button)
	allocation_hint = make_label(self,"",Vector2(60,619),520,16,MUTED,25)
	capacity_label = clipped_readout(self,Vector2(66,653),Vector2(246,65),CYAN)
	allocation_label = clipped_readout(self,Vector2(74,1088),Vector2(490,38),SKIN.PAPER)
	remaining_label = clipped_readout(self,Vector2(338,653),Vector2(244,65),INK)
	var count: int = host.game.reactor_modules().size()
	module_scroll = preload("res://scripts/reactor_module_scroll.gd").new()
	module_scroll.position = Vector2(648,420)
	module_scroll.size = Vector2(692,660)
	module_scroll.module_count = count
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	module_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	module_scroll.theme = SKIN.theme()
	add_child(module_scroll)
	module_content = Control.new()
	module_content.custom_minimum_size = Vector2(670,maxi(3,count)*BAY_HEIGHT)
	module_scroll.add_child(module_content)
	allocation_scroll = preload("res://scripts/reactor_module_scroll.gd").new()
	allocation_scroll.position = Vector2(48,744)
	allocation_scroll.size = Vector2(546,330)
	allocation_scroll.module_count = count
	allocation_scroll.bay_height = 110
	allocation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	allocation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	allocation_scroll.theme = SKIN.theme()
	add_child(allocation_scroll)
	var allocation_content := Control.new()
	allocation_content.custom_minimum_size = Vector2(524,maxi(3,count)*110)
	allocation_scroll.add_child(allocation_content)
	module_scroll.get_v_scroll_bar().value_changed.connect(func(_value):
		allocation_scroll.go_to_slot(module_scroll.current_slot())
		update_module_animation_visibility()
		update_flow_offsets()
		update_scroll_hint())
	allocation_scroll.get_v_scroll_bar().value_changed.connect(func(_value):module_scroll.go_to_slot(allocation_scroll.current_slot()))
	var index := 0
	for key in host.game.reactor_modules():
		var accent: Color = MODULE_COLORS.get(key,CYAN)
		var row := card(module_content,Vector2(0,index*BAY_HEIGHT),Vector2(692,BAY_HEIGHT),accent)
		static_chrome(row,preload("res://assets/ui/reactor/toon-bay.svg"),Vector2(64,4),Vector2(606,204))
		route_visual(row,"conduit",Vector2.ZERO,Vector2(230,BAY_HEIGHT),ROUTES.branch_route(key))
		var branch := route_visual(row,"branch",Vector2.ZERO,Vector2(230,BAY_HEIGHT),ROUTES.branch_route(key))
		branch.flow_source=network
		var equipment_view := Control.new()
		equipment_view.position = Vector2(80,15)
		equipment_view.size = Vector2(223,180)
		equipment_view.clip_contents = true
		equipment_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(equipment_view)
		var device_path := "res://assets/ui/reactor/toon-%s.svg" % key
		if ResourceLoader.exists(device_path):
			static_chrome(equipment_view,load(device_path),Vector2.ZERO,equipment_view.size)
		else:module_icon(equipment_view,key,Vector2(65,40),Vector2(96,96))
		var scene_fx := visual(equipment_view,"compact_"+key,Vector2.ZERO,equipment_view.size,accent)
		scene_fx.flow_source=network
		scene_fx.inlet_point=ROUTES.DEVICE_INLETS.get(key,Vector2(58,86))
		var dimmer := ColorRect.new()
		dimmer.position = equipment_view.position
		dimmer.size = equipment_view.size
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dimmer)
		readout_plate(row,Vector2(312,16),Vector2(348,180))
		var icon := module_icon(row,key,Vector2(323,25),Vector2(34,34))
		var name_label := make_label(row,"",Vector2(367,24),177,25,INK)
		name_label.text = UIText.data_text("reactor",key)
		name_label.tooltip_text = name_label.text
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var boost := make_label(row,"",Vector2(324,83),322,25,CYAN)
		var clear_button := Button.new()
		clear_button.text = UIText.t("reactor.clear")
		clear_button.position = Vector2(561,25)
		clear_button.size = Vector2(102,40)
		button_style(clear_button,CYAN)
		clear_button.pressed.connect(func():change_allocation(0,key))
		row.add_child(clear_button)
		var bay_track := visual(row,"segments",Vector2(326,140),Vector2(322,38),accent)
		var bay_energy := make_label(row,"",Vector2(334,142),306,20,SKIN.PAPER,34)
		bay_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var allocation_row := card(allocation_content,Vector2(0,index*110),Vector2(524,106),accent)
		allocation_row.add_theme_stylebox_override("panel",SKIN.surface())
		module_icon(allocation_row,key,Vector2(14,28),Vector2(42,42))
		var allocation_name := make_label(allocation_row,"",Vector2(70,6),110,22,INK,32)
		allocation_name.text = UIText.data_text("reactor",key)
		allocation_name.tooltip_text = allocation_name.text
		allocation_name.mouse_filter = Control.MOUSE_FILTER_PASS
		var share := make_label(allocation_row,"",Vector2(180,6),324,20,INK,32)
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var track := visual(allocation_row,"track",Vector2(112,38),Vector2(350,32),accent)
		var slider := HSlider.new()
		slider.position = track.position
		slider.size = track.size
		slider.min_value = 0
		slider.step = int(host.db.config.reactorAllocationStep)
		slider.modulate.a = 0.0
		slider.value_changed.connect(change_allocation.bind(key))
		slider.focus_entered.connect(track.set_hovered.bind(true))
		slider.focus_exited.connect(track.set_hovered.bind(false))
		allocation_row.add_child(slider)
		var input := preload("res://scripts/reactor_power_input.gd").new()
		input.position = Vector2(112,34)
		input.size = Vector2(350,44)
		input.slider = slider
		input.track = track
		allocation_row.add_child(input)
		var energy := make_label(allocation_row,"",Vector2(70,70),438,19,INK,30)
		energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var supply_background := supply_segment(allocation_row,INK)
		supply_background.size.x = 346
		var manual_segment := supply_segment(allocation_row,MODULE_COLORS.weapons)
		var free_segment := supply_segment(allocation_row,ACCENT)
		var allocation_boost := make_label(allocation_row,"",Vector2(70,77),438,17,CYAN,25)
		allocation_boost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		allocation_boost.hide()
		var steps: Array[Button] = []
		for direction in [-1,1]:
			var step_button := Button.new()
			step_button.text = "−" if direction < 0 else "+"
			step_button.position = Vector2(70 if direction < 0 else 474,37)
			step_button.size = Vector2(34,34)
			step_button.add_theme_font_size_override("font_size",25)
			button_style(step_button,accent)
			step_button.pressed.connect(step_allocation.bind(key,direction))
			allocation_row.add_child(step_button)
			steps.append(step_button)
		module_controls[key] = {"index":index,"row":row,"branch":branch,"dimmer":dimmer,"scene_fx":scene_fx,"name":name_label,"icon":icon,"slider":slider,"input":input,"track":track,"energy":energy,"boost":boost,"clear":clear_button,"bay_energy":bay_energy,"bay_track":bay_track,"share":share,"allocation_boost":allocation_boost,"steps":steps,"manual_segment":manual_segment,"free_segment":free_segment}
		index += 1
	move_child(readout_plate(self,Vector2(48,1080),Vector2(546,62)),allocation_label.get_parent().get_index())
	total_track = visual(self,"segments",Vector2(63,1088),Vector2(510,40))
	move_child(total_track,allocation_label.get_parent().get_index())
	footer_flow = visual(self,"footer_conduit",Vector2(648,1080),Vector2(110,90))
	readout_plate(self,Vector2(760,1094),Vector2(578,68))
	scroll_hint = make_label(self,"",Vector2(780,1106),540,20,INK,42)
	update_scroll_hint()
	update_flow_offsets()
	host.game.event.connect(on_game_event)
	visibility_changed.connect(refresh)
	host.equipment_tabs.tab_changed.connect(func(_index: int):refresh())
	refresh()

func _exit_tree() -> void:
	if is_instance_valid(host) and host.game.event.is_connected(on_game_event):host.game.event.disconnect(on_game_event)

func invalidate() -> void:
	if not dirty:refresh_elapsed=0.0
	dirty=true

func on_game_event(kind: String, payload: Dictionary) -> void:
	match kind:
		"collect","galaxy_income":
			if str(payload.id)==str(int(host.db.config.reactorUraniumId)):invalidate()
		"resources_changed":
			if payload.ids.has(str(int(host.db.config.reactorUraniumId))):invalidate()
		"reactor_changed","unlocks_changed","planet_reforged":invalidate()
		"planet_changed":
			if payload.has("reward") or payload.has("activated"):invalidate()

func refresh_pending(delta := 0.0) -> void:
	if not is_instance_valid(host):return
	var next := [page_active(),host.game.paused]
	if next!=animation_state:
		animation_state=next
		refresh_animation_state()
	if not dirty or not next[0]:return
	if not host.game.paused:refresh_elapsed+=maxf(0.0,delta)*host.game.speed
	# One game-second from first change, matching automation; direct actions/reveal stay immediate.
	if delta<=0.0 or refresh_elapsed+0.000000001>=1.0:refresh()

func step_allocation(key: String, direction: int) -> void:
	change_allocation(float(host.game.profile.reactorAllocation.get(key,0))+direction*int(host.db.config.reactorAllocationStep),key)

func upgrade(mode: String) -> void:
	var amount: int = host.game.reactor_max_upgrades() if mode == "MAX" else 10 if mode == "x10" else 1
	if host.game.upgrade_reactor(amount):refresh()

func change_allocation(value: float, key: String) -> void:
	if refreshing:return
	host.game.set_reactor_allocation(key,value)
	refresh()

func page_active() -> bool:
	# Tab selection changes synchronously, before deferred CanvasItem visibility.
	return is_visible_in_tree() and is_instance_valid(host.equipment_tabs) and host.equipment_tabs.get_current_tab_control() == self

func update_module_animation_visibility() -> void:
	if not is_instance_valid(host) or not is_instance_valid(module_scroll):return
	var animate: bool = page_active() and not host.game.paused
	var first: int = module_scroll.current_slot()
	for controls in module_controls.values():
		var in_view: bool = animate and controls.index >= first and controls.index < first+3
		for key in ["branch","track","scene_fx"]:
			var layer: Control = controls[key]
			var powered: bool = layer.ratio > 0.0 or (key == "branch" and layer.trunk_ratio > 0.0)
			var active: bool = in_view and powered
			if layer.is_processing() != active:layer.set_process(active)

func refresh_animation_state() -> void:
	if not is_instance_valid(host):return
	var animate: bool = page_active() and not host.game.paused
	if is_instance_valid(core) and core.is_processing() != (animate and core.ratio > 0.0):core.set_process(animate and core.ratio > 0.0)
	if is_instance_valid(network):
		var network_active: bool = animate and network.ratio > 0.0
		if network.is_processing() != network_active:network.set_process(network_active)
	update_module_animation_visibility()
	if is_instance_valid(total_track):
		var total_active: bool = animate and total_track.mode != "segments" and total_track.ratio > 0.0
		if total_track.is_processing() != total_active:total_track.set_process(total_active)
	if is_instance_valid(footer_flow):
		var footer_active: bool = animate and footer_flow.ratio > 0.0
		if footer_flow.is_processing() != footer_active:footer_flow.set_process(footer_active)

func refresh() -> void:
	if not is_instance_valid(host):return
	animation_state=[page_active(),host.game.paused]
	refresh_animation_state()
	if not page_active():return
	dirty=false
	refresh_elapsed=0.0
	refreshing = true
	var animate: bool = not host.game.paused
	var game = host.game
	var capacity: int = game.reactor_capacity()
	var allocated: int = game.reactor_allocated()
	if host.ui_state_changed(allocation_hint,[allocated]):
		host.set_ui_value(allocation_hint,"text",UIText.t("reactor.upgrade_idle" if allocated == 0 else "reactor.upgrade_shares"))
	var available = game.profile.resources.get(str(int(host.db.config.reactorUraniumId)),0)
	var reactor_enabled: bool = game.reactor_unlocked()
	var free_ratio: float = game.charge_free_ratio()
	# The visual source follows real effective module supply, including free power.
	var source_strength := 0.0
	for key in module_controls:
		source_strength+=game.reactor_effective_ratio(key)
	source_strength=clampf(source_strength,0.0,1.0) if capacity>0 else 0.0
	# Each control owns only its display dependencies. Hidden changes are caught
	# on reveal; direct input and income refresh immediately without a timer.
	if host.ui_state_changed(level_label,[game.profile.reactorLevel,host.db.config.reactorUpgradeBase,host.db.config.reactorUpgradeGrowth]):
		host.set_ui_value(level_label,"text",UIText.t("reactor.level",{"level":str(int(game.profile.reactorLevel))}))
		host.set_ui_value(next_label,"text",UIText.t("reactor.next_level",{"level":str(int(game.profile.reactorLevel)+1)}))
		host.set_ui_value(cost_label,"text",UIText.t("reactor.cost",{"cost":purchase_cost_text(game.reactor_upgrade_cost())}))
	if host.ui_state_changed(energy_label,[capacity]):
		host.set_ui_value(energy_label,"text",UIText.t("reactor.energy",{"energy":energy_text(capacity)}))
		set_readout(capacity_label,energy_label.text)
	if host.ui_state_changed(uranium_label,[available]):
		host.set_ui_value(uranium_label,"text",UIText.t("reactor.uranium",{"uranium":host.number(available)}))
	if host.ui_state_changed(upgrade_buttons.MAX,[game.profile.reactorLevel,available,reactor_enabled,host.db.config.reactorUpgradeBase,host.db.config.reactorUpgradeGrowth]):
		var max_count: int = game.reactor_max_upgrades()
		affordable_count = max_count
		host.set_ui_value(equalize_button,"disabled",not reactor_enabled)
		for mode in upgrade_buttons:
			var needed: int = max_count if mode == "MAX" else 10 if mode == "x10" else 1
			host.set_ui_value(upgrade_buttons[mode],"disabled",needed <= 0 or max_count < needed or not reactor_enabled)
	if host.ui_state_changed(benefit_label,[game.profile.reactorLevel,available,reactor_enabled,capacity,game.reactor_energy(),game.profile.reactorAllocation.duplicate(),free_ratio,Array(game.reactor_available_modules()),host.db.config.reactorEnergyGrowth,host.db.config.reactorUpgradeBase,host.db.config.reactorUpgradeGrowth,host.db.config.reactorBoostExponent,host.db.config.reactorPercentScale]):
		refresh_upgrade_preview()
	for key in module_controls:
		var controls: Dictionary = module_controls[key]
		var slider: HSlider = controls.slider
		var unlocked: bool = game.reactor_module_unlocked(key)
		var enabled: bool = unlocked and reactor_enabled
		var amount: int = int(game.profile.reactorAllocation.get(key,0)) if unlocked else 0
		if not host.ui_state_changed(controls.row,[capacity,allocated,unlocked,reactor_enabled,amount,free_ratio,source_strength,host.db.config.reactorBoostExponent,host.db.config.reactorPercentScale,host.db.unlock_row("reactor_module",key).get("level",0)]):continue
		host.set_ui_value(slider,"editable",enabled)
		host.set_ui_value(controls.input,"mouse_filter",Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE)
		controls.input.capacity = capacity
		controls.input.available_max = maxi(amount,capacity-allocated+amount)
		host.set_ui_value(slider,"max_value",capacity)
		host.set_ui_value(slider,"value",amount)
		var power_ratio := float(amount)/maxf(1.0,capacity)
		var effective_ratio: float = game.reactor_effective_ratio(key)
		var effective_energy: float = effective_ratio*capacity
		var free_energy: float = maxf(0.0,effective_energy-amount)
		var visual_ratio := clampf(effective_ratio,0.0,1.0) if effective_energy>0.0 else 0.0
		controls.track.set_ratio(power_ratio)
		controls.branch.set_ratio(visual_ratio)
		controls.branch.set_trunk_ratio(source_strength)
		controls.bay_track.set_ratio(visual_ratio)
		var manual_percent := UIText.t("reactor.allocation_tiny") if amount > 0 and power_ratio < 0.01 else percent_text(power_ratio*100.0)+"%"
		update_supply_display(controls,manual_percent,power_ratio,free_ratio if enabled else 0.0)
		host.set_ui_value(controls.steps[0],"disabled",amount <= 0 or not enabled)
		host.set_ui_value(controls.steps[1],"disabled",allocated >= capacity or not enabled)
		controls.track.set_available_ratio(float(controls.input.available_max)/maxf(1.0,capacity))
		controls.scene_fx.set_ratio(visual_ratio)
		var shade := 0.58 if not enabled else 0.32 if visual_ratio == 0 else 0.08*(1.0-sqrt(visual_ratio))
		host.set_ui_value(controls.dimmer,"color",Color(0.0,0.015,0.03,shade))
		host.set_ui_value(controls.boost,"modulate",Color(1.0,1.0,1.0,1.0) if visual_ratio > 0 else Color(0.72,0.72,0.72,1.0))
		set_readout(controls.energy,UIText.t("reactor.flow.manual",{"amount":energy_text(amount),"capacity":energy_text(capacity)}))
		set_readout(controls.bay_energy,UIText.t("reactor.flow.effective",{"energy":energy_text(effective_energy),"percent":percent_text(effective_ratio*100.0)}))
		host.set_ui_value(controls.clear,"disabled",amount == 0 or not enabled)
		var percent: float = (game.reactor_multiplier(key)-1.0)*100.0
		var effect_percent: String = NumberFormat.percentage(percent)
		host.set_ui_value(controls.allocation_boost,"text",UIText.t("reactor.flow.free",{"energy":energy_text(free_energy),"percent":percent_text(free_ratio*100.0 if enabled else 0.0)}))
		var effect_key := "reactor.module.%s.effect" % key
		var effect: String = UIText.t(effect_key) if MODULE_COLORS.has(key) else key
		set_readout(controls.boost,effect+"  "+UIText.t("reactor.module.boost",{"percent":effect_percent}) if unlocked else UIText.t("reactor.module.locked",{"level":str(int(host.db.unlock_row("reactor_module",key).get("level",0)))}))
		host.set_ui_value(controls.row,"tooltip_text",UIText.t("reactor.flow.details",{"manual":energy_text(amount),"share":manual_percent,"free":energy_text(free_energy),"free_percent":percent_text(free_ratio*100.0 if enabled else 0.0),"effective":energy_text(effective_energy),"effect":controls.boost.text})+("\n"+UIText.t("reactor.flow.smelting_scope") if key == "smelting" else "\n"+UIText.t("reactor.module.condensation.desc") if key == "condensation" else ""))
	update_module_animation_visibility()
	core.set_ratio(source_strength)
	network.set_ratio(source_strength)
	if core.is_processing() != (animate and source_strength>0.0):core.set_process(animate and source_strength>0.0)
	if network.is_processing() != (animate and source_strength>0.0):network.set_process(animate and source_strength>0.0)
	if host.ui_state_changed(allocation_label,[capacity,allocated]):
		set_readout(allocation_label,UIText.t("reactor.allocated",{"allocated":energy_text(allocated),"total":energy_text(capacity)}))
		set_readout(remaining_label,UIText.t("reactor.remaining",{"energy":energy_text(capacity-allocated)}))
		total_track.set_ratio(float(allocated)/maxf(1.0,capacity))
	refreshing = false

func refresh_upgrade_preview() -> void:
	var game: BattleGame = host.game
	for mode in upgrade_buttons:
		var count: int = affordable_count if mode == "MAX" else 10 if mode == "x10" else 1
		var quote: Dictionary = PREVIEW.quote(game,count)
		var title: String = UIText.t("reactor.upgrade.max",{"count":str(count)}) if mode == "MAX" else UIText.t("reactor.upgrade.x10" if mode == "x10" else "reactor.upgrade.x1")
		host.set_ui_value(upgrade_buttons[mode],"text",UIText.t("reactor.purchase_button",{"title":title,"cost":purchase_cost_text(quote.cost),"energy":energy_text(quote.next_capacity-quote.capacity)}))
		var details: String = UIText.t("reactor.purchase_details",{"count":str(count),"cost":purchase_cost_text(quote.cost,false),"current":energy_text(quote.capacity),"next":energy_text(quote.next_capacity)})
		for key in quote.effects:
			var effect: Dictionary = quote.effects[key]
			details += "\n"+UIText.t("reactor.purchase_effect",{"module":UIText.data_text("reactor",key),"current":"%.2f" % ((effect.current-1.0)*100.0),"next":"%.2f" % ((effect.next-1.0)*100.0),"gain":"%.2f" % effect.gain})
		details += "\n"+UIText.t("reactor.purchase_scope")
		host.set_ui_value(upgrade_buttons[mode],"tooltip_text",details)
		if mode == "x1":
			var lines := PackedStringArray()
			for key in ["weapons","defence"]:
				if not quote.effects.has(key):continue
				var effect: Dictionary = quote.effects[key]
				lines.append(UIText.t("reactor.purchase_effect_short",{"module":UIText.data_text("reactor",key),"current":"%.2f" % ((effect.current-1.0)*100.0),"next":"%.2f" % ((effect.next-1.0)*100.0),"gain":"%.2f" % effect.gain}))
			host.set_ui_value(benefit_label,"text",UIText.t("reactor.single_preview",{"effects":"\n".join(lines)}))
