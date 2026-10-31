extends Control
## Composable B01 bay: background, four physical routes, core, four devices.
const PipeView = preload("res://src/ui/reactor_pipe_view.gd")
const ModuleView = preload("res://src/ui/reactor_module_view.gd")
const PortContract = preload("res://src/ui/reactor_port_contract.gd")
const BAY = preload("res://assets/ui/reactor/b01/modular-bay-background.png")
const CORE = preload("res://assets/ui/reactor/b01/modular-core.png")
const CORE_WORK = preload("res://assets/ui/reactor/b01/modular-core-work.png")
const WEAPONS = preload("res://assets/ui/reactor/b01/r6-weapons.png")
const DEFENCE = preload("res://assets/ui/reactor/b01/r6-defence.png")
const SMELTING = preload("res://assets/ui/reactor/b01/r6-smelting.png")
const CONDENSATION = preload("res://assets/ui/reactor/b01/r6-condensation.png")
const CORE_FIELD = preload("res://assets/ui/reactor/b01/modular-core-field.gdshader")
const CONSOLE_COMPACT = preload("res://assets/ui/reactor/b01/modular-console-compact.png")
const CONSOLE_FOUR = preload("res://assets/ui/reactor/b01/modular-console-four.png")
const CLAMP_LEFT = preload("res://assets/ui/reactor/b01/modular-core-clamp-left.png")
const CLAMP_RIGHT = preload("res://assets/ui/reactor/b01/modular-core-clamp-right.png")
const GIMBAL_REAR = preload("res://assets/ui/reactor/b01/modular-core-gimbal-rear-00.png")
const GIMBAL_FRONT = preload("res://assets/ui/reactor/b01/modular-core-gimbal-front-00.png")
const IDS := ["weapons", "defence", "smelting", "condensation"]
const OPERATING := {"weapons":{"row":0}, "defence":{"row":1}, "smelting":{"row":2}, "condensation":{"row":3}}
const SOURCE_SIZE := Vector2(1187.0, 1326.0)
const VIEW_SIZE := Vector2(808.0, 835.0)
const MODULES := {
	"weapons": WEAPONS,
	"defence": DEFENCE,
	"smelting": SMELTING,
	"condensation": CONDENSATION,
}
var _pipes: Dictionary = {}
var _modules: Dictionary = {}
var _bay: Sprite2D
var _core_field: ColorRect
var _field_material: ShaderMaterial
var _console: Sprite2D
var _clamp_left: Sprite2D
var _clamp_right: Sprite2D
var _gimbal_back: Sprite2D
var _gimbal_front: Sprite2D
var _enabled: Array = []
var _loads: Dictionary = {}
var _static_viewport: SubViewport
var _static_layer: Sprite2D
var _static_originals: Array[Sprite2D] = []
var _static_generation: int = 0
var _static_ids: Array = []
var _clock: float = -1.0
var _phase: float = 0.0
var diagnostics := {"draws":0, "field_updates":0, "active_frames":0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = VIEW_SIZE
	set_process(false)
	_bay = _full_layer(BAY)
	for id in IDS:
		var pipe: Control = PipeView.new()
		pipe.size = VIEW_SIZE
		pipe.configure(id)
		pipe.visible = false
		add_child(pipe)
		_pipes[id] = pipe
	_gimbal_back = _central_layer(GIMBAL_REAR)
	var core := _source_layer(CORE,Rect2(385,0,418,638))
	core.visible = true
	_core_field = ColorRect.new()
	_core_field.position = Vector2(283,95)
	_core_field.size = Vector2(244,220)
	_core_field.color = Color.WHITE
	_core_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_material = ShaderMaterial.new()
	_field_material.shader = CORE_FIELD
	_field_material.set_shader_parameter("core_work_surface",CORE_WORK)
	_core_field.material = _field_material
	_core_field.visible = false
	add_child(_core_field)
	_gimbal_front = _central_layer(GIMBAL_FRONT)
	_clamp_left = _source_layer(CLAMP_LEFT,Rect2(395,285,190,75))
	_clamp_right = _source_layer(CLAMP_RIGHT,Rect2(603,285,190,75))
	# Keep the gripping feet on the globe's outer sockets; the centre stays
	# unobstructed so the chamber and the front/rear bearing read as a volume.
	_clamp_left.position.x -= 52.0
	_clamp_right.position.x += 52.0
	for id in IDS:
		var module: Control = ModuleView.new()
		module.configure(id,MODULES[id],PortContract.source_rect(id))
		module.visible = false
		add_child(module)
		_modules[id] = module
	_console = _source_layer(CONSOLE_FOUR,Rect2(0,670,1187,656))
	_console.modulate = Color(0.57,0.76,0.79)
	# Keep the source assets separate. Only the unchanged background, conduit
	# shells and console are composed once per availability state in a viewport.
	_static_viewport = SubViewport.new()
	_static_viewport.size = Vector2i(VIEW_SIZE)
	_static_viewport.disable_3d = true
	_static_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_static_viewport)
	_static_layer = Sprite2D.new()
	_static_layer.centered = false
	_static_layer.texture = _static_viewport.get_texture()
	_static_layer.visible = false
	add_child(_static_layer)
	move_child(_static_layer, 0)

