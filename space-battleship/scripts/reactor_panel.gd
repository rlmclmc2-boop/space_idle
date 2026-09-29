extends Panel

const CYAN := Color("35e6fa")
const MUTED := Color("82a7bd")
const INK := Color("ddf7ff")
const MODULE_COLORS := {"weapons":Color("ffab4d"),"defence":Color("53bbff"),"smelting":Color("3ff0bd"),"condensation":Color("c998ff")}
const MODULE_ICONS := {"weapons":preload("res://assets/ui/reactor/weapon.svg"),"defence":preload("res://assets/ui/reactor/defence.svg"),"smelting":preload("res://assets/ui/reactor/smelting.svg"),"condensation":preload("res://assets/ui/reactor/condensation.svg")}
const HEADER_ART := preload("res://assets/ui/reactor/reactor-header.png")
const MODULE_BAY_FRAME := preload("res://assets/ui/reactor/module-bay-frame.png")
const MODULE_SCENES := {"weapons":preload("res://assets/ui/reactor/module-weapons-v2.png"),"defence":preload("res://assets/ui/reactor/module-defence-v2.png"),"smelting":preload("res://assets/ui/reactor/module-smelting-v2.png")}
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
var allocation_label: Label
var remaining_label: Label
var total_track: Control
var upgrade_buttons: Dictionary = {}
var equalize_button: Button
var module_controls: Dictionary = {}
var refreshing := false

