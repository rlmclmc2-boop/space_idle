extends Control
## Local scene geometry only. Powers are already-adopted owner presentation values.
const SUPPORTS = preload("res://assets/ui/reactor/centered-v1/supports.png")
const MOUNTING_PLATE = preload("res://assets/ui/reactor/centered-v1/mounting-plate-r2.png")
const MOUNTING_PLATE_THREE = preload("res://assets/ui/reactor/centered-v1/mounting-plate-three-r2.png")
const FIELD = preload("res://assets/ui/reactor/centered-v1/working_fields.gdshader")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const PLATE_SCALE := 0.6
const PLATE_ORIGIN := Vector2(96.8, 20.0)
const PLATE_MOUNTS := {"core":Vector2(512,690),"weapons":Vector2(225,275),"defence":Vector2(800,275),"smelting":Vector2(225,1105),"condensation":Vector2(800,1105)}
const PLATE_ROUTES := {"weapons":[Vector2(382,506),Vector2(312,398)],"defence":[Vector2(642,506),Vector2(712,398)],"smelting":[Vector2(382,872),Vector2(312,986)],"condensation":[Vector2(642,872),Vector2(712,986)]}
const OPERATING_SOURCE := {
	"weapons":{"effect":Vector2(92,367),"supply":Vector2(92,402),"slider":Vector2(120,445),"width":225.0,"track":167.0},
	"defence":{"effect":Vector2(712,367),"supply":Vector2(712,402),"slider":Vector2(739,445),"width":225.0,"track":167.0},
	"smelting":{"effect":Vector2(92,1185),"supply":Vector2(92,1220),"slider":Vector2(120,1263),"width":225.0,"track":167.0},
	"condensation":{"effect":Vector2(712,1185),"supply":Vector2(712,1220),"slider":Vector2(739,1263),"width":225.0,"track":167.0}}
const EFFECTS := {"core": Rect2(-89, -87, 180, 180), "weapons": Rect2(-46, -48, 92, 92), "defence": Rect2(-47, -47, 94, 94), "smelting": Rect2(-45, -55, 90, 104), "condensation": Rect2(-44, -54, 88, 104)}
var _enabled: Array = []
var _loads: Dictionary = {}
var _fields: Dictionary = {}
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
	for id in _fields:
		_fields[id].visible = id == "core" or (id in _enabled and float(_loads.get(id,0.0)) > 0.0)
		_fields[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	for id in _connections:
		_connections[id].visible = id in _enabled and float(_loads.get(id,0.0)) > 0.0
		_connections[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	queue_redraw()

func clear_snapshot() -> void:
	_enabled.clear()
	_loads.clear()
	_selected = ""
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

func _draw() -> void:
	diagnostics.draws += 1
	draw_rect(Rect2(0,0,808,900),Color("102c38"))
	var plate: Texture2D = MOUNTING_PLATE if "condensation" in _enabled else MOUNTING_PLATE_THREE
	# Stations, consoles and buried conduits share one undistorted transform.
	draw_texture_rect(plate, Rect2(PLATE_ORIGIN,Vector2(1024,1536)*PLATE_SCALE), false)
	for x in [PLATE_ORIGIN.x,PLATE_ORIGIN.x+1024*PLATE_SCALE]:
		draw_line(Vector2(x,66),Vector2(x,797),Color("34717a"),2.0,true)
	draw_rect(Rect2(0, 0, 808, 65), Color("efeede"))
	draw_texture_rect_region(SUPPORTS,Rect2(158,797,491,100),Rect2(1031,747,491,100))
	# All housings and couplings are now one source image and one transform.
	for id in _enabled:
		if str(id) == _selected: draw_arc(_centre(id), 113, -0.18, 0.18, 12, Color("81c9bf"), 3, true)
