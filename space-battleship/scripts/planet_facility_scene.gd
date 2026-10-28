extends Control
## Display-only 3D architecture over the analytical surface. No building hit targets.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
## Fixed terrain anchors; both facilities follow the surface phase, not cloud motion.
const SURFACE_UV := {"refinery": Vector2(0.42, 0.34), "equipment": Vector2(0.44, 0.67)}
const WORK_PARTS := {
	"auto_explore": ["HabitatRingSpin", "SolarHingeLeft", "SolarHingeRight"],
	"refinery": ["IntakeWheelLeft", "IntakeWheelRight", "CoolingShutters"],
	"equipment": ["GantrySlide", "ToolArmSweep"],
	"shipyard": ["CraneSlide", "DockCollarSpin"]
}
var scene_center := Vector2.ZERO
var _viewport := SubViewport.new()
var _image := TextureRect.new()
var _world := Node3D.new()
var _camera := Camera3D.new()
var _models: Dictionary = {}
var _parts: Dictionary = {}
var _contact_materials: Dictionary = {}
var _owned: Array = []
var _occluder := MeshInstance3D.new()
var _radius := 3.0
var _clock := 0.0
var _phase := 0.0
var _body_pixels := 200.0
var _last_size := Vector2.ZERO
var _axis_ratio := 1.0
var _pulse_strength := 0.0
var _pulse_speed := 0.08
var _surface_clock := 0.0
var _workshop_arm_base_y := 0.0

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
		var model: Node3D = load("res://assets/planets/facilities_v5/" + kind + ".glb").instantiate()
		_world.add_child(model)
		_models[kind] = model
		var moving: Dictionary = {}
		for part_name in WORK_PARTS[kind]:
			var pivot := model.find_child(part_name, true, false) as Node3D
			assert(pivot != null, "Missing facility work pivot: " + kind + "/" + part_name)
			moving[part_name] = pivot
		_parts[kind] = moving
		if kind == "equipment": _install_workshop_illustration(model, moving)
		if SURFACE_UV.has(kind):
			var patch := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(3.5, 2.7)
			plane.subdivide_width = 8
			plane.subdivide_depth = 6
			patch.mesh = plane
			var contact := ShaderMaterial.new()
			contact.shader = preload("res://scripts/planet_contact_shadow.gdshader")
			contact.render_priority = -64
			patch.material_override = contact
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(patch)
			_contact_materials[kind] = contact
		_transparent_materials(model)
		model.visible = false
	resized.connect(_layout)
	_layout()

func _install_workshop_illustration(model: Node3D, moving: Dictionary) -> void:
	# The approved R5 silhouette is carried by two depth-tested, camera-facing
	# art layers. The original GLB keeps its named animation pivots and anchor.
	_hide_imported_meshes(model)
	var body := Sprite3D.new()
	body.name = "IllustratedWorkshopBody"
	body.texture = preload("res://assets/planets/facilities_v5/illustrated/workshop-body.png")
	body.pixel_size = 0.0031
	body.position = Vector3(0, 1.38, 0)
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.shaded = false
	body.double_sided = true
	model.add_child(body)
	var arm := Sprite3D.new()
	arm.name = "IllustratedToolArm"
	arm.texture = preload("res://assets/planets/facilities_v5/illustrated/workshop-arm.png")
	arm.pixel_size = body.pixel_size
	var arm_pivot := moving["ToolArmSweep"] as Node3D
	_workshop_arm_base_y = arm_pivot.position.y
	arm.position = body.position + Vector3(0, 0.01, 0) - arm_pivot.position
	arm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arm.shaded = false
	arm.double_sided = true
	arm_pivot.add_child(arm)

func _hide_imported_meshes(node: Node) -> void:
	if node is MeshInstance3D: node.visible = false
	for child in node.get_children(): _hide_imported_meshes(child)

func _transparent_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(index)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
				material.albedo_color.a = 0.999
				material.render_priority = 0
				node.set_surface_override_material(index, material)
	for child in node.get_children(): _transparent_materials(child)

