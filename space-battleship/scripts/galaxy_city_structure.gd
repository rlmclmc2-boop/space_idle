extends "res://scripts/galaxy_city_modules.gd"
var layout
var platform_nodes:Array[Node3D]=[]
var bridge_nodes:Array[Node3D]=[]
var hub:Node3D
var mounts := {}
var mount_paths := {}
var mount_cache := {}
var rebuild_count := 0
var platform_templates := {}
var bridge_meshes := {}

func configure(value) -> void:
	begin_configure(value)
	bake(hub)
	for id in layout.positions:prepare_platform(id)
	for edge in layout.links:prepare_bridge(edge)
	rebuild_count+=1

func begin_configure(value) -> void:
	layout=value
	for child in get_children():child.free()
	ports.clear();connections.clear();platform_nodes.clear();bridge_nodes.clear();mounts.clear();mount_paths.clear()
	hub=deck("Hub",Vector3.ZERO,Vector2(38,38),[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK],11.1)

func prepare_platform(id:int) -> void:
	var used:Array=[]
	for edge in layout.links:
		if not edge.has(id):continue
		var other:int=edge[1] if edge[0]==id else edge[0]
		used.append((layout.point(other)-layout.point(id)).normalized())
	var base:=platform_instance(layout.key(id),layout.point(id),used)
	base.set_meta("slot_id",id)
	platform_nodes.append(base)

func prepare_bridge(edge:Array) -> void:
	var side:Vector3=(layout.point(edge[1])-layout.point(edge[0])).normalized()
	var a:=anchor(layout.key(edge[0]),side);var b:=anchor(layout.key(edge[1]),-side)
	var span:=a.global_position.distance_to(b.global_position)
	bridge(a,b,bridge_meshes.get(span))
	var body:Node3D=connections[-1].mesh
	if not bridge_meshes.has(span):
		bake(body);bridge_meshes[span]=body.get_node("StaticStructure").mesh
	bridge_nodes.append(body)

func platform_instance(key:String,at:Vector3,used:Array) -> Node3D:
	# The authored 16x16 deck varies only by its four service openings.
	# Reuse its baked mesh and exact socket hierarchy, not temporary primitives.
	var mask:=0
	var sides:=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
	for index in sides.size():
		if used.has(sides[index]):mask|=1<<index
	if platform_templates.has(mask):
		var template:Dictionary=platform_templates[mask]
		var node:Node3D=template.scene.instantiate()
		node.name=key;node.position=at;add_child(node)
		for side in used:ports[key+"/"+str(side)]=node.get_node(template.sockets[side])
		return node
	var node:=deck(key,at,Vector2(16,16),used)
	maintenance_hatch(node,Vector3(5.8,0,5.8));bake(node)
	var sockets:Dictionary={}
	for side in used:sockets[side]=node.get_path_to(anchor(key,side))
	var pending:Array[Node]=[node]
	while not pending.is_empty():
		var parent:Node=pending.pop_back()
		for child in parent.get_children():child.owner=node;pending.append(child)
	var packed:=PackedScene.new()
	if packed.pack(node)==OK:platform_templates[mask]={"scene":packed,"sockets":sockets}
	return node

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
