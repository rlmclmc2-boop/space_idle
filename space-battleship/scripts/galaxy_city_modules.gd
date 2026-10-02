extends Node3D
## Static city structure primitives. No gameplay state or per-frame updates.
const DECK := Color("dce0d1")
const HULL := Color("20364a")
const EDGE := Color("476071")
const CYAN := Color("64adb9")
const PORT_WIDTH := 5.2
const PORT_Y := -0.9
var ports := {}
var connections: Array = []
var material := StandardMaterial3D.new()

func _init() -> void:
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED

func box(parent:Node3D,at:Vector3,dimensions:Vector3,color:Color) -> MeshInstance3D:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	var h:=dimensions*0.5
	var vertices:Array[Vector3]=[Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,-h.y,h.z),Vector3(-h.x,-h.y,h.z),Vector3(-h.x,h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)]
	var faces:=[[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7],[3,2,1,0]]
	for index in faces.size():
		mesh.surface_set_color(color.darkened([0.0,0.15,0.30,0.22,0.12,0.4][index]))
		var f:Array=faces[index]
		for vertex in [f[0],f[1],f[2],f[0],f[2],f[3]]:mesh.surface_add_vertex(vertices[vertex])
	mesh.surface_end()
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;parent.add_child(node)
	return node

func slab(parent:Node3D,width:float,depth:float,top:float,bottom:float,bevel:float,color:Color) -> void:
	var x:=width*0.5;var z:=depth*0.5
	var loop:Array[Vector2]=[Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),Vector2(x,z-bevel),Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)]
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for index in loop.size():
		var a:=Vector3(loop[index].x,top,loop[index].y);var b:=Vector3(loop[(index+1)%loop.size()].x,top,loop[(index+1)%loop.size()].y)
		mesh.surface_set_color(color)
		for vertex in [Vector3(0,top,0),a,b]:mesh.surface_add_vertex(vertex)
		mesh.surface_set_color(color.darkened(0.38 if index<4 else 0.22))
		var drop:=Vector3(0,top-bottom,0)
		for vertex in [a,b,b-drop,a,b-drop,a-drop,Vector3(0,bottom,0),b-drop,a-drop]:mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var node:=MeshInstance3D.new();node.mesh=mesh;parent.add_child(node)

func port(parent:Node3D,key:String,side:Vector3,half:float) -> Marker3D:
	var root:=Node3D.new();root.name="ServicePort_"+key;parent.add_child(root)
	root.position=side*half+Vector3(0,PORT_Y,0)
	root.basis=Basis(Vector3.UP,atan2(side.x,side.z))
	# Local +Z is outward. Open frame: no plate or wall crosses the aperture.
	box(root,Vector3(-2.72,0,0),Vector3(0.52,2.5,0.95),EDGE)
	box(root,Vector3(2.72,0,0),Vector3(0.52,2.5,0.95),EDGE)
	box(root,Vector3(0,1.02,0),Vector3(5.65,0.34,0.95),EDGE)
	box(root,Vector3(0,-1.02,0),Vector3(5.65,0.34,0.95),EDGE)
	# Paired shoulders and a raised crown make the flange readable from above.
	for sign in [-1,1]:
		box(root,Vector3(sign*2.8,0.2,0),Vector3(0.65,2.2,0.62),DECK)
		box(root,Vector3(sign*2.8,1.4,0),Vector3(0.72,0.32,0.9),DECK)
		box(root,Vector3(sign*2.8,1.59,0),Vector3(0.34,0.07,0.34),Color("bf9d64"))
	box(root,Vector3(0,1.22,0),Vector3(4.8,0.22,0.5),DECK)
	var anchor:=Marker3D.new();anchor.name="PipeSocket";root.add_child(anchor);ports[key]=anchor
	return anchor

func platform(key:String,at:Vector3,used:Array,rotation_y:=0.0) -> Node3D:
	var node:=Node3D.new();node.name=key;add_child(node);node.position=at;node.rotation.y=rotation_y
	# Building contact plane Y=0; load-bearing hollow hull extends below it.
	slab(node,16,16,-0.22,-0.68,1.4,EDGE)
	slab(node,15.8,15.8,0,-0.24,1.35,DECK)
	# Four restrained deck seams terminate at the structural perimeter.
	for sign in [-1,1]:
		box(node,Vector3(sign*5.5,0.016,0),Vector3(0.055,0.025,13.0),Color("9daea9"))
		box(node,Vector3(0,0.017,sign*5.5),Vector3(13.0,0.025,0.055),Color("9daea9"))
	slab(node,15.5,15.5,-2.8,-3.2,1.2,EDGE)
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var wall:=Node3D.new();node.add_child(wall);wall.position=side*7.72;wall.basis=Basis(Vector3.UP,atan2(side.x,side.z))
		if used.has(side):
			# An actual wall opening joins the enclosed service corridor.
			for sign in [-1,1]:box(wall,Vector3(sign*5.25,-1.55,0),Vector3(4.9,2.5,0.45),HULL)
			box(wall,Vector3(0,-2.3,0),Vector3(PORT_WIDTH,1.0,0.45),HULL)
		else:box(wall,Vector3(0,-1.55,0),Vector3(13.2,2.5,0.45),HULL)
		for sign in [-1,1]:
			box(wall,Vector3(sign*5.3,-1.4,0.31),Vector3(2.5,1.25,0.26),EDGE)
			box(wall,Vector3(sign*5.3,-1.37,0.47),Vector3(1.85,0.62,0.08),HULL)
			box(wall,Vector3(sign*5.3,-0.76,0.5),Vector3(1.5,0.12,0.13),DECK)
			box(wall,Vector3(sign*6.65,-1.45,0.22),Vector3(0.5,2.35,0.65),DECK.darkened(0.18))
	for x in [-5.9,5.9]:
		for z in [-5.9,5.9]:
			box(node,Vector3(x,-3.25,z),Vector3(1.15,2.1,1.15),EDGE)
			box(node,Vector3(x,-4.3,z),Vector3(0.7,0.4,0.7),HULL)
	for side in used:
		var name_key:=key+"/"+str(side)
		port(node,name_key,side,8.0)
	return node

