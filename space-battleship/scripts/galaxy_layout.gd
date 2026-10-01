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
