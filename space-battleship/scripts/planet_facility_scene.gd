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
var _pulse_strength := 0.0
var _pulse_speed := 0.08
var _surface_clock := 0.0
var _workshop_arm_base_y := 0.0
var _workshop_body_sprite: Sprite3D
var _workshop_arm_sprite: Sprite3D
var _workshop_carriage_sprite: Sprite3D
var _workshop_link: MeshInstance3D
var _refinery_shutter_sprites: Dictionary = {}
var _refinery_body_sprite: Sprite3D
var _refinery_feed_markers: Array[MeshInstance3D] = []
var _shipyard_crane_sprite: Sprite3D
var _shipyard_ring_sprite: Sprite3D
const WORKSHOP_ARM_SPLIT_Y := 428.0
const WORKSHOP_ARM_IMAGE_HEIGHT := 1024.0
const WORKSHOP_ARM_IMAGE_WIDTH := 1536.0

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
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -38, 0)
	light.light_color = Color("fff0d8")
	light.light_energy = 0.95
	_world.add_child(light)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position.z = 18
	_world.add_child(_camera)
	_spine = preload("res://scripts/planet_orbital_spine.gd").new()
	_world.add_child(_spine)
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
		if kind == "equipment": _install_workshop_illustration(model, moving)
		if kind == "refinery": _install_refinery_illustration(model, moving)
		if kind == "shipyard": _install_shipyard_illustration(model, moving)
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
	body.texture = preload("res://assets/planets/facilities_v5/illustrated/workshop-orbit-integrated.png")
	body.pixel_size = 0.0031
	body.position = Vector3(0, 1.38, 0)
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.shaded = false
	body.double_sided = true
	body.render_priority = 0
	model.add_child(body)
	_workshop_body_sprite = body
	# Both sprites sample the original illustration. Splitting at the shoulder
	# keeps the ivory carriage on the gantry while the tool works below it.
	var arm_texture := preload("res://assets/planets/facilities_v5/illustrated/workshop-arm.png")
	var carriage_texture := AtlasTexture.new()
	carriage_texture.atlas = arm_texture
	carriage_texture.region = Rect2(0, 0, WORKSHOP_ARM_IMAGE_WIDTH, WORKSHOP_ARM_SPLIT_Y)
	var tool_texture := AtlasTexture.new()
	tool_texture.atlas = arm_texture
	tool_texture.region = Rect2(0, WORKSHOP_ARM_SPLIT_Y, WORKSHOP_ARM_IMAGE_WIDTH, WORKSHOP_ARM_IMAGE_HEIGHT - WORKSHOP_ARM_SPLIT_Y)
	var gantry := moving["GantrySlide"] as Node3D
	var carriage := Sprite3D.new()
	carriage.name = "IllustratedGantryCarriage"
	carriage.texture = carriage_texture
	carriage.pixel_size = body.pixel_size
	carriage.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	carriage.shaded = false
	carriage.double_sided = true
	carriage.render_priority = 2
	gantry.add_child(carriage)
	_workshop_carriage_sprite = carriage
	var link := MeshInstance3D.new()
	link.name = "TelescopingToolLink"
	var link_mesh := CylinderMesh.new()
	link_mesh.top_radius = 0.075
	link_mesh.bottom_radius = 0.075
	link_mesh.height = 1.0
	link.mesh = link_mesh
	var link_material := StandardMaterial3D.new()
	link_material.albedo_color = Color("102b48")
	link_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	link_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	link_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	link_material.render_priority = 0
	link.material_override = link_material
	model.add_child(link)
	_workshop_link = link
	var arm := Sprite3D.new()
	arm.name = "IllustratedToolArm"
	arm.texture = tool_texture
	arm.pixel_size = body.pixel_size
	var arm_pivot := moving["ToolArmSweep"] as Node3D
	_workshop_arm_base_y = arm_pivot.position.y
	arm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arm.shaded = false
	arm.double_sided = true
	arm.render_priority = 1
	arm_pivot.add_child(arm)
	_workshop_arm_sprite = arm

