extends RefCounted
## Draw-only top-strip projection. Values and receipts arrive already formatted.
const SHELL := preload("res://scripts/shell_presentation.gd")
const ART := preload("res://scripts/resource_art.gd")
const LEFT := 65.0
const WIDTH := 420.0
const GAP := 8.0

static func card_rect(index: int, count: int) -> Rect2:
	var width := (WIDTH-GAP*float(count-1))/float(count)
	return Rect2(LEFT+float(index)*(width+GAP),3,width,72)

static func fitted_size(value: String, max_width: float, upper: int, lower: int) -> int:
	for size in range(upper,lower-1,-1):
		if SHELL.face(700).get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=max_width:return size
	return lower

static func draw_resource(canvas: CanvasItem, index: int, count: int, id: String, caption: String, value: String, increment: String = "") -> void:
	var rect := card_rect(index,count)
	canvas.draw_style_box(SHELL.surface(SHELL.PAPER),rect)
	ART.draw_icon(canvas,id,rect.position+Vector2(19,16),23.0)
	canvas.draw_string(SHELL.face(600),rect.position+Vector2(36,22),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,19 if count==2 else 17,SHELL.NAVY)
	canvas.draw_string(SHELL.face(700),rect.position+Vector2(11,48),value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted_size(value,rect.size.x-22.0,24,13),SHELL.NAVY)
	if not increment.is_empty():
		var size := fitted_size(increment,rect.size.x-22.0,15,10)
		canvas.draw_string(SHELL.face(700),rect.position+Vector2(11,66),increment,HORIZONTAL_ALIGNMENT_LEFT,-1,size,ART.accent(id))
		canvas.draw_rect(Rect2(rect.position+Vector2(4,69),Vector2(rect.size.x-8,2)),Color(ART.accent(id),0.7))
