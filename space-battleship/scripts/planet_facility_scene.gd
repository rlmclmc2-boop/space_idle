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
var _fill_light: DirectionalLight3D
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
var _solid_body := false
var _pulse_strength := 0.0
var _pulse_speed := 0.08
var _surface_clock := 0.0
var _workshop_arm_base_y := 0.0
var _workshop_gantry_base_x := 0.0
var _shipyard_crane_base_x := 0.0
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
	environment.environment.ambient_light_color = Color("8095a3")
	environment.environment.ambient_light_energy = 0.18
	_world.add_child(environment)
	_scene_environment = environment
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -38, 0)
	light.light_color = Color("fff0d8")
	light.light_energy = 1.12
	light.shadow_enabled = true
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 0.9
	_world.add_child(light)
	_scene_light = light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(24, 132, 0)
	fill.light_color = Color("b5d4df")
	fill.light_energy = 0.10
	_world.add_child(fill)
	_fill_light = fill
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position.z = 18
	_world.add_child(_camera)
	_spine = preload("res://scripts/planet_orbital_spine.gd").new()
	_world.add_child(_spine)
	# Lift the large thin orbit as one plane. The globe depth mask still hides
	# the far rail, while the front rail stays clear of the lower silhouette.
	_spine.position.y = 0.35
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
		var model: Node3D = load("res://assets/planets/facilities_v9/" + kind + ".glb").instantiate()
		_spine.add_child(model)
		_models[kind] = model
		var moving: Dictionary = {}
		for part_name in WORK_PARTS[kind]:
			var pivot := model.find_child(part_name, true, false) as Node3D
			assert(pivot != null, "Missing facility work pivot: " + kind + "/" + part_name)
			moving[part_name] = pivot
		_parts[kind] = moving
		if kind == "auto_explore": _depth_clip_orbital_model(model)
		if kind == "equipment":
			_workshop_arm_base_y = (moving["ToolArmSweep"] as Node3D).position.y
			_workshop_gantry_base_x = (moving["GantrySlide"] as Node3D).position.x
		if kind == "shipyard": _shipyard_crane_base_x = (moving["CraneSlide"] as Node3D).position.x
		if kind in ["equipment", "shipyard", "refinery"]: _depth_clip_orbital_model(model)
		if kind == "refinery": _install_refinery_work(model)
		match kind:
			"auto_explore": _add_work_light(model, "Command second occupied tier dark hull", Color("79cfe9"), 1.0, 1.9, Vector3(0, 0.28, 0))
			"refinery": _add_work_light(model, "Heat chamber upper armored ring deck", Color("ffc16e"), 1.7, 2.0, Vector3(0, 0.42, 0))
			"equipment": _add_work_light(model, "Manufacturing open assembly well", Color("ff9b47"), 0.08, 1.35, Vector3(0, 0.40, 0))
			"shipyard": _add_work_light(model, "Dock recessed central landing lane", Color("ffab4e"), 0.08, 1.35, Vector3(0, 0.42, 0))
		if kind == "equipment":
			_add_work_spot(model, "Factory traveling winch", "Manufacturing recessed machine bed",
				Color("ff9a48"), 6.0, 1.65, 39.0, Vector3(0, 0, -0.08))
			_add_signal_spill(model, "Manufacturing entrance amber soffit lamp", Color("ff9b55"), 0.38, 0.75)
		if kind == "shipyard":
			_add_work_spot(model, "Dock portal recessed soffit", "Dock recessed central landing lane",
				Color("ff8e39"), 3.4, 1.7, 42.0, Vector3(0, -0.07, -0.06))
			_add_signal_spill(model, "Dock entrance amber pressure lamp", Color("ff9850"), 0.46, 0.75)
		if kind == "auto_explore":
			_add_work_light(model, "Command dark structural foundation", Color("ffae65"), 0.46, 1.45, Vector3(0, 0, -0.10))
			_add_signal_spill(model, "Command underdeck amber service signal", Color("ff9e51"), 1.30)
		if kind == "refinery":
			_add_work_light(model, "Heat chamber dark integrated foundation", Color("ff9a48"), 0.65, 1.55, Vector3(0, 0, -0.08))
			_add_signal_spill(model, "Heat ring amber machinery port", Color("ff9a48"), 2.16)
		model.visible = false
	resized.connect(_layout)
	_layout()

