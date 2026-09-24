extends Control

# Purely decorative. Facility entries come from a planet row's optional visualFacilities list.
const PLANET_TEXTURE := preload("res://assets/ui/planet-globe.png")
const FACILITY_COLORS := {
	"scout_satellite": Color("8ce9ff"),
	"space_station": Color("ffd89b"),
	"mining_platform": Color("e8bb86"),
	"research_facility": Color("a6b9ff"),
	"defense_platform": Color("ffb0a8"),
	"orbital_factory": Color("b4e6ce"),
}
const TAU_F := TAU

var planet_id := ""
var appearance: Dictionary = {}
var facilities: Array = []
var active := false
var selected_facility := ""
var phase := 0.0
var completion_age := 10.0
var last_degree := 0
var draw_calls := 0
var frame_accumulator := 0.0
var surface_texture: Texture2D = PLANET_TEXTURE
var texture_path := ""

func configure(id: String, row: Dictionary) -> void:
	planet_id = id
	var appearance_source = row.get("visual", {})
	if appearance_source is String:appearance_source = JSON.parse_string(appearance_source)
	appearance = appearance_source if appearance_source is Dictionary else {}
	var next_path := str(appearance.get("texture", ""))
	if next_path != texture_path:
		texture_path = next_path
		surface_texture = load(next_path) if not next_path.is_empty() and ResourceLoader.exists(next_path) else PLANET_TEXTURE
	var facility_source = row.get("visualFacilities", [])
	if facility_source is String:facility_source = JSON.parse_string(facility_source)
	var entries: Array = facility_source if facility_source is Array else []
	var next: Array = []
	for entry in entries:
		if not entry is Dictionary:continue
		var kind := str(entry.get("type", ""))
		if not FACILITY_COLORS.has(kind) or not bool(entry.get("owned", false)):continue
		next.append(entry)
	if facilities != next:
		facilities = next
		queue_redraw()

func set_exploration(is_active: bool, degree: int) -> void:
	if degree > last_degree:
		completion_age = 0.0
	last_degree = degree
	if active != is_active:
		active = is_active
		queue_redraw()

func complete() -> void:
	completion_age = 0.0
	queue_redraw()

func select_facility(id: String) -> void:
	if selected_facility == id:return
	selected_facility = id
	queue_redraw()

func advance(dt: float, paused: bool) -> void:
	if not is_visible_in_tree():return
	if paused:
		if completion_age < 1.5:
			completion_age += dt
			queue_redraw()
		return
	frame_accumulator += dt
	if frame_accumulator < 1.0 / 24.0:return
	var step := minf(frame_accumulator, 0.1)
	frame_accumulator = 0.0
	phase += step
	completion_age += step
	queue_redraw()

