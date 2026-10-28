extends Control
## Local scene geometry only. Powers are already-adopted owner presentation values.
const ATLAS = preload("res://assets/ui/reactor/centered-v1/static-bodies.png")
const FIELD = preload("res://assets/ui/reactor/centered-v1/working_fields.gdshader")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const CORE_CENTRE := Vector2(404, 440)
const REGIONS := {"core": Rect2(0, 0, 540, 512), "weapons": Rect2(546, 55, 478, 457), "defence": Rect2(1024, 0, 512, 512), "smelting": Rect2(0, 512, 536, 512), "condensation": Rect2(540, 512, 484, 512)}
const BODY_WIDTH := {"core":336.0, "weapons":214.0, "defence":214.0, "smelting":204.0, "condensation":210.0}
# Full atlas coordinates, measured at each actual socket mouth. Common normals
# describe the visible coupling axis; body placement is derived, never guessed
# independently of the connector. Source units remain source pixels.
const SOURCE_PORTS := {
	"weapons":{"core":Vector2(104,100),"input":Vector2(905,392),"outward":Vector2(-1,-1),"gap":104.0},
	"defence":{"core":Vector2(440,100),"input":Vector2(1166,388),"outward":Vector2(1,-1),"gap":104.0},
	"smelting":{"core":Vector2(104,420),"input":Vector2(424,596),"outward":Vector2(-1,1),"gap":32.0},
	"condensation":{"core":Vector2(440,420),"input":Vector2(651,632),"outward":Vector2(1,1),"gap":32.0}}
const INSERTION_SOURCE_PX := 16.0
const EFFECTS := {"core": Rect2(-89, -87, 180, 180), "weapons": Rect2(-37, -40, 68, 68), "defence": Rect2(-33, -30, 76, 68), "smelting": Rect2(-29, -57, 64, 90), "condensation": Rect2(-28, -49, 56, 84)}
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
		var ends: Array = _ports(id)
		ends[1] -= _normal(id) * INSERTION_SOURCE_PX * _scale(id)
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

func _scale(id: String) -> float:
	return float(BODY_WIDTH[id]) / float(REGIONS[id].size.x)

func _normal(id: String) -> Vector2:
	return SOURCE_PORTS[id].outward.normalized()

func _core_port(id: String) -> Vector2:
	return CORE_CENTRE + (SOURCE_PORTS[id].core - REGIONS.core.get_center()) * _scale("core")

func _centre(id: String) -> Vector2:
	if id == "core": return CORE_CENTRE
	var input_offset: Vector2 = (SOURCE_PORTS[id].input - REGIONS[id].get_center()) * _scale(id)
	return _core_port(id) + _normal(id) * float(SOURCE_PORTS[id].gap) - input_offset

func _ports(id: String) -> Array:
	var input: Vector2 = _centre(id) + (SOURCE_PORTS[id].input - REGIONS[id].get_center()) * _scale(id)
	return [_core_port(id), input]

func show_snapshot(ids: Array, loads: Dictionary, selected: String) -> void:
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	_selected = selected
	for id in _fields:
		_fields[id].visible = id == "core" or id in _enabled
		_fields[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	for id in _connections:
		_connections[id].visible = id in _enabled
		_connections[id].material.set_shader_parameter("power", clampf(float(_loads.get(id, 0.0)), 0.0, 1.0))
	queue_redraw()

func advance_visual_clock(game_time: float, paused: bool) -> void:
	if not is_visible_in_tree():
		_clock = -1.0
		return
	var elapsed: float = 0.0 if _clock < 0.0 else maxf(0.0, game_time - _clock)
	_clock = game_time
	if paused or elapsed == 0.0 or float(_loads.get("core", 0.0)) <= 0.0: return
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

func reset_clock() -> void:
	_clock = -1.0

func _draw() -> void:
	diagnostics.draws += 1
	draw_rect(Rect2(0, 0, 808, 900), Color("102c38"))
	draw_rect(Rect2(0, 0, 808, 65), Color("efeede"))
	# An open technical mounting surface, never four cabinet cells.
	for x in [18.0, 790.0]: draw_line(Vector2(x, 83), Vector2(x, 797), Color("244c57"), 1, true)
	for id in _enabled:
		var ends: Array = _ports(str(id))
		# Tube extends into the real mouth behind the device's opaque front lip.
		var inserted: Vector2 = ends[1] + _normal(id) * INSERTION_SOURCE_PX * _scale(id)
		draw_line(ends[0] + Vector2(0, 4), inserted + Vector2(0, 4), Color("071c26"), 30, true)
		draw_line(ends[0], inserted, Color("d8dfd5"), 23, true)
		draw_line(ends[0], inserted, Color("214d59"), 12, true)
	for id in ["core"] + _enabled:
		var body_size: Vector2 = REGIONS[id].size * _scale(id)
		var target: Rect2 = Rect2(_centre(id) - body_size * 0.5, body_size)
		draw_texture_rect_region(ATLAS, target, REGIONS[id])
	# Four different operating supports: accelerator rail, shield lip, process
	# sill and split condenser ledge. Controls are real children, never baked.
	if "weapons" in _enabled:
		draw_line(Vector2(28, 289), Vector2(28, 385), Color("d5dfd4"), 7, true)
		draw_line(Vector2(28, 385), Vector2(270, 385), Color("d5dfd4"), 7, true)
	if "defence" in _enabled:
		draw_arc(Vector2(650, 364), 30, 0.0, PI, 28, Color("b9d2cd"), 6, true)
		draw_line(Vector2(778, 289), Vector2(778, 384), Color("b9d2cd"), 6, true)
	if "smelting" in _enabled:
		draw_line(Vector2(30, 791), Vector2(270, 791), Color("d6ded2"), 9, true)
		draw_line(Vector2(30, 740), Vector2(30, 791), Color("315b64"), 7, true)
	if "condensation" in _enabled:
		draw_line(Vector2(532, 791), Vector2(650, 791), Color("bccfc9"), 6, true)
		draw_line(Vector2(778, 739), Vector2(778, 791), Color("bccfc9"), 6, true)
	for id in _enabled:
		if str(id) == _selected: draw_arc(_centre(id), 113, -0.18, 0.18, 12, Color("81c9bf"), 3, true)