func _add_work_light(model: Node3D, anchor_name: String, color: Color,
		energy: float, light_range: float, offset: Vector3) -> void:
	var anchor := model.find_child(anchor_name, true, false) as Node3D
	assert(anchor != null, "Missing authored work-light anchor: " + anchor_name)
	var light := OmniLight3D.new()
	light.name = "AuthoredWorkLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_specular = 0.60
	light.shadow_enabled = anchor_name in ["Manufacturing open assembly well", "Dock recessed central landing lane"]
	anchor.add_child(light)
	light.position = offset

func _add_work_spot(model: Node3D, anchor_name: String, target_name: String, color: Color,
		energy: float, light_range: float, cone_degrees: float, offset: Vector3) -> void:
	var anchor := model.find_child(anchor_name, true, false) as Node3D
	assert(anchor != null, "Missing authored work spot anchor: " + anchor_name)
	var target := model.find_child(target_name, true, false) as Node3D
	assert(target != null, "Missing authored work spot target: " + target_name)
	var spot := SpotLight3D.new()
	spot.name = "FocusedWorkSpot"
	spot.light_color = color
	spot.light_energy = energy
	spot.light_specular = 0.22
	spot.spot_range = light_range
	spot.spot_angle = cone_degrees
	# The factory lamp sits inside the moving gantry. Its own shadow map would
	# occlude the workpiece completely; the directional key still casts the
	# machine and bay contact shadows onto the deck.
	spot.shadow_enabled = anchor_name != "Factory traveling winch"
	spot.shadow_bias = 0.025
	spot.shadow_normal_bias = 0.35
	anchor.add_child(spot)
	spot.position = offset
	if anchor_name == "Factory traveling winch":
		# The moving bridge is nearly level with the work bed after the orbit
		# transform. Place its lamp below the bridge but above the bed normal.
		spot.global_position = target.global_position + target.global_transform.basis.z.normalized() * 0.50
	# Imported Blender facilities rotate their local Z into the ring plane.
	# Aim at the authored work surface in that local frame; both then continue
	# rotating together with their independently owned facility.
	spot.look_at(target.global_position, Vector3.BACK)

func _add_signal_spill(model: Node3D, name_prefix: String, color: Color,
		energy: float, light_range: float = 1.0) -> void:
	var signals: Array[MeshInstance3D] = []
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if String(child.name).begins_with(name_prefix):
			signals.append(child as MeshInstance3D)
	assert(signals.size() >= 4, "Missing authored service lamps: " + name_prefix)
	for index in [0, int(signals.size() / 2)]:
		var lamp := OmniLight3D.new()
		lamp.name = "AuthoredServiceSpill"
		lamp.light_color = color
		lamp.light_energy = energy
		lamp.omni_range = light_range
		lamp.light_specular = 0.18
		signals[index].add_child(lamp)

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
		# The asset uses the shared full-orbit authoring frame. Ore moves across
		# the refinery's open heat bay rather than around the old local saddle.
		marker.position = Vector3(lerpf(5.29, 5.61, travel), 0.15, lerpf(-3.27, -3.69, travel))

