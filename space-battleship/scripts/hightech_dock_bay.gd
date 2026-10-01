extends Control
## Persistent workstation chrome; machine art and assembly geometry stay independent.
const PRESENTATION := preload("res://scripts/hightech_presentation.gd")
var accent := Color("67dcec")
var selected := false
var pending := false
var frame: StyleBoxFlat
var readout: StyleBoxFlat

func _ready() -> void:
	frame=PRESENTATION.station_surface()
	readout=PRESENTATION.surface("readout")

func _draw() -> void:
	if frame==null:return
	draw_style_box(frame,Rect2(Vector2(4,4),size-Vector2(8,8)))
	draw_style_box(readout,Rect2(16,304,size.x-32,136))
	if has_focus():draw_rect(Rect2(Vector2(9,9),size-Vector2(18,18)),PRESENTATION.TEAL,false,2)

func update_frame() -> void:
	if frame==null:return
	frame.bg_color=Color("203442") if pending else Color("304c60")
	frame.border_color=PRESENTATION.TEAL if selected else PRESENTATION.NAVY
	frame.set_border_width_all(5 if selected else 3)
	queue_redraw()

func set_pending(value: bool) -> void:
	if pending==value:return
	pending=value
	update_frame()

func set_selected(value: bool) -> void:
	if selected==value:return
	selected=value
	update_frame()

func _notification(what: int) -> void:
	if what==NOTIFICATION_FOCUS_ENTER or what==NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
