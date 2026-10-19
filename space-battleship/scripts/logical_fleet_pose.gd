extends RefCounted
## Prototype pure data authority. Descriptor capture is main-thread-only;
## pose, projection and socket queries belong exclusively to simulation.
## Simulation-owned transforms. Scene descriptors are captured once at startup;
## logical updates never read or write a Node3D, material, or render server.
const VIEW = preload("res://scripts/presented_ship_view.gd")
const LAYOUT = preload("res://dev/toon_ship/hybrid_layout.gd")
const DRONES = preload("res://scripts/hyperspace_drone_visual.gd")
const APPEARANCE = preload("res://scripts/hyperspace_appearance.gd")
const GEOMETRY = preload("res://scripts/ship_geometry_convention.gd")
var manifest: Dictionary
var hulls: Dictionary = {}
var approved: Dictionary = {}
var weapons: Dictionary = {}
var drone_sockets: Dictionary = {}
var carrier_mount: Array = []
var hull_key := ""
var modules: Array[Dictionary] = []
var module_by_slot: Dictionary = {}
var drone_by_id: Dictionary = {}
var carriers: Array[Dictionary] = []
var drones: Array[Dictionary] = []
var ship_transform := Transform3D.IDENTITY
var rendered_position := Vector2.ZERO
var rendered_height := 0.0
var orbit_elapsed := 0.0
var orbit_center := Vector3.ZERO
var elapsed := 0.0
var size := Vector2.ZERO
var camera_transform := Transform3D.IDENTITY
var projection := Projection.IDENTITY
var configuration_dirty := true
var base_signature:Array=[]
var configured_entries:Array=[]
var configured_capacity:=0
var configured_bag:Dictionary={}

func prepare(view) -> void:
	manifest = view.manifest
	size = view.size
	camera_transform = view.camera.get_camera_transform()
	projection = view.camera.get_camera_projection()
	# Temporary invisible native instances reproduce imported transforms and the
	# authored drone socket installation. No instance survives this preparation.
	for key in manifest.hulls:
		var root = (load(str(manifest.hulls[key].path)) as PackedScene).instantiate()
		var mounts: Array = []
		for index in int(manifest.hulls[key].hull_mount_budget):
			mounts.append(_chain(root.find_child("WeaponMount%02d" % (index+1),true,false),root))
		hulls[key] = mounts
		root.free()
	for key in view.approved_hull_art:
		if not manifest.hulls.has(key):continue
		var row:Dictionary=view.approved_hull_art[key]
		var texture:=load(str(row.get("texture",""))) as Texture2D
		if texture==null:continue
		var opaque_pixels:=texture.get_image().get_used_rect()
		var opaque:=Rect2(opaque_pixels)
		if opaque.size.y<=0:continue
		var texture_size:=texture.get_size()
		var pixels_per_model:float=float(manifest.hulls[key].model_span)/opaque.size.y
		var offset:=(Vector2(opaque_pixels.position)+Vector2(opaque_pixels.size)*0.5)-texture_size*0.5
		approved[key]={"opaque":opaque,"mesh_size":texture_size*pixels_per_model,
			"base_position":GEOMETRY.body_center(manifest.hulls[key])+Vector3(-offset.x*pixels_per_model,0.05,-offset.y*pixels_per_model),
			"hardpoints":row.hardpoints,"weapon_scale":float(row.get("weapon_scale",1.0))}
	var carrier = (load(str(manifest.drone.path)) as PackedScene).instantiate()
	carrier_mount = _chain(carrier.find_child("WeaponMount01",true,false),carrier)
	carrier.free()
	for key in {"laser":"pulse_laser","missile":"missile","cannon":"cannon","longLaser":"long_laser"}:
		var name: String = {"laser":"pulse_laser","missile":"missile","cannon":"cannon","longLaser":"long_laser"}[key]
		var root = (load("res://assets/ships/player/toon_v1/weapons/"+name+".glb") as PackedScene).instantiate()
		root.transform = Transform3D.IDENTITY
		var pivot: Node3D = root.find_child("TurretPivot",true,false)
		var sockets: Array = []
		for socket_name in ["Muzzle","Muzzle02"]:
			var socket: Node3D = root.find_child(socket_name,true,false)
			if socket != null:
				if key == "missile": socket.position.z = -0.495
				sockets.append(_chain(socket,pivot))
		weapons[key] = {"pivot_chain":_chain(pivot,root),"pivot_euler":pivot.rotation,"pivot_scale":pivot.scale,"sockets":sockets}
		root.free()
		var drone: Node3D = APPEARANCE.scene(key).instantiate()
		drone.visible = false
		view.world.add_child(drone)
		var installer = DRONES.new()
		installer.install_muzzles(drone,"descriptor",key)
		var points: Array = []
		for socket in installer.muzzles.descriptor: points.append(socket.transform)
		drone_sockets[key] = {"root":drone.transform,"points":points}
		installer.free()
		drone.free()

