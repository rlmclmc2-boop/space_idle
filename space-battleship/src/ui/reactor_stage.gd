extends Control
## Local scene geometry only. Powers are already-adopted owner presentation values.
const ATLAS = preload("res://assets/ui/reactor/centered-v1/static-bodies.png")
const SUPPORTS = preload("res://assets/ui/reactor/centered-v1/supports.png")
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
const SUPPORT_REGIONS := {"weapons":Rect2(525,136,486,302),"defence":Rect2(1037,150,464,283),"smelting":Rect2(23,607,479,281),"condensation":Rect2(527,597,480,308)}
const SUPPORT_ORIGINS := {"weapons":Vector2(10,250),"defence":Vector2(520,238),"smelting":Vector2(12,643),"condensation":Vector2(510,632)}
const SUPPORT_SCALES := {"weapons":0.53,"defence":0.56,"smelting":0.55,"condensation":0.57}
const OPERATING_ANCHORS := {
	"weapons":{"effect":Vector2(593,259),"supply":Vector2(594,301),"slider":Vector2(592,365),"width":188.0,"track":124.0},
	"defence":{"effect":Vector2(1100,277),"supply":Vector2(1100,315),"slider":Vector2(1141,371),"width":212.0,"track":132.0},
	"smelting":{"effect":Vector2(125,730),"supply":Vector2(125,773),"slider":Vector2(156,839),"width":178.0,"track":130.0},
	"condensation":{"effect":Vector2(617,733),"supply":Vector2(617,771),"slider":Vector2(619,843),"width":174.0,"track":150.0}}
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
	var layout: Dictionary = OPERATING_ANCHORS[id].duplicate()
	for key in ["effect","supply","slider"]:
		layout[key] = SUPPORT_ORIGINS[id]+(layout[key]-SUPPORT_REGIONS[id].position)*float(SUPPORT_SCALES[id])
	return layout

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
	draw_rect(Rect2(0, 0, 808, 900), Color("102c38"))
	draw_rect(Rect2(0, 0, 808, 65), Color("efeede"))
	# An open technical mounting surface, never four cabinet cells.
	for x in [18.0, 790.0]: draw_line(Vector2(x, 83), Vector2(x, 797), Color("244c57"), 1, true)
	for id in _enabled:
		var source: Rect2 = SUPPORT_REGIONS[id]
		draw_texture_rect_region(SUPPORTS,Rect2(SUPPORT_ORIGINS[id],source.size*float(SUPPORT_SCALES[id])),source)
	draw_texture_rect_region(SUPPORTS,Rect2(158,797,491,100),Rect2(1031,747,491,100))
	for id in _enabled:
		_draw_coupling(str(id))
	for id in ["core"] + _enabled:
		var body_size: Vector2 = REGIONS[id].size * _scale(id)
		var target: Rect2 = Rect2(_centre(id) - body_size * 0.5, body_size)
		draw_texture_rect_region(ATLAS, target, REGIONS[id])
	for id in _enabled:
		if str(id) == _selected: draw_arc(_centre(id), 113, -0.18, 0.18, 12, Color("81c9bf"), 3, true)

func _draw_coupling(id: String) -> void:
	var ends: Array = _ports(id)
	var normal: Vector2 = _normal(id)
	var angle: float = normal.angle()
	var span: float = ends[0].distance_to(ends[1])
	var material_scale: float = 0.135
	# Repeat the straight window at uniform scale, never squash a complete
	# three-dimensional sleeve to fit the two different socket gaps.
	var start: float = 13.0
	var finish: float = span-16.0
	var offset: float = start
	while offset < finish:
		var piece: float = minf(14.04,finish-offset)
		draw_set_transform(ends[0]+normal*offset,angle,Vector2.ONE*material_scale)
		draw_texture_rect_region(SUPPORTS,Rect2(0,-44,piece/material_scale,88),Rect2(209,280,piece/material_scale,88))
		offset += piece
	draw_set_transform(ends[0]-normal*6.0,angle,Vector2.ONE*material_scale)
	draw_texture_rect_region(SUPPORTS,Rect2(-38,-95,180,185),Rect2(30,226,180,185))
	draw_set_transform(ends[1]+normal*INSERTION_SOURCE_PX*_scale(id),angle,Vector2.ONE*material_scale)
	draw_texture_rect_region(SUPPORTS,Rect2(-172,-95,194,185),Rect2(310,226,194,185))
	draw_set_transform(Vector2.ZERO)
