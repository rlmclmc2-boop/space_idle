extends Control
## Reactor bay art and work effects. Every light reads adopted, effective owner load.
const FOUR = preload("res://assets/ui/reactor/ship-hub-r4/background-four.png")
const THREE = preload("res://assets/ui/reactor/ship-hub-r4/background-three.png")
const WORK = preload("res://assets/ui/reactor/ship-hub-r4/hub_work.gdshader")
const CORE_SOURCE = preload("res://assets/ui/reactor/ship-hub-r4/core-work.png")
const CORE_WORK = preload("res://assets/ui/reactor/ship-hub-r4/core_work.gdshader")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const BLUE := Color(0.25, 0.80, 0.95)
const AMBER := Color(1.0, 0.55, 0.18)
const PORTS := {
	"weapons": Rect2(81, 127, 112, 61),
	"defence": Rect2(642, 129, 95, 68),
	"smelting": Rect2(85, 476, 98, 72),
	"condensation": Rect2(646, 472, 95, 78),
}
const ROUTES := {
	"weapons": [Vector2(300, 274), Vector2(213, 209)],
	"defence": [Vector2(510, 274), Vector2(603, 207)],
	"smelting": [Vector2(294, 429), Vector2(216, 478)],
	"condensation": [Vector2(514, 429), Vector2(602, 477)],
}
const OPERATING := {
	"weapons": {"mount":Vector2(6, 246), "effect":Vector2(35, 253), "supply":Vector2(35, 303), "effective":Vector2(35, 322), "slider":Vector2(44, 271), "width":180.0, "track":154.0},
	"defence": {"mount":Vector2(586, 246), "effect":Vector2(615, 253), "supply":Vector2(615, 303), "effective":Vector2(615, 322), "slider":Vector2(624, 271), "width":180.0, "track":154.0},
	"smelting": {"mount":Vector2(6, 580), "effect":Vector2(35, 587), "supply":Vector2(35, 637), "effective":Vector2(35, 656), "slider":Vector2(44, 605), "width":180.0, "track":154.0},
	"condensation": {"mount":Vector2(586, 580), "effect":Vector2(615, 587), "supply":Vector2(615, 637), "effective":Vector2(615, 656), "slider":Vector2(624, 605), "width":180.0, "track":154.0},
}
var _enabled: Array = []
var _loads: Dictionary = {}
var _fields: Dictionary = {}
var _connections: Dictionary = {}
var _clock: float = -1.0
var _phase: float = 0.0
var diagnostics := {"draws":0, "field_updates":0, "active_frames":0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(808, 835)
	set_process(false)
	_add_core()
	for id in IDS:
		_add_work(id, PORTS[id], 1, AMBER if id in ["weapons", "smelting"] else BLUE)
		var ends: Array = ROUTES[id]
		var start: Vector2 = ends[0]
		var finish: Vector2 = ends[1]
		var flow := _new_work(Rect2(start, Vector2(start.distance_to(finish), 13)), 2, AMBER if id in ["weapons", "smelting"] else BLUE)
		flow.rotation = (finish - start).angle()
		flow.position -= Vector2(0, 6.5).rotated(flow.rotation)
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

func _add_work(id: String, rect: Rect2, kind: int, tint: Color) -> void:
	_fields[id] = _new_work(rect, kind, tint)

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

func _draw() -> void:
	diagnostics.draws += 1
	draw_texture_rect(FOUR if "condensation" in _enabled else THREE, Rect2(0, 0, 808, 835), false)