func _depth_clip_orbital_model(node: Node) -> void:
	# Imported opaque armor must use the same globe intersection as the owned
	# ring. A transparent depth mask cannot hide an already drawn opaque GLB.
	if node is MeshInstance3D and node.mesh != null:
		# The shallow, overlapping shuttle wing shells self-shadow into a dotted
		# pattern at the actual page size. The enclosing bay still casts its real
		# structural shadows across the vessel and landing deck.
		if node.name.begins_with("Shuttle visible swept pressure hull") or node.name.begins_with("Shuttle broad lifting wing") or node.name.begins_with("Shuttle upper engine cowling") or node.name.begins_with("Shuttle shallow dorsal navy armor channel") or node.name.begins_with("Heat dome honeycomb pressure seam"):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in node.mesh.get_surface_count():
			var original := node.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://scripts/planet_spine_opaque.gdshader")
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("luminous", original.emission_enabled)
			material.set_shader_parameter("hull_roughness", original.roughness)
			material.set_shader_parameter("hull_metallic", original.metallic)
			material.set_shader_parameter("panel_grid", _armor_panel_grid(node.name))
			material.set_shader_parameter("armor_reflection", _armor_reflection(node.name))
			material.set_shader_parameter("armor_surface", _armor_surface(node.name))
			material.set_shader_parameter("armor_terminal_zone", _armor_terminal_zone(node.name))
			if String(node.name).to_lower().contains("amber"):
				material.set_shader_parameter("emission_boost", 1.65)
			if node.name.begins_with("Dock deep armored portal fascia") or node.name.begins_with("Dock angled end armor cheek") or node.name.begins_with("Manufacturing sloped load shoulder"):
				material.set_shader_parameter("facade_gradient", 0.29)
			elif node.name.begins_with("Dock inner pressure socket cheek") or node.name.begins_with("Manufacturing track entry armor cheek") or node.name.begins_with("Fabrication room armored inner wall"):
				material.set_shader_parameter("facade_gradient", 0.22)
			node.set_surface_override_material(index, material)
			_orbital_depth_materials.append(material)
	for child in node.get_children(): _depth_clip_orbital_model(child)

func _armor_panel_grid(authored_name: String) -> Vector2:
	# Broad authored box faces and explicitly UV-mapped armor plates only.
	# Curved pieces retain their authored facet and silhouette treatment.
	if authored_name.begins_with("Dock continuous pressure landing deck"):
		return Vector2(3, 4)
	if authored_name.begins_with("Docked shuttle fuselage"):
		return Vector2(2, 3)
	if authored_name.begins_with("Shuttle visible swept pressure hull"):
		return Vector2(2, 4)
	if authored_name.begins_with("Shuttle broad lifting wing"):
		return Vector2(1, 2)
	if authored_name.begins_with("Shuttle upper engine cowling"):
		return Vector2(1, 2)
	if authored_name.begins_with("Fabrication room separated armor roof"):
		return Vector2(1, 2)
	if authored_name.begins_with("Dock separated service bay roof"):
		return Vector2(1, 1)
	for prefix in ["Dock deep armored portal fascia", "Dock angled end armor cheek",
			"Dock sloped outer entrance shoulder", "Manufacturing sloped load shoulder"]:
		if authored_name.begins_with(prefix): return Vector2(1, 2)
	if authored_name.begins_with("Fabrication room continuous dark hull"):
		return Vector2(1, 3)
	if authored_name.begins_with("Manufacturing full pressure sole"):
		return Vector2(2, 3)
	for prefix in ["Dock inner service pod roof", "Dock inner pressure socket cheek",
			"Dock separated service bay dark hull", "Dock side-deck dark removable service plate",
			"Manufacturing segmented load-floor armor tile",
			"Manufacturing outer wall removable armor panel"]:
		if authored_name.begins_with(prefix): return Vector2.ONE
	return Vector2.ZERO

func _armor_reflection(authored_name: String) -> float:
	# A few broad housings catch light at page scale; dark working cavities do not.
	for prefix in ["Docked shuttle", "Shuttle visible", "Shuttle broad",
			"Shuttle upper", "Dock separated service bay roof",
			"Fabrication room separated armor roof", "Dock deep armored portal fascia",
			"Manufacturing sloped load shoulder"]:
		if authored_name.begins_with(prefix): return 1.0
	for prefix in ["Dock continuous pressure landing deck", "Dock segmented pale load-floor tile",
			"Manufacturing segmented load-floor armor tile", "Manufacturing continuous modular work deck",
			"Fabrication room continuous side pressure shell", "Command stepped ivory observation deck",
			"Command upper observation cap", "Heat chamber lower armored ring deck",
			"Heat chamber upper armored ring deck", "Heat chamber gold faceted crown"]:
		if authored_name.begins_with(prefix): return 0.65
	return 0.0

