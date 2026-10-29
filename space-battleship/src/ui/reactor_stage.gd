extends Control
## Reactor bay art and work effects. Every light reads adopted, effective owner load.
const FOUR = preload("res://assets/ui/reactor/ship-hub-r9/working-bay-four.png")
const WORK = preload("res://assets/ui/reactor/ship-hub-r9/transport_work.gdshader")
const AMBIENT_WORK = preload("res://assets/ui/reactor/ship-hub-r5/ambient_work.gdshader")
const CORE_SOURCE = preload("res://assets/ui/reactor/ship-hub-r4/core-work.png")
const CORE_WORK = preload("res://assets/ui/reactor/ship-hub-r4/core_work.gdshader")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const BLUE := Color(0.25, 0.80, 0.95)
const AMBER := Color(1.0, 0.55, 0.18)
const ROUTES := {
	# Axes of the four visible glass shafts, inside the dark collars. Coordinates
	# are on the 808 x 835 bay image, from the core towards each device.
	"weapons": [Vector2(277, 219), Vector2(230, 190)],
	"defence": [Vector2(531, 219), Vector2(578, 190)],
	"smelting": [Vector2(276, 434), Vector2(218, 468)],
	"condensation": [Vector2(532, 434), Vector2(590, 468)],
}
const OPERATING := {
	"weapons": {"title":Vector2(41, 127), "factor":Vector2(125, 127), "work":Vector2(37, 164), "work_size":Vector2(146, 44), "control":Vector2(59, 219), "tilt":6.0},
	"defence": {"title":Vector2(630, 127), "factor":Vector2(708, 127), "work":Vector2(624, 164), "work_size":Vector2(146, 44), "control":Vector2(654, 228), "tilt":-6.0},
	"smelting": {"title":Vector2(39, 434), "factor":Vector2(125, 434), "work":Vector2(37, 474), "work_size":Vector2(146, 72), "control":Vector2(52, 542), "tilt":-10.0},
	"condensation": {"title":Vector2(647, 434), "factor":Vector2(715, 434), "work":Vector2(624, 474), "work_size":Vector2(146, 72), "control":Vector2(660, 526), "tilt":10.0},
}
var _enabled: Array = []
var _loads: Dictionary = {}
var _fields: Dictionary = {}
var _connections: Dictionary = {}
var _ambient: ColorRect
var _feed: ColorRect
var _clock: float = -1.0
var _phase: float = 0.0
var diagnostics := {"draws":0, "field_updates":0, "active_frames":0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(808, 835)
	set_process(false)
	_add_ambient()
	_add_feed()
	_add_core()
	for id in IDS:
		var ends: Array = ROUTES[id]
		var start: Vector2 = ends[0]
		var finish: Vector2 = ends[1]
		var flow := _new_work(Rect2(start, Vector2(start.distance_to(finish), 12)), 2, AMBER if id in ["weapons", "smelting"] else BLUE)
		flow.rotation = (finish - start).angle()
		flow.position -= Vector2(0, 6.0).rotated(flow.rotation)
		flow.material.set_shader_parameter("module_kind", IDS.find(id))
		_connections[id] = flow

func _new_work(rect: Rect2, kind: int, tint: Color) -> ColorRect:
	var field := ColorRect.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.position = rect.position
	field.size = rect.size
	field.visible = false
	var material := ShaderMaterial.new()
	material.shader = WORK
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("tint", tint)
	field.material = material
	add_child(field)
	return field

func _add_ambient() -> void:
	_ambient = ColorRect.new()
	_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient.position = Vector2(164,120)
	_ambient.size = Vector2(480,450)
	_ambient.visible = false
	var material := ShaderMaterial.new()
	material.shader = AMBIENT_WORK
	_ambient.material = material
	add_child(_ambient)

func _add_feed() -> void:
	# The supply glass ends under the upper collar; the lower ivory ring is solid
	# foreground and must never receive a moving packet over its front lip.
	_feed = _new_work(Rect2(Vector2(395, 73), Vector2(18, 73)), 3, BLUE)

func _add_core() -> void:
	var field := TextureRect.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.position = Vector2(272, 211)
	field.size = Vector2(264, 264)
	field.texture = CORE_SOURCE
	field.visible = false
	var material := ShaderMaterial.new()
	material.shader = CORE_WORK
	field.material = material
	add_child(field)
	_fields["core"] = field

func control_layout(id: String) -> Dictionary:
	var row: Dictionary = OPERATING[id]
	return row

func show_snapshot(ids: Array, loads: Dictionary, _selected: String) -> void:
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	var core_power: float = clampf(float(_loads.get("core",0.0)),0.0,1.0)
	_ambient.visible = core_power > 0.0
	_ambient.material.set_shader_parameter("power",core_power)
	_feed.visible = core_power > 0.0
	_feed.material.set_shader_parameter("power",core_power)
	for id in _fields:
		var load: float = clampf(float(_loads.get(id, 0.0)), 0.0, 1.0)
		_fields[id].visible = (id == "core" or id in _enabled) and load > 0.0
		_fields[id].material.set_shader_parameter("power", load)
	for id in _connections:
		var load: float = clampf(float(_loads.get(id, 0.0)), 0.0, 1.0)
		_connections[id].visible = id in _enabled and load > 0.0
		_connections[id].material.set_shader_parameter("power", load)
	queue_redraw()

func clear_snapshot() -> void:
	_enabled.clear()
	_loads.clear()
	_ambient.visible = false
	_feed.visible = false
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
	_ambient.material.set_shader_parameter("phase",_phase)
	_feed.material.set_shader_parameter("phase",_phase)
	diagnostics.active_frames += 1
	for id in _fields:
		if _fields[id].visible:
			_fields[id].material.set_shader_parameter("phase", _phase)
			diagnostics.field_updates += 1
	for id in _connections:
		if _connections[id].visible:
			_connections[id].material.set_shader_parameter("phase", _phase)
			diagnostics.field_updates += 1
	return true

func reset_clock() -> void:
	_clock = -1.0

func visual_phase() -> float:
	return _phase

func _draw() -> void:
	diagnostics.draws += 1
	draw_texture_rect(FOUR, Rect2(0, 0, 808, 835), false)
