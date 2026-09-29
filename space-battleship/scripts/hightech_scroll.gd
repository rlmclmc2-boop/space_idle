extends ScrollContainer
## The hall browses whole two-station rows. No animation or partial-row resting position.
var row_stride := 438
var snapping := false
var pan_distance := 0.0

func _ready() -> void:
	get_v_scroll_bar().custom_step=row_stride
	get_v_scroll_bar().value_changed.connect(snap_to_row)

func snap_to_row(_value := 0.0) -> void:
	if snapping:return
	var bar := get_v_scroll_bar()
	var limit := maxi(0,int(bar.max_value-bar.page))
	var target := clampi(roundi(float(scroll_vertical)/row_stride)*row_stride,0,limit)
	if target==scroll_vertical:return
	snapping=true
	scroll_vertical=target
	snapping=false

func move_row(direction: int) -> void:
	scroll_vertical+=direction*row_stride
	snap_to_row()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not get_global_rect().has_point(get_global_mouse_position()):return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			move_row(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		pan_distance+=event.delta.y
		if absf(pan_distance)>=1.0:
			move_row(1 if pan_distance>0 else -1)
			pan_distance=0.0
		get_viewport().set_input_as_handled()
