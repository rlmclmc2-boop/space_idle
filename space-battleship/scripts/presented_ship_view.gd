extends Control
## Transparent top-down 3D rendering inside the existing 2D battlefield.

const LAYOUT := preload("res://dev/toon_ship/hybrid_layout.gd")
const DEFAULT_WEAPON := preload("res://assets/ships/player/toon_v1/weapons/pulse_laser.tscn")
const TOON := preload("res://addons/flexible_toon_shader/flexible_toon.gdshader")
const SHIELD := preload("res://dev/toon_ship/shield.gdshader")
const EXHAUST := preload("res://dev/toon_ship/exhaust.gdshader")
const WORLD_PER_PIXEL := 0.05

@export var weapon_scene: PackedScene = DEFAULT_WEAPON

var viewport: SubViewport
var camera: Camera3D
var ship: Node3D
var weapon_mount: Node3D
var weapon: Node3D
var modules: Array[Dictionary] = []
var loadout_signature := ""
var hull_key := ""
var hull_config: Dictionary = {}
var manifest: Dictionary = {}
var carriers: Array[Node3D] = []
var carrier_states: Array[Dictionary] = []
var pose_initialized := false
var last_pose_scale := 0.0
const CARRIER_SCALE := 0.70
const CARRIER_WEAPON_SCALE := 1.20
const ORBIT_PERIOD := 18.0
var orbit_elapsed := 0.0
var orbit_center := Vector3.ZERO
const MAX_CARRIER_LAG := 0.45
const STATION_WANDER := 0.78
const ANCHOR_DEADBAND := 0.90
var visual_rng := RandomNumberGenerator.new()
var turret: Node3D
var muzzle: Node3D
var shield: MeshInstance3D
var shield_material: ShaderMaterial
var material_entries: Array[Dictionary] = []
var exhaust_materials: Array[ShaderMaterial] = []
var exhaust_nodes: Array[MeshInstance3D] = []
var world: Node3D
var rendered_height := 0.0
var rendered_position := Vector2.ZERO
var model_span := 1.0
var formation_width := 1.0
var elapsed := 0.0
var last_settings: Dictionary = {}
var last_toon_enabled := true
var last_rim_enabled := true


func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://dev/toon_ship/hybrid_manifest.json"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "ShipViewport"
	viewport.size = Vector2i(size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var output := TextureRect.new()
	output.name = "ShipComposite"
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output.texture = viewport.get_texture()
	add_child(output)
	world = Node3D.new()
	viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c0ca")
	environment.ambient_light_energy = 0.18
	environment_node.environment = environment
	world.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-35,-50,0)
	key.light_color = Color("fff8ee")
	key.light_energy = 1.0
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 110
	key.shadow_bias = 0.8
	key.shadow_normal_bias = 3.0
	world.add_child(key)
	camera = Camera3D.new()
	camera.name = "BattleCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = size.x * WORLD_PER_PIXEL
	camera.near = 0.1
	camera.far = 110
	camera.position = Vector3(0,60,0)
	# Exact top-down projection: model -Z points to screen top; no turntable camera.
	camera.rotation_degrees.x = -90
	world.add_child(camera)


