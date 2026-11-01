extends Control
## One module's surface and its own local, load-driven working mechanism.
const SOURCE_SIZE := Vector2(1187.0,1326.0)
const VIEW_SIZE := Vector2(808.0,835.0)
const WORK_SHADER = preload("res://assets/ui/reactor/b01/modular-module-work.gdshader")
const PortContract = preload("res://src/ui/reactor_port_contract.gd")
const WORK_SURFACES := {
	"weapons": preload("res://assets/ui/reactor/b01/r6-weapons-work.png"),
	"defence": preload("res://assets/ui/reactor/b01/r6-defence-work.png"),
	"smelting": preload("res://assets/ui/reactor/b01/r6-smelting-work.png"),
	"condensation": preload("res://assets/ui/reactor/b01/r6-condensation-work.png"),
}
const SHIELD_FRONT = preload("res://assets/ui/reactor/b01/r6-defence-front.png")
const SHIELD_FRONT_GLOW = preload("res://assets/ui/reactor/b01/modular-shield-front-glow.gdshader")
const KINDS := {"weapons":0, "defence":1, "smelting":2, "condensation":3}
# The work layer is cropped by the shared source-space contract.
var _work: ShaderMaterial
var _effect: ColorRect
var _front_effect: ColorRect
var _front_glow: ShaderMaterial
var _load: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func configure(id: String, texture: Texture2D, source_rect: Rect2) -> void:
	assert(KINDS.has(id))
	position = source_rect.position * VIEW_SIZE / SOURCE_SIZE
	size = source_rect.size * VIEW_SIZE / SOURCE_SIZE
	var surface := Sprite2D.new()
	surface.texture = texture
	surface.centered = false
	surface.scale = VIEW_SIZE / SOURCE_SIZE
	add_child(surface)
	_effect = ColorRect.new()
	var work_rect: Rect2 = PortContract.work_rect(id)
	_effect.position = (work_rect.position-source_rect.position) * VIEW_SIZE / SOURCE_SIZE
	_effect.size = work_rect.size * VIEW_SIZE / SOURCE_SIZE
	_effect.color = Color.WHITE
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work = ShaderMaterial.new()
	_work.shader = WORK_SHADER
	_work.set_shader_parameter("module_kind",KINDS[id])
	_work.set_shader_parameter("work_surface",WORK_SURFACES[id])
	_effect.material = _work
	_effect.visible = false
	add_child(_effect)
	if id == "defence":
		var front := Sprite2D.new()
		front.texture = SHIELD_FRONT
		front.centered = false
		front.scale = VIEW_SIZE / SOURCE_SIZE
		add_child(front)
		_front_effect = ColorRect.new()
		_front_effect.size = size
		_front_effect.color = Color.WHITE
		_front_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_glow = ShaderMaterial.new()
		_front_glow.shader = SHIELD_FRONT_GLOW
		_front_glow.set_shader_parameter("front_surface",SHIELD_FRONT)
		_front_effect.material = _front_glow
		_front_effect.visible = false
		add_child(_front_effect)

func set_workload(value: float) -> void:
	_load = clampf(value,0.0,1.0)
	_effect.visible = _load > 0.0
	_work.set_shader_parameter("load_fraction",_load)
	if _front_effect != null:
		_front_effect.visible = _load > 0.0
		_front_glow.set_shader_parameter("load_fraction",_load)

func set_visual_phase(value: float) -> void:
	if _load > 0.0:
		_work.set_shader_parameter("phase",value)
		if _front_glow != null:
			_front_glow.set_shader_parameter("phase",value)
