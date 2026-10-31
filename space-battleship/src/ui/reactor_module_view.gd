extends Control
## One module's surface and its own local, load-driven working mechanism.
const SOURCE_SIZE := Vector2(1187.0,1326.0)
const VIEW_SIZE := Vector2(808.0,835.0)
const WORK_SHADER = preload("res://assets/ui/reactor/b01/modular-module-work.gdshader")
const WORK_SURFACES := {
	"weapons": preload("res://assets/ui/reactor/b01/modular-weapons-work.png"),
	"defence": preload("res://assets/ui/reactor/b01/modular-defence-work.png"),
	"smelting": preload("res://assets/ui/reactor/b01/modular-smelting-work.png"),
	"condensation": preload("res://assets/ui/reactor/b01/modular-condensation-work.png"),
}
const KINDS := {"weapons":0, "defence":1, "smelting":2, "condensation":3}
# Conservative UV envelopes of each shader's nonzero device-local work.
# Paint only these pixels; the shader maps screen coordinates back to the
# original full-device UV so the visible result and phase stay identical.
const WORK_BOUNDS := {
	"weapons": Rect2(0.0, 0.17, 0.29, 0.31),
	"defence": Rect2(0.43, 0.06, 0.57, 0.78),
	"smelting": Rect2(0.34, 0.38, 0.46, 0.50),
	"condensation": Rect2(0.34, 0.12, 0.53, 0.78),
}
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
	var bounds: Rect2 = WORK_BOUNDS[id]
	_effect.position = size * bounds.position
	_effect.size = size * bounds.size
	_effect.color = Color.WHITE
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work = ShaderMaterial.new()
	_work.shader = WORK_SHADER
	_work.set_shader_parameter("module_kind",KINDS[id])
	_work.set_shader_parameter("work_surface",WORK_SURFACES[id])
	_work.set_shader_parameter("work_origin_px",position)
	_work.set_shader_parameter("work_size_px",size)
	_work.set_shader_parameter("work_view_size_px",VIEW_SIZE)
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