func set_hull(key: String) -> bool:
	if key == hull_key: return true
	if not manifest.hulls.has(key): return false
	for carrier in carriers: carrier.free()
	carrier_states.clear()
	pose_initialized = false
	orbit_elapsed = 0.0
	if is_instance_valid(ship): ship.free()
	modules.clear()
	carriers.clear()
	material_entries.clear()
	exhaust_nodes.clear()
	exhaust_materials.clear()
	loadout_signature = ""
	hull_key = key
	visual_rng.seed = 5729+key.hash()
	hull_config = manifest.hulls[key]
	model_span = float(hull_config.model_span)
	var radius := float(manifest.weapon_contract.conservative_xz_rotation_radius)
	var left := float(hull_config.godot_aabb_min[0])
	var right := float(hull_config.godot_aabb_max[0])
	for point in hull_config.weapon_mounts:
		left = minf(left,float(point.position[0])-radius)
		right = maxf(right,float(point.position[0])+radius)
	for offset in hull_config.drone_offsets:
		left = minf(left,float(offset[0])+minf(-radius,float(manifest.drone.godot_aabb_min[0])))
		right = maxf(right,float(offset[0])+maxf(radius,float(manifest.drone.godot_aabb_max[0])))
	formation_width = right-left
	ship = (load(str(hull_config.path)) as PackedScene).instantiate()
	ship.name = "PrototypeShip"
	world.add_child(ship)
	weapon_mount = ship.find_child("WeaponMount01",true,false)
	_install_materials(ship)
	_add_exhausts()
	shield = MeshInstance3D.new()
	shield.name = "PrototypeShield"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	shield.mesh = sphere
	var low: Array = hull_config.godot_aabb_min
	var high: Array = hull_config.godot_aabb_max
	shield.scale = Vector3((float(high[0])-float(low[0]))*0.55,2.1,model_span*0.55)
	shield.position.y = 0.2
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_material = ShaderMaterial.new()
	shield_material.shader = SHIELD
	shield.material_override = shield_material
	ship.add_child(shield)
	if not last_settings.is_empty(): apply_parameters(last_settings,last_toon_enabled,last_rim_enabled)
	return true



func _install_materials(node: Node, owner := "hull") -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var source: StandardMaterial3D = node.mesh.surface_get_material(index)
			var mat := ShaderMaterial.new()
			mat.shader = TOON
			mat.set_shader_parameter("albedo",source.albedo_color)
			mat.set_shader_parameter("clamp_diffuse_to_max",true)
			mat.set_shader_parameter("use_attenuation",true)
			mat.set_shader_parameter("steepness",1.0)
			mat.set_shader_parameter("specular_shininess",9.0)
			mat.set_shader_parameter("emission_color",source.emission)
			node.set_surface_override_material(index,mat)
			material_entries.append({"material":mat,"name":source.resource_name,"owner":owner})
	for child in node.get_children():
		_install_materials(child,owner)


func set_loadout(entries: Array, active_capacity := -1) -> bool:
	if hull_key.is_empty(): return false
	var capacity := entries.size() if active_capacity < 0 else active_capacity
	var assignment := LAYOUT.assign(entries,capacity,int(hull_config.hull_mount_budget))
	var signature := str(assignment)
	if signature == loadout_signature: return true
	var resources := {"laser":"pulse_laser","missile":"missile","cannon":"cannon","longLaser":"long_laser"}
	for item in assignment:
		if not resources.has(item.key):
			push_error("Unsupported weapon visual: "+str(item.key))
			return false
		if item.carrier == "drone" and item.mount >= hull_config.drone_offsets.size():
			push_error("Insufficient visual drone offsets for active loadout")
			return false
	for module in modules: module.node.free()
	for carrier in carriers: carrier.free()
	modules.clear()
	carriers.clear()
	carrier_states.clear()
	material_entries = material_entries.filter(func(entry): return entry.owner=="hull")
	for item in assignment:
		var mount: Node3D
		if item.carrier == "hull":
			mount = ship.find_child("WeaponMount%02d"%(int(item.mount)+1),true,false) as Node3D
		else:
			var carrier := (load(str(manifest.drone.path)) as PackedScene).instantiate() as Node3D
			carrier.name = "VisualCarrierSlot%02d"%(int(item.slot)+1)
			world.add_child(carrier)
			var offset: Array = hull_config.drone_offsets[item.mount]
			var local_offset := Vector3(float(offset[0]),float(offset[1]),float(offset[2]))
			carrier_states.append({"offset":local_offset,"ready":false,"heading":0.0})
			# Never show the world origin while a freshly created formation awaits a pose.
			carrier.visible = false
			carriers.append(carrier)
			_install_materials(carrier,"carrier")
			mount = carrier.find_child("WeaponMount01",true,false) as Node3D
		if mount == null:
			push_error("Missing independent visual mount")
			return false
		var resource := load("res://assets/ships/player/toon_v1/weapons/"+str(resources[item.key])+".glb") as PackedScene
		var node := resource.instantiate() as Node3D
		mount.add_child(node)
		node.transform = Transform3D.IDENTITY
		if item.carrier=="drone":node.scale=Vector3.ONE*CARRIER_WEAPON_SCALE
		modules.append({"slot":item.slot,"key":item.key,"carrier":item.carrier,"mount_index":item.mount,"node":node,"mount":mount,
			"pivot":node.find_child("TurretPivot",true,false),"muzzle":node.find_child("Muzzle",true,false),
			"muzzle2":node.find_child("Muzzle02",true,false)})
		if item.key=="missile":
			# Visible LaunchOpening front face in polish_weapons.py, Blender Y -> -Z.
			for socket in [modules.back().muzzle,modules.back().muzzle2]:
				if socket!=null:socket.position.z=-0.495
		_install_materials(node,"weapon")
	loadout_signature = signature
	weapon = modules[0].node if not modules.is_empty() else null
	turret = modules[0].pivot if not modules.is_empty() else null
	muzzle = modules[0].muzzle if not modules.is_empty() else null
	if not last_settings.is_empty(): apply_parameters(last_settings,last_toon_enabled,last_rim_enabled)
	return true


