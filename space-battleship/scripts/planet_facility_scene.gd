extends Control
## Display-only 3D architecture on an independent orbital spine. No building hit targets.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
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
var _scene_environment: WorldEnvironment
var _scene_light: DirectionalLight3D
var _spine: Node3D
var _models: Dictionary = {}
var _parts: Dictionary = {}
var _owned: Array = []
var _occluder := MeshInstance3D.new()
var _radius := 3.0
var _clock := 0.0
var _phase := 0.0
var _body_pixels := 200.0
var _last_size := Vector2.ZERO
var _last_body_pixels := -1.0
var _axis_ratio := 1.0
var _compact_stellar := false
var _pulse_strength := 0.0
var _pulse_speed := 0.08
var _surface_clock := 0.0
var _workshop_arm_base_y := 0.0
var _refinery_feed_markers: Array[MeshInstance3D] = []
var _orbital_depth_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X
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
	_scene_environment = environment
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -38, 0)
	light.light_color = Color("fff0d8")
	light.light_energy = 0.95
	_world.add_child(light)
	_scene_light = light
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position.z = 18
	_world.add_child(_camera)
	_spine = preload("res://scripts/planet_orbital_spine.gd").new()
	_world.add_child(_spine)
	# The tilted architectural plane sits below the photosphere's visual center:
	# its front load path clears the lower limb while the back path stays masked.
	_spine.position.y = -0.42
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
		_spine.add_child(model)
		_models[kind] = model
		var moving: Dictionary = {}
		for part_name in WORK_PARTS[kind]:
			var pivot := model.find_child(part_name, true, false) as Node3D
			assert(pivot != null, "Missing facility work pivot: " + kind + "/" + part_name)
			moving[part_name] = pivot
		_parts[kind] = moving
		if kind == "auto_explore": _depth_clip_orbital_model(model)
		if kind == "equipment": _workshop_arm_base_y = (moving["ToolArmSweep"] as Node3D).position.y
		if kind in ["equipment", "shipyard", "refinery"]: _depth_clip_orbital_model(model)
		if kind == "refinery": _install_refinery_work(model)
		model.visible = false
	resized.connect(_layout)
	_layout()

func _install_refinery_work(model: Node3D) -> void:
	# The three moving loads follow the real recessed tread into the furnace
	# mouth; all static walls, hoppers, and the mouth are imported 3D geometry.
	var feed_material := StandardMaterial3D.new()
	feed_material.albedo_color = Color("ffd079")
	feed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	feed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feed_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	feed_material.render_priority = 2
	for index in 3:
		var marker := MeshInstance3D.new()
		marker.name = "ConveyorOreMarker%d" % index
		var ore := BoxMesh.new()
		ore.size = Vector3(0.11, 0.065, 0.12)
		marker.mesh = ore
		marker.material_override = feed_material
		model.add_child(marker)
		_refinery_feed_markers.append(marker)

func _position_refinery_work(_model: Node3D, clock: float) -> void:
	for index in _refinery_feed_markers.size():
		var travel := fposmod(clock * 0.28 + float(index) / 3.0, 1.0)
		var marker := _refinery_feed_markers[index]
		marker.position = Vector3(lerpf(-1.15, -0.31, travel), 0.0, 0.36)

func _depth_clip_orbital_model(node: Node) -> void:
	# Imported opaque armor must use the same globe intersection as the owned
	# ring. A transparent depth mask cannot hide an already drawn opaque GLB.
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var original := node.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://scripts/planet_spine_opaque.gdshader")
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("luminous", original.emission_enabled)
			node.set_surface_override_material(index, material)
			_orbital_depth_materials.append(material)
	for child in node.get_children(): _depth_clip_orbital_model(child)

