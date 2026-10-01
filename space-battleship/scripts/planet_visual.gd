extends Control

# Purely decorative. Facility entries come from a planet row's optional visualFacilities list.
const OrbitModels := preload("res://scripts/orbital_facilities.gd")
const Art := preload("res://scripts/planet_art.gd")
const PlanetSphere := preload("res://scripts/rotating_planet.gd")
const BACKDROP := preload("res://assets/planets/toon/exploration-field.svg")
const FACILITY_COLORS := {
	"scout_satellite": Color("8ce9ff"),
	"space_station": Color("ffd89b"),
	"auto_explore": Color("ffd89b"),
	"refinery": Color("e8bb86"),
	"equipment": Color("a6b9ff"),
	"shipyard": Color("b4e6ce"),
	"mining_platform": Color("e8bb86"),
	"research_facility": Color("a6b9ff"),
	"defense_platform": Color("ffb0a8"),
	"orbital_factory": Color("b4e6ce"),
}
const TAU_F := TAU
const ENTRY_DURATION := 2.8
const COMPLETION_FLASH_DURATION := 0.28
const STELLAR_WORK_STATES := ["planet.work.spectrum", "planet.work.radiation", "planet.work.signal", "planet.work.magnetic"]
const WORK_STATES := ["planet.work.mapping", "planet.work.surface", "planet.work.signal", "planet.work.deep"]

var facility_renderer: Node
var icon_mode := false
var planet_id := ""
var appearance: Dictionary = {}
var facilities: Array = []
var active := false
var selected_facility := ""
var phase := 0.0
var completion_age := 10.0
var last_degree = 0
var draw_calls := 0
var frame_accumulator := 0.0
var globe = PlanetSphere.new()
var background_layer := Control.new()
var orbit_back_layer := Control.new()
var configured_appearance: Dictionary = {}
var appearance_initialized := false
var orbit_geometry: Dictionary = {}
var exploration_age := 0.0
# Transient presentation only; owned by this view and discarded on hide.
var facility_reveals: Dictionary = {}
var departure_age := 10.0
var departure_point := Vector2.ZERO
var departure_direction := Vector2.RIGHT
var departure_front := true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for layer in [background_layer, orbit_back_layer, globe]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.show_behind_parent = true
		add_child(layer)
	background_layer.draw.connect(_draw_background)
	orbit_back_layer.draw.connect(_draw_back_orbits)
	resized.connect(_layout_globe)
	_layout_globe()

func _layout_globe() -> void:
	orbit_geometry.clear()
	globe.fit_sphere(size * 0.5, minf(size.x, size.y) * 0.43 / maxf(1.0, globe.extent) if icon_mode else _body_radius())
	background_layer.queue_redraw()
	orbit_back_layer.queue_redraw()
	queue_redraw()

func _body_radius() -> float:
	var base := minf(size.y * 0.39, size.x * 0.285)
	var requested := base * clampf(float(appearance.get("radiusScale", 1.0)), 0.08, 1.25)
	# Keep the entire authored corona/beam envelope inside the scene.
	var available := maxf(1.0, minf(size.x, size.y) * 0.5 - 16.0)
	return minf(requested, available / maxf(1.0, globe.extent))

func _orbit_radius() -> float:
	# Compact stars keep a readable operational area without an Earth-sized scan.
	return maxf(_body_radius(), minf(size.y * 0.39, size.x * 0.285) * 0.65)