func aim_at(target: Vector2) -> void:
	# Invert the hull transform, then rotate around the socket's local Y axis.
	var world_target := Vector3((target.x-size.x*0.5)*WORLD_PER_PIXEL,0,(target.y-size.y*0.5)*WORLD_PER_PIXEL)
	for module in modules:
		var local: Vector3 = module.mount.to_local(world_target)
		module.pivot.rotation.y = atan2(-local.x,-local.z)


func set_slot_angles(angles: Array) -> void:
	for module in modules:
		if int(module.slot)<angles.size(): module.pivot.rotation.y = -float(angles[module.slot])-module.mount.global_rotation.y


func screen_muzzle_for_slot(slot: int, ordinal:int=0) -> Vector2:
	for module in modules:
		if int(module.slot)==slot:
			var socket:Node3D=module.muzzle2 if ordinal%2==1 and module.muzzle2!=null else module.muzzle
			return camera.unproject_position(socket.global_position)
	return Vector2.ZERO


func _add_exhausts() -> void:
	var sockets := ship.find_children("ExhaustSocket*","Node3D",true,false)
	for index in sockets.size():
		var socket := sockets[index] as Node3D
		var plume := MeshInstance3D.new()
		plume.name = "BlueExhaust"
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(0.65,1.65)
		plume.mesh = mesh
		plume.position = Vector3(0,0.08,0.78)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = EXHAUST
		mat.set_shader_parameter("phase",float(index)*1.7)
		plume.material_override = mat
		socket.add_child(plume)
		exhaust_materials.append(mat)
		exhaust_nodes.append(plume)


func apply_parameters(settings: Dictionary, toon_enabled: bool, rim_enabled: bool, weapon_only := false) -> void:
	last_settings = settings.duplicate()
	last_toon_enabled = toon_enabled
	last_rim_enabled = rim_enabled
	var steps := maxi(2,int(settings.toon_steps))
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	var shadow := Color(0.22,0.24,0.27)
	var mid := Color(0.63,0.64,0.65)
	var highlight := Color(0.82,0.84,0.86)
	for i in steps:
		var amount := float(i)/float(steps-1)
		offsets.append(amount)
		colors.append(shadow.lerp(mid,amount*2.0) if amount<0.5 else mid.lerp(highlight,(amount-0.5)*2.0))
	gradient.offsets = offsets
	gradient.colors = colors
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT if toon_enabled else Gradient.GRADIENT_INTERPOLATE_LINEAR
	var ramp := GradientTexture1D.new()
	ramp.width = 32
	ramp.gradient = gradient
	for entry in material_entries:
		if weapon_only and entry.owner!="weapon": continue
		var mat: ShaderMaterial = entry.material
		mat.set_shader_parameter("toon_enabled",toon_enabled)
		mat.set_shader_parameter("cuts",steps-1)
		mat.set_shader_parameter("wrap",0.5-float(settings.toon_shadow_threshold))
		mat.set_shader_parameter("use_ramp",true)
		mat.set_shader_parameter("ramp",ramp)
		mat.set_shader_parameter("use_specular",float(settings.specular_strength)>0)
		mat.set_shader_parameter("specular_strength",float(settings.specular_strength))
		mat.set_shader_parameter("use_rim",rim_enabled)
		mat.set_shader_parameter("rim_width",float(settings.rim_power))
		mat.set_shader_parameter("rim_color",Color(0.30,0.65,0.85,float(settings.rim_strength)))
		var is_engine := str(entry.name).begins_with("ProtoEngine")
		var is_accent := str(entry.name).begins_with("ProtoCyan")
		mat.set_shader_parameter("emission_strength",float(settings.emission_strength)*(float(settings.engine_emission) if is_engine else 0.12 if is_accent else 0.0))
	if not weapon_only:
		for mat in exhaust_materials:
			mat.set_shader_parameter("engine_emission",float(settings.engine_emission)*float(settings.emission_strength))
		shield_material.set_shader_parameter("shield_opacity",float(settings.shield_opacity))


