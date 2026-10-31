extends Control
## One module's surface and its own local, load-driven working mechanism.
const SOURCE_SIZE := Vector2(1187.0,1326.0)
const VIEW_SIZE := Vector2(808.0,835.0)
const WORK_SHADER = preload("res://assets/ui/reactor/b01/modular-module-work.gdshader")
const KINDS := {"weapons":0, "defence":1, "smelting":2, "condensation":3}
var _work: ShaderMaterial
var _effect: ColorRect
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
	_effect.position = Vector2.ZERO
	_effect.size = size
	_effect.color = Color.WHITE
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work = ShaderMaterial.new()
	_work.shader = WORK_SHADER
	_work.set_shader_parameter("module_kind",KINDS[id])
	_effect.material = _work
	_effect.visible = false
	add_child(_effect)

func set_workload(value: float) -> void:
	_load = clampf(value,0.0,1.0)
	_effect.visible = _load > 0.0
	_work.set_shader_parameter("load_fraction",_load)

func set_visual_phase(value: float) -> void:
	if _load > 0.0:
		_work.set_shader_parameter("phase",value)
