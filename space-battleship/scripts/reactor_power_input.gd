extends Control

var slider: HSlider
var track: Control
signal allocation_requested(value)
const I=preload("res://scripts/reactor_integer.gd")
var capacity = 1
var available_max = 0
var dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():track.set_hovered(true))
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(false)

func _on_mouse_exited() -> void:
	if not dragging:track.set_hovered(false)

func _gui_input(event: InputEvent) -> void:
	if not slider.editable:return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
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
	if slider.get_meta("reactor_normalized",false):
		var value=I.minimum(I.share(capacity,roundi(fraction*1000000000),1000000000)[0],available_max)
		var ratio:=I.ratio(value,capacity)
		track.set_preview_ratio(minf(fraction,I.ratio(available_max,capacity)))
		slider.set_value_no_signal(ratio)
		allocation_requested.emit(value)
	else:
		var continuous := minf(fraction*float(capacity),float(available_max))
		var value := mini(roundi(fraction*float(capacity)),int(available_max))
		track.set_preview_ratio(continuous/maxf(float(capacity),1.0))
		slider.value = value

func finish_drag(local_x: float) -> void:
	apply_pointer(local_x)
	dragging = false
	set_process_input(false)
	track.set_preview_ratio(-1.0)
	track.set_hovered(get_global_rect().has_point(get_global_mouse_position()))
