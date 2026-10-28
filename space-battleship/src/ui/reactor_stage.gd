extends Control
## Local scene geometry only. Powers are already-adopted owner presentation values.
const ATLAS = preload("res://assets/ui/reactor/centered-v1/static-bodies.png")
const SUPPORTS = preload("res://assets/ui/reactor/centered-v1/supports.png")
const MOUNTING_PLATE = preload("res://assets/ui/reactor/centered-v1/mounting-plate.png")
const MOUNTING_PLATE_THREE = preload("res://assets/ui/reactor/centered-v1/mounting-plate-three.png")
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
const SUPPORT_REGIONS := {"weapons":Rect2(525,136,486,302),"defence":Rect2(1037,150,464,283),"smelting":Rect2(23,607,479,281),"condensation":Rect2(527,597,480,308)}
const SUPPORT_ORIGINS := {"weapons":Vector2(10,250),"defence":Vector2(520,238),"smelting":Vector2(12,643),"condensation":Vector2(510,632)}
const SUPPORT_SCALES := {"weapons":0.53,"defence":0.56,"smelting":0.55,"condensation":0.57}
const OPERATING_ANCHORS := {
	"weapons":{"effect":Vector2(40,315),"supply":Vector2(40,339),"slider":Vector2(48,371),"width":178.0,"track":136.0},
	"defence":{"effect":Vector2(555,314),"supply":Vector2(555,338),"slider":Vector2(583,368),"width":183.0,"track":135.0},
	"smelting":{"effect":Vector2(68,711),"supply":Vector2(68,735),"slider":Vector2(82,769),"width":168.0,"track":125.0},
	"condensation":{"effect":Vector2(560,711),"supply":Vector2(560,735),"slider":Vector2(578,769),"width":171.0,"track":145.0}}
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
		ends[0] += _normal(id)*13.0
		ends[1] -= _normal(id)*16.0
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
	# Page-space points follow the visible horizontal screen and inset track,
	# rather than scaling source-atlas points across different perspectives.
	return OPERATING_ANCHORS[id].duplicate()

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
	draw_texture_rect(MOUNTING_PLATE if "condensation" in _enabled else MOUNTING_PLATE_THREE, Rect2(0, 54, 808, 900), false)
	draw_rect(Rect2(0, 0, 808, 65), Color("efeede"))
	for id in _enabled:
		var source: Rect2 = SUPPORT_REGIONS[id]
		draw_texture_rect_region(SUPPORTS,Rect2(SUPPORT_ORIGINS[id],source.size*float(SUPPORT_SCALES[id])),source)
		var console: Dictionary = OPERATING_ANCHORS[id]
		var face := Rect2(console.effect-Vector2(5,1),Vector2(float(console.width)+7.0,49.0))
		draw_rect(face,Color("123843",0.93))
		draw_rect(face,Color("57989b",0.75),false,1.0)
	draw_texture_rect_region(SUPPORTS,Rect2(158,797,491,100),Rect2(1031,747,491,100))
	# Each short terminal sleeve follows its own artwork socket and enters
	# behind the device lip; the shared plate carries the longer buried run.
	for id in _enabled:
		var input: Vector2 = _ports(str(id))[1]
		var toward_core: Vector2 = -_normal(str(id))
		draw_line(input-toward_core*11.0,input+toward_core*37.0,Color("082b36"),24.0,true)
		draw_line(input-toward_core*11.0,input+toward_core*37.0,Color("d9ddca"),19.0,true)
		draw_line(input-toward_core*11.0,input+toward_core*37.0,Color("176b79"),13.0,true)
		draw_line(input-toward_core*11.0,input+toward_core*37.0,Color("61d0cd"),5.0,true)
	for id in ["core"] + _enabled:
		var body_size: Vector2 = REGIONS[id].size * _scale(id)
		var target: Rect2 = Rect2(_centre(id) - body_size * 0.5, body_size)
		draw_texture_rect_region(ATLAS, target, REGIONS[id])
	for id in _enabled:
		var input: Vector2 = _ports(str(id))[1]
		draw_circle(input,9.0,Color("102e39"))
		draw_arc(input,9.0,0.0,TAU,24,Color("dbe3ce"),2.5,true)
		draw_circle(input,4.5,Color("59d7d3"))
	# A locked branch remains a sealed part of the shared manifold.
	for id in IDS:
		if id not in _enabled:
			_draw_closed_port(id)
	for id in _enabled:
		if str(id) == _selected: draw_arc(_centre(id), 113, -0.18, 0.18, 12, Color("81c9bf"), 3, true)

func _draw_closed_port(id: String) -> void:
	var port: Vector2 = _core_port(id)
	draw_circle(port, 16.0, Color("102d38"))
	draw_arc(port, 15.0, 0.0, TAU, 32, Color("e3dfc8"), 5.0, true)
	draw_arc(port, 9.0, 0.0, TAU, 32, Color("2e6871"), 2.0, true)
	draw_circle(port, 4.0, Color("183d48"))
