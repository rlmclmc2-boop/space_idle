extends Panel

signal swap_requested(source: int, target: int)

var slot_index := 0
var tech_key := ""
var drop_highlight := false

func _ready() -> void:
	mouse_exited.connect(func():drop_highlight=false;queue_redraw())

func _get_drag_data(_position: Vector2):
	if tech_key.is_empty():
		return null
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel",get_theme_stylebox("panel").duplicate())
	preview.modulate.a = 0.9
	var label := Label.new()
	label.text = "  " + tech_key + "  ·  松手换位  "
	label.add_theme_font_override("font",get_theme_font("font"))
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color("71e5f4"))
	preview.add_child(label)
	set_drag_preview(preview)
	return {"kind":"hightech_slot","container":get_parent().get_instance_id(),"source":slot_index}

func _can_drop_data(_position: Vector2, data) -> bool:
	drop_highlight = data is Dictionary and data.get("kind") == "hightech_slot" and data.get("container") == get_parent().get_instance_id() and data.get("source") is int and int(data.source) != slot_index
	queue_redraw()
	return drop_highlight

func _drop_data(position: Vector2, data) -> void:
	if _can_drop_data(position,data):
		swap_requested.emit(int(data.source),slot_index)
	drop_highlight = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drop_highlight = false
		queue_redraw()

func _draw() -> void:
	if drop_highlight:
		draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("71e5f4"),false,2)