func configure_shape(appearance: Dictionary) -> void:
	_axis_ratio = maxf(0.05, float(appearance.get("axisRatio", 1.0)))
	_pulse_strength = clampf(float(appearance.get("pulseStrength", 0.0)), 0.0, 0.05)
	_pulse_speed = maxf(0, float(appearance.get("pulseSpeed", 0.08)))

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
	_camera.position.x = -(scene_center.x - size.x * 0.5) * _radius / maxf(1, _body_pixels)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_pose(clock: float, surface_phase: float, body_pixels: float, surface_clock: float = -1.0) -> void:
	_clock = clock
	_phase = surface_phase
	_body_pixels = body_pixels
	if surface_clock >= 0: _surface_clock = surface_clock
	if not is_inside_tree(): return
	if size != _last_size or not is_equal_approx(_camera.size, _radius * size.y / maxf(1, body_pixels)): _layout()
	var pulse := 1.0 + _pulse_strength * sin(_surface_clock * TAU * _pulse_speed)
	_occluder.scale = Vector3(pulse, _axis_ratio * pulse, pulse)
	for kind in _owned:
		var model: Node3D = _models[kind]
		_animate_parts(kind, clock)
		if SURFACE_UV.has(kind):
			var uv: Vector2 = SURFACE_UV[kind]
			var lon := (uv.x - 0.5 - surface_phase) * TAU
			var lat := (uv.y - 0.5) * PI
			var point := Vector3(sin(lon) * cos(lat), -sin(lat), cos(lon) * cos(lat))
			var normal := Vector3(point.x, point.y / _axis_ratio, point.z).normalized()
			var east := Vector3(cos(lon), 0, -sin(lon)).normalized()
			var north := east.cross(normal).normalized()
			# Model Y is local up. Its foundation lies on the surface tangent.
			# Embed each broad contact pad into the tangent. The shadow is projected
			# onto the true ellipsoid, so both pad and shadow follow the same terrain.
			model.transform = Transform3D(Basis(east, normal, north).rotated(normal, 0.35 if kind == "refinery" else -0.20).scaled(Vector3.ONE * 0.35), Vector3(point.x, point.y * _axis_ratio, point.z) * (_radius * pulse) - normal * 0.055)
			_contact_materials[kind].set_shader_parameter("body_axes", Vector3(_radius * pulse, _radius * _axis_ratio * pulse, _radius * pulse))
		else:
			if kind == "shipyard":
				# Confirmed independent service berth outside the station orbit.
				# A rearward depth gap keeps 3D equipment clear, while its lower-right
				# screen footprint is outside the station's full projected envelope.
				model.position = Vector3(_radius * 1.09, -_radius * 0.88, -_radius * 0.33)
			else:
				var path: Dictionary = preload("res://scripts/orbital_facilities.gd").path_for(kind)
				var a := float(path.phase) + clock * float(path.speed)
				var radial := minf(_radius * float(path.radius), maxf(_radius * 1.10, (minf(scene_center.x, size.x - scene_center.x) - 82.0) * _radius / maxf(1, _body_pixels)))
				var xy := Vector2(cos(a) * radial, -sin(a) * radial * float(path.ratio)).rotated(-float(path.tilt))
				model.position = Vector3(xy.x, xy.y, sin(a) * radial * sqrt(1.0 - float(path.ratio) * float(path.ratio)))
			model.rotation = Vector3(0.90, -0.25 + (clock * 0.04 if kind == "auto_explore" else 0.0), 0.10)
			model.scale = Vector3.ONE * (0.28 if kind == "auto_explore" else 0.34)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _animate_parts(kind: String, clock: float) -> void:
	var moving: Dictionary = _parts[kind]
	match kind:
		"auto_explore":
			(moving["HabitatRingSpin"] as Node3D).rotation.y = clock * 0.28
			(moving["SolarHingeLeft"] as Node3D).rotation.z = sin(clock * 0.32) * 0.15
			(moving["SolarHingeRight"] as Node3D).rotation.z = -sin(clock * 0.32) * 0.15
		"refinery":
			(moving["IntakeWheelLeft"] as Node3D).rotation.z = clock * 1.6
			(moving["IntakeWheelRight"] as Node3D).rotation.z = -clock * 1.6
			(moving["CoolingShutters"] as Node3D).rotation.x = sin(clock * 0.70) * 0.13
		"equipment":
			(moving["GantrySlide"] as Node3D).position.x = sin(clock * 0.42) * 0.30
			(moving["ToolArmSweep"] as Node3D).rotation.y = sin(clock * 0.75) * 0.25
			(moving["ToolArmSweep"] as Node3D).position.y = _workshop_arm_base_y + sin(clock * 0.75) * 0.35
		"shipyard":
			(moving["CraneSlide"] as Node3D).position.x = sin(clock * 0.50) * 0.50
			(moving["DockCollarSpin"] as Node3D).rotation.z = clock * 0.42
