extends Node2D
## Existing scene shader and authored paintings. This surface never advances gameplay.
var _session
var _material := ShaderMaterial.new()
var _last_stage: int = -1
var _last_progress: float = -1.0
var _last_game_time: float = -1.0
var _last_streak: float = -1.0
var _last_hyperspace: float = -1.0
var _stars := MeshInstance2D.new()
var _surface := MeshInstance2D.new()

func _init(session) -> void:
	_session = session
	z_index = 0

func _ready() -> void:
	_material.shader = preload("res://scripts/starfield.gdshader")
	_material.set_shader_parameter("route_atlas", load("res://assets/backgrounds/hyperspace/routes_atlas.png"))
	var view := Vector2(_session.battle.view_size())
	# Polygon2D without a bound texture supplies zero UVs to the shader.
	# An explicit mesh preserves normalized UVs for the custom samplers.
	var surface_mesh := ArrayMesh.new()
	var surface_arrays: Array = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(view.x, 0, 0), Vector3(view.x, view.y, 0), Vector3.ZERO, Vector3(view.x, view.y, 0), Vector3(0, view.y, 0)])
	surface_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN])
	surface_arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(1, 0, 0, 0), Color(1, 0, 0, 0), Color(1, 0, 0, 0), Color(1, 0, 0, 0), Color(1, 0, 0, 0), Color(1, 0, 0, 0)])
	surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	_surface.mesh = surface_mesh
	_surface.material = _material
	add_child(_surface)
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var random := RandomNumberGenerator.new()
	random.seed = 9147 # Presentation-only star distribution; domain RNG is untouched.
	for index in 180:
		var colour := Color(random.randf_range(0.2, 0.9), random.randf(), random.randf(), 1.0)
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
			vertices.append(Vector3(corner.x, corner.y, 0))
			uv.append(corner)
			colors.append(colour)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_stars.mesh = mesh
	_stars.material = _material
	add_child(_stars)
	_process(0)

func _process(_dt: float) -> void:
	var facts: Dictionary = _session.campaign_system.scenery_facts()
	if _last_stage != int(facts.stage):
		_last_stage = int(facts.stage)
		var opening: bool = _last_stage in [1, 2]
		_material.set_shader_parameter("opening_enabled", opening)
		if opening:
			var texture: Texture2D = load("res://assets/backgrounds/opening/stage_%02d.png" % _last_stage)
			_material.set_shader_parameter("opening_texture", texture)
			var height: float = float(texture.get_height())
			_material.set_shader_parameter("opening_sample", Vector3(2.0 / height, 960.0 / height, maxf(0.0, height - 964.0) / height))
	var progress: float = float(facts.progress)
	if progress != _last_progress:
		_last_progress = progress
		_material.set_shader_parameter("opening_progress", progress)
		_material.set_shader_parameter("travel", progress * 4000.0)
	var game_time: float = float(_session.game_time)
	if game_time != _last_game_time:
		_last_game_time = game_time
		_material.set_shader_parameter("flight_time", game_time)
	var streak: float = 0.7 if facts.state in ["travel", "departing"] else 0.0
	if streak != _last_streak:
		_last_streak = streak
		_material.set_shader_parameter("streak", streak)
	var hyperspace: float = 1.0 if facts.state == "hyperspace" else 0.0
	if hyperspace != _last_hyperspace:
		_last_hyperspace = hyperspace
		_material.set_shader_parameter("hyperspace", hyperspace)
