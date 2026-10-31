extends Control
## Composable B01 bay: background, four physical routes, core, four devices.
const PipeView = preload("res://src/ui/reactor_pipe_view.gd")
const ModuleView = preload("res://src/ui/reactor_module_view.gd")
const BAY = preload("res://assets/ui/reactor/b01/modular-bay-background.png")
const CORE = preload("res://assets/ui/reactor/b01/modular-core.png")
const WEAPONS = preload("res://assets/ui/reactor/b01/modular-weapons.png")
const DEFENCE = preload("res://assets/ui/reactor/b01/modular-defence.png")
const SMELTING = preload("res://assets/ui/reactor/b01/modular-smelting.png")
const CONDENSATION = preload("res://assets/ui/reactor/b01/modular-condensation.png")
const CORE_FIELD = preload("res://assets/ui/reactor/b01/modular-core-field.gdshader")
const CONSOLE_COMPACT = preload("res://assets/ui/reactor/b01/modular-console-compact.png")
const CONSOLE_FOUR = preload("res://assets/ui/reactor/b01/modular-console-four.png")
const CLAMP_LEFT = preload("res://assets/ui/reactor/b01/modular-core-clamp-left.png")
const CLAMP_RIGHT = preload("res://assets/ui/reactor/b01/modular-core-clamp-right.png")
const CORE_ROTOR = preload("res://assets/ui/reactor/b01/modular-core-rotor.png")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const OPERATING := {"weapons":{"row":0}, "defence":{"row":1}, "smelting":{"row":2}, "condensation":{"row":3}}
const SOURCE_SIZE := Vector2(1187.0, 1326.0)
const VIEW_SIZE := Vector2(808.0, 835.0)
const MODULES := {
	"weapons": {"texture":WEAPONS, "source_rect":Rect2(0,70,359,271)},
	"defence": {"texture":DEFENCE, "source_rect":Rect2(893,40,294,271)},
	"smelting": {"texture":SMELTING, "source_rect":Rect2(55,380,315,276)},
	"condensation": {"texture":CONDENSATION, "source_rect":Rect2(845,380,291,283)},
}
var _pipes: Dictionary = {}
var _modules: Dictionary = {}
var _core_field: ColorRect
var _field_material: ShaderMaterial
var _console: Sprite2D
var _clamp_left: Sprite2D
var _clamp_right: Sprite2D
var _rotor: Sprite2D
var _clamp_left_home: Vector2
var _clamp_right_home: Vector2
var _enabled: Array = []
var _loads: Dictionary = {}
var _clock: float = -1.0
var _phase: float = 0.0
var diagnostics := {"draws":0, "field_updates":0, "active_frames":0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = VIEW_SIZE
	set_process(false)
	_full_layer(BAY)
	for id in IDS:
		var pipe: Control = PipeView.new()
		pipe.size = VIEW_SIZE
		pipe.configure(id)
		pipe.visible = false
		add_child(pipe)
		_pipes[id] = pipe
	var core := _source_layer(CORE,Rect2(385,0,418,638))
	core.visible = true
	_core_field = ColorRect.new()
	_core_field.position = Vector2(283,95)
	_core_field.size = Vector2(244,220)
	_core_field.color = Color.WHITE
	_core_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_material = ShaderMaterial.new()
	_field_material.shader = CORE_FIELD
	_core_field.material = _field_material
	_core_field.visible = false
	add_child(_core_field)
	_rotor = Sprite2D.new()
	_rotor.texture = CORE_ROTOR
	_rotor.position = Vector2(595,330) * VIEW_SIZE / SOURCE_SIZE
	_rotor.scale = VIEW_SIZE / SOURCE_SIZE
	_rotor.visible = false
	add_child(_rotor)
	_clamp_left = _source_layer(CLAMP_LEFT,Rect2(395,300,190,45))
	_clamp_right = _source_layer(CLAMP_RIGHT,Rect2(603,300,190,45))
	_clamp_left_home = _clamp_left.position
	_clamp_right_home = _clamp_right.position
	for id in IDS:
		var module: Control = ModuleView.new()
		module.configure(id,MODULES[id].texture,MODULES[id].source_rect)
		module.visible = false
		add_child(module)
		_modules[id] = module
	_console = _source_layer(CONSOLE_FOUR,Rect2(0,670,1187,656))

func control_layout(id: String) -> Dictionary:
	return OPERATING[id]

static func visibility_power(owner_load: float) -> float:
	var load: float = clampf(owner_load, 0.0, 1.0)
	return maxf(load, 0.18) if load > 0.0 else 0.0

func show_snapshot(ids: Array, loads: Dictionary) -> void:
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	_console.texture = CONSOLE_FOUR if _enabled.size() >= 4 else CONSOLE_COMPACT
	for id in IDS:
		var enabled: bool = id in _enabled
		_pipes[id].visible = enabled
		_modules[id].visible = enabled
		var workload: float = visibility_power(float(_loads.get(id,0.0))) if enabled else 0.0
		_pipes[id].set_workload(workload)
		_modules[id].set_workload(workload)
	_core_field.visible = float(_loads.get("core",0.0)) > 0.0
	_rotor.visible = _core_field.visible
	_field_material.set_shader_parameter("load_fraction",visibility_power(float(_loads.get("core",0.0))))
	_set_clamp_travel(0.0)
	diagnostics.field_updates += 1

func clear_snapshot() -> void:
	_enabled.clear()
	_loads.clear()
	_core_field.visible = false
	_rotor.visible = false
	_set_clamp_travel(0.0)
	for id in IDS:
		_pipes[id].visible = false
		_modules[id].visible = false

func advance_visual_clock(game_time: float, paused: bool) -> bool:
	if not is_visible_in_tree():
		_clock = -1.0
		return false
	var elapsed: float = 0.0 if _clock < 0.0 else maxf(0.0, game_time-_clock)
	_clock = game_time
	if paused or elapsed == 0.0 or float(_loads.get("core",0.0)) <= 0.0: return false
	_phase = fmod(_phase+elapsed,4096.0)
	_field_material.set_shader_parameter("phase",_phase)
	_rotor.rotation = _phase*0.55
	var cycle: float = fmod(_phase,5.2)
	var travel: float = 0.0
	if cycle < 1.2:
		travel = _smooth_travel(cycle/1.2)
	elif cycle < 3.1:
		travel = 1.0
	elif cycle < 4.3:
		travel = 1.0-_smooth_travel((cycle-3.1)/1.2)
	_set_clamp_travel(travel)
	for id in _enabled:
		_pipes[id].set_visual_phase(_phase)
		_modules[id].set_visual_phase(_phase)
	diagnostics.active_frames += 1
	return true

func reset_clock() -> void:
	_clock = -1.0

func visual_phase() -> float:
	return _phase

static func _smooth_travel(t: float) -> float:
	return t*t*(3.0-2.0*t)

func _set_clamp_travel(t: float) -> void:
	var travel: float = t*10.0*VIEW_SIZE.x/SOURCE_SIZE.x
	_clamp_left.position = _clamp_left_home + Vector2(travel,0.0)
	_clamp_right.position = _clamp_right_home - Vector2(travel,0.0)

func _full_layer(texture: Texture2D) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = texture
	layer.centered = false
	layer.position = Vector2.ZERO
	layer.scale = VIEW_SIZE / SOURCE_SIZE
	add_child(layer)
	return layer

func _source_layer(texture: Texture2D, source_rect: Rect2) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = texture
	layer.centered = false
	layer.position = source_rect.position * VIEW_SIZE / SOURCE_SIZE
	layer.scale = VIEW_SIZE / SOURCE_SIZE
	add_child(layer)
	return layer
