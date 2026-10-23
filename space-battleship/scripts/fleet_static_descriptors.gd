extends RefCounted
## Per-view startup data. Temporary imported scenes are freed before return;
## only authored values and asset paths survive, never live members or poses.
const DRONES = preload("res://scripts/hyperspace_drone_visual.gd")
const APPEARANCE = preload("res://scripts/hyperspace_appearance.gd")
const GEOMETRY = preload("res://scripts/ship_geometry_convention.gd")
var manifest: Dictionary
var approved_hull_art: Dictionary = {}
var presentation_art: Dictionary = {}
var hulls: Dictionary = {}
var approved: Dictionary = {}
var weapons: Dictionary = {}
var drone_sockets: Dictionary = {}
var carrier_mount: Array = []

func prepare(world: Node3D) -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://dev/toon_ship/hybrid_manifest.json"))
	presentation_art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/fleet_20261019/manifest.json")).weapons
	var visual_rows: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	if visual_rows is Dictionary: approved_hull_art = visual_rows.get("ships",{})
	# Temporary invisible native instances reproduce imported transforms and the
	# authored drone socket installation. No instance survives this preparation.
	for key in manifest.hulls:
		var root = (load(str(manifest.hulls[key].path)) as PackedScene).instantiate()
		var mounts: Array = []
		for index in int(manifest.hulls[key].hull_mount_budget):
			mounts.append(_chain(root.find_child("WeaponMount%02d" % (index+1),true,false),root))
		hulls[key] = mounts
		root.free()
	for key in approved_hull_art:
		if not manifest.hulls.has(key):continue
		var row:Dictionary=approved_hull_art[key]
		var path:=str(row.get("texture",""))
		if not path.begins_with("res://assets/ships/approved_fleet_20261018/player/") and not path.begins_with("res://assets/ships/fleet_20261019/player/"):continue
		var texture:=load(path) as Texture2D
		if texture==null:continue
		var opaque_pixels:=texture.get_image().get_used_rect()
		var opaque:=Rect2(opaque_pixels)
		if opaque.size.x<=0 or opaque.size.y<=0:continue
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
		world.add_child(drone)
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

