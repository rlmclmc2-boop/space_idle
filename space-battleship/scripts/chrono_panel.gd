extends Control

const NAVY := Color("243d50")
const PAPER := Color("ecebdc")
const TEAL := Color("83cfcb")
const MUTED := Color("546c74")
const PARTICLE = preload("res://assets/chrono/particle.svg")

class EnergyFlow extends Control:
	var intensity := 0.0
	var phase := 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or intensity <= 0:
			set_process(false)
			return
		phase = fposmod(phase + delta * (0.25 + intensity), 1.0)
		queue_redraw()

	func _draw() -> void:
		if intensity <= 0 or size.x <= 0:
			return
		var line_y := size.y * 0.5
		draw_line(Vector2(0,line_y),Vector2(size.x,line_y),Color(0.15,0.44,0.50,0.10 * intensity),14)
		for index in 4:
			var x := fposmod(phase + float(index) / 4.0,1.0) * size.x
			draw_line(Vector2(x,line_y-16),Vector2(minf(x+24,size.x),line_y+16),Color(0.15,0.44,0.50,0.30 * intensity),3)

var scene: Node2D
var panel: Panel
var heading_label: Label
var heading_icon: TextureRect
var scroll: ScrollContainer
var content: VBoxContainer
var status_grid: GridContainer
var balance_label: Label
var reserve_bar: ProgressBar
var multiplier_label: Label
var current_label: Label
var endurance_label: Label
var limit_label: Label
var speed_slider: HSlider
var marker_strip: Control
var flow: EnergyFlow
var speed_buttons: Array[Button] = []
var options: Array[Dictionary] = []
var selected_speed := -1.0
var selected_index := -1
var idle_style: StyleBoxFlat
var active_style: StyleBoxFlat
var idle_hover_style: StyleBoxFlat
var active_hover_style: StyleBoxFlat
var idle_pressed_style: StyleBoxFlat
var active_pressed_style: StyleBoxFlat
var reserve_content: VBoxContainer
var speed_content: VBoxContainer
var slider_section: VBoxContainer
var reserve_frame: PanelContainer
var speed_frame: PanelContainer
var slider_frame: PanelContainer