func anchor(key:String,side:Vector3) -> Marker3D:return ports[key+"/"+str(side)]

func bridge(a:Marker3D,b:Marker3D) -> void:
	var start:=a.global_position;var finish:=b.global_position
	var direction:Vector3=(finish-start).normalized()
	assert(a.global_basis.z.dot(direction)>0.999 and b.global_basis.z.dot(-direction)>0.999,"Bridge must mate to opposed outward sockets")
	assert(absf(start.y-finish.y)<0.001,"Adapters must supply common service height")
	var span:=start.distance_to(finish)
	var node:=Node3D.new();node.name="ServiceBridge";add_child(node);node.global_position=(start+finish)*0.5;node.global_basis=Basis(Vector3.UP,atan2(direction.x,direction.z))
	# Hollow service volume; roof/floor/side skins stop exactly at socket planes.
	box(node,Vector3(0,-0.79,0),Vector3(4.8,0.22,span),HULL)
	for sign in [-1,1]:box(node,Vector3(sign*2.28,0,0),Vector3(0.24,1.36,span),HULL)
	box(node,Vector3(0,0.79,0),Vector3(4.8,0.22,span),DECK.darkened(0.1))
	for sign in [-1,1]:
		box(node,Vector3(sign*2.32,0.17,0),Vector3(0.14,0.32,span),CYAN)
		box(node,Vector3(sign*2.25,1.06,0),Vector3(0.48,0.58,maxf(0.1,span-1.05)),DECK)
	if span>3:
		for z in [-span*0.23,span*0.23]:
			box(node,Vector3(0,0.925,z),Vector3(4.2,0.045,0.085),EDGE)
			for sign in [-1,1]:box(node,Vector3(sign*2.48,-0.05,z),Vector3(0.34,1.7,0.4),EDGE)
	connections.append({"a":a,"b":b,"mesh":node,"span":span})

func elbow(at:Vector3) -> Node3D:
	var node:=Node3D.new();node.name="ElbowJunction";add_child(node);node.position=at
	slab(node,6,6,0,-0.22,0.6,DECK)
	slab(node,6,6,-1.58,-1.8,0.6,HULL)
	# North/east mouths are open into one shared turn chamber.
	box(node,Vector3(-2.88,-0.9,0),Vector3(0.24,1.36,4.8),HULL)
	box(node,Vector3(0,-0.9,2.88),Vector3(4.8,1.36,0.24),HULL)
	port(node,"junction/north",Vector3.FORWARD,3)
	port(node,"junction/east",Vector3.RIGHT,3)
	# One solid junction shares the exact bridge cross-section and deck elevation.
	maintenance_hatch(node,Vector3.ZERO)
	return node

func maintenance_hatch(parent:Node3D,at:Vector3) -> void:
	var root:=Node3D.new();parent.add_child(root);root.position=at
	slab(root,2.1,2.1,0.12,0.01,0.28,EDGE)
	slab(root,1.65,1.65,0.28,0.12,0.2,DECK.darkened(0.12))
	for sign in [-1,1]:box(root,Vector3(sign*0.57,0.34,0),Vector3(0.2,0.12,0.55),EDGE)

func mounting_collar(parent:Node3D,dimensions:Vector2) -> void:
	# An open mounting curb meets the original foundation without lifting the GLB.
	for sign in [-1,1]:
		box(parent,Vector3(sign*(dimensions.x*0.5+0.14),0.14,0),Vector3(0.32,0.28,dimensions.y+0.6),EDGE)
		box(parent,Vector3(0,0.14,sign*(dimensions.y*0.5+0.14)),Vector3(dimensions.x+0.6,0.28,0.32),EDGE)
		for other in [-1,1]:
			box(parent,Vector3(sign*(dimensions.x*0.5+0.08),0.31,other*(dimensions.y*0.5+0.08)),Vector3(0.72,0.38,0.72),DECK.darkened(0.08))

