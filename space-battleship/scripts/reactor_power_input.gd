extends Control

var slider: HSlider
var track: Control
var capacity := 1
var available_max := 0
var dragging := false
var value_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():track.set_hovered(true))
	mouse_exited.connect(_on_mouse_exited)
	value_label = Label.new()
	value_label.size = Vector2(72,30)
	value_label.position.y = -16
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.mouse_filter = MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size",20)
	value_label.add_theme_color_override("font_color",Color.WHITE)
	value_label.add_theme_color_override("font_outline_color",Color("041522"))
	value_label.add_theme_constant_override("outline_size",4)
	value_label.hide()
	add_child(value_label)
	set_process_input(false)

func _on_mouse_exited() -> void:
	if not dragging:track.set_hovered(false)

func _gui_input(event: InputEvent) -> void:
	if not slider.editable:return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			value_label.show()
			set_process_input(true)
			slider.grab_focus()
			track.flash_click()
			apply_pointer(event.position.x)
			accept_event()
		elif dragging:
			finish_drag(event.position.x)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		apply_pointer(event.position.x)
		accept_event()

func _input(event: InputEvent) -> void:
	if not dragging:return
	if event is InputEventMouseMotion:
		apply_pointer((get_global_transform().affine_inverse()*event.global_position).x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_drag((get_global_transform().affine_inverse()*event.global_position).x)
		get_viewport().set_input_as_handled()

func apply_pointer(local_x: float) -> void:
	var fraction := clampf(local_x/maxf(size.x,1.0),0.0,1.0)
	var continuous := minf(fraction*float(capacity),float(available_max))
	var value := mini(roundi(fraction*float(capacity)),available_max)
	track.set_preview_ratio(continuous/maxf(float(capacity),1.0))
	value_label.text = str(value) if value < 1000000 else NumberFormat.compact(value)
	value_label.position.x = clampf(continuous/maxf(float(capacity),1.0)*size.x-value_label.size.x*0.5,0.0,size.x-value_label.size.x)
	slider.value = value

func finish_drag(local_x: float) -> void:
	apply_pointer(local_x)
	dragging = false
	set_process_input(false)
	track.set_preview_ratio(-1.0)
	value_label.hide()
	track.set_hovered(get_global_rect().has_point(get_global_mouse_position()))
