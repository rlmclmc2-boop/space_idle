extends Control
## Bounded, code-drawn first-generation factory art. No imported image or render target.

const NAVY := Color("122737")
const STEEL := Color("426477")
const FACE := Color("a8bdc5")
const WHITE := Color("d9e5e3")
const EDGE := Color("102634")
const CYAN := Color("80d9d0")
const GLOW := Color("9af2df")
const COPPER := Color("dfa96b")
const SHADOW := Color("0b1a28")

var technology_id := "weapon_accuracy"
var level := 0
var researching := false
var progress := 0.0
var icon_mode := false
var phase := 0.0

func set_display(id: String, current_level: int, is_researching: bool, fraction: float, as_icon := false) -> void:
	technology_id = id
	level = max(0, current_level)
	researching = is_researching
	progress = clampf(fraction, 0.0, 1.0)
	icon_mode = as_icon
	set_process(is_visible_in_tree() and researching and not icon_mode)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree() and researching and not icon_mode)

func _process(delta: float) -> void:
	phase = fmod(phase + minf(delta, 0.05) * 1.9, TAU)
	queue_redraw()

func _plate(rect: Rect2, fill: Color, border := EDGE, width := 3.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, border, false, width)

func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], EDGE, 3.0, true)

func _disk(center: Vector2, radius: float, fill: Color, border := EDGE) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0, TAU, 32, border, 3.0, true)

func _beam(a: Vector2, b: Vector2, color := STEEL, width := 9.0) -> void:
	draw_line(a, b, EDGE, width + 4.0, true)
	draw_line(a, b, color, width, true)

func _draw() -> void:
	if not icon_mode:
		_draw_room()
	var unit := minf(size.x / (90.0 if icon_mode else 560.0), size.y / (88.0 if icon_mode else 425.0))
	var center := size * (Vector2(0.5, 0.5) if icon_mode else Vector2(0.5, 0.52))
	draw_set_transform(center, 0.0, Vector2.ONE * unit)
	_draw_machine()
	draw_set_transform(Vector2.ZERO)

func _draw_room() -> void:
	_plate(Rect2(Vector2.ZERO, size), NAVY, STEEL, 2.0)
	var horizon := size.y * 0.69
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, horizon), Vector2(size.x - 3, horizon),
		Vector2(size.x - 3, size.y - 3), Vector2(3, size.y - 3)
	]), Color("193343"))
	for i in 7:
		var x := (float(i) + 0.5) * size.x / 7.0
		draw_line(Vector2(x, horizon), Vector2(x + (x - size.x * 0.5) * 0.3, size.y), STEEL.darkened(0.4), 2.0)
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), CYAN.darkened(0.43), 3.0)
	for i in 4:
		var x := (float(i) + 0.5) * size.x / 4.0
		_plate(Rect2(x - 37, 28, 74, 124), Color("233f50"), STEEL)
		_plate(Rect2(x - 24, 49, 48, 47), CYAN.darkened(0.65), CYAN.darkened(0.4), 2.0)
	# The assembly gantry is one bounded moving object.
	var motion := sin(phase) * 20.0 if researching else 0.0
	_beam(Vector2(size.x * 0.25, 43), Vector2(size.x * 0.75, 43), FACE, 15)
	_plate(Rect2(size.x * 0.5 - 42 + motion, 24, 84, 38), WHITE)
	_beam(Vector2(size.x * 0.5 + motion, 62), Vector2(size.x * 0.5 + motion, 122), FACE, 13)
	_poly(PackedVector2Array([
		Vector2(size.x * 0.5 - 30 + motion, 121),
		Vector2(size.x * 0.5 + 30 + motion, 121),
		Vector2(size.x * 0.5 + 19 + motion, 143),
		Vector2(size.x * 0.5 - 19 + motion, 143)
	]), COPPER)

func _draw_machine() -> void:
	# Every technology uses the same oblique front view, shell material, edge and light.
	_poly(PackedVector2Array([
		Vector2(-205, 135), Vector2(150, 135), Vector2(205, 179),
		Vector2(-145, 179)
	]), SHADOW)
	_plate(Rect2(-188, 114, 375, 33), STEEL)
	_plate(Rect2(-165, 75, 330, 43), FACE)
	for x in [-130.0, 130.0]:
		_plate(Rect2(x - 12, 118, 24, 31), COPPER)
	# Refit marks persist through ten levels without swapping the generation model.
	var fittings := mini(level % 10, 4)
	for i in fittings:
		_plate(Rect2(-137 + i * 23, 87, 16, 13), CYAN, EDGE, 2.0)
	match technology_id:
		"weapon_accuracy": _draw_weapon()
		"equipment_reinforcement": _draw_armor()
		"resource_refining": _draw_refinery()
		"fragment_condensation": _draw_condenser()
		"equipment_precision": _draw_precision()
		"uranium_extraction": _draw_uranium()
		"joint_integration": _draw_integration()
		"ai_singularity": _draw_ai()
		_: _draw_ai()

func _draw_weapon() -> void:
	_plate(Rect2(-93, 15, 186, 68), WHITE)
	_poly(PackedVector2Array([Vector2(-154, -13), Vector2(125, -13), Vector2(150, 4), Vector2(-132, 4)]), FACE)
	_plate(Rect2(-155, -8, 309, 34), STEEL)
	_plate(Rect2(-43, -41, 85, 31), FACE)
	_disk(Vector2(1, -43), 15, CYAN)
	_disk(Vector2(126, 8), 16, COPPER)
	var target := Vector2(-144 + (sin(phase * 1.4) * 29 if researching else 0.0), -28)
	draw_arc(target, 26, 0, TAU, 32, CYAN, 3.0)
	_beam(target + Vector2(-34, 0), target + Vector2(34, 0), CYAN, 2.0)
	_beam(target + Vector2(0, -34), target + Vector2(0, 34), CYAN, 2.0)

