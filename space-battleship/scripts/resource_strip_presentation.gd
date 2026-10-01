extends RefCounted
## Draw-only top-strip projection. Values arrive already formatted by the host.
const SHELL := preload("res://scripts/shell_presentation.gd")
const ICONS := [preload("res://assets/ui/shell/iron.svg"),preload("res://assets/ui/shell/uranium.svg")]
const RECTS := [Rect2(65,9,205,60),Rect2(280,9,205,60)]
const VALUE_WIDTH := 181.0

static func value_size(value: String) -> int:
	# Fit the complete value, including units, at the same weight and contrast.
	for size in [24,23,22,21]:
		if SHELL.face(700).get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=VALUE_WIDTH:return size
	return 20

static func draw_resource(canvas: CanvasItem, index: int, caption: String, value: String) -> void:
	var rect: Rect2=RECTS[index]
	canvas.draw_style_box(SHELL.surface(SHELL.PAPER),rect)
	canvas.draw_texture_rect(ICONS[index],Rect2(rect.position+Vector2(9,5),Vector2(27,27)),false)
	canvas.draw_string(SHELL.face(600),rect.position+Vector2(42,22),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20,SHELL.NAVY)
	canvas.draw_string(SHELL.face(700),rect.position+Vector2(12,49),value,HORIZONTAL_ALIGNMENT_LEFT,-1,value_size(value),SHELL.NAVY)