func configure_shape(appearance: Dictionary) -> void:
	_axis_ratio = maxf(0.05, float(appearance.get("axisRatio", 1.0)))
	_compact_stellar = float(appearance.get("emission", 0.0)) > 0.0 and float(appearance.get("radiusScale", 1.0)) <= 0.3
	var scale := float(appearance.get("radiusScale", 1.0))
	var is_large_star := float(appearance.get("emission", 0.0)) > 0.0 and scale > 0.3
	var field_tint := Color("e9bd8d") if scale > 1.0 else Color("f1d6a9") if is_large_star else Color(str(appearance.get("atmosphereColor", "fff2df")))
	_spine.set_stellar_field(field_tint, 0.62 if float(appearance.get("emission", 0.0)) > 0.0 else 0.0)
	_scene_light.light_color = Color("ffd3af") if scale > 1.0 and is_large_star else Color("ffe8c8") if is_large_star else Color("fff0d8")
	_scene_environment.environment.ambient_light_color = Color("b5a5a0") if scale > 1.0 and is_large_star else Color("a9adb1") if is_large_star else Color("91aeb6")
	_pulse_strength = clampf(float(appearance.get("pulseStrength", 0.0)), 0.0, 0.05)
	_pulse_speed = maxf(0, float(appearance.get("pulseSpeed", 0.08)))

func configure(entries: Array) -> void:
	_owned = []
	for entry in entries:
		var kind: String = str(entry.type)
		if _models.has(kind) and not kind in _owned: _owned.append(kind)
	for kind in _models: _models[kind].visible = kind in _owned
	_spine.configure(_owned)
	update_pose(_clock, _phase, _body_pixels)

func _layout() -> void:
	if size.x < 1 or size.y < 1: return
	_viewport.size = Vector2i(size)
	_last_size = size
	_last_body_pixels = _body_pixels
	var visible_height := _radius * size.y / _render_pixels()
	_camera.fov = rad_to_deg(2.0 * atan(visible_height / (2.0 * _camera.position.z)))
	_camera.position.x = -(scene_center.x - size.x * 0.5) * _radius / _render_pixels()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _render_pixels() -> float:
	# Compact stellar cores still need an orbital facility structure, but the
	# full terrestrial ring makes the center read as an empty 700px hole.
	return maxf(_body_pixels, minf(size.x * (0.16 if _compact_stellar else 0.235), size.y * (0.235 if _compact_stellar else 0.34)))

func update_pose(clock: float, surface_phase: float, body_pixels: float, surface_clock: float = -1.0) -> void:
	_clock = clock
	_phase = surface_phase
	_body_pixels = body_pixels
	if surface_clock >= 0: _surface_clock = surface_clock
	if not is_inside_tree(): return
	if size != _last_size or not is_equal_approx(_last_body_pixels, body_pixels): _layout()
	var pulse := 1.0 + _pulse_strength * sin(_surface_clock * TAU * _pulse_speed)
	var globe_scale := _body_pixels / _render_pixels()
	_occluder.scale = Vector3(globe_scale * pulse, _axis_ratio * globe_scale * pulse, globe_scale * pulse)
	_spine.set_body_scale(_occluder.scale)
	for material in _orbital_depth_materials:
		material.set_shader_parameter("body_scale", _occluder.scale)
	_spine.update_pose(clock)
	for kind in _owned:
		var model: Node3D = _models[kind]
		_animate_parts(kind, clock)
		var a: float = _spine.FACILITY_ANGLES[kind]
		# The built saddle orbits with the spine; the service module keeps an
		# upright attitude on that saddle, so long solar wings do not roll into
		# detached vertical slivers as the orbital structure turns.
		var scale_factor := 0.70 if kind == "auto_explore" else 0.65 if kind == "refinery" else 0.62 if kind == "equipment" else 0.60
		var upright := Basis.from_euler(Vector3(0.90, -0.25, 0.10)).scaled(Vector3.ONE * scale_factor)
		if kind in ["shipyard", "equipment", "auto_explore", "refinery"]:
			# Both open work bays are authored in the owned section's local frame.
			# The workshop's through axis follows the actual orbit tangent.
			var outward: Vector3 = _spine.point(a).normalized()
			var axis_x: Vector3 = -outward if kind == "shipyard" else (_spine.point(a + 0.001) - _spine.point(a - 0.001)).normalized()
			var axis_y: Vector3 = _spine.plane_normal()
			model.transform = Transform3D(Basis(axis_x, axis_y, axis_x.cross(axis_y)).scaled(Vector3.ONE * scale_factor), _spine.socket_position(a, kind))
		else:
			model.transform = Transform3D(_spine.basis.inverse() * upright, _spine.socket_position(a, kind))
		if kind == "refinery": _position_refinery_work(model, clock)
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
