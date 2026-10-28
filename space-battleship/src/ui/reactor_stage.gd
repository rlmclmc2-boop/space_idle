extends Control
## Local scene geometry only. Powers are already-adopted owner presentation values.
const MOUNTING_PLATE = preload("res://assets/ui/reactor/centered-v1/mounting-plate-quality-four.png")
const MOUNTING_PLATE_THREE = preload("res://assets/ui/reactor/centered-v1/mounting-plate-quality-three.png")
const FIELD = preload("res://assets/ui/reactor/centered-v1/working_fields.gdshader")
const IDLE_FILTER = preload("res://assets/ui/reactor/centered-v1/idle_light_filter.gdshader")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const PLATE_SCALE := 0.6
const PLATE_ORIGIN := Vector2(96.8, 20.0)
const PLATE_MOUNTS := {"core":Vector2(512,690),"weapons":Vector2(225,275),"defence":Vector2(800,275),"smelting":Vector2(225,1105),"condensation":Vector2(800,1105)}
const PLATE_ROUTES := {"weapons":[Vector2(382,506),Vector2(312,398)],"defence":[Vector2(642,506),Vector2(712,398)],"smelting":[Vector2(382,872),Vector2(312,986)],"condensation":[Vector2(642,872),Vector2(712,986)]}
const OPERATING_SOURCE := {
	"weapons":{"effect":Vector2(92,375),"supply":Vector2(92,410),"slider":Vector2(120,445),"width":258.0,"track":220.0},
	"defence":{"effect":Vector2(712,375),"supply":Vector2(712,410),"slider":Vector2(739,445),"width":258.0,"track":220.0},
	"smelting":{"effect":Vector2(92,1173),"supply":Vector2(92,1208),"slider":Vector2(120,1243),"width":258.0,"track":220.0},
	"condensation":{"effect":Vector2(712,1173),"supply":Vector2(712,1208),"slider":Vector2(739,1243),"width":258.0,"track":220.0}}