func control_layout(id: String) -> Dictionary:
	return OPERATING[id]

static func visibility_power(owner_load: float) -> float:
	var load: float = clampf(owner_load, 0.0, 1.0)
	return maxf(load, 0.18) if load > 0.0 else 0.0

func show_snapshot(ids: Array, loads: Dictionary) -> void:
	var static_changed: bool = ids != _static_ids
	_enabled = ids.duplicate()
	_loads = loads.duplicate()
	_console.texture = CONSOLE_FOUR if _enabled.size() >= 4 else CONSOLE_COMPACT
	if static_changed:
		_static_ids = ids.duplicate()
		_rebuild_static_cache()
	for id in IDS:
		var enabled: bool = id in _enabled
		_pipes[id].visible = enabled
		_modules[id].visible = enabled
		var workload: float = visibility_power(float(_loads.get(id,0.0))) if enabled else 0.0
		_pipes[id].set_workload(workload)
		_modules[id].set_workload(workload)
	_core_field.visible = float(_loads.get("core",0.0)) > 0.0
	_gimbal_back.visible = true
	_gimbal_front.visible = true
	_field_material.set_shader_parameter("load_fraction",visibility_power(float(_loads.get("core",0.0))))
	_field_material.set_shader_parameter("route_loads",Vector4(
		visibility_power(float(_loads.get("weapons",0.0))) if "weapons" in _enabled else 0.0,
		visibility_power(float(_loads.get("defence",0.0))) if "defence" in _enabled else 0.0,
		visibility_power(float(_loads.get("smelting",0.0))) if "smelting" in _enabled else 0.0,
		visibility_power(float(_loads.get("condensation",0.0))) if "condensation" in _enabled else 0.0))
	diagnostics.field_updates += 1

func clear_snapshot() -> void:
	_static_generation += 1
	_static_ids.clear()
	_static_layer.visible = false
	for original in _static_originals: original.visible = true
	_enabled.clear()
	_loads.clear()
	_core_field.visible = false
	_gimbal_back.visible = false
	_gimbal_front.visible = false
	for id in IDS:
		_pipes[id].visible = false
		_modules[id].visible = false

func _rebuild_static_cache() -> void:
	_static_generation += 1
	var generation: int = _static_generation
	_static_layer.visible = false
	for original in _static_originals: original.visible = true
	_static_originals.clear()
	for child in _static_viewport.get_children():
		_static_viewport.remove_child(child)
		child.queue_free()
	_static_originals.append(_bay)
	_clone_static_sprite(_bay)
	for id in IDS:
		if id in _static_ids:
			var shell: Sprite2D = _pipes[id]._shell
			_static_originals.append(shell)
			_clone_static_sprite(shell)
	_static_originals.append(_console)
	_clone_static_sprite(_console)
	_static_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_finish_static_cache(generation)

func _clone_static_sprite(original: Sprite2D) -> void:
	var copy := Sprite2D.new()
	copy.texture = original.texture
	copy.centered = original.centered
	copy.position = original.position
	copy.scale = original.scale
	copy.modulate = original.modulate
	_static_viewport.add_child(copy)

func _finish_static_cache(generation: int) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if generation != _static_generation: return
	_static_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for original in _static_originals: original.visible = false
	_static_layer.visible = true

func advance_visual_clock(game_time: float, paused: bool) -> bool:
	if not is_visible_in_tree():
		_clock = -1.0
		return false
	var elapsed: float = 0.0 if _clock < 0.0 else maxf(0.0, game_time-_clock)
	_clock = game_time
	if paused or elapsed == 0.0 or float(_loads.get("core",0.0)) <= 0.0: return false
	_phase = fmod(_phase+elapsed,4096.0)
	_field_material.set_shader_parameter("phase",_phase)
	for id in _enabled:
		_pipes[id].set_visual_phase(_phase)
		_modules[id].set_visual_phase(_phase)
	diagnostics.active_frames += 1
	return true

func reset_clock() -> void:
	_clock = -1.0

func visual_phase() -> float:
	return _phase

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

func _central_layer(texture: Texture2D) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = texture
	layer.position = Vector2(595,330) * VIEW_SIZE / SOURCE_SIZE
	layer.scale = VIEW_SIZE / SOURCE_SIZE
	layer.visible = false
	add_child(layer)
	return layer