func _chain(node: Node3D, root: Node3D) -> Array:
	var result: Array = []
	while node != root:
		result.push_front(node.transform)
		node = node.get_parent() as Node3D
	return result

func _global(root: Transform3D, chain: Array) -> Transform3D:
	for transform in chain: root = root * transform
	return root

func configure(key: String, entries: Array, capacity: int, bag: Dictionary) -> void:
	if not configuration_dirty and key == hull_key: return
	configuration_dirty = false
	configured_entries=[]
	for entry in entries:configured_entries.append({"key":str(entry.get("key",""))})
	configured_capacity=capacity
	configured_bag={"generation":int(bag.get("generation",-1)),"equipped":[],"drones":{}}
	var hull_changed := key != hull_key
	if hull_changed:
		hull_key = key
		orbit_elapsed = 0.0
		ship_transform = Transform3D.IDENTITY
	var assignment: Array = LAYOUT.assign(entries,capacity,int(manifest.hulls[key].hull_mount_budget))
	var old_modules := modules
	var old_carriers := carriers
	modules = []; carriers = []
	module_by_slot.clear(); drone_by_id.clear()
	var unchanged := not hull_changed and old_modules.size() == assignment.size()
	if unchanged:
		for index in assignment.size():
			if old_modules[index].assignment != assignment[index]: unchanged = false; break
	for item in assignment:
		var existing: Dictionary = {}
		# Retain setter state only when the native assignment would also survive.
		if unchanged: existing = old_modules[modules.size()]
		var module: Dictionary = existing if not existing.is_empty() else {"assignment":item,"pivot":Transform3D.IDENTITY}
		module.descriptor = weapons[item.key]
		module.mount_chain = hulls[key][item.mount].duplicate() if item.carrier == "hull" else carrier_mount.duplicate()
		var offset:Vector3=preload("res://scripts/ship_geometry_convention.gd").weapon_mount_offset(key,int(item.slot))
		if offset!=Vector3.ZERO:module.mount_chain.append(Transform3D(Basis.IDENTITY,offset))
		if existing.is_empty():
			module.pivot = module.descriptor.pivot_chain.back()
		if item.carrier == "drone":
			carriers.append(old_carriers[carriers.size()] if unchanged else {"transform":Transform3D.IDENTITY,"euler":Vector3.ZERO})
			module.carrier_index = carriers.size()-1
		modules.append(module)
		module_by_slot[int(item.slot)] = module
	var next_drones: Array[Dictionary] = []
	for id in bag.get("equipped",[]):
		var data: Dictionary = bag.get("drones",{}).get(id,{})
		var weapon: String = str(data.get("weapon",""))
		if not drone_sockets.has(weapon): continue
		var appearance:Dictionary={"weapon":weapon,"legendary":bool(data.get("legendary",false)),"origin_quality":str(data.get("origin_quality","white")),"ultimate":bool(data.get("ultimate",false)),"affixes":[]}
		for affix in data.get("affixes",[]):appearance.affixes.append({"tier":int(affix.get("tier",6)),"key":str(affix.get("key",""))})
		var ultimate:Dictionary=data.get("ultimate_affix",{})
		if not ultimate.is_empty():appearance.ultimate_affix={"tier":int(ultimate.get("tier",6)),"key":str(ultimate.get("key",""))}
		configured_bag.equipped.append(str(id));configured_bag.drones[str(id)]=appearance
		var member: Dictionary = {}
		for old in drones:
			if old.id == str(id) and old.weapon == weapon: member = old; break
		if member.is_empty(): member = {"id":str(id),"weapon":weapon,"transform":drone_sockets[weapon].root}
		next_drones.append(member)
		if next_drones.size() == 5: break
	drones = next_drones
	for member in drones: drone_by_id[str(member.id)] = member
	invalidate_pose()

