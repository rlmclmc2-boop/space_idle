extends RefCounted
## Pure view mapping from the approved individual-platform composition; never saved.
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
	var xs:Array=[-65.0,-43.0,-21.0,0.0,20.0,41.0,64.0]
	var zs:Array=[-64.0,-42.0,-20.0,0.0,21.0,44.0,66.0]
	for i in cells.size():
		var id:=slot_id(i)
		if id<region.slots.size():positions[id]=Vector3(xs[cells[i].x+3],0,zs[cells[i].y+3])
	for edge in edges:
		var a:=slot_id(edge[0]);var b:=slot_id(edge[1])
		if (a<0 or positions.has(a)) and positions.has(b):links.append([a,b])
func slot_id(index:int) -> int:return -1 if index<0 else (index*7+3)%30
func point(id:int) -> Vector3:return Vector3.ZERO if id<0 else positions[id]
func key(id:int) -> String:return "Hub" if id<0 else "Slot%d"%id