func set_pose(center: Vector2, height_pixels: float, angle: float, target: Vector2, time: float, shield_enabled: bool, close_up: bool, visual_delta := 0.0) -> void:
	elapsed = time
	rendered_height = height_pixels * (2.8 if close_up else 1.0)
	rendered_position = size*Vector2(0.5,0.58) if close_up else center
	var scale_value := rendered_height / model_span * WORLD_PER_PIXEL
	ship.scale = Vector3.ONE*scale_value
	orbit_center = Vector3((rendered_position.x-size.x*0.5)*WORLD_PER_PIXEL,0,(rendered_position.y-size.y*0.5)*WORLD_PER_PIXEL)
	orbit_elapsed += clampf(visual_delta,0.0,0.10)
	# Restrained anchored hull motion. Carrier orbits use orbit_center, not this bob.
	ship.position = orbit_center+Vector3(0,0,sin(orbit_elapsed*TAU/8.0)*1.2*WORLD_PER_PIXEL)
	ship.rotation = Vector3(0,-angle+sin(orbit_elapsed*TAU/10.0)*deg_to_rad(0.65),0)
	_update_carriers(scale_value,visual_delta)
	aim_at(target)
	shield.visible = shield_enabled
	shield_material.set_shader_parameter("impact_strength",maxf(0.0,1.0-fposmod(time,3.8)/0.6))
	for i in exhaust_nodes.size():
		exhaust_nodes[i].scale.z = 1.0+sin(time*9+float(i))*0.06
	# A paused diagnostic changes presentation without ticking gameplay. Request precisely one redraw.
	if viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _carrier_safe(point: Vector3, scale_value: float, own_index: int) -> bool:
	var local := (point-ship.global_position)/scale_value
	var low: Array=hull_config.godot_aabb_min
	var high: Array=hull_config.godot_aabb_max
	var radius := float(manifest.weapon_contract.conservative_xz_rotation_radius)*CARRIER_SCALE*CARRIER_WEAPON_SCALE
	# Conservative hull rectangle exclusion plus weapon rotation envelopes.
	if local.x>float(low[0])-radius and local.x<float(high[0])+radius and local.z>float(low[2])-radius and local.z<float(high[2])+radius:return false
	for mount in hull_config.weapon_mounts:
		var pos:=Vector3(float(mount.position[0]),0,float(mount.position[2]))
		if Vector2(local.x-pos.x,local.z-pos.z).length()<radius+1.24+0.08:return false
	for i in carriers.size():
		if i==own_index or not bool(carrier_states[i].ready):continue
		var diff:Vector3=(point-carriers[i].global_position)/scale_value
		if Vector2(diff.x,diff.z).length()<radius*2.0+0.12:return false
	var screen:=camera.unproject_position(point)
	var pixel_radius:=radius*scale_value/WORLD_PER_PIXEL+10.0
	return Rect2(Vector2.ONE*pixel_radius,size-Vector2.ONE*pixel_radius*2.0).has_point(screen)