func _map_texture(key: String, fallback: Texture2D) -> Texture2D:
	var path := str(appearance.get(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):return fallback
	var resource = load(path)
	return resource if resource is Texture2D else fallback

func _visual_value(value, fallback):
	if value is String:
		if value.strip_edges().is_empty():return fallback
		var parser := JSON.new()
		return parser.data if parser.parse(value) == OK else fallback
	return value

func configure(id: String, row: Dictionary) -> void:
	planet_id = id
	var appearance_source = row.get("visual", {})
	appearance_source = _visual_value(appearance_source, {})
	appearance = appearance_source if appearance_source is Dictionary else {}
	if not appearance_initialized or appearance != configured_appearance:
		appearance_initialized = true
		configured_appearance = appearance.duplicate(true)
		# Legacy texture is a finished globe, never scroll it as an albedo map.
		globe.surface_map = _map_texture("surfaceTexture", PlanetSphere.SURFACE)
		globe.cloud_map = _map_texture("cloudTexture", PlanetSphere.CLOUDS)
		globe.surface_speed = float(appearance.get("surfaceSpeed", 0.006))
		globe.cloud_speed = float(appearance.get("cloudSpeed", 0.0073))
		globe.glow_strength = clampf(float(appearance.get("glowStrength", 0.30)), 0.0, 1.0)
		globe.shadow_strength = clampf(float(appearance.get("shadowStrength", 0.86)), 0.0, 1.0)
		globe.cloud_opacity = clampf(float(appearance.get("cloudOpacity", 0.65)), 0.0, 1.0)
		globe.atmosphere_color = _color("atmosphereColor", Color("5ac8f0"))
		globe.configure_visual(appearance)
		globe.light_direction = Vector3(-0.65, -0.45, 0.62)
		globe.apply_settings()
		_layout_globe()
	var facility_source = row.get("visualFacilities", [])
	facility_source = _visual_value(facility_source, [])
	var entries: Array = facility_source if facility_source is Array else []
	var next: Array = []
	for entry in entries:
		if not entry is Dictionary:continue
		var kind := str(entry.get("type", ""))
		if not FACILITY_COLORS.has(kind) or not bool(entry.get("owned", false)):continue
		next.append(entry)
	if is_instance_valid(facility_renderer):
		facility_renderer.configure(next)
		facility_renderer.update_pose(phase)
	if facilities != next:
		facilities = next
		orbit_back_layer.queue_redraw()
		queue_redraw()

func set_exploration(is_active: bool, degree, elapsed: float = 0.0) -> void:
	last_degree = degree
	if active != is_active:
		if active and not is_active and is_visible_in_tree():
			var center := size * 0.5
			var radius := _orbit_radius()
			departure_point = _scout_position(exploration_age, center, radius)
			departure_direction = (_scout_position(exploration_age + 0.01, center, radius) - departure_point).normalized()
			departure_front = _scout_in_front()
			departure_age = 0.0
		if is_active:departure_age = 10.0
		active = is_active
		exploration_age = ENTRY_DURATION + 1.0 if elapsed > 0.2 else 0.0
		orbit_back_layer.queue_redraw()
		queue_redraw()
	# Reveal catches up a missed arrival without replaying its pulse.
	if active and elapsed >= ENTRY_DURATION + 1.0 and exploration_age < ENTRY_DURATION:
		exploration_age = ENTRY_DURATION + 1.0
		orbit_back_layer.queue_redraw()

func work_state_key() -> String:
	if exploration_age < ENTRY_DURATION:return "planet.work.arriving"
	var states: Array = STELLAR_WORK_STATES if float(appearance.get("emission", 0.0)) > 0.0 else WORK_STATES
	return states[int(exploration_age / 11.0) % states.size()]

func complete() -> void:
	if not is_visible_in_tree():return
	completion_age = 0.0
	var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 0.78
	globe.globe_material.set_shader_parameter("completion_spot", spot)
	globe.globe_material.set_shader_parameter("completion_flash", 0.50)

func reveal_facility(id: String) -> void:
	if not is_visible_in_tree():return
	facility_reveals[id] = 0.0
	orbit_back_layer.queue_redraw()
	queue_redraw()

func clear_transients() -> void:
	if completion_age < COMPLETION_FLASH_DURATION:
		globe.globe_material.set_shader_parameter("completion_flash", 0.0)
	completion_age = 10.0
	departure_age = 10.0
	facility_reveals.clear()
	frame_accumulator = 0.0
	# A returning page shows an ongoing flight without replaying arrival.
	if active:exploration_age = maxf(exploration_age, ENTRY_DURATION + 1.0)
	orbit_back_layer.queue_redraw()
	queue_redraw()

func select_facility(id: String) -> void:
	if selected_facility == id:return
	selected_facility = id
	orbit_back_layer.queue_redraw()
	queue_redraw()

func advance(dt: float, paused: bool) -> void:
	if not is_visible_in_tree():return
	if paused or dt <= 0.0:return
	frame_accumulator += dt
	if frame_accumulator < 1.0 / 24.0:return
	var step := frame_accumulator
	globe.advance(step)
	frame_accumulator = 0.0
	phase += step
	if is_instance_valid(facility_renderer):facility_renderer.update_pose(phase)
	if active:exploration_age += step
	if completion_age < 3.2:
		var previous_age := completion_age
		completion_age += step
		if previous_age < COMPLETION_FLASH_DURATION:
			globe.globe_material.set_shader_parameter("completion_flash", 0.50 * maxf(0.0, 1.0 - completion_age / COMPLETION_FLASH_DURATION))
	departure_age += step
	for id in facility_reveals.keys():
		facility_reveals[id] += step
		if float(facility_reveals[id]) >= 1.4:facility_reveals.erase(id)
	orbit_back_layer.queue_redraw()
	queue_redraw()

func _draw_background() -> void:
	if icon_mode:return
	# Static field, separate from the owner-driven sphere and orbital motion.
	background_layer.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, size), false)