func _install_refinery_illustration(model: Node3D, moving: Dictionary) -> void:
	# The two ore hoppers, recessed furnace and feed belt are one fixed image;
	# the two cooler shutters retain separate, clock-driven working layers.
	_hide_imported_meshes(model)
	var body := Sprite3D.new()
	body.name = "IllustratedRefineryBody"
	body.texture = preload("res://assets/planets/facilities_v5/illustrated/refinery-orbit-integrated.png")
	body.pixel_size = 0.0032
	body.position = Vector3(0, 1.50, 0)
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.shaded = false
	body.double_sided = true
	model.add_child(body)
	_refinery_body_sprite = body
	for side in ["Left", "Right"]:
		var pivot := moving["IntakeWheel" + side] as Node3D
		var shutter := Sprite3D.new()
		shutter.name = "IllustratedCoolerShutter" + side
		shutter.texture = load("res://assets/planets/facilities_v5/illustrated/refinery-shutter-" + side.to_lower() + ".png")
		shutter.pixel_size = body.pixel_size
		shutter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		shutter.shaded = false
		shutter.double_sided = true
		shutter.render_priority = 1
		pivot.add_child(shutter)
		_refinery_shutter_sprites[side] = shutter
	var feed_material := StandardMaterial3D.new()
	feed_material.albedo_color = Color("ffd079")
	feed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	feed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feed_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	feed_material.render_priority = 2
	for index in 3:
		var marker := MeshInstance3D.new()
		marker.name = "ConveyorOreMarker%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(0.17, 0.11)
		marker.mesh = quad
		marker.material_override = feed_material
		model.add_child(marker)
		_refinery_feed_markers.append(marker)

func _position_refinery_work(model: Node3D, clock: float) -> void:
	var camera_to_model := model.global_transform.basis.inverse()
	var screen_right := (camera_to_model * Vector3.RIGHT).normalized()
	var screen_up := (camera_to_model * Vector3.UP).normalized()
	var camera_front := (camera_to_model * Vector3.BACK).normalized()
	var width := _refinery_body_sprite.scale.x
	var base := _refinery_body_sprite.position + camera_front * 0.25
	var opening := 0.5 + 0.5 * sin(clock * 0.70)
	for side in ["Left", "Right"]:
		var pivot := _parts["refinery"]["IntakeWheel" + side] as Node3D
		var sign := -1.0 if side == "Left" else 1.0
		var target := base + screen_up * (0.23 * opening) + screen_right * (sign * 0.10 * opening * width)
		(_refinery_shutter_sprites[side] as Sprite3D).position = pivot.transform.basis.inverse() * (target - pivot.position)
	# Three small ore loads travel along the illustrated input belt into the
	# furnace. This makes processing visible at the actual ~100px game scale.
	var belt_start := base - screen_right * (0.96 * width) - screen_up * 1.08
	var belt_end := base - screen_right * (0.27 * width) - screen_up * 0.25
	for index in _refinery_feed_markers.size():
		var travel := fposmod(clock * 0.20 + float(index) / 3.0, 1.0)
		var marker := _refinery_feed_markers[index]
		marker.transform = Transform3D(Basis(screen_right * width, screen_up, camera_front), belt_start.lerp(belt_end, travel) + camera_front * 0.04)

func _install_shipyard_illustration(model: Node3D, moving: Dictionary) -> void:
	# The open two-level cantilever stays fixed; only the service crane travels
	# along its upper berth and the docking ring signals its active station.
	_hide_imported_meshes(model)
	var body := Sprite3D.new()
	body.name = "IllustratedShipyardBody"
	body.texture = preload("res://assets/planets/facilities_v5/illustrated/shipyard-orbit-integrated.png")
	body.pixel_size = 0.0030
	body.position = Vector3(0, 1.36, 0)
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.shaded = false
	body.double_sided = true
	model.add_child(body)
	var crane := Sprite3D.new()
	crane.name = "IllustratedServiceCrane"
	crane.texture = preload("res://assets/planets/facilities_v5/illustrated/shipyard-crane.png")
	crane.pixel_size = body.pixel_size
	crane.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crane.shaded = false
	crane.double_sided = true
	crane.render_priority = 1
	(moving["CraneSlide"] as Node3D).add_child(crane)
	_shipyard_crane_sprite = crane
	var ring_texture := AtlasTexture.new()
	ring_texture.atlas = preload("res://assets/planets/facilities_v5/illustrated/shipyard-berth-ring.png")
	ring_texture.region = Rect2(820, 310, 560, 390)
	var ring := Sprite3D.new()
	ring.name = "IllustratedDockCollar"
	ring.texture = ring_texture
	ring.pixel_size = body.pixel_size
	ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ring.shaded = false
	ring.double_sided = true
	ring.render_priority = 2
	(moving["DockCollarSpin"] as Node3D).add_child(ring)
	_shipyard_ring_sprite = ring

