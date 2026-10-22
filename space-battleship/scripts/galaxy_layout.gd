extends RefCounted
## Immutable, JSON-safe layout in Godot X/Z world units. One authoritative plan.
const VERSION := 1
const SPACING := 26.0

static func generate(count: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var core := {"id":-1,"parent_id":-1,"depth":0,"planned_type":"core","node_id":"core","type":"core","world_pos":[0.0,0.0],"footprint":[32.0,32.0],"rotation_y":0.0,"connections":[],"requires":[]}
	var nodes: Array=[]
	var positions := {Vector2i.ZERO:"core"}
	var queue: Array[Vector2i]=[Vector2i.ZERO]
	var cursor := 0
	while nodes.size()<count:
		var parent := queue[cursor]
		cursor+=1
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var cell: Vector2i=parent+direction
			if positions.has(cell) or nodes.size()>=count:continue
			var id := "node_%03d"%nodes.size()
			var parent_id: String=positions[parent]
			var node := {"id":nodes.size(),"parent_id":-1 if parent_id=="core" else int(parent_id.trim_prefix("node_")),"depth":absi(cell.x)+absi(cell.y),"planned_type":"","node_id":id,"type":"","world_pos":[cell.x*SPACING,cell.y*SPACING],"footprint":[14.0,14.0],"rotation_y":atan2(float(direction.x),float(direction.y)),"connections":[parent_id],"requires":[parent_id],"visual_seed":rng.randi()}
			if parent_id=="core":core.connections.append(id)
			else:nodes[int(parent_id.trim_prefix("node_"))].connections.append(id)
			positions[cell]=id
			queue.append(cell)
			nodes.append(node)
	var edges: Array=[]
	for node in nodes:
		var parent_id: String=node.requires[0]
		var parent: Dictionary=core if parent_id=="core" else nodes[int(parent_id.trim_prefix("node_"))]
		# Corridors stop at footprints, never pass through a third building.
		var a := Vector2(parent.world_pos[0],parent.world_pos[1])
		var b := Vector2(node.world_pos[0],node.world_pos[1])
		var direction := (b-a).normalized()
		var start := a+direction*float(parent.footprint[0])*0.5
		var end := b-direction*float(node.footprint[0])*0.5
		edges.append({"from":parent_id,"to":node.node_id,"width":2.0,"path":[[start.x,start.y],[end.x,end.y]]})
	return {"layout_version":VERSION,"core_id":"core","units":"godot_world_xz","core":core,"nodes":nodes,"edges":edges}

static func number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func integer(value:Variant)->bool:return number(value) and float(value)==floorf(float(value)) and absf(float(value))<9.22e18
static func point(value:Variant)->bool:return value is Array and value.size()==2 and value.all(number)

static func valid_snapshot(raw: Dictionary, builds: Dictionary) -> bool:
	if not raw.get("blueprint") is Dictionary:return false
	var plan: Dictionary=raw.blueprint
	if plan.get("units")!="godot_world_xz":return false
	if plan.get("layout_version")!=VERSION or plan.get("core_id")!="core" or not plan.get("core") is Dictionary or not plan.get("nodes") is Array or not plan.get("edges") is Array:return false
	var nodes: Array=plan.nodes
	if nodes.is_empty() or nodes.size()>10000 or plan.edges.size()!=nodes.size():return false
	var identities := {}
	var connections := {}
	for i in range(-1,nodes.size()):
		if i>=0 and not nodes[i] is Dictionary:return false
		var node: Dictionary=plan.core if i<0 else nodes[i]
		for key in ["id","parent_id","depth","node_id","type","world_pos","footprint","rotation_y","connections","requires"]:
			if not node.has(key):return false
		for key in ["id","parent_id","depth"]:
			if not integer(node[key]):return false
		for key in ["node_id","type"]:
			if not node[key] is String:return false
		if not point(node.world_pos) or not point(node.footprint) or not number(node.rotation_y):return false
		if not node.connections is Array or not node.requires is Array or not node.connections.all(func(v):return v is String) or not node.requires.all(func(v):return v is String):return false
		if i>=0 and (not integer(node.get("visual_seed")) or not node.get("planned_type") is String):return false
		if int(node.id)!=i or node.node_id!=("core" if i<0 else "node_%03d"%i):return false
		if node.footprint[0]<=0 or node.footprint[1]<=0:return false
		if i<0:
			if node.type!="core" or node.get("planned_type","core")!="core" or node.parent_id!=-1 or node.depth!=0 or not node.requires.is_empty():return false
		else:
			if not node.has("visual_seed") or int(node.parent_id)<-1 or int(node.parent_id)>=i:return false
			for type in [node.type,node.get("planned_type",node.type)]:
				if not str(type).is_empty() and not builds.has(type):return false
			if not str(node.type).is_empty() and not str(node.get("planned_type","")).is_empty() and node.type!=node.planned_type:return false
			var parent: Dictionary=plan.core if int(node.parent_id)<0 else nodes[int(node.parent_id)]
			if node.depth!=parent.depth+1 or node.requires!=[parent.node_id]:return false
		identities[node.node_id]=node
		connections[node.node_id]=[]
	var destinations := {}
	for edge in plan.edges:
		if not edge is Dictionary or not edge.get("path") is Array or not edge.path.all(point) or not number(edge.get("width")):return false
		if not edge.has("path") or edge.path.size()<2 or not edge.has("from") or not edge.has("to") or not edge.has("width") or edge.width<=0:return false
		if not identities.has(edge.from) or not identities.has(edge.to) or edge.to=="core" or destinations.has(edge.to):return false
		if identities[edge.to].requires!=[edge.from]:return false
		destinations[edge.to]=true
		connections[edge.from].append(edge.to);connections[edge.to].append(edge.from)
	for id in identities:
		var expected: Array=connections[id]
		var actual: Array=identities[id].connections
		if actual.size()!=expected.size() or not expected.all(func(ref):return actual.has(ref)):return false
	for i in raw.get("slots",[]).size():
		var slot: Dictionary=raw.slots[i]
		if i>=nodes.size() or slot.get("id",i)!=i or slot.get("node_id",nodes[i].node_id)!=nodes[i].node_id:return false
		for type in [slot.get("type",""),slot.get("planned_type","")]:
			if not str(type).is_empty() and not builds.has(type):return false
		if not str(nodes[i].type).is_empty() and not str(slot.get("type","")).is_empty() and nodes[i].type!=slot.type:return false
	return true