func _draw_back_orbits() -> void:
	if icon_mode:return
	var center := size * 0.5
	var radius := _orbit_radius()
	for ring in ([1] if active else []):
		_orbit(center, radius * (1.42 + ring * 0.26), 0.37 + ring * 0.04, ring, false, orbit_back_layer)
	_draw_facility_paths(center, radius, false, orbit_back_layer)
	_draw_facilities(center, radius, false, orbit_back_layer)
	if active and not _scout_in_front():_draw_scout(center, radius, orbit_back_layer)
	if not active and departure_age < 1.0 and not departure_front:_draw_departure(orbit_back_layer)

func _draw() -> void:
	if icon_mode:return
	draw_calls += 1
	var center := size * 0.5
	var radius := _orbit_radius()
	var atmosphere := _color("atmosphereColor", Color("5ac8f0"))
	if active:_draw_scans(center, _body_radius(), atmosphere)
	for ring in ([1] if active else []):
		_orbit(center, radius * (1.42 + ring * 0.26), 0.37 + ring * 0.04, ring, true)
	_draw_facility_paths(center, radius, true, self)
	_draw_facilities(center, radius, true)
	_draw_ambient(center, radius)
	if not active and departure_age < 1.0 and departure_front:_draw_departure(self)
	if active and _scout_in_front():_draw_scout(center, radius)

func _orbit(center: Vector2, horizontal: float, vertical_ratio: float, ring: int, front: bool, canvas: CanvasItem = null) -> void:
	if canvas == null:canvas = self
	horizontal = minf(horizontal, size.x * 0.5 - 48.0)
	var begin := 0.0 if front else PI
	var geometry_key := ring * 2 + int(front)
	if not orbit_geometry.has(geometry_key):
		var vertices := PackedVector2Array()
		for step in 33:
			var angle := begin + PI * step / 32.0
			vertices.append(center + Vector2(cos(angle) * horizontal, sin(angle) * horizontal * vertical_ratio))
		orbit_geometry[geometry_key] = vertices
	var points: PackedVector2Array = orbit_geometry[geometry_key]
	var arrival := _arrival_strength() if ring == 1 else 0.0
	var orbit_color := _color("atmosphereColor", Color("92d4ed")).lerp(Color("92d4ed"), 0.35)
	canvas.draw_polyline(points, Color(orbit_color, (0.38 if front else 0.11) - ring * 0.04 + arrival * 0.16), 1.7 if front else 1.0, true)
	var glint_angle := phase * (0.12 + ring * 0.035) + ring * 2.1
	if (sin(glint_angle) >= 0.0) == front:
		var point := center + Vector2(cos(glint_angle) * horizontal, sin(glint_angle) * horizontal * vertical_ratio)
		canvas.draw_circle(point, 2.2, Color("c6f4ff", 0.22 if front else 0.08))