func setup(owner: Node2D) -> void:
	scene = owner
	options = scene.game.chrono_options()
	panel = Panel.new()
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel",panel_style(PAPER,NAVY))
	add_child(panel)
	heading_icon = TextureRect.new()
	heading_icon.texture = PARTICLE
	heading_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heading_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading_icon.position = Vector2(30,22)
	heading_icon.size = Vector2(48,48)
	heading_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading_icon)
	heading_label = make_label(panel,34,NAVY)
	heading_label.text = UIText.t("chrono.engine")
	heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_label.position = Vector2(92,24)
	heading_label.anchor_right = 1
	heading_label.offset_right = -38
	heading_label.offset_bottom = 76
	scroll = ScrollContainer.new()
	scroll.anchor_right = 1
	scroll.anchor_bottom = 1
	scroll.offset_left = 38
	scroll.offset_top = 100
	scroll.offset_right = -38
	scroll.offset_bottom = -28
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",26)
	scroll.add_child(content)
	status_grid = GridContainer.new()
	status_grid.columns = 2
	status_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_grid.add_theme_constant_override("h_separation",20)
	status_grid.add_theme_constant_override("v_separation",18)
	content.add_child(status_grid)
	reserve_frame = section_frame(status_grid,NAVY)
	reserve_content = section_body(reserve_frame)
	var reserve_header := HBoxContainer.new()
	reserve_header.add_theme_constant_override("separation",12)
	reserve_content.add_child(reserve_header)
	var reserve_icon := TextureRect.new()
	reserve_icon.texture = PARTICLE
	reserve_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reserve_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reserve_icon.custom_minimum_size = Vector2(42,42)
	reserve_header.add_child(reserve_icon)
	var reserve_title := make_label(reserve_header,24,PAPER)
	reserve_title.text = UIText.t("chrono.reserve")
	reserve_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_label = make_label(reserve_content,54,PAPER)
	balance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reserve_bar = ProgressBar.new()
	reserve_bar.custom_minimum_size.y = 22
	reserve_bar.show_percentage = false
	reserve_bar.add_theme_stylebox_override("background",panel_style(Color("182e3d"),Color("65838b")))
	var fill := panel_style(TEAL,TEAL)
	fill.set_border_width_all(0)
	reserve_bar.add_theme_stylebox_override("fill",fill)
	reserve_content.add_child(reserve_bar)
	speed_frame = section_frame(status_grid,Color("d2e6e1"))
	speed_content = section_body(speed_frame)
	var speed_title := make_label(speed_content,24,NAVY)
	speed_title.text = UIText.t("chrono.speed")
	multiplier_label = make_label(speed_content,82,NAVY)
	current_label = make_label(speed_content,26,NAVY)
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slider_frame = section_frame(content,Color("f6f4e8"))
	slider_section = section_body(slider_frame)
	var slider_title := make_label(slider_section,26,NAVY)
	slider_title.text = UIText.t("chrono.slider")
	var slider_area := Control.new()
	slider_area.custom_minimum_size.y = 76
	slider_section.add_child(slider_area)
	flow = EnergyFlow.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.set_process(false)
	slider_area.add_child(flow)
	speed_slider = HSlider.new()
	speed_slider.min_value = 0
	speed_slider.max_value = maxi(0,options.size()-1)
	speed_slider.step = 1
	speed_slider.tick_count = options.size()
	speed_slider.ticks_on_borders = true
	speed_slider.focus_mode = Control.FOCUS_ALL
	var rail := panel_style(Color("b5c7c4"),NAVY)
	rail.set_content_margin_all(7)
	rail.set_border_width_all(2)
	speed_slider.add_theme_stylebox_override("slider",rail)
	var filled_rail := panel_style(TEAL,NAVY)
	filled_rail.set_content_margin_all(7)
	speed_slider.add_theme_stylebox_override("grabber_area",filled_rail)
	speed_slider.add_theme_stylebox_override("grabber_area_highlight",filled_rail)
	speed_slider.add_theme_icon_override("grabber",preload("res://assets/chrono/slider_grabber.svg"))
	speed_slider.add_theme_icon_override("grabber_highlight",preload("res://assets/chrono/slider_grabber_hover.svg"))
	speed_slider.add_theme_icon_override("grabber_disabled",preload("res://assets/chrono/slider_grabber.svg"))
	speed_slider.add_theme_icon_override("tick",preload("res://assets/chrono/slider_tick.svg"))
	speed_slider.value_changed.connect(select_index)
	slider_area.add_child(speed_slider)
	slider_area.resized.connect(func():
		var edge := maxf(0,slider_area.size.x / maxf(2,options.size()*2) - 16)
		var width := maxf(0,slider_area.size.x-edge*2)
		for control in [flow,speed_slider]:
			control.position = Vector2(edge,12)
			control.size = Vector2(width,48))
	marker_strip = Control.new()
	marker_strip.custom_minimum_size.y = 58
	slider_section.add_child(marker_strip)
	marker_strip.resized.connect(layout_markers)
	idle_style = panel_style(PAPER,NAVY)
	active_style = panel_style(TEAL,NAVY)
	idle_hover_style = panel_style(Color("fffdf0"),Color("519caa"))
	active_hover_style = panel_style(TEAL.lightened(0.12),NAVY)
	idle_pressed_style = panel_style(Color("d8e6de"),NAVY)
	active_pressed_style = panel_style(TEAL.darkened(0.12),NAVY)
	for option in options:
		var index := speed_buttons.size()
		var button := Button.new()
		button.clip_text = true
		button.add_theme_font_override("font",scene.font)
		button.add_theme_font_size_override("font_size",26)
		button.add_theme_stylebox_override("disabled",panel_style(Color("ced3cc"),Color("93a4a3")))
		var focus_style := panel_style(Color.TRANSPARENT,Color("438b98"))
		focus_style.set_border_width_all(4)
		button.add_theme_stylebox_override("focus",focus_style)
		for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
			button.add_theme_color_override(state,NAVY)
		button.add_theme_color_override("font_disabled_color",Color("66797a"))
		button.text = UIText.t("chrono.multiplier",{"multiplier":format_number(float(option.multiplier))})
		button.tooltip_text = UIText.t("chrono.option",{"multiplier":format_number(float(option.multiplier)),"cost":format_number(float(option.cost))})
		button.pressed.connect(func():select_index(index))
		marker_strip.add_child(button)
		speed_buttons.append(button)
	var endurance_frame := section_frame(content,NAVY)
	var endurance_body := section_body(endurance_frame)
	endurance_label = make_label(endurance_body,26,PAPER)
	endurance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limit_label = make_label(content,22,MUTED)
	limit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limit_label.text = UIText.t("chrono.limit",{"hours":format_number(float(scene.db.config.offlineMax))})
	scroll.resized.connect(layout_content)
	panel.resized.connect(layout_shell)
	visibility_changed.connect(update_flow_activity)
	call_deferred("layout_shell")
	refresh()

func make_label(parent: Control, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.add_theme_font_override("font",scene.font)
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	parent.add_child(result)
	return result

func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(3)
	result.set_corner_radius_all(14)
	return result

func section_frame(parent: Control, fill: Color) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := panel_style(fill,NAVY)
	style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel",style)
	parent.add_child(frame)
	return frame

func section_body(frame: PanelContainer) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	frame.add_child(body)
	return body

func format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value,roundf(value)) else str(value)

func layout_shell() -> void:
	if not is_instance_valid(scroll):
		return
	var narrow := panel.size.x < 650
	var margin := 20 if narrow else 38
	heading_icon.position.x = margin
	heading_label.offset_left = margin+56
	heading_label.offset_right = -margin
	heading_label.add_theme_font_size_override("font_size",19 if panel.size.x < 330 else 23 if panel.size.x < 390 else 28 if narrow else 34)
	scroll.offset_top = 112 if narrow else 100
	scroll.offset_left = margin
	scroll.offset_right = -margin
	layout_content()

