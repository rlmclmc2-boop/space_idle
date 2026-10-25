extends RefCounted
## Pure view mapping. Keep the approved core composition and extend it for current nodes.
var positions := {}
var links:Array=[]
var core_offset:=Vector3(-0.43235588,-0.09000003,-1.19500065)*1.2
func configure(region) -> void:
	positions.clear();links.clear()
	var cells:Array[Vector2i]=[]
	for z in range(-3,4):
		for x in range(-3,4):
			if maxi(absi(x),absi(z))>=2 and absi(x)+absi(z)<=4:cells.append(Vector2i(x,z))
	cells.append(Vector2i(-3,-2));cells.append(Vector2i(2,3))
	var queue:Array[int]=[];var seen:Dictionary={};var edges:Array=[]
	for cell in [Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]:
		var i:=cells.find(cell);queue.append(i);seen[i]=true;edges.append([-1,i])
	while not queue.is_empty():
		var i:int=queue.pop_front()
		for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
			var other:=cells.find(cells[i]+delta)
			if other<0 or seen.has(other):continue
			seen[other]=true;queue.append(other);edges.append([i,other])
	for pair in [[Vector2i(-2,-2),Vector2i(-1,-2)],[Vector2i(1,2),Vector2i(2,2)],[Vector2i(2,-1),Vector2i(2,-2)]]:
		var edge:Array=[cells.find(pair[0]),cells.find(pair[1])]
		if not edges.has(edge) and not edges.has([edge[1],edge[0]]):edges.append(edge)
	var ids: Array = region.nodes.keys()
	ids.sort_custom(func(a, b): return int(a) < int(b))
	var authored_count: int = cells.size()
	var occupied: Dictionary = {}
	for cell in cells: occupied[cell] = true
	var cursor: int = 0
	# Add outward adjacent platforms after the authored composition. Every new
	# platform has one real service bridge and never replaces a domain node.
	while cells.size() < ids.size():
		var parent: int = cursor
		var origin: Vector2i = cells[cursor]
		cursor += 1
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var cell: Vector2i = origin + direction
			if occupied.has(cell) or maxi(absi(cell.x), absi(cell.y)) < 2: continue
			occupied[cell] = true
			edges.append([parent, cells.size()])
			cells.append(cell)
			if cells.size() >= ids.size(): break
	var xs: Array = [-65.0,-43.0,-21.0,0.0,20.0,41.0,64.0]
	var zs: Array = [-64.0,-42.0,-20.0,0.0,21.0,44.0,66.0]
	var cell_ids: Dictionary = {}
	for i in cells.size():
		var rank: int = (i * 7 + 3) % authored_count if i < authored_count else i
		if rank >= ids.size(): continue
		var id: int = int(ids[rank])
		cell_ids[i] = id
		positions[id] = Vector3(axis_position(cells[i].x, xs), 0, axis_position(cells[i].y, zs))
	for edge in edges:
		var a: int = -1 if int(edge[0]) == -1 else int(cell_ids.get(edge[0], -2))
		var b: int = int(cell_ids.get(edge[1], -2))
		if (a == -1 or positions.has(a)) and positions.has(b): links.append([a,b])
func axis_position(cell: int, authored: Array) -> float:
	if cell < -3: return float(authored[0]) + (cell + 3) * 22.0
	if cell > 3: return float(authored[-1]) + (cell - 3) * 22.0
	return float(authored[cell + 3])
func point(id:int) -> Vector3:return Vector3.ZERO if id<0 else positions[id]
func key(id:int) -> String:return "Hub" if id<0 else "Slot%d"%id
