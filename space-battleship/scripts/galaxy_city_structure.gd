extends "res://scripts/galaxy_city_modules.gd"
var layout
var district_nodes:Array[Node3D]=[]
var branch_nodes:Array=[]
var hub:Node3D
var junction_nodes:Array[Node3D]=[]
var trunk_nodes:Array[Node3D]=[]
var mounts := {}
var mount_paths := {}
var mount_cache := {}
var active_groups:Array[bool]=[]
var rebuild_count := 0

func configure(value) -> void:
	layout=value
	for child in get_children():child.free()
	ports.clear();connections.clear();district_nodes.clear();branch_nodes.clear();junction_nodes.clear();trunk_nodes.clear();mounts.clear();mount_paths.clear();active_groups.clear()
	hub=deck("Hub",Vector3.ZERO,Vector2(38,38),[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK],11.1)
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var p:Vector3=side*15.8
		maintenance_hatch(hub,p+Vector3(side.z*2,0,-side.x*2))
	bake(hub)
	for index in layout.groups.size():
		var group:Dictionary=layout.groups[index]
		var base:=deck("District%d"%index,group.center,group.size,[group.side])
		for col in range(1,int(group.columns)):
			box(base,Vector3((col-int(group.columns)*0.5)*16,0.016,0),Vector3(0.06,0.025,group.size.y-2.8),Color("9daea9"))
		for row in range(1,int(group.rows)):
			box(base,Vector3(0,0.016,(row-int(group.rows)*0.5)*16),Vector3(group.size.x-2.8,0.025,0.06),Color("9daea9"))
		maintenance_hatch(base,Vector3(group.size.x*0.5-2.5,0,group.size.y*0.5-2.5))
		bake(base);district_nodes.append(base);active_groups.append(false)
	for front in [-1,1]:
		var index:=0 if front<0 else 4
		var fork:=junction("Fork%d"%index,Vector3(0,0,layout.groups[index].center.z),[Vector3.LEFT,Vector3.RIGHT,Vector3(0,0,-front)])
		bake(fork);junction_nodes.append(fork)
		var before:=connections.size();bridge(anchor("Hub",Vector3(0,0,front)),anchor("Fork%d"%index,Vector3(0,0,-front)));var trunk:Node3D=connections[before].mesh;bake(trunk);trunk_nodes.append(trunk)
	for index in layout.groups.size():
		var group:Dictionary=layout.groups[index]
		var source:Marker3D
		if index in [2,3]:source=anchor("Hub",Vector3.LEFT if index==2 else Vector3.RIGHT)
		else:source=anchor("Fork%d"%(0 if index<2 else 4),Vector3.LEFT if index in [0,4] else Vector3.RIGHT)
		var before:=connections.size();bridge(source,anchor("District%d"%index,group.side))
		var body:Node3D=connections[before].mesh;bake(body);branch_nodes.append(body)
	rebuild_count+=1

func refresh_states(region) -> bool:
	var changed:=false
	for index in layout.groups.size():
		var enabled:bool=layout.groups[index].ids.any(func(id):return region.slots[id].status!="empty")
		if enabled!=active_groups[index]:changed=true;active_groups[index]=enabled
		district_nodes[index].visible=enabled;branch_nodes[index].visible=enabled
	for index in 2:
		var enabled:=active_groups[0 if index==0 else 4] or active_groups[1 if index==0 else 5]
		junction_nodes[index].visible=enabled;trunk_nodes[index].visible=enabled
	return changed

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