func _facility_point(center: Vector2, radius: float, kind: String, angle: float) -> Vector2:
	var path := OrbitModels.path_for(kind)
	var extent := minf(radius * float(path.radius), size.x * 0.5 - 44.0)
	return center + Vector2(cos(angle) * extent, sin(angle) * extent * float(path.ratio)).rotated(float(path.tilt))

func _draw_facility_paths(center: Vector2, radius: float, front: bool, canvas: CanvasItem) -> void:
	for entry in facilities:
		var kind := str(entry.get("type", ""))
		var path := OrbitModels.path_for(kind)
		# Stationary docks have no misleading orbital track.
		if float(path.speed) == 0.0:continue
		var key := "facility_" + kind + str(front)
		if not orbit_geometry.has(key):
			var points := PackedVector2Array()
			var begin := 0.0 if front else PI
			for index in 65:points.append(_facility_point(center, radius, kind, begin + PI * float(index) / 64.0))
			orbit_geometry[key] = points
		var chosen := selected_facility == str(entry.get("id", ""))
		canvas.draw_polyline(orbit_geometry[key], Color(0.52, 0.72, 0.82, (0.17 if front else 0.055) * (1.65 if chosen else 1.0)), 1.0, true)

func _draw_facilities(center: Vector2, radius: float, front: bool, canvas: CanvasItem = null) -> void:
	if canvas == null:canvas = self
	for entry in facilities:
		var kind := str(entry.get("type", ""))
		var angle := OrbitModels.angle_for(kind, phase)
		var depth := sin(angle)
		if (depth >= 0.0) != front:continue
		var point := _facility_point(center, radius, kind, angle)
		var near_weight := (depth + 1.0) * 0.5
		var span := clampf(_body_radius() * 0.37, 48.0, 76.0) * lerpf(0.78, 1.06, near_weight)
		var artwork: Texture2D = facility_renderer.texture(kind) if is_instance_valid(facility_renderer) else Art.facility(kind)
		if artwork == null:continue
		var tint := Color(0.65, 0.72, 0.82).lerp(Color.WHITE, near_weight)
		Art.draw_fitted(canvas, artwork, Rect2(point - Vector2.ONE * span * 0.5, Vector2.ONE * span), tint)
		if selected_facility == str(entry.get("id", "")):
			canvas.draw_arc(point, span * 0.43, 0, TAU, 32, Color(0.60, 0.87, 1.0, 0.55), 1.0, true)

func _arrival_strength() -> float:
	if not active:return 0.0
	var age := exploration_age - ENTRY_DURATION
	if age < 0.0 or age >= 0.8:return 0.0
	return sin(PI * age / 0.8) * (1.0 - age / 0.8)

func _scout_position(age: float, center: Vector2, radius: float) -> Vector2:
	if age >= ENTRY_DURATION:
		var angle := (age - ENTRY_DURATION) * 0.48
		return center + Vector2(cos(angle) * radius * 1.65, sin(angle) * radius * 0.68)
	var t := clampf(age / ENTRY_DURATION, 0.0, 1.0)
	# Accelerate on approach, brake into the original ellipse with matching tangent speed.
	var end_slope := 0.68 * 0.48 * ENTRY_DURATION / 1.5
	var u := (0.24 + end_slope - 2.0) * t * t * t + (3.0 - 0.48 - end_slope) * t * t + 0.24 * t
	var start := Vector2(size.x + 16.0, center.y - radius * 1.2)
	var end := center + Vector2(radius * 1.65, 0.0)
	return start.bezier_interpolate(start + Vector2(-radius * 0.55, radius * 0.18), end - Vector2(0.0, radius * 0.5), end, u)

