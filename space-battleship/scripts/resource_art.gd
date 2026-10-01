extends RefCounted
## One resource silhouette for drops, pickup flights and UI balances.
const IRON := preload("res://assets/resources/iron.svg")
const URANIUM := preload("res://assets/resources/uranium.svg")
const FRAGMENT := preload("res://assets/resources/fragment.svg")

static func texture(id: String) -> Texture2D:
	match id:
		"1":return IRON
		"2":return URANIUM
		"jewel":return FRAGMENT
	return null

static func accent(id: String) -> Color:
	match id:
		"1":return Color("edba78")
		"2":return Color("b3a0e4")
	return Color("83cfcb")

static func draw_icon(canvas: CanvasItem, id: String, center: Vector2, extent: float, alpha := 1.0) -> void:
	var icon := texture(id)
	if icon!=null:
		canvas.draw_texture_rect(icon,Rect2(center-Vector2.ONE*extent*0.5,Vector2.ONE*extent),false,Color(1,1,1,alpha))

static func draw_drop(canvas: CanvasItem, drop: Dictionary, center: Vector2, time: float) -> void:
	var id := "jewel" if drop.has("jewel") else str(drop.id)
	var color := accent(id)
	var age := float(drop.age)
	var furnace: bool = drop.get("hightech",false)
	var generated: bool = drop.get("auto_gen",false)
	var bob := sin(time*3.0+float(drop.uid))*2.0
	# Spawn motion begins at the existing visibility threshold. Pickup anchors
	# stay untouched; this small displacement is decorative only.
	var reveal := clampf((age-(0.0 if furnace or generated else 0.5))/0.18,0.0,1.0)
	var point := center+Vector2(0,bob-(1.0-reveal)*5.0)
	var extent := (42.0 if furnace else (38.0 if generated else 32.0))*lerpf(0.75,1.0,reveal)
	if furnace:
		# Retain the ten-second source timer, without a large opaque backplate.
		canvas.draw_arc(point,24.0,-PI/2,-PI/2+TAU*clampf(1.0-age/10.0,0,1),24,Color(color,0.6),1.5,true)
	elif generated:
		canvas.draw_line(point-Vector2(0,19),point-Vector2(0,37),Color(color,0.3),2.0,true)
	draw_icon(canvas,id,point,extent)