const EFFECTS := {"core": Rect2(-89, -87, 180, 180), "weapons": Rect2(-46, -48, 92, 92), "defence": Rect2(-47, -47, 94, 94), "smelting": Rect2(-45, -55, 90, 104), "condensation": Rect2(-44, -54, 88, 104)}
const FILTER_REGIONS := {"core":Rect2(-128,-128,256,256),"weapons":Rect2(-60,-58,180,116),"defence":Rect2(-67,-64,134,128),"smelting":Rect2(-70,-65,140,140),"condensation":Rect2(-67,-68,134,136)}
var _enabled: Array = []
var _loads: Dictionary = {}
var _fields: Dictionary = {}
var _idle_filters: Dictionary = {}
var _connections: Dictionary = {}
var _phase: float = 0.0
var _clock: float = -1.0
var _selected: String = ""
var diagnostics := {"draws": 0, "field_updates": 0, "active_frames": 0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(808, 900)
	set_process(false)
	for index in 5:
		var id: String = "core" if index == 0 else str(IDS[index - 1])
		var idle_filter := ColorRect.new()
		idle_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		idle_filter.position = _centre(id) + FILTER_REGIONS[id].position
		idle_filter.size = FILTER_REGIONS[id].size
		var filter_material := ShaderMaterial.new()
		filter_material.shader = IDLE_FILTER
		filter_material.set_shader_parameter("kind", index)
		filter_material.set_shader_parameter("power", 0.0)
		idle_filter.material = filter_material
		add_child(idle_filter)
		_idle_filters[id] = idle_filter
		var field := ColorRect.new()
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.position = _centre(id) + EFFECTS[id].position
		field.size = EFFECTS[id].size
		var material := ShaderMaterial.new()
		material.shader = FIELD
		material.set_shader_parameter("kind", index)
		material.set_shader_parameter("power", 0.0)
		field.material = material
		add_child(field)
		_fields[id] = field
	for id in IDS:
		var route: Array = PLATE_ROUTES[id]
		var ends: Array = [_plate_point(route[0]),_plate_point(route[1])]
		var field := ColorRect.new()
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.position = ends[0]
		field.rotation = (ends[1] - ends[0]).angle()
		field.size = Vector2(ends[0].distance_to(ends[1]), 8)
		field.position -= Vector2(0, 4).rotated(field.rotation)
		var material := ShaderMaterial.new()
		material.shader = FIELD
		material.set_shader_parameter("kind", 5)
		material.set_shader_parameter("power", 0.0)
		field.material = material
		add_child(field)
		_connections[id] = field

func control_layout(id: String) -> Dictionary:
	var source: Dictionary = OPERATING_SOURCE[id]
	return {"effect":_plate_point(source.effect),"supply":_plate_point(source.supply),
		"slider":_plate_point(source.slider),"width":float(source.width)*PLATE_SCALE,
		"track":float(source.track)*PLATE_SCALE}

func _plate_point(source: Vector2) -> Vector2:
	return PLATE_ORIGIN + source * PLATE_SCALE

func _centre(id: String) -> Vector2:
	return _plate_point(PLATE_MOUNTS[id])

func show_snapshot(ids: Array, loads: Dictionary, selected: String) -> void:
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	_selected = selected
	for id in _idle_filters:
		var load: float = clampf(float(_loads.get(id, 0.0)), 0.0, 1.0)
		_idle_filters[id].visible = (id == "core" or id in _enabled) and load < 0.20
		_idle_filters[id].material.set_shader_parameter("power", load)
	for id in _fields:
		_fields[id].visible = (id == "core" or id in _enabled) and float(_loads.get(id,0.0)) > 0.0
		_fields[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	for id in _connections:
		_connections[id].visible = id in _enabled and float(_loads.get(id,0.0)) > 0.0
		_connections[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	queue_redraw()

func clear_snapshot() -> void:
	_enabled.clear()
	_loads.clear()
	_selected = ""
	for idle_filter in _idle_filters.values(): idle_filter.visible = false
	for field in _fields.values(): field.visible = false
	for field in _connections.values(): field.visible = false
	queue_redraw()

func advance_visual_clock(game_time: float, paused: bool) -> bool:
	if not is_visible_in_tree():
		_clock = -1.0
		return false
	var elapsed: float = 0.0 if _clock < 0.0 else maxf(0.0, game_time - _clock)
	_clock = game_time
	if paused or elapsed == 0.0 or float(_loads.get("core", 0.0)) <= 0.0: return false
	_phase = fmod(_phase + elapsed, 4096.0)
	diagnostics.active_frames += 1
	for id in _fields:
		if _fields[id].visible and float(_loads.get(id, 0.0)) > 0.0:
			_fields[id].material.set_shader_parameter("phase", _phase)
			diagnostics.field_updates += 1
	for id in _connections:
		if _connections[id].visible and float(_loads.get(id, 0.0)) > 0.0:
			_connections[id].material.set_shader_parameter("phase", _phase)
			diagnostics.field_updates += 1
	return true

func reset_clock() -> void:
	_clock = -1.0

func _draw_side_surface(left: bool) -> void:
	var start_x: float = 0.0 if left else PLATE_ORIGIN.x + 1024.0 * PLATE_SCALE
	var width: float = PLATE_ORIGIN.x
	draw_rect(Rect2(start_x, 65, width, 835), Color("0c3540"))
	for offset in [13.0, 34.0, 61.0, 82.0]:
		var x: float = start_x + offset
		draw_line(Vector2(x, 65), Vector2(x, 900), Color("25616c", 0.47), 1.0, true)
	for y in [217.0, 456.0, 711.0]:
		draw_line(Vector2(start_x + 9, y), Vector2(start_x + width - 9, y), Color("144a55", 0.9), 2.0, true)
		draw_line(Vector2(start_x + 25, y + 3), Vector2(start_x + width - 25, y + 3), Color("6fb8b1", 0.35), 1.0, true)
	for y in [148.0, 366.0, 619.0, 776.0]:
		draw_rect(Rect2(start_x + 45, y, 7, 23), Color("083742"))
		draw_line(Vector2(start_x + 48, y + 4), Vector2(start_x + 48, y + 19), Color("31aeb5", 0.7), 2.0, true)

func _draw() -> void:
	diagnostics.draws += 1
	var plate: Texture2D = MOUNTING_PLATE if "condensation" in _enabled else MOUNTING_PLATE_THREE
	# Only the peripheral surface fills the module; machinery retains one undistorted transform.
	_draw_side_surface(true)
	_draw_side_surface(false)
	draw_texture_rect(plate, Rect2(PLATE_ORIGIN,Vector2(1024,1536)*PLATE_SCALE), false)
	draw_rect(Rect2(0, 0, 808, 65), Color("efeede"))
	for id in _enabled:
		var layout: Dictionary = control_layout(str(id))
		var top_left: Vector2 = layout.effect - Vector2(12, 10)
		var width: float = 180.0
		var height: float = 52.0
		var strut_end: Vector2 = Vector2(_centre(str(id)).x, top_left.y)
		draw_line(strut_end - Vector2(0, 8), strut_end, Color("0a303b", 0.92), 9.0, true)
		draw_line(strut_end - Vector2(0, 8), strut_end, Color("c5d5c6", 0.72), 4.0, true)
		var shelf := PackedVector2Array([
			top_left + Vector2(0, 8), top_left + Vector2(10, 0),
			top_left + Vector2(width - 10, 0), top_left + Vector2(width, 8),
			top_left + Vector2(width - 6, height), top_left + Vector2(6, height)])
		draw_colored_polygon(shelf, Color("082f3a", 0.78))
		draw_line(top_left + Vector2(47, 0), top_left + Vector2(width - 47, 0), Color("c0d5c7", 0.75), 2.0, true)
		draw_line(top_left + Vector2(width * 0.5, -8), top_left + Vector2(width * 0.5, 0), Color("5eaba9", 0.85), 3.0, true)
		draw_rect(Rect2(layout.slider + Vector2(-6, 2), Vector2(float(layout.track) + 12.0, 14.0)), Color("082f3a", 0.72))
	# Quiet master-control surface keeps hierarchy below the operating machinery.
	draw_rect(Rect2(24, 809, 744, 77), Color("092d38", 0.88))
	draw_line(Vector2(36, 810), Vector2(756, 810), Color("56a5a7", 0.7), 1.0, true)
	draw_line(Vector2(392, 822), Vector2(392, 870), Color("6b9694", 0.42), 1.0, true)
	for id in _enabled:
		if str(id) == _selected: draw_arc(_centre(id), 113, -0.18, 0.18, 12, Color("81c9bf"), 3, true)
