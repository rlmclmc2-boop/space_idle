extends Control
## Owner-driven overlay: no independent timer, tween, or shared-parent redraw.
var age := 10.0
var duration := 1.2
var accent := Color("83d5c4")
var border := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.set_border_width_all(2)
	border.set_corner_radius_all(5)
	hide()

func trigger(color: Color, seconds: float = 1.2) -> void:
	accent = color
	duration = seconds
	age = 0.0
	show()
	queue_redraw()

func clear() -> void:
	age = duration
	if visible:hide()

func advance(delta: float, paused: bool) -> void:
	if paused or delta <= 0.0 or not visible or not is_visible_in_tree():return
	age = minf(duration, age + delta)
	if age >= duration:
		hide()
		return
	queue_redraw()

func _draw() -> void:
	var p := clampf(age / duration, 0.0, 1.0)
	var strength := (1.0 - p) * (1.0 - p)
	border.bg_color = Color(accent, strength * 0.06)
	border.border_color = Color(accent, strength * 0.8)
	draw_style_box(border, Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0))
	var y := lerpf(8.0, size.y - 8.0, smoothstep(0.0, 1.0, p))
	draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(accent, strength * 0.22), 2.0, true)