func pose_base(center: Vector2, height: float, angle: float, time: float, close_up: bool, dt: float) -> void:
	elapsed = time
	rendered_height = height * (2.8 if close_up else 1.0)
	rendered_position = size*Vector2(0.5,0.58) if close_up else center
	var scale_value: float = rendered_height / float(manifest.hulls[hull_key].model_span) * VIEW.WORLD_PER_PIXEL
	orbit_center = Vector3((rendered_position.x-size.x*0.5)*VIEW.WORLD_PER_PIXEL,0,(rendered_position.y-size.y*0.5)*VIEW.WORLD_PER_PIXEL)
	orbit_elapsed += clampf(dt,0.0,0.10)
	_pose_carriers(scale_value)
	var signature:Array=[hull_key,rendered_position,rendered_height,angle,size]
	if base_signature==signature:return
	base_signature=signature
	ship_transform = preload("res://scripts/ship_geometry_convention.gd").centered_transform(Basis.from_euler(Vector3(0,-angle,0)).scaled_local(Vector3.ONE*scale_value),orbit_center,manifest.hulls[hull_key])
	var zoom := 2.8 if close_up else 1.0
	for index in drones.size():
		var member: Dictionary = drones[index]
		var point: Vector2 = rendered_position+DRONES.OFFSETS[index]*zoom
		if zoom == 1.0:
			point.x = clampf(point.x,28,size.x-28); point.y = clampf(point.y,32,size.y-60)
		# Native set_global_position dirties Euler/scale before set_scale.
		var euler: Vector3 = member.transform.basis.orthonormalized().get_euler()
		member.transform = Transform3D(Basis.from_euler(euler).scaled_local(Vector3.ONE*16.0*VIEW.WORLD_PER_PIXEL*zoom),Vector3((point.x-size.x*0.5)*VIEW.WORLD_PER_PIXEL,0.5,(point.y-size.y*0.5)*VIEW.WORLD_PER_PIXEL))

func _pose_carriers(scale_value: float) -> void:
	var hull: Dictionary = manifest.hulls[hull_key]
	var pixels_per_model := scale_value / VIEW.WORLD_PER_PIXEL
	var low: Array = hull.godot_aabb_min; var high: Array = hull.godot_aabb_max
	var half := Vector2(maxf(absf(float(low[0])),absf(float(high[0]))),maxf(absf(float(low[2])),absf(float(high[2]))))*pixels_per_model
	var carrier_radius := maxf(1.6,float(manifest.weapon_contract.conservative_xz_rotation_radius)*VIEW.CARRIER_WEAPON_SCALE)*VIEW.CARRIER_SCALE*pixels_per_model+3.0
	var extent := VIEW.FLEET_HALF_EXTENT
	extent.x = minf(extent.x,minf(rendered_position.x,size.x-rendered_position.x)-8.0)
	extent.y = minf(extent.y,minf(rendered_position.y,size.y-rendered_position.y)-8.0)
	var radius := Vector2(minf(half.x+carrier_radius*0.55+8.0,extent.x-carrier_radius),minf(half.y+carrier_radius*0.55+8.0,extent.y-carrier_radius)).max(Vector2.ONE*8.0)*VIEW.WORLD_PER_PIXEL
	for index in carriers.size():
		var carrier: Dictionary = carriers[index]
		var phase := TAU*float(index)/maxi(carriers.size(),1)
		var period := VIEW.ORBIT_PERIOD*(1.0+0.055*sin(float(index)*2.399963))
		var theta := TAU*orbit_elapsed/period+phase
		var radial := 0.94+0.06*sin(theta*2.0+float(index)*1.7)
		# Preserve scale -> global-position -> rotation setter rounding, including
		# recovery of scale from the previous yaw's basis after the global write.
		var scaled := Basis.from_euler(carrier.euler).scaled_local(Vector3.ONE*scale_value*VIEW.CARRIER_SCALE)
		carrier.euler = Vector3(0,atan2(-cos(theta)*radius.x,-sin(theta)*radius.y),0)
		carrier.transform = Transform3D(Basis.from_euler(carrier.euler).scaled_local(scaled.get_scale()),orbit_center+Vector3(sin(theta)*radius.x*radial,-1.6*scale_value,-cos(theta)*radius.y*radial))

func invalidate_pose() -> void:
	base_signature.clear()
	# Configuration and ownership capture can replace transforms without a step.
	# Projection descriptors are immutable after prepare; invalidate here if changed.
	for module in modules:
		module.erase("mount_root")
		module.erase("pivot_yaw")
		module.socket_points = {}
	for member in drones:
		member.erase("socket_transform")
		member.socket_points = {}