func _draw() -> void:
	draw_calls += 1
	var center := size * 0.5
	var radius := minf(size.y * 0.39, size.x * 0.248)
	var base := _color("surfaceColor", Color("326ba0"))
	var atmosphere := _color("atmosphereColor", Color("5ac8f0"))
	for star in 75:
		var point := Vector2(fmod(float(star * 193 + 47), size.x), fmod(float(star * 137 + 19), size.y))
		var alpha := 0.08 + 0.20 * absf(sin(float(star) * 11.7))
		draw_circle(point, 0.55 + float(star % 7 == 0) * 0.55, Color("b5dcf4", alpha))
	for grid in 5:
		var x := size.x * float(grid + 1) / 6.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("4b95b2", 0.035), 1.0)
	# Background and orbital back halves stay behind the planet.
	draw_circle(Vector2(size.x * 0.83, size.y * 0.22), size.y * 0.16, Color("24506d", 0.045))
	draw_circle(Vector2(size.x * 0.15, size.y * 0.76), size.y * 0.15, Color("31536b", 0.035))
	draw_circle(center, radius * 1.36, Color(atmosphere, 0.018 + 0.007 * sin(phase * 0.55)))
	draw_circle(center, radius * 1.15, Color(atmosphere, 0.075))
	for ring in 3:
		_orbit(center, radius * (1.42 + ring * 0.26), 0.37 + ring * 0.04, ring, false)
	_draw_facilities(center, radius, false)
	# The authored globe provides surface detail; subtle rotation and cloud glints keep it alive.
	draw_circle(center, radius * 1.02, base.darkened(0.3))
	draw_set_transform(center, phase * 0.003, Vector2.ONE)
	draw_texture_rect(surface_texture, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for band in 2:
		var y := center.y + (band - 0.5) * radius * 0.45
		var drift := sin(phase * (0.10 + band * 0.03)) * radius * 0.07
		draw_line(Vector2(center.x - radius * 0.50 + drift, y), Vector2(center.x + radius * 0.32 + drift, y - radius * 0.06), Color.WHITE * Color(1, 1, 1, 0.055), radius * 0.09, true)
	draw_arc(center, radius * 1.006, 0, TAU_F, 96, Color(atmosphere, 0.45), 2.5, true)
	if active:
		var scan := fmod(phase * 0.22, 1.0)
		draw_arc(center, radius * (0.18 + scan * 0.78), -0.75, 1.1, 24, Color(atmosphere, (1.0 - scan) * 0.28), 2.0, true)
		var scan_point := center + Vector2(cos(phase * 0.35), sin(phase * 0.35) * 0.7) * radius * 0.65
		draw_circle(scan_point, 3.0, Color(atmosphere, 0.75))
	if completion_age < 1.1:
		var p := completion_age / 1.1
		draw_arc(center, radius * (1.05 + p * 0.70), 0, TAU_F, 72, Color(atmosphere, (1.0-p) * 0.72), 2.0, true)
	for ring in 3:
		_orbit(center, radius * (1.42 + ring * 0.26), 0.37 + ring * 0.04, ring, true)
	_draw_facilities(center, radius, true)
	_draw_ambient(center, radius)

func _orbit(center: Vector2, horizontal: float, vertical_ratio: float, ring: int, front: bool) -> void:
	var begin := 0.0 if front else PI
	var points := PackedVector2Array()
	for step in 33:
		var angle := begin + PI * step / 32.0
		points.append(center + Vector2(cos(angle) * horizontal, sin(angle) * horizontal * vertical_ratio))
	draw_polyline(points, Color("92d4ed", (0.38 if front else 0.11) - ring * 0.04), 1.7 if front else 1.0, true)
	var glint_angle := phase * (0.12 + ring * 0.035) + ring * 2.1
	if (sin(glint_angle) >= 0.0) == front:
		var point := center + Vector2(cos(glint_angle) * horizontal, sin(glint_angle) * horizontal * vertical_ratio)
		draw_circle(point, 2.2, Color("c6f4ff", 0.22 if front else 0.08))

func _draw_facilities(center: Vector2, radius: float, front: bool) -> void:
	for index in facilities.size():
		var entry: Dictionary = facilities[index]
		var kind := str(entry.get("type", ""))
		var orbit := clampi(int(entry.get("orbit", index % 3)), 0, 5)
		var speed := 0.08 + 0.025 * float(index % 3)
		var angle := phase * speed + float(entry.get("phase", index * 2.399))
		if (sin(angle) >= 0.0) != front:continue
		var extent := radius * (1.42 + orbit * 0.26)
		var point := center + Vector2(cos(angle) * extent, sin(angle) * extent * (0.37 + orbit * 0.04))
		var tint: Color = FACILITY_COLORS[kind]
		var selected := str(entry.get("id", "")) == selected_facility and not selected_facility.is_empty()
		var kind_scale := 1.9 if kind == "space_station" else (1.5 if kind == "scout_satellite" else 1.65)
		var scale := kind_scale * (1.20 if selected else 1.0) * (1.0 + minf(0.30, maxf(0.0, float(entry.get("level", 1)) - 1.0) * 0.05))
		var bob := sin(phase * (0.8 + index * 0.13)) * 1.2
		point.y += bob
		if selected:draw_arc(point, 11 * scale, 0, TAU_F, 30, Color(tint, 0.6), 1.4, true)
		if str(entry.get("status", "")) == "working":draw_arc(point, 10 * scale + sin(phase * 1.2 + index) * 1.5, 0, TAU_F, 30, Color(tint, 0.20), 1.2, true)
		match kind:
			"scout_satellite":
				draw_rect(Rect2(point - Vector2(8, 2) * scale, Vector2(16, 4) * scale), Color(tint, 0.55))
				draw_circle(point, 3.5 * scale, tint)
			"space_station":
				draw_arc(point, 7 * scale, 0, TAU_F, 24, tint, 2.0, true)
				draw_line(point + Vector2(0, -10) * scale, point + Vector2(0, 10) * scale, tint, 2.0, true)
				if fmod(phase + index, 9.0) < 1.2:draw_arc(point, 9 * scale + fmod(phase + index, 9.0) * 9, 0, TAU_F, 30, Color(tint, 0.17), 1.0, true)
			"mining_platform":
				draw_colored_polygon(PackedVector2Array([point + Vector2(-7, -4), point + Vector2(7, -4), point + Vector2(4, 5), point + Vector2(-4, 5)]), tint)
			"research_facility":
				draw_circle(point, 5 * scale, Color(tint, 0.35))
				draw_arc(point, 7 * scale, phase * 0.3, phase * 0.3 + PI * 1.4, 20, tint, 1.5, true)
			"defense_platform":
				draw_rect(Rect2(point - Vector2(5, 5) * scale, Vector2(10, 10) * scale), tint)
				draw_line(point, point + Vector2(cos(phase * 0.16), sin(phase * 0.16)) * 9, Color.WHITE, 1.2, true)
			"orbital_factory":
				draw_rect(Rect2(point - Vector2(7, 4) * scale, Vector2(14, 8) * scale), tint)
				draw_line(point + Vector2(-10, -7) * scale, point + Vector2(10, -7) * scale, tint, 1.5, true)
		draw_circle(point + Vector2(0, -3), 1.1, Color.WHITE * Color(1, 1, 1, 0.4 + 0.25 * sin(phase * (0.7 + index * 0.12))))
	if active and front:
		var angle := phase * 0.48
		var scout := center + Vector2(cos(angle) * radius * 1.65, sin(angle) * radius * 0.68)
		draw_colored_polygon(PackedVector2Array([scout + Vector2(5, 0), scout + Vector2(-4, -3), scout + Vector2(-2, 0), scout + Vector2(-4, 3)]), Color("a6f6ff"))

func _draw_ambient(center: Vector2, radius: float) -> void:
	# Fixed low-frequency cycles avoid spawning objects or random work each frame.
	var transport_cycle := fmod(phase, 23.0)
	if transport_cycle < 5.0:
		var x := lerpf(12.0, size.x - 12.0, transport_cycle / 5.0)
		var point := Vector2(x, center.y - radius * 1.22 + 4.0 * sin(transport_cycle))
		draw_line(point - Vector2(5, 1), point + Vector2(3, -1), Color("afd9e8", 0.35), 1.5, true)
	var debris_cycle := fmod(phase + 11.0, 37.0)
	if debris_cycle < 9.0:
		var point := Vector2(lerpf(size.x - 10.0, 20.0, debris_cycle / 9.0), size.y * 0.12 + debris_cycle * 0.7)
		draw_circle(point, 1.3, Color("c7ddeb", 0.24))

func _color(key: String, fallback: Color) -> Color:
	var value := str(appearance.get(key, ""))
	return Color(value) if Color.html_is_valid(value) else fallback
