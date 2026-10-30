extends Control
## B01 painted reactor bay. Animation and power read accepted Owner presentation.
const IDLE = preload("res://assets/ui/reactor/b01/idle-console.png")
const ACTIVE = preload("res://assets/ui/reactor/b01/active-console.png")
const LOCKED_IDLE = preload("res://assets/ui/reactor/b01/locked-idle-console.png")
const LOCKED_ACTIVE = preload("res://assets/ui/reactor/b01/locked-active-console.png")
const LIVE = preload("res://assets/ui/reactor/b01/live-material.gdshader")
const EFFECT_MASK = preload("res://assets/ui/reactor/b01/effect-mask.png")
const MODULE_MASK = preload("res://assets/ui/reactor/b01/module-mask.png")
const PIPE_MASK = preload("res://assets/ui/reactor/b01/pipe-mask.png")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const OPERATING := {"weapons":{"row":0}, "defence":{"row":1}, "smelting":{"row":2}, "condensation":{"row":3}}
var _enabled: Array = []
var _loads: Dictionary = {}
var _clock: float = -1.0
var _phase: float = 0.0
var _paint: ShaderMaterial
var diagnostics := {"draws":0, "field_updates":0, "active_frames":0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(808, 835)
	_paint = ShaderMaterial.new()
	_paint.shader = LIVE
	_paint.set_shader_parameter("active_plate", ACTIVE)
	_paint.set_shader_parameter("locked_idle_plate", LOCKED_IDLE)
	_paint.set_shader_parameter("locked_active_plate", LOCKED_ACTIVE)
	_paint.set_shader_parameter("effect_mask", EFFECT_MASK)
	_paint.set_shader_parameter("module_mask", MODULE_MASK)
	_paint.set_shader_parameter("pipe_mask", PIPE_MASK)
	material = _paint
	set_process(false)

func control_layout(id: String) -> Dictionary:
	return OPERATING[id]

static func visibility_power(owner_load: float) -> float:
	var load: float = clampf(owner_load, 0.0, 1.0)
	return maxf(load, 0.18) if load > 0.0 else 0.0

func show_snapshot(ids: Array, loads: Dictionary) -> void:
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	_paint.set_shader_parameter("condensation_enabled", 1.0 if "condensation" in _enabled else 0.0)
	_paint.set_shader_parameter("core_load", visibility_power(float(_loads.get("core", 0.0))))
	for id in IDS:
		_paint.set_shader_parameter(id + "_load", visibility_power(float(_loads.get(id, 0.0))) if id in _enabled else 0.0)
	diagnostics.field_updates += 1
	queue_redraw()

func clear_snapshot() -> void:
	_enabled.clear()
	_loads.clear()
	_paint.set_shader_parameter("condensation_enabled", 0.0)
	_paint.set_shader_parameter("core_load", 0.0)
	for id in IDS: _paint.set_shader_parameter(id + "_load", 0.0)
	queue_redraw()

func advance_visual_clock(game_time: float, paused: bool) -> bool:
	if not is_visible_in_tree():
		_clock = -1.0
		return false
	var elapsed: float = 0.0 if _clock < 0.0 else maxf(0.0, game_time - _clock)
	_clock = game_time
	if paused or elapsed == 0.0 or float(_loads.get("core", 0.0)) <= 0.0: return false
	_phase = fmod(_phase + elapsed, 4096.0)
	_paint.set_shader_parameter("phase", _phase)
	diagnostics.active_frames += 1
	return true

func reset_clock() -> void:
	_clock = -1.0

func visual_phase() -> float:
	return _phase

func _draw() -> void:
	diagnostics.draws += 1
	draw_texture_rect(IDLE, Rect2(0, 0, 808, 835), false)
