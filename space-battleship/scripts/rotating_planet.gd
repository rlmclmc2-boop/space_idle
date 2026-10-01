extends ColorRect
## Reusable sphere with unlit equirectangular maps. Speeds are turns/second.
## Owner supplies time: no TIME uniform, hidden/paused views freeze exactly.
const SURFACE := preload("res://assets/planets/toon/origin-surface.svg")
const CLOUDS := preload("res://assets/planets/toon/origin-clouds.svg")
@export var surface_map: Texture2D = SURFACE
@export var cloud_map: Texture2D = CLOUDS
@export var surface_speed := 0.006
@export var cloud_speed := 0.0073
@export_range(0.0, 1.0) var glow_strength := 0.30
@export_range(0.0, 1.0) var shadow_strength := 0.86
@export_range(0.0, 1.0) var cloud_opacity := 0.65
@export var atmosphere_color := Color("5ac8f0")
@export var light_direction := Vector3(0.65, -0.45, 0.62)
var phases := Vector2.ZERO
var parameter_writes := 0
var globe_material := ShaderMaterial.new()
var visual_clock := 0.0
var extent := 1.09
# Optional visual fields share the existing planet.visual dictionary. No IDs here.
const VISUAL_DEFAULTS := {
	"emission": 0.0, "detailScale": 1.0, "detailStrength": 1.0,
	"axisRatio": 1.0, "coronaWidth": 0.02, "pulseStrength": 0.0,
	"pulseSpeed": 0.08, "flareStrength": 0.0, "beamLength": 0.0,
	"beamWidth": 0.13, "beamSpeed": 1.6, "magnetosphere": 0.0,
}
const VISUAL_UNIFORMS := {
	"emission": "emission", "detailScale": "detail_scale", "detailStrength": "detail_strength",
	"axisRatio": "axis_ratio", "coronaWidth": "corona_width", "pulseStrength": "pulse_strength",
	"pulseSpeed": "pulse_speed", "flareStrength": "flare_strength", "beamLength": "beam_length",
	"beamWidth": "beam_width", "beamSpeed": "beam_speed", "magnetosphere": "magnetosphere",
}

func configure_visual(appearance: Dictionary) -> void:
	for key in VISUAL_DEFAULTS:
		var value = appearance.get(key, VISUAL_DEFAULTS[key])
		var number := float(value) if value is float or value is int else float(VISUAL_DEFAULTS[key])
		if not is_finite(number):number = float(VISUAL_DEFAULTS[key])
		globe_material.set_shader_parameter(VISUAL_UNIFORMS[key], maxf(0.0, number))
	for key in {"surfaceTint":"surface_tint", "shadowTint":"shadow_tint"}:
		var fallback := "ffffff" if key == "surfaceTint" else "777777"
		var value := str(appearance.get(key, fallback))
		globe_material.set_shader_parameter("surface_tint" if key == "surfaceTint" else "shadow_tint", Color(value) if Color.html_is_valid(value) else Color(fallback))
	extent = maxf(1.09, 1.0 + minf(1.0, float(globe_material.get_shader_parameter("corona_width"))) * 4.0)
	extent = maxf(extent, minf(10.0, float(globe_material.get_shader_parameter("beam_length"))) + 0.2)
	globe_material.set_shader_parameter("extent", extent)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_material.shader = preload("res://scripts/rotating_planet.gdshader")
	material = globe_material

func _ready() -> void:
	apply_settings()

func apply_settings() -> void:
	for key in ["surface_map", "cloud_map", "glow_strength", "shadow_strength", "cloud_opacity", "atmosphere_color", "light_direction"]:
		globe_material.set_shader_parameter(key, get(key))

func advance(delta: float, paused := false) -> void:
	if paused or not is_visible_in_tree() or delta <= 0.0:return
	phases.x = fposmod(phases.x + delta * surface_speed, 1.0)
	phases.y = fposmod(phases.y + delta * cloud_speed, 1.0)
	visual_clock = fposmod(visual_clock + delta, 3600.0)
	globe_material.set_shader_parameter("phase", phases)
	globe_material.set_shader_parameter("visual_clock", visual_clock)
	parameter_writes += 2

func fit_sphere(center: Vector2, radius: float) -> void:
	position = center - Vector2.ONE * radius * extent
	size = Vector2.ONE * radius * 2.0 * extent