func _mount(module: Dictionary) -> Transform3D:
	var root: Transform3D = ship_transform if module.assignment.carrier == "hull" else carriers[module.carrier_index].transform
	if not module.has("mount_root") or module.mount_root != root:
		module.mount_root = root
		if module.assignment.carrier=="hull" and approved.has(hull_key) and rendered_height>0.0:
			var art:Dictionary=approved[hull_key]
			var fit:Dictionary=GEOMETRY.approved_body_fit(art.opaque,art.mesh_size,art.base_position,size,rendered_height,rendered_position,float(manifest.hulls[hull_key].model_span))
			var position:Vector3=GEOMETRY.approved_mount_position(fit,art.hardpoints[int(module.assignment.mount)].pos)
			var mount_basis:Basis=_global(Transform3D.IDENTITY,module.mount_chain).basis.scaled_local(Vector3.ONE*float(art.weapon_scale))
			module.mount_transform=root*Transform3D(mount_basis,position)
		else:
			module.mount_transform = _global(root,module.mount_chain)
		module.mount_position = project(module.mount_transform.origin)
		module.mount_yaw = module.mount_transform.basis.orthonormalized().get_euler().y
		module.socket_points = {}
	return module.mount_transform

func _set_pivot(module: Dictionary, yaw: float) -> void:
	if module.has("pivot_yaw") and float(module.pivot_yaw) == yaw: return
	module.pivot_yaw = yaw
	var descriptor: Dictionary = module.descriptor
	var euler: Vector3 = descriptor.pivot_euler
	euler.y = yaw
	var next := Transform3D(Basis.from_euler(euler).scaled_local(descriptor.pivot_scale),module.pivot.origin)
	if next == module.pivot: return
	module.pivot = next
	module.socket_points = {}

func set_slot_angles(angles: Array) -> void:
	for module in modules:
		if int(module.assignment.slot) < angles.size():
			_mount(module)
			_set_pivot(module,-float(angles[module.assignment.slot])-float(module.mount_yaw))

func project(point: Vector3) -> Vector2:
	var local := camera_transform.basis.transposed()*(point-camera_transform.origin)
	var clip := projection*Vector4(local.x,local.y,local.z,1.0)
	var normal := Vector3(clip.x,clip.y,clip.z)/clip.w
	return Vector2((normal.x*0.5+0.5)*size.x,(-normal.y*0.5+0.5)*size.y)

func screen_muzzle_for_slot(slot: int, ordinal := 0) -> Vector2:
	var module: Dictionary = module_by_slot.get(slot,{})
	if module.is_empty(): return Vector2.ZERO
	var transform := _mount(module)
	var sockets: Array = module.descriptor.sockets
	var socket_index := 1 if ordinal%2 == 1 and sockets.size()>1 else 0
	if module.socket_points.has(socket_index): return module.socket_points[socket_index]
	var root_scale := VIEW.CARRIER_WEAPON_SCALE if module.assignment.carrier == "drone" else 1.0
	transform = transform*Transform3D(Basis.from_scale(Vector3.ONE*root_scale),Vector3.ZERO)
	var chain: Array = module.descriptor.pivot_chain
	for index in chain.size(): transform = transform*(module.pivot if index == chain.size()-1 else chain[index])
	var point := project(_global(transform,sockets[socket_index]).origin)
	module.socket_points[socket_index] = point
	return point

func screen_mount_for_slot(slot:int) -> Vector2:
	var module: Dictionary = module_by_slot.get(slot,{})
	if module.is_empty(): return Vector2.ZERO
	_mount(module)
	return module.mount_position

func screen_muzzle_for_drone(id: String, ordinal: int) -> Vector2:
	var member: Dictionary = drone_by_id.get(id,{})
	if member.is_empty(): return rendered_position
	var sockets: Array = drone_sockets[member.weapon].points
	if sockets.is_empty(): return rendered_position
	if not member.has("socket_transform") or member.socket_transform != member.transform:
		member.socket_transform = member.transform
		member.socket_points = {}
	var socket_index := posmod(ordinal,sockets.size())
	if not member.socket_points.has(socket_index):
		member.socket_points[socket_index] = project((member.transform*sockets[socket_index]).origin)
	return member.socket_points[socket_index]
