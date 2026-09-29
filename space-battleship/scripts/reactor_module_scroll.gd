extends ScrollContainer

var bay_height := 220
const VISIBLE_BAYS := 3

var module_count := 0
var touch_start_y := 0.0
var touch_start_slot := 0
var touch_dragged := false

func max_slot() -> int:
	return maxi(0,module_count-VISIBLE_BAYS)

func current_slot() -> int:
	return clampi(roundi(float(scroll_vertical)/bay_height),0,max_slot())

func go_to_slot(slot: int) -> void:
	scroll_vertical = clampi(slot,0,max_slot())*bay_height

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if Rect2(Vector2.ZERO,size).has_point(point):
			go_to_slot(current_slot() + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventPanGesture and absf(event.delta.y) > 0.05:
		go_to_slot(current_slot() + (1 if event.delta.y > 0.0 else -1))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_start_y = event.position.y
			touch_start_slot = current_slot()
			touch_dragged = false
		else:
			if touch_dragged:
				var direction := 1 if event.position.y < touch_start_y else -1
				go_to_slot(touch_start_slot+direction*maxi(1,roundi(absf(event.position.y-touch_start_y)/bay_height)))
			else:go_to_slot(current_slot())
	elif event is InputEventScreenDrag:
		if absf(event.position.y-touch_start_y) > 16.0:touch_dragged = true