func _scout_in_front() -> bool:
	return exploration_age < ENTRY_DURATION or sin((exploration_age - ENTRY_DURATION) * 0.48) >= 0.0

func _draw_scout(center: Vector2, radius: float, canvas: CanvasItem = null) -> void:
	if canvas == null:canvas = self
	var point := _scout_position(exploration_age, center, radius)
	var tangent := (_scout_position(exploration_age + 0.01, center, radius) - point).normalized()
	var settling := smoothstep(ENTRY_DURATION - 0.55, ENTRY_DURATION + 0.65, exploration_age)
	var thrust := lerpf(0.48, 0.095, settling) * (0.92 + 0.08 * sin(phase * 5.3))
	# A short sampled wake follows the same path; no emitter or nodes are spawned.
	for segment in 8:
		var lag := float(segment) * 0.035
		var a := _scout_position(maxf(0.0, exploration_age - lag), center, radius)
		var b := _scout_position(maxf(0.0, exploration_age - lag - 0.035), center, radius)
		canvas.draw_line(a - tangent * 4.0, b - tangent * 4.0, Color("8bcddf", thrust * (1.0 - float(segment) / 8.0)), 1.6, true)
	# Artwork faces up; align its bow to the existing path tangent.
	canvas.draw_set_transform(point, tangent.angle() + PI * 0.5, Vector2.ONE)
	Art.draw_fitted(canvas, Art.SCOUT, Rect2(-12, -24, 24, 48))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_departure(canvas: CanvasItem) -> void:
	var t := clampf(departure_age, 0.0, 1.0)
	var end := Vector2(size.x + 45.0, -35.0)
	var point := departure_point.bezier_interpolate(departure_point + departure_direction * 100.0, end + Vector2(-120, 90), end, t * t)
	var next_t := minf(1.0, t + 0.01)
	var next := departure_point.bezier_interpolate(departure_point + departure_direction * 100.0, end + Vector2(-120, 90), end, next_t * next_t)
	var direction := (next - point).normalized()
	canvas.draw_line(point - direction * (8.0 + t * 20.0), point, Color("8bcddf", (1.0 - t) * 0.4), 2.0, true)
	canvas.draw_set_transform(point, direction.angle() + PI * 0.5, Vector2.ONE)
	Art.draw_fitted(canvas, Art.SCOUT, Rect2(-12, -24, 24, 48), Color(1, 1, 1, 1.0 - smoothstep(0.65, 1.0, t)))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_scans(center: Vector2, radius: float, atmosphere: Color) -> void:
	var age := exploration_age - ENTRY_DURATION
	if age < 0.0:return
	if age < 0.95:
		var p := age / 0.95
		draw_arc(center, radius * (1.02 + p * 0.22), 0.0, TAU_F, 80, Color(atmosphere, sin(PI * p) * (1.0 - p) * 0.26), 1.4, true)
	# Unequal gaps and changing arc bearings keep the sweep quiet and non-mechanical.
	var cycle := int(age / 26.0)
	var clock := fmod(age, 26.0)
	var delay := 3.2 if clock < 13.0 else 16.9
	var scan_age := clock - delay
	if scan_age < 0.0 or scan_age > 2.6 or completion_age < 1.1:return
	var p := scan_age / 2.6
	var bearing := float(cycle) * 1.73 + (0.35 if clock < 13.0 else 2.4)
	var strength := sin(PI * p) * 0.18
	draw_arc(center, radius * (0.22 + p * 0.72), bearing, bearing + 1.65, 40, Color(atmosphere, strength), 1.5, true)
	draw_arc(center, radius * (0.19 + p * 0.72), bearing + 0.12, bearing + 1.45, 36, Color(atmosphere, strength * 0.20), 3.0, true)

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