func _draw_armor() -> void:
	_plate(Rect2(-113, -28, 226, 99), STEEL)
	_poly(PackedVector2Array([Vector2(-68, -3), Vector2(71, -3), Vector2(92, 20), Vector2(66, 60), Vector2(-67, 60), Vector2(-91, 20)]), WHITE)
	for side in [-1.0, 1.0]:
		var x := side * 128
		_plate(Rect2(x - 22, -81, 44, 120), FACE)
		_beam(Vector2(x, -77), Vector2(x, -8), COPPER, 13)
		var press := (6.0 + 4.0 * sin(phase * 2.0)) if researching else 4.0
		_plate(Rect2(x - 38, -10 + press, 76, 23), COPPER)
	_beam(Vector2(-148, -84), Vector2(148, -84), FACE, 13)

func _draw_refinery() -> void:
	_plate(Rect2(-97, -67, 194, 138), WHITE)
	_plate(Rect2(-75, -42, 150, 73), STEEL)
	_poly(PackedVector2Array([Vector2(-42, 10), Vector2(39, 10), Vector2(23, 47), Vector2(-25, 47)]), COPPER)
	for side in [-1.0, 1.0]:
		_beam(Vector2(side * 102, -40), Vector2(side * 155, 43), FACE, 14)
		_plate(Rect2(side * 128 - 23, 42, 46, 26), CYAN.darkened(0.33))
	var pour := 23 + (12.0 * (sin(phase) + 1.0) if researching else 0.0)
	_beam(Vector2(0, -30), Vector2(0, -30 + pour), CYAN, 8)

func _draw_condenser() -> void:
	_plate(Rect2(-110, -63, 220, 130), FACE)
	_plate(Rect2(-92, -47, 184, 92), STEEL)
	# The crystal is a contained product, not the machine silhouette.
	draw_arc(Vector2(0, -1), 63, 0, TAU, 48, COPPER, 15.0)
	draw_arc(Vector2(0, -1), 64, 0, TAU, 48, EDGE, 3.0)
	for side in [-1.0, 1.0]:
		_plate(Rect2(side * 125 - 18, -47, 36, 94), WHITE)
		_beam(Vector2(side * 113, -16), Vector2(side * 68, -1), CYAN, 9)
	var pulse := 1.0 + (0.08 * sin(phase * 2.0) if researching else 0.0)
	_poly(PackedVector2Array([Vector2(0, -37) * pulse, Vector2(27, -2) * pulse,
		Vector2(0, 36) * pulse, Vector2(-27, -2) * pulse]), GLOW)

func _draw_precision() -> void:
	_plate(Rect2(-113, -52, 226, 116), FACE)
	_plate(Rect2(-88, -33, 176, 75), STEEL)
	_plate(Rect2(-58, 12, 116, 25), WHITE)
	for side in [-1.0, 1.0]:
		_beam(Vector2(side * 133, -72), Vector2(side * 97, -18), FACE, 18)
		_beam(Vector2(side * 97, -18), Vector2(side * 51, 1), COPPER, 15)
	var tool_y := 14.0 + (sin(phase * 2.0) * 7.0 if researching else 0.0)
	_poly(PackedVector2Array([Vector2(-17, tool_y), Vector2(17, tool_y),
		Vector2(8, tool_y + 23), Vector2(-8, tool_y + 23)]), CYAN)

func _draw_uranium() -> void:
	_plate(Rect2(-132, -59, 264, 125), FACE)
	_disk(Vector2(0, -2), 78, STEEL)
	_disk(Vector2(0, -2), 57, SHADOW)
	for i in 3:
		var a := TAU * float(i) / 3.0 + (phase if researching else 0.0)
		var center := Vector2(cos(a), sin(a)) * 39
		_poly(PackedVector2Array([center + Vector2(-15, -11), center + Vector2(16, -11),
			center + Vector2(12, 13), center + Vector2(-12, 13)]), COPPER)
	_disk(Vector2(0, -2), 18, CYAN)
	_plate(Rect2(-128, 44, 45, 23), WHITE)
	_plate(Rect2(83, 44, 45, 23), WHITE)

func _draw_integration() -> void:
	_plate(Rect2(-135, -60, 270, 125), WHITE)
	_plate(Rect2(-112, -41, 224, 84), STEEL)
	for side in [-1.0, 1.0]:
		_disk(Vector2(side * 62, 0), 39, FACE)
		_disk(Vector2(side * 62, 0), 25, CYAN.darkened(0.32))
		_beam(Vector2(side * 62, -42), Vector2(side * 62, -86), COPPER, 12)
	var bridge := 8.0 + (sin(phase) * 3.0 if researching else 0.0)
	_beam(Vector2(-32, bridge), Vector2(32, bridge), GLOW, 12)
	_disk(Vector2(0, bridge), 18, COPPER)

func _draw_ai() -> void:
	_plate(Rect2(-106, -70, 212, 140), WHITE)
	_plate(Rect2(-80, -47, 160, 95), STEEL)
	for side in [-1.0, 1.0]:
		for y in [-47.0, -14.0, 19.0]:
			_plate(Rect2(side * 116 - 10, y, 20, 22), COPPER, EDGE, 2.0)
	_disk(Vector2.ZERO, 38, SHADOW)
	_disk(Vector2.ZERO, 23, CYAN)
	var orbit := Vector2(cos(phase), sin(phase)) * 53.0 if researching else Vector2(0, -53)
	draw_arc(Vector2.ZERO, 54, 0, TAU, 48, COPPER, 4.0)
	_disk(orbit, 9, GLOW)
