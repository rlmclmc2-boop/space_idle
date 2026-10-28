extends Control
## Display-only 3D architecture over the analytical surface. No building hit targets.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
const SURFACE_UV := {"refinery": Vector2(0.45, 0.70), "equipment": Vector2(0.36, 0.36)}
var _viewport := SubViewport.new()
var _image := TextureRect.new()
var _world := Node3D.new()
var _camera := Camera3D.new()
var _models: Dictionary = {}
var _owned: Array = []
var _occluder := MeshInstance3D.new()
var _radius := 3.0
var _clock := 0.0
var _phase := 0.0
var _body_pixels := 200.0
var _last_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_viewport.add_child(_world)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.texture = _viewport.get_texture()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_image)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("91aeb6")
	environment.environment.ambient_light_energy = 0.42
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -38, 0)
	light.light_color = Color("fff0d8")
	light.light_energy = 0.95
	_world.add_child(light)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position.z = 24
	_world.add_child(_camera)
	var sphere := SphereMesh.new()
	sphere.radius = _radius
	sphere.height = _radius * 2
	sphere.radial_segments = 64
	sphere.rings = 32
	_occluder.mesh = sphere
	# Transparent depth mask is drawn before the transparent architecture.
	# The visible surface/light/clouds remain owned by rotating_planet.gdshader.
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, depth_draw_always; void fragment(){ ALBEDO=vec3(0.0); ALPHA=0.0; }"
	var mask := ShaderMaterial.new()
	mask.shader = shader
	mask.render_priority = -128
	_occluder.material_override = mask
	_world.add_child(_occluder)
	for kind in KINDS:
		var model: Node3D = load("res://assets/planets/facilities_v2/" + kind + ".glb").instantiate()
		_world.add_child(model)
		_models[kind] = model
		_transparent_materials(model)
		model.visible = false
	resized.connect(_layout)
	_layout()

func _transparent_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(index)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color.a = 0.999
				material.render_priority = 0
				node.set_surface_override_material(index, material)
	for child in node.get_children(): _transparent_materials(child)

func configure(entries: Array) -> void:
	_owned = []
	for entry in entries:
		var kind: String = str(entry.type)
		if _models.has(kind) and not kind in _owned: _owned.append(kind)
	for kind in _models: _models[kind].visible = kind in _owned
	update_pose(_clock, _phase, _body_pixels)

func _layout() -> void:
	if size.x < 1 or size.y < 1: return
	_viewport.size = Vector2i(size)
	_last_size = size
	_camera.size = _radius * size.y / maxf(1, _body_pixels)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_pose(clock: float, surface_phase: float, body_pixels: float) -> void:
	_clock = clock
	_phase = surface_phase
	_body_pixels = body_pixels
	if not is_inside_tree(): return
	if size != _last_size or not is_equal_approx(_camera.size, _radius * size.y / maxf(1, body_pixels)): _layout()
	for kind in _owned:
		var model: Node3D = _models[kind]
		if SURFACE_UV.has(kind):
			var uv: Vector2 = SURFACE_UV[kind]
			var lon := (uv.x - 0.5 - surface_phase) * TAU
			var lat := (uv.y - 0.5) * PI
			var normal := Vector3(sin(lon) * cos(lat), -sin(lat), cos(lon) * cos(lat))
			var east := Vector3(cos(lon), 0, -sin(lon)).normalized()
			var north := east.cross(normal).normalized()
			# Model Y is local up. Its foundation lies on the surface tangent.
			model.transform = Transform3D(Basis(east, normal, north).scaled(Vector3.ONE * 0.24), normal * (_radius + 0.012))
		else:
			var path: Dictionary = preload("res://scripts/orbital_facilities.gd").path_for(kind)
			var a := 0.65 if kind == "shipyard" else float(path.phase) + clock * float(path.speed)
			var radial := _radius * float(path.radius)
			var xy := Vector2(cos(a) * radial, -sin(a) * radial * float(path.ratio)).rotated(-float(path.tilt))
			model.position = Vector3(xy.x, xy.y, sin(a) * radial * 0.7)
			model.rotation = Vector3(0.90, -0.25 + clock * 0.04, 0.10)
			model.scale = Vector3.ONE * (0.28 if kind == "auto_explore" else 0.34)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