func make_label(parent: Control, key: String, at: Vector2, width: float, font_size := 18, color := INK, height := 42.0) -> Label:
	var result: Label = host.equipment_card_label(parent,"" if key.is_empty() else UIText.t(key),Rect2(at,Vector2(width,height)),font_size,color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size >= 24 and strong_font != null:result.add_theme_font_override("font",strong_font)
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
	var selected := 13
	for font_size in range(25 if label.size.y > 40.0 else 17,12,-1):
		if font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= label.size.x-8.0:
			selected = font_size
			break
	if label.get_theme_font_size("font_size") != selected:label.add_theme_font_size_override("font_size",selected)

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

func button_style(button: Button, accent: Color, primary := false) -> void:
	button.add_theme_font_size_override("font_size",21)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_stylebox_override("normal",host.style(Color(accent.r,accent.g,accent.b,0.2 if primary else 0.07),accent.darkened(0.2)))
	button.add_theme_stylebox_override("hover",host.style(Color(accent.r,accent.g,accent.b,0.33),accent))
	button.add_theme_stylebox_override("pressed",host.style(Color(accent.r,accent.g,accent.b,0.5),accent.lightened(0.3)))
	button.add_theme_stylebox_override("disabled",host.style(Color("0b1b28"),Color("264051")))

func image_region(parent: Control, texture: Texture2D, region: Rect2, at: Vector2, dimensions: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return static_chrome(parent,atlas,at,dimensions)

func visual(parent: Control, mode: String, at: Vector2, dimensions: Vector2, accent := CYAN) -> Control:
	var layer := preload("res://scripts/reactor_visual.gd").new()
	layer.mode = mode
	layer.accent = accent
	layer.position = at
	layer.size = dimensions
	parent.add_child(layer)
	return layer

func module_icon(parent: Control, key: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	return static_chrome(parent,MODULE_ICONS.get(key,MODULE_ICONS.defence),at,dimensions)

func setup(owner_ui: Node) -> void:
	host = owner_ui
	strong_font = FontVariation.new()
	strong_font.base_font = host.font
	strong_font.variation_embolden = 0.6
	add_theme_stylebox_override("panel",glass_style(Color("27758d")))
	clip_contents = true
	static_chrome(self,preload("res://assets/ui/reactor/room-backing.svg"),Vector2.ZERO,Vector2(1364,1200))
	room = image_region(self,HEADER_ART,Rect2(0,0,990,660),Vector2.ZERO,Vector2(690,510))
	static_chrome(self,preload("res://assets/ui/reactor/integrated-console.svg"),Vector2.ZERO,Vector2(1364,1200))
	for section in 3:
		var trim := 45 if section == 0 else 0
		image_region(self,MODULE_BAY_FRAME,Rect2(397,trim*230.0/220.0,145,230-trim*230.0/220.0),Vector2(630,420+section*220+trim),Vector2(70,220-trim))
	core = visual(self,"core",Vector2(187,70),Vector2(350,350))
	var core_caption := make_label(self,"reactor.core_caption",Vector2(179,457),354,18,CYAN)
	core_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network = visual(self,"network",Vector2(345,315),Vector2(337,155))
	level_label = make_label(self,"",Vector2(766,72),530,44,CYAN,60)
	energy_label = make_label(self,"",Vector2(766,153),272,28,CYAN)
	uranium_label = make_label(self,"",Vector2(1055,153),250,26,INK)
	next_label = make_label(self,"",Vector2(766,211),270,23,INK)
	cost_label = make_label(self,"",Vector2(1055,211),260,22,INK)
	var upgrade_group := Control.new()
	upgrade_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upgrade_group)
	for index in 3:
		var mode: String = ["x1","x10","MAX"][index]
		var button := Button.new()
		button.text = "" if mode == "MAX" else UIText.t("reactor.upgrade.x10" if mode == "x10" else "reactor.upgrade.x1")
		button.position = Vector2(763+index*181,278)
		button.size = Vector2(170,58)
		button.add_theme_font_size_override("font_size",23)
		button_style(button,MODULE_COLORS.weapons if mode == "MAX" else CYAN,mode == "MAX")
		button.pressed.connect(upgrade.bind(mode))
		upgrade_group.add_child(button)
		upgrade_buttons[mode] = button
	make_label(self,"reactor.control_heading",Vector2(59,552),380,29,INK)
	make_label(self,"reactor.control_subtitle",Vector2(60,593),380,13,MUTED,24)
	equalize_button = Button.new()
	equalize_button.text = UIText.t("reactor.equalize")
	equalize_button.position = Vector2(447,552)
	equalize_button.size = Vector2(135,46)
	button_style(equalize_button,CYAN)
	equalize_button.pressed.connect(func():host.game.equalize_reactor_allocation();refresh())
	add_child(equalize_button)
	capacity_label = clipped_readout(self,Vector2(66,653),Vector2(246,65),CYAN)
	allocation_label = clipped_readout(self,Vector2(66,1085),Vector2(510,22),MUTED)
	remaining_label = clipped_readout(self,Vector2(338,653),Vector2(244,65),MODULE_COLORS.weapons)
	var count: int = host.game.reactor_modules().size()
	module_scroll = preload("res://scripts/reactor_module_scroll.gd").new()
	module_scroll.position = Vector2(648,420)
	module_scroll.size = Vector2(692,660)
	module_scroll.module_count = count
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	module_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(module_scroll)
	module_content = Control.new()
	module_content.custom_minimum_size = Vector2(692,maxi(3,count)*BAY_HEIGHT)
	module_scroll.add_child(module_content)
	allocation_scroll = preload("res://scripts/reactor_module_scroll.gd").new()
	allocation_scroll.position = Vector2(48,744)
	allocation_scroll.size = Vector2(546,330)
	allocation_scroll.module_count = count
	allocation_scroll.bay_height = 110
	allocation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	allocation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(allocation_scroll)
	var allocation_content := Control.new()
	allocation_content.custom_minimum_size = Vector2(546,maxi(3,count)*110)
	allocation_scroll.add_child(allocation_content)
	module_scroll.get_v_scroll_bar().value_changed.connect(func(_value):
		allocation_scroll.go_to_slot(module_scroll.current_slot())
		update_module_animation_visibility())
	allocation_scroll.get_v_scroll_bar().value_changed.connect(func(_value):module_scroll.go_to_slot(allocation_scroll.current_slot()))
	var index := 0
	for key in host.game.reactor_modules():
		var accent: Color = MODULE_COLORS.get(key,CYAN)
		var row := card(module_content,Vector2(0,index*BAY_HEIGHT),Vector2(692,BAY_HEIGHT),accent)
		static_chrome(row,preload("res://assets/ui/reactor/module-housing-v3.png"),Vector2(64,4),Vector2(628,204))
		static_chrome(row,preload("res://assets/ui/reactor/module-rim.svg"),Vector2(64,4),Vector2(628,204)).modulate = accent
		static_chrome(row,preload("res://assets/ui/reactor/module-console.svg"),Vector2(64,4),Vector2(628,204))
		static_chrome(row,preload("res://assets/ui/reactor/module-coupling.svg"),Vector2.ZERO,Vector2(146,220))
		var branch := visual(row,"branch",Vector2.ZERO,Vector2(146,BAY_HEIGHT),accent)
		var equipment_view := Control.new()
		equipment_view.position = Vector2(80,15)
		equipment_view.size = Vector2(223,180)
		equipment_view.clip_contents = true
		equipment_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(equipment_view)
		if key == "defence":
			static_chrome(equipment_view,preload("res://assets/ui/reactor/module-defence-v3.png"),Vector2(24,0),Vector2(180,180))
		elif key == "condensation":
			image_region(equipment_view,preload("res://assets/hightech/furnace-jewel-core.png"),Rect2(280,130,700,970),Vector2(53,0),Vector2(130,180))
		elif MODULE_SCENES.has(key):
			var texture: Texture2D = MODULE_SCENES[key]
			static_chrome(equipment_view,texture,Vector2(0,0),Vector2(223,180))
		var scene_fx := visual(equipment_view,"compact_"+key,Vector2.ZERO,equipment_view.size,accent)
		var dimmer := ColorRect.new()
		dimmer.position = equipment_view.position
		dimmer.size = equipment_view.size
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dimmer)
		var icon := module_icon(row,key,Vector2(323,25),Vector2(34,34))
		var name_label := make_label(row,"",Vector2(369,24),190,29,accent)
		name_label.text = UIText.data_text("reactor",key)
		var boost := make_label(row,"",Vector2(324,83),348,27,CYAN)
		var clear_button := Button.new()
		clear_button.text = UIText.t("reactor.clear")
		clear_button.position = Vector2(561,25)
		clear_button.size = Vector2(102,40)
		button_style(clear_button,CYAN)
		clear_button.pressed.connect(func():change_allocation(0,key))
		row.add_child(clear_button)
		var bay_energy := make_label(row,"",Vector2(327,144),170,18,INK,34)
		var bay_track := visual(row,"segments",Vector2(500,151),Vector2(159,20),accent)
		var allocation_row := card(allocation_content,Vector2(0,index*110),Vector2(546,100),accent)
		static_chrome(allocation_row,preload("res://assets/ui/reactor/allocation-console.svg"),Vector2.ZERO,Vector2(546,100))
		module_icon(allocation_row,key,Vector2(14,28),Vector2(42,42))
		var allocation_name := make_label(allocation_row,"",Vector2(76,6),180,22,accent,32)
		allocation_name.text = UIText.data_text("reactor",key)
		var share := make_label(allocation_row,"",Vector2(278,6),207,19,INK,32)
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var track := visual(allocation_row,"track",Vector2(124,43),Vector2(360,20),accent)
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
		input.position = Vector2(124,34)
		input.size = Vector2(360,34)
		input.slider = slider
		input.track = track
		allocation_row.add_child(input)
		var energy := make_label(allocation_row,"",Vector2(124,72),205,18,INK,26)
		var allocation_boost := make_label(allocation_row,"",Vector2(332,72),154,20,CYAN,26)
		allocation_boost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var steps: Array[Button] = []
		for direction in [-1,1]:
			var step_button := Button.new()
			step_button.text = "−" if direction < 0 else "+"
			step_button.position = Vector2(78 if direction < 0 else 495,39)
			step_button.size = Vector2(34,34)
			step_button.add_theme_font_size_override("font_size",25)
			button_style(step_button,accent)
			step_button.pressed.connect(step_allocation.bind(key,direction))
			allocation_row.add_child(step_button)
			steps.append(step_button)
		module_controls[key] = {"index":index,"row":row,"branch":branch,"dimmer":dimmer,"scene_fx":scene_fx,"name":name_label,"icon":icon,"slider":slider,"input":input,"track":track,"energy":energy,"boost":boost,"clear":clear_button,"bay_energy":bay_energy,"bay_track":bay_track,"share":share,"allocation_boost":allocation_boost,"steps":steps}
		index += 1
	total_track = visual(self,"busbar",Vector2(63,1114),Vector2(523,8))
	footer_flow = visual(self,"footer_conduit",Vector2(648,1080),Vector2(110,90))
	make_label(self,"reactor.expansion",Vector2(807,1114),480,23,MUTED)
	visibility_changed.connect(refresh)
	refresh()

func step_allocation(key: String, direction: int) -> void:
	change_allocation(float(host.game.profile.reactorAllocation.get(key,0))+direction*int(host.db.config.reactorAllocationStep),key)

func upgrade(mode: String) -> void:
	var amount: int = host.game.reactor_max_upgrades() if mode == "MAX" else 10 if mode == "x10" else 1
	if host.game.upgrade_reactor(amount):refresh()

func change_allocation(value: float, key: String) -> void:
	if refreshing:return
	host.game.set_reactor_allocation(key,value)
	refresh()

func update_module_animation_visibility() -> void:
	if not is_instance_valid(host) or not is_instance_valid(module_scroll):return
	var animate: bool = is_visible_in_tree() and not host.game.paused
	var first: int = module_scroll.current_slot()
	for controls in module_controls.values():
		var in_view: bool = animate and controls.index >= first and controls.index < first+3
		for key in ["branch","track","scene_fx"]:
			var layer: Control = controls[key]
			var powered: bool = layer.ratio > 0.0 or (key == "branch" and layer.trunk_ratio > 0.0)
			var active: bool = in_view and powered
			if layer.is_processing() != active:layer.set_process(active)

func refresh() -> void:
	if not is_instance_valid(host):return
	var animate: bool = is_visible_in_tree() and not host.game.paused
	if is_instance_valid(core) and core.is_processing() != animate:core.set_process(animate)
	if is_instance_valid(network):
		var network_active: bool = animate and network.ratio > 0.0
		if network.is_processing() != network_active:network.set_process(network_active)
	update_module_animation_visibility()
	if is_instance_valid(total_track):
		var total_active: bool = animate and total_track.ratio > 0.0
		if total_track.is_processing() != total_active:total_track.set_process(total_active)
	if is_instance_valid(footer_flow):
		var footer_active: bool = animate and footer_flow.ratio > 0.0
		if footer_flow.is_processing() != footer_active:footer_flow.set_process(footer_active)
	if not is_visible_in_tree():return
	refreshing = true
	var game = host.game
	var capacity: int = game.reactor_capacity()
	var allocated: int = game.reactor_allocated()
	var available = game.profile.resources.get(str(int(host.db.config.reactorUraniumId)),0)
	var reactor_enabled: bool = game.reactor_unlocked()
	var free_ratio: float = game.charge_free_ratio()
	# Each control owns only its display dependencies. Hidden changes are caught
	# on reveal; direct input and income refresh immediately without a timer.
	if host.ui_state_changed(level_label,[game.profile.reactorLevel,host.db.config.reactorUpgradeBase,host.db.config.reactorUpgradeGrowth]):
		host.set_ui_value(level_label,"text",UIText.t("reactor.level",{"level":str(int(game.profile.reactorLevel))}))
		host.set_ui_value(next_label,"text",UIText.t("reactor.next_level",{"level":str(int(game.profile.reactorLevel)+1)}))
		host.set_ui_value(cost_label,"text",UIText.t("reactor.cost",{"cost":host.number(game.reactor_upgrade_cost())}))
	if host.ui_state_changed(energy_label,[capacity]):
		host.set_ui_value(energy_label,"text",UIText.t("reactor.energy",{"energy":host.number(capacity)}))
		set_readout(capacity_label,energy_label.text)
	if host.ui_state_changed(uranium_label,[available]):
		host.set_ui_value(uranium_label,"text",UIText.t("reactor.uranium",{"uranium":host.number(available)}))
	if host.ui_state_changed(upgrade_buttons.MAX,[game.profile.reactorLevel,available,reactor_enabled,host.db.config.reactorUpgradeBase,host.db.config.reactorUpgradeGrowth]):
		var max_count: int = game.reactor_max_upgrades()
		host.set_ui_value(equalize_button,"disabled",not reactor_enabled)
		for mode in upgrade_buttons:
			var needed: int = max_count if mode == "MAX" else 10 if mode == "x10" else 1
			host.set_ui_value(upgrade_buttons[mode],"disabled",needed <= 0 or max_count < needed or not reactor_enabled)
			if mode == "MAX":host.set_ui_value(upgrade_buttons[mode],"text",UIText.t("reactor.upgrade.max",{"count":str(max_count)}))
	for key in module_controls:
		var controls: Dictionary = module_controls[key]
		var slider: HSlider = controls.slider
		var unlocked: bool = game.reactor_module_unlocked(key)
		var enabled: bool = unlocked and reactor_enabled
		var amount: int = int(game.profile.reactorAllocation.get(key,0)) if unlocked else 0
		if not host.ui_state_changed(controls.row,[capacity,allocated,unlocked,reactor_enabled,amount,free_ratio,host.db.config.reactorBoostExponent,host.db.config.reactorPercentScale,host.db.unlock_row("reactor_module",key).get("level",0)]):continue
		host.set_ui_value(slider,"editable",enabled)
		host.set_ui_value(controls.input,"mouse_filter",Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE)
		controls.input.capacity = capacity
		controls.input.available_max = maxi(amount,capacity-allocated+amount)
		host.set_ui_value(slider,"max_value",capacity)
		host.set_ui_value(slider,"value",amount)
		var power_ratio := float(amount)/maxf(1.0,capacity)
		var visual_ratio := clampf(game.reactor_effective_ratio(key),0.0,1.0)
		controls.track.set_ratio(power_ratio)
		controls.branch.set_ratio(visual_ratio)
		controls.branch.set_trunk_ratio(float(allocated)/maxf(1.0,capacity))
		controls.bay_track.set_ratio(visual_ratio)
		var allocation_text: String=UIText.t("reactor.allocation_tiny") if amount > 0 and power_ratio < 0.01 else UIText.t("reactor.allocation_share",{"percent":str(roundi(power_ratio*100.0))})
		if enabled and free_ratio!=0.0:allocation_text=UIText.t("planet.charge_with_bonus",{"allocation":allocation_text,"bonus":NumberFormat.precise(free_ratio*100.0)})
		host.set_ui_value(controls.share,"text",allocation_text)
		host.set_ui_value(controls.steps[0],"disabled",amount <= 0 or not enabled)
		host.set_ui_value(controls.steps[1],"disabled",allocated >= capacity or not enabled)
		controls.track.set_available_ratio(float(controls.input.available_max)/maxf(1.0,capacity))
		controls.scene_fx.set_ratio(visual_ratio)
		var shade := 0.53 if visual_ratio == 0 else 0.20*(1.0-sqrt(visual_ratio))
		host.set_ui_value(controls.dimmer,"color",Color(0.0,0.015,0.03,shade))
		host.set_ui_value(controls.boost,"modulate",Color(1.0,1.0,1.0,1.0) if visual_ratio > 0 else Color(0.72,0.72,0.72,1.0))
		host.set_ui_value(controls.energy,"text",UIText.t("reactor.module.energy",{"energy":host.number(amount)}))
		host.set_ui_value(controls.bay_energy,"text",controls.energy.text)
		host.set_ui_value(controls.clear,"disabled",amount == 0 or not enabled)
		var percent: float = (game.reactor_multiplier(key)-1.0)*float(host.db.config.reactorPercentScale)
		var percent_text: String = host.number(percent) if percent >= 1000.0 else "%.1f" % percent
		host.set_ui_value(controls.allocation_boost,"text",UIText.t("reactor.module.boost",{"percent":percent_text}))
		var effect_key := "reactor.module.%s.effect" % key
		var effect: String = UIText.t(effect_key) if MODULE_COLORS.has(key) else key
		host.set_ui_value(controls.boost,"text",effect+"  "+UIText.t("reactor.module.boost",{"percent":percent_text}) if unlocked else UIText.t("reactor.module.locked",{"level":str(int(host.db.unlock_row("reactor_module",key).get("level",0)))}))
		host.set_ui_value(controls.row,"tooltip_text",UIText.t("reactor.module.condensation.desc") if key == "condensation" else "")
	update_module_animation_visibility()
	var network_active: bool = animate and allocated > 0
	if network.is_processing() != network_active:network.set_process(network_active)
	if host.ui_state_changed(allocation_label,[capacity,allocated]):
		set_readout(allocation_label,UIText.t("reactor.allocated",{"allocated":host.number(allocated),"total":host.number(capacity)}))
		set_readout(remaining_label,UIText.t("reactor.remaining",{"energy":host.number(capacity-allocated)}))
		core.set_ratio(float(allocated)/maxf(1.0,capacity))
		network.set_ratio(float(allocated)/maxf(1.0,capacity))
		total_track.set_ratio(float(allocated)/maxf(1.0,capacity))
		footer_flow.set_ratio(float(allocated)/maxf(1.0,capacity))
	var total_active := animate and allocated > 0
	if total_track.is_processing() != total_active:total_track.set_process(total_active)
	if footer_flow.is_processing() != total_active:footer_flow.set_process(total_active)
	refreshing = false
