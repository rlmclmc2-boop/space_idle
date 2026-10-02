extends "res://scripts/galaxy_city_modules.gd"
var layout
var platform_nodes:Array[Node3D]=[]
var bridge_nodes:Array[Node3D]=[]
var hub:Node3D
var mounts := {}
var mount_paths := {}
var mount_cache := {}
var rebuild_count := 0

func configure(value) -> void:
	layout=value
	for child in get_children():child.free()
	ports.clear();connections.clear();platform_nodes.clear();bridge_nodes.clear();mounts.clear();mount_paths.clear()
	hub=deck("Hub",Vector3.ZERO,Vector2(38,38),[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK],11.1)
	bake(hub)
	for id in layout.positions:
		var used:Array=[]
		for edge in layout.links:
			if not edge.has(id):continue
			var other:int=edge[1] if edge[0]==id else edge[0]
			used.append((layout.point(other)-layout.point(id)).normalized())
		var base:=deck(layout.key(id),layout.point(id),Vector2(16,16),used)
		base.set_meta("slot_id",id)
		maintenance_hatch(base,Vector3(5.8,0,5.8));bake(base);platform_nodes.append(base)
	for edge in layout.links:
		var side:Vector3=(layout.point(edge[1])-layout.point(edge[0])).normalized()
		bridge(anchor(layout.key(edge[0]),side),anchor(layout.key(edge[1]),-side))
		var body:Node3D=connections[-1].mesh;bake(body);bridge_nodes.append(body)
	rebuild_count+=1

func update_mount(id:int,path:String,node:Node3D,bounds:Array,family:String) -> void:
	if mount_paths.get(id,"")==path:return
	if mounts.has(id):mounts[id].free();mounts.erase(id)
	mount_paths[id]=path
	if path=="empty":return
	var root:=Node3D.new();root.name="MountingCollar";node.add_child(root)
	if mount_cache.has(path):
		var mesh:=MeshInstance3D.new();mesh.mesh=mount_cache[path];mesh.material_override=material;root.add_child(mesh)
	else:
		if family=="colony_ring":round_mount(root,float(bounds[0])*0.7)
		else:mounting_collar(root,Vector2(float(bounds[0]),float(bounds[2]))*1.4)
		bake(root);mount_cache[path]=root.get_node("StaticStructure").mesh
	mounts[id]=root