func round_mount(parent:Node3D,radius:float) -> void:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for index in 32:
		var a:=TAU*index/32.0;var b:=TAU*(index+1)/32.0
		var inner_a:=Vector3(cos(a)*(radius-0.32),0.32,sin(a)*(radius-0.32))
		var inner_b:=Vector3(cos(b)*(radius-0.32),0.32,sin(b)*(radius-0.32))
		var outer_a:=Vector3(cos(a)*(radius+0.12),0.32,sin(a)*(radius+0.12))
		var outer_b:=Vector3(cos(b)*(radius+0.12),0.32,sin(b)*(radius+0.12))
		mesh.surface_set_color(EDGE)
		for vertex in [inner_a,inner_b,outer_b,inner_a,outer_b,outer_a]:mesh.surface_add_vertex(vertex)
		mesh.surface_set_color(HULL)
		for edge in [[outer_a,outer_b],[inner_b,inner_a]]:
			var p:Vector3=edge[0];var q:Vector3=edge[1];var d:=Vector3(0,0.31,0)
			for vertex in [p,q,q-d,p,q-d,p-d]:mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var node:=MeshInstance3D.new();node.mesh=mesh;parent.add_child(node)
	for index in 4:
		var angle:=PI*index/2
		var shoe:=box(parent,Vector3(cos(angle)*radius,0.34,sin(angle)*radius),Vector3(0.75,0.5,0.7),DECK.darkened(0.08));shoe.rotation.y=-angle

func deck(key:String,at:Vector3,dimensions:Vector2,used:Array,bevel:=1.4) -> Node3D:
	var root:=Node3D.new();root.name=key;add_child(root);root.position=at
	slab(root,dimensions.x,dimensions.y,-0.22,-0.68,bevel,EDGE)
	slab(root,dimensions.x-0.2,dimensions.y-0.2,0,-0.24,bevel,DECK)
	slab(root,dimensions.x-0.5,dimensions.y-0.5,-2.8,-3.2,bevel,EDGE)
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var along:float=dimensions.y if absf(side.x)>0.5 else dimensions.x
		var half:float=(dimensions.x if absf(side.x)>0.5 else dimensions.y)*0.5
		var width:=along-2*bevel
		var wall:=Node3D.new();root.add_child(wall);wall.position=side*(half-0.28);wall.basis=Basis(Vector3.UP,atan2(side.x,side.z))
		if used.has(side):
			var segment:float=(width-PORT_WIDTH)*0.5
			for sign in [-1,1]:box(wall,Vector3(sign*(PORT_WIDTH+segment)*0.5,-1.55,0),Vector3(segment,2.5,0.45),HULL)
			box(wall,Vector3(0,-2.3,0),Vector3(PORT_WIDTH,1,0.45),HULL)
			port(root,key+"/"+str(side),side,half)
		else:box(wall,Vector3(0,-1.55,0),Vector3(width,2.5,0.45),HULL)
		var count:=maxi(2,ceili(width/8))
		for i in count:
			var x:float=(i+0.5)*width/count-width*0.5
			if used.has(side) and absf(x)<3.3:continue
			box(wall,Vector3(x,-1.4,0.31),Vector3(2.5,1.25,0.26),EDGE)
			box(wall,Vector3(x,-1.37,0.47),Vector3(1.85,0.62,0.08),HULL)
			box(wall,Vector3(x,-0.76,0.5),Vector3(1.5,0.12,0.13),DECK)
		for sign in [-1,1]:box(wall,Vector3(sign*(width*0.5-0.3),-1.45,0.1),Vector3(0.5,2.35,0.7),DECK.darkened(0.18))
	# Close the clipped corners with structural diagonal walls.
	for x in [-1,1]:
		for z in [-1,1]:
			var a:=Vector3(x*(dimensions.x*0.5-bevel),-1.55,z*(dimensions.y*0.5-0.28))
			var b:=Vector3(x*(dimensions.x*0.5-0.28),-1.55,z*(dimensions.y*0.5-bevel))
			var rib:=box(root,(a+b)*0.5,Vector3(0.45,2.5,a.distance_to(b)),HULL);rib.rotation.y=atan2((b-a).x,(b-a).z)
			box(root,Vector3(x*(dimensions.x*0.5-bevel),-3.4,z*(dimensions.y*0.5-bevel)),Vector3(1.2,1.3,1.2),EDGE)
	return root

func junction(key:String,at:Vector3,used:Array) -> Node3D:
	var root:=deck(key,at,Vector2(7,7),used,0.55)
	maintenance_hatch(root,Vector3.ZERO)
	return root

func bake(root:Node3D) -> void:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	var meshes:Array[MeshInstance3D]=[]
	collect_meshes(root,meshes)
	var inverse:=root.global_transform.affine_inverse()
	for node in meshes:
		var transform:=inverse*node.global_transform
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var tint:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for index in (indices if not indices.is_empty() else range(points.size())):
				vertices.append(transform*points[index]);colors.append(tint[index] if not tint.is_empty() else Color.WHITE)
	for node in meshes:node.free()
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body:=MeshInstance3D.new();body.name="StaticStructure";body.mesh=mesh;body.material_override=material;body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(body)

func collect_meshes(root:Node,output:Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:output.append(root)
	for child in root.get_children():collect_meshes(child,output)