func _armor_surface(authored_name: String) -> float:
	# Only large exposed plates receive the UV-locked surface finish. The
	# recessed machine beds, windows and emissive signals remain clean.
	for prefix in ["Dock continuous pressure landing deck", "Dock deep armored portal fascia",
			"Dock separated service bay roof", "Dock segmented pale load-floor tile",
			"Manufacturing segmented load-floor armor tile", "Manufacturing outer wall removable armor panel",
			"Fabrication room separated armor roof", "Fabrication room continuous side pressure shell",
			"Manufacturing sloped load shoulder", "Command stepped ivory observation deck",
			"Command upper observation cap", "Heat chamber lower armored ring deck"]:
		if authored_name.begins_with(prefix): return 1.0
	return 0.0

func _armor_terminal_zone(authored_name: String) -> float:
	for prefix in ["Dock deep armored portal fascia", "Dock outer pressure portal shoulder",
			"Dock sloped outer entrance shoulder", "Dock angled end armor cheek",
			"Manufacturing sloped load shoulder", "Fabrication room continuous side pressure shell"]:
		if authored_name.begins_with(prefix): return 0.9
	return 0.0

func configure_shape(appearance: Dictionary) -> void:
	_axis_ratio = maxf(0.05, float(appearance.get("axisRatio", 1.0)))
	_compact_stellar = float(appearance.get("emission", 0.0)) > 0.0 and float(appearance.get("radiusScale", 1.0)) <= 0.3
	_solid_body = float(appearance.get("emission", 0.0)) == 0.0 and float(appearance.get("radiusScale", 1.0)) <= 1.0
	_scene_light.light_energy = 0.95 if _solid_body else 1.12
	_scene_environment.environment.ambient_light_energy = 0.14 if _solid_body else 0.18
	var scale := float(appearance.get("radiusScale", 1.0))
	var is_large_star := float(appearance.get("emission", 0.0)) > 0.0 and scale > 0.3
	var field_tint := Color("e9bd8d") if scale > 1.0 else Color("f1d6a9") if is_large_star else Color(str(appearance.get("atmosphereColor", "fff2df")))
	_spine.set_stellar_field(field_tint, 0.62 if float(appearance.get("emission", 0.0)) > 0.0 else 0.0)
	_scene_light.light_color = Color("ffd3af") if scale > 1.0 and is_large_star else Color("ffe8c8") if is_large_star else Color("fff0d8")
	_fill_light.light_color = Color("ffd2b5") if is_large_star else Color("b5d4df")
	_scene_environment.environment.ambient_light_color = Color("a4938a") if scale > 1.0 and is_large_star else Color("8994a0") if is_large_star else Color("8095a3")
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
	if _solid_body: return _body_pixels
	# Compact stellar cores still need an orbital facility structure, but the
	# full terrestrial ring makes the center read as an empty 700px hole.
	return maxf(_body_pixels, minf(size.x * (0.16 if _compact_stellar else 0.235), size.y * (0.285 if _compact_stellar else 0.34)))

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
	# update_pose sets a new rotation basis; apply the compact star scale after
	# it so the common ring and all four sockets contract as one structure.
	# A beamed core is capped by its beam envelope. Bring its ring slightly
	# closer to the photosphere while retaining readable facility scale below.
	var spine_scale := maxf(0.50, globe_scale) if _compact_stellar else 1.0
	_spine.scale = Vector3.ONE * spine_scale
	for kind in _owned:
		var model: Node3D = _models[kind]
		_animate_parts(kind, clock)
		# All four owned meshes are authored against the same ring center. The
		# shared basis maps the Blender orbit plane to this tilted runtime plane;
		# no per-node socket scale may distort their continuous architecture.
		var orbit_basis := Basis(Vector3.RIGHT, _spine.plane_normal(),
			Vector3(0.0, -_spine.TILT_Y, _spine.TILT_Z))
		model.transform = Transform3D(orbit_basis, Vector3.ZERO)
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
			(moving["GantrySlide"] as Node3D).position.x = _workshop_gantry_base_x + sin(clock * 0.42) * 0.30
			(moving["ToolArmSweep"] as Node3D).rotation.y = sin(clock * 0.75) * 0.25
			(moving["ToolArmSweep"] as Node3D).position.y = _workshop_arm_base_y + sin(clock * 0.75) * 0.35
		"shipyard":
			(moving["CraneSlide"] as Node3D).position.x = _shipyard_crane_base_x + sin(clock * 0.50) * 0.50
			(moving["DockCollarSpin"] as Node3D).rotation.z = clock * 0.42