func _update_carriers(scale_value: float, visual_delta: float) -> void:
	if hull_key=="Heavy_Battleship":
		_update_orbit_carriers(scale_value)
		return
	# World-space, independent visual stationkeeping. Each craft owns a target,
	# dwell clock and heading. There is no orbit, shared sine, or combat RNG use.
	var resized := not is_equal_approx(last_pose_scale,scale_value)
	var dt := clampf(visual_delta,0.0,0.10)
	for i in carriers.size():
		var carrier:=carriers[i]
		var state:=carrier_states[i]
		var nominal:Vector3=ship.global_position+Vector3(state.offset)*scale_value
		carrier.scale=Vector3.ONE*scale_value*CARRIER_SCALE
		if not bool(state.ready) or resized:
			carrier.global_position=nominal
			carrier.rotation=Vector3.ZERO
			state.merge({"ready":true,"heading":0.0,"anchor":nominal,"goal":nominal,"wait":0.45+float(i)*0.70},true)
		elif dt>0.0:
			# Small mother-ship movement does not drag every craft with it.
			if Vector3(state.anchor).distance_to(nominal)>ANCHOR_DEADBAND*scale_value:
				state.anchor=nominal
				state.goal=nominal
				state.wait=0.0
			state.wait=float(state.wait)-dt
			if float(state.wait)<=0.0:
				for attempt in 8:
					var candidate:Vector3=Vector3(state.anchor)+Vector3(visual_rng.randf_range(-STATION_WANDER,STATION_WANDER),0,visual_rng.randf_range(-STATION_WANDER,STATION_WANDER))*scale_value
					if _carrier_safe(candidate,scale_value,i):
						state.goal=candidate
						break
				state.wait=visual_rng.randf_range(2.4,4.2)
			var previous:=carrier.global_position
			var next:=previous.lerp(Vector3(state.goal),1.0-exp(-(1.8+float(i)*0.25)*dt))
			# Collision safety takes priority over an individual station choice.
			if not _carrier_safe(next,scale_value,i):
				state.goal=nominal
				next=previous.lerp(nominal,1.0-exp(-4.0*dt))
			if next.distance_to(Vector3(state.goal))<0.002*scale_value:next=state.goal
			carrier.global_position=next
			var movement:=next-previous
			var heading:=clampf(-movement.x/maxf(scale_value*dt,0.0001)*0.13,-0.14,0.14)
			state.heading=lerpf(float(state.heading),heading,1.0-exp(-3.0*dt))
			if absf(float(state.heading))<0.0001:state.heading=0.0
			carrier.rotation=Vector3(0,float(state.heading),0)
		carrier.visible=true
	last_pose_scale=scale_value
	pose_initialized=true


func _update_orbit_carriers(scale_value: float) -> void:
	# All phases advance continuously with bounded individual speed variation.
	# Equal average periods preserve separation indefinitely (no eventual overtakes).
	for i in carriers.size():
		var phase := TAU*float(i)/3.0
		var theta := TAU*orbit_elapsed/ORBIT_PERIOD+phase+0.045*sin(TAU*orbit_elapsed/ORBIT_PERIOD*2.0+phase)
		var rx := 5.65+float(i)*0.06
		var rz := 5.85-float(i)*0.06
		var carrier:=carriers[i]
		carrier.scale=Vector3.ONE*scale_value*CARRIER_SCALE
		carrier.global_position=orbit_center+Vector3(sin(theta)*rx,0.10,-cos(theta)*rz)*scale_value
		# Independently directed carrier; its turret compensates for the world yaw.
		carrier.rotation=Vector3(0,atan2(-cos(theta)*rx,-sin(theta)*rz),0)
		carrier_states[i].ready=true
		carrier.visible=true
	last_pose_scale=scale_value
	pose_initialized=true


func screen_muzzle() -> Vector2:
	return camera.unproject_position(muzzle.global_position) if muzzle != null else Vector2.ZERO


func set_rendering(enabled: bool, paused := false) -> void:
	visible = enabled
	viewport.render_target_update_mode = (SubViewport.UPDATE_ONCE if paused else SubViewport.UPDATE_ALWAYS) if enabled else SubViewport.UPDATE_DISABLED