func layout_content() -> void:
	if not is_instance_valid(scroll):
		return
	var narrow := scroll.size.x < 850
	var short := scroll.size.y < 620
	status_grid.columns = 1 if narrow else 2
	status_grid.add_theme_constant_override("v_separation",14 if narrow and short else 32)
	content.add_theme_constant_override("separation",14 if short else 26)
	reserve_content.add_theme_constant_override("separation",8 if short else 12)
	speed_content.add_theme_constant_override("separation",6 if short else 12)
	balance_label.add_theme_font_size_override("font_size",48 if narrow else 54)
	multiplier_label.add_theme_font_size_override("font_size",64 if narrow and short else 82)
	for frame in [reserve_frame,speed_frame,slider_frame]:
		var style: StyleBoxFlat = frame.get_theme_stylebox("panel")
		style.set_content_margin_all(12 if scroll.size.x < 390 else 22)
	slider_section.add_theme_constant_override("separation",8 if short else 16)
	layout_markers()

func layout_markers() -> void:
	var count := speed_buttons.size()
	if count == 0 or marker_strip.size.x <= 0:
		return
	# Keep every multiplier readable in narrow panels, without changing slider stops.
	var columns := count if marker_strip.size.x >= 540 else mini(count,5)
	var rows := ceili(float(count) / columns)
	var spacing := marker_strip.size.x / columns
	var width := minf(96,maxf(24,spacing-8))
	var height := rows * 64.0
	if marker_strip.custom_minimum_size.y != height:
		marker_strip.custom_minimum_size.y = height
	for index in count:
		var button := speed_buttons[index]
		button.position = Vector2((index % columns) * spacing + (spacing-width)*0.5,(index / columns)*64)
		button.size = Vector2(width,56)
		button.add_theme_font_size_override("font_size",16 if width < 50 else 26)
		button.text = UIText.t("chrono.multiplier",{"multiplier":format_number(float(options[index].multiplier))})

func select_index(value: float) -> void:
	var index := clampi(roundi(value),0,options.size()-1)
	if not scene.game.set_speed(float(options[index].multiplier)):
		speed_slider.set_value_no_signal(maxi(0,selected_index))
		return
	refresh()

func update_flow_activity() -> void:
	if not is_instance_valid(flow):
		return
	var active: bool = is_visible_in_tree() and flow.intensity > 0 and not scene.game.paused
	if flow.is_processing() != active:
		flow.set_process(active)
		if not active:flow.queue_redraw()

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var game: BattleGame = scene.game
	var particles := float(game.profile.chronoParticles)
	var capacity := game.chrono_capacity()
	var balance := UIText.t("chrono.balance",{"amount":str(int(floorf(particles)))})
	if balance_label.text != balance:balance_label.text = balance
	if reserve_bar.max_value != maxf(1,capacity):reserve_bar.max_value = maxf(1,capacity)
	if reserve_bar.value != particles:reserve_bar.value = particles
	var index := 0
	for option_index in options.size():
		if is_equal_approx(float(options[option_index].multiplier),game.speed):
			index = option_index
			break
	var cost := float(options[index].cost)
	var multiplier := format_number(game.speed)
	var large := UIText.t("chrono.multiplier",{"multiplier":multiplier})
	if multiplier_label.text != large:multiplier_label.text = large
	var current := UIText.t("chrono.current",{"multiplier":multiplier,"cost":format_number(cost)})
	if current_label.text != current:current_label.text = current
	var duration := UIText.t("chrono.endurance_free") if cost <= 0 else UIText.t("chrono.endurance",{"time":format_duration(particles / cost)})
	if endurance_label.text != duration:endurance_label.text = duration
	if selected_index != index:
		selected_index = index
		selected_speed = game.speed
		speed_slider.set_value_no_signal(index)
		for option_index in speed_buttons.size():
			var button := speed_buttons[option_index]
			button.add_theme_stylebox_override("normal",active_style if option_index == index else idle_style)
			button.add_theme_stylebox_override("hover",active_hover_style if option_index == index else idle_hover_style)
			button.add_theme_stylebox_override("pressed",active_pressed_style if option_index == index else idle_pressed_style)
		flow.intensity = maxf(0,float(index) / maxf(1,options.size()-1) - 0.55) / 0.45
		flow.queue_redraw()
	for option_index in speed_buttons.size():
		var disabled := float(options[option_index].cost) > 0 and particles <= 0
		if speed_buttons[option_index].disabled != disabled:speed_buttons[option_index].disabled = disabled
	update_flow_activity()

func format_duration(seconds: float) -> String:
	var whole := maxi(0,int(floorf(seconds)))
	return "%02d:%02d:%02d" % [whole / 3600,(whole / 60) % 60,whole % 60]

