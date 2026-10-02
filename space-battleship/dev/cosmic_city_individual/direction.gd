extends "res://dev/cosmic_city_individual/modules.gd"
## Direction-only preview. Each stable slot has its own platform and original GLB.
var locations:Array[Vector2i]=[]
var links:Array=[]
var bodies:Array[Node3D]=[]
func build(map) -> void:
	for z in range(-3,4):
		for x in range(-3,4):
			if maxi(absi(x),absi(z))>=2 and absi(x)+absi(z)<=4:locations.append(Vector2i(x,z))
	locations.append(Vector2i(-3,-2));locations.append(Vector2i(2,3))
	var queue:Array[int]=[];var seen:Dictionary={}
	for cell in [Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]:
		var i:=locations.find(cell);queue.append(i);seen[i]=true;links.append([-1,i])
	while not queue.is_empty():
		var i:int=queue.pop_front()
		for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
			var other:=locations.find(locations[i]+delta)
			if other<0 or seen.has(other):continue
			seen[other]=true;queue.append(other);links.append([i,other])
	for pair in [[Vector2i(-2,-2),Vector2i(-1,-2)],[Vector2i(1,2),Vector2i(2,2)],[Vector2i(2,-1),Vector2i(2,-2)]]:
		var edge:Array=[locations.find(pair[0]),locations.find(pair[1])]
		if not links.has(edge) and not links.has([edge[1],edge[0]]):links.append(edge)
	var hub:=deck("Hub",Vector3.ZERO,Vector2(38,38),[Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK],11.1)
	bake(hub);bodies.append(hub)
	var core:Node3D=map.asset(str(map.region.row.core_asset));core.scale=Vector3.ONE*1.2;core.position=Vector3(-0.43235588,-0.09000003,-1.19500065)*1.2;add_child(core)
	for i in locations.size():
		var used:Array=[]
		for edge in links:
			if not edge.has(i):continue
			var other:int=edge[1] if edge[0]==i else edge[0]
			used.append((point(other)-point(i)).normalized())
		var slot_id:int=(i*7+3)%30
		var slot:Dictionary=map.region.slots[slot_id]
		var base:=deck("Slot%d"%slot_id,point(i),Vector2(16,16),used)
		maintenance_hatch(base,Vector3(5.8,0,5.8));bake(base);bodies.append(base)
		base.set_meta("slot_id",slot_id)
		var model:Node3D=map.asset(map.visual_path(slot));model.scale=Vector3.ONE*1.4;model.rotation.y=float(map.region.blueprint.nodes[slot_id].rotation_y);base.add_child(model)
		var bounds:Array=map.asset_bounds[map.visual_path(slot)]
		var mount:=Node3D.new();mount.rotation.y=model.rotation.y;base.add_child(mount)
		if str(slot.planned_type)=="colony_ring":round_mount(mount,float(bounds[0])*0.7)
		else:mounting_collar(mount,Vector2(float(bounds[0]),float(bounds[2]))*1.4)
		bake(mount)
	for edge in links:
		var a:int=edge[0];var b:int=edge[1]
		var side:Vector3=(point(b)-point(a)).normalized()
		bridge(anchor(key(a),side),anchor(key(b),-side));bake(connections[-1].mesh)
	print("INDIVIDUAL DIRECTION platforms=",locations.size()," buildings=",locations.size()," bridges=",connections.size()," reachable=",seen.size()," shared_functional_decks=0")
func key(i:int) -> String:return "Hub" if i<0 else "Slot%d"%((i*7+3)%30)
func point(i:int) -> Vector3:
	if i<0:return Vector3.ZERO
	var cell:Vector2i=locations[i]
	var xs:Array=[-65.0,-43.0,-21.0,0.0,20.0,41.0,64.0]
	var zs:Array=[-64.0,-42.0,-20.0,0.0,21.0,44.0,66.0]
	return Vector3(xs[cell.x+3],0,zs[cell.y+3])