func _position_shipyard_work(model: Node3D, clock: float) -> void:
	var camera_to_model := model.global_transform.basis.inverse()
	var screen_right := (camera_to_model * Vector3.RIGHT).normalized()
	var screen_up := (camera_to_model * Vector3.UP).normalized()
	var camera_front := (camera_to_model * Vector3.BACK).normalized()
	var origin := Vector3(0, 1.36, 0) + camera_front * 0.25
	var crane_pivot := _parts["shipyard"]["CraneSlide"] as Node3D
	var crane_target := origin + screen_right * (crane_pivot.position.x * 0.50)
	_shipyard_crane_sprite.position = crane_pivot.transform.basis.inverse() * (crane_target - crane_pivot.position)
	var ring_pivot := _parts["shipyard"]["DockCollarSpin"] as Node3D
	# The ring crop is centered at source pixel (1100, 505) of a 1536x1024 artboard.
	var ring_target := origin + screen_right * (332.0 * _shipyard_ring_sprite.pixel_size) + screen_up * (7.0 * _shipyard_ring_sprite.pixel_size)
	_shipyard_ring_sprite.position = ring_pivot.transform.basis.inverse() * (ring_target - ring_pivot.position)
	_shipyard_ring_sprite.modulate.a = 0.80 + 0.20 * (0.5 + 0.5 * sin(clock * 1.3))

func _position_workshop_arm(model: Node3D) -> void:
	# Keep the illustrated arm on a stable camera-facing layer. A direct child
	# offset follows the tilted ground normal and crosses the body's depth plane,
	# making the arm vanish behind opaque pixels during its vertical stroke.
	var gantry := _parts["equipment"]["GantrySlide"] as Node3D
	var pivot := _parts["equipment"]["ToolArmSweep"] as Node3D
	# Sprite3D billboards face the camera. Its source image's X/Y axes are
	# therefore camera right/up, not the model's tilted ground-tangent axes.
	var camera_to_model := model.global_transform.basis.inverse()
	var screen_right := (camera_to_model * Vector3.RIGHT).normalized()
	var screen_up := (camera_to_model * Vector3.UP).normalized()
	var camera_front := (camera_to_model * Vector3.BACK).normalized()
	var width := _workshop_body_sprite.scale.x
	var origin := _workshop_body_sprite.position + screen_right * (gantry.position.x * width) + camera_front * 0.25
	var pixel_size := _workshop_arm_sprite.pixel_size
	var carriage_center := origin + screen_up * (WORKSHOP_ARM_IMAGE_HEIGHT - WORKSHOP_ARM_SPLIT_Y) * pixel_size * 0.5
	# The pivot still owns the game-clock cycle. Map its full stroke to a
	# downward extension, keeping the tool below the rail at every phase.
	var extension := (_workshop_arm_base_y + 0.35 - pivot.position.y) * 0.5
	var tool_center := origin - screen_up * (WORKSHOP_ARM_SPLIT_Y * pixel_size * 0.5 + extension)
	_workshop_carriage_sprite.position = carriage_center - gantry.position
	_workshop_arm_sprite.position = pivot.transform.basis.inverse() * (tool_center - gantry.position - pivot.position)
	# The telescoping section occupies only the opening below the fixed rail
	# carriage; the tool art covers its lower end and the carriage covers its top.
	_workshop_link.visible = extension > 0.01
	if _workshop_link.visible:
		var joint := origin - screen_right * (0.10 * width) + screen_up * ((WORKSHOP_ARM_IMAGE_HEIGHT * 0.5 - WORKSHOP_ARM_SPLIT_Y) * pixel_size)
		_workshop_link.transform = Transform3D(Basis(screen_right, screen_up, camera_front).scaled(Vector3(width, extension + 0.10, 1)), joint - screen_up * extension * 0.5)

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
	# Tiny white dwarfs and pulsars retain a readable ring instead of shrinking
	# the whole facility system to the small photosphere's pixel diameter.
	return maxf(_body_pixels, minf(size.x * 0.235, size.y * 0.34))

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
	_spine.update_pose(clock)
	for kind in _owned:
		var model: Node3D = _models[kind]
		_animate_parts(kind, clock)
		var a: float = _spine.FACILITY_ANGLES[kind]
		# The built saddle orbits with the spine; the service module keeps an
		# upright attitude on that saddle, so long solar wings do not roll into
		# detached vertical slivers as the orbital structure turns.
		var scale_factor := 0.36 if kind == "auto_explore" else 0.42
		var upright := Basis.from_euler(Vector3(0.90, -0.25, 0.10)).scaled(Vector3.ONE * scale_factor)
		model.transform = Transform3D(_spine.basis.inverse() * upright, _spine.socket_position(a, kind))
		if kind == "equipment": _position_workshop_arm(model)
		if kind == "refinery": _position_refinery_work(model, clock)
		if kind == "shipyard": _position_shipyard_work(model, clock)
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
