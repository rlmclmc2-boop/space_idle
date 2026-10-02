extends Node3D
## Static navigation corridors read the logic-owned parent graph. No layout or gameplay RNG.
var curves := {}
var pipe_curves := {}
var active_edges: Array[int] = []
var network := MeshInstance3D.new()
var planned := StandardMaterial3D.new()
var operating := StandardMaterial3D.new()
var building := StandardMaterial3D.new()
var triangle_count := 0

func _ready() -> void:
	add_child(network)
	for mat in [planned,operating,building]:
		mat.albedo_color=Color.WHITE
		mat.vertex_color_use_as_albedo=true
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	network.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func ribbon(lines: Array,curve: Curve3D,start: float,end: float,half_width: float,color: Color,thickness := 0.0) -> void:
	if end-start<0.01:return
	# Sample each actual corner instead of shortcutting a bent authoritative route.
	var cuts: Array[float]=[start,end]
	var distance := 0.0
	for index in range(1,curve.point_count):
		distance+=curve.get_point_position(index-1).distance_to(curve.get_point_position(index))
		if distance>start and distance<end:cuts.append(distance)
	cuts.sort()
	for index in range(1,cuts.size()):
		var a := curve.sample_baked(cuts[index-1])
		var b := curve.sample_baked(cuts[index])
		var side := Vector3(-(b-a).z,0,(b-a).x).normalized()*half_width
		lines.append([a,b,side,color,thickness])
		if thickness>0 and index<cuts.size()-1:
			# Solid elbow joins close the outside corner between adjacent segments.
			lines.append([b-Vector3(half_width,0,0),b+Vector3(half_width,0,0),Vector3(0,0,half_width),color,thickness])

func rebuild(snapshot: Dictionary, core_radius := 0.0) -> void:
	curves.clear()
	pipe_curves.clear()
	active_edges.clear()
	triangle_count=0
	var mesh := ImmediateMesh.new()
	var lines := {"planned":[],"operating":[],"building":[]}
	var states := {"core":"active"}
	var centers := {"core":Vector3(float(snapshot.core.world_pos[0]),0.35,float(snapshot.core.world_pos[1]))}
	for node in snapshot.nodes:
		states[str(node.node_id)]=str(node.status)
		centers[str(node.node_id)]=Vector3(float(node.world_pos[0]),0.35,float(node.world_pos[1]))
	for edge in snapshot.edges:
		var id := int(str(edge.to).trim_prefix("node_"))
		var curve := Curve3D.new()
		# All X/Z positions and widths are supplied by the saved blueprint.
		for point in edge.path:curve.add_point(Vector3(float(point[0]),1.3,float(point[1])))
		curves[id]=curve
		var pipe:=Curve3D.new()
		var origin:Vector3=centers[str(edge.from)]
		if str(edge.from)=="core" and core_radius>0:
			var toward:=Vector3(float(edge.path[0][0]),0.35,float(edge.path[0][1]))-origin
			origin+=toward.normalized()*core_radius
		pipe.add_point(origin)
		for point in edge.path:
			var position:=Vector3(float(point[0]),0.35,float(point[1]))
			if position.distance_squared_to(pipe.get_point_position(pipe.point_count-1))>0.0001:pipe.add_point(position)
		var endpoint:Vector3=centers[str(edge.to)]
		if endpoint.distance_squared_to(pipe.get_point_position(pipe.point_count-1))>0.0001:pipe.add_point(endpoint)
		pipe_curves[id]=pipe
		# Transport/construction navigation retains the original curve; pipe geometry
		# extends into the actual foundations rather than stopping at reserved lots.
		curve=pipe
		var status: String=states[str(edge.to)]
		var group := "planned" if status=="empty" else "building" if status=="constructing" else "operating"
		if status in ["active","upgrading"] and states[str(edge.from)] in ["active","upgrading"]:active_edges.append(id)
		var length := curve.get_baked_length()
		var width := float(edge.width)
		if group!="planned":
			# Continuous low conduits for every completed depth, with static shaded sides.
			var color := Color("648087") if group=="operating" else Color("786444")
			ribbon(lines[group],curve,0,length,maxf(0.45,width*0.28),color,0.25)
		else:
			for index in maxi(1,ceili(length/4.6)):
				var start := minf(index*4.6,length)
				ribbon(lines[group],curve,start,minf(start+1.25,length),width*0.055,Color("293f4c"))
	for group in ["planned","operating","building"]:
		if lines[group].is_empty():continue
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,planned if group=="planned" else operating if group=="operating" else building)
		for line in lines[group]:
			var a: Vector3=line[0]
			var b: Vector3=line[1]
			var width: Vector3=line[2]
			mesh.surface_set_color(line[3])
			for vertex in [a-width,b-width,b+width,a-width,b+width,a+width]:mesh.surface_add_vertex(vertex)
			triangle_count+=2
			if float(line[4])>0:
				var drop:=Vector3(0,float(line[4]),0)
				mesh.surface_set_color(Color(line[3]).darkened(0.35))
				for sign in [-1.0,1.0]:
					var side:Vector3=width*sign
					for vertex in [a+side,b+side,b+side-drop,a+side,b+side-drop,a+side-drop]:mesh.surface_add_vertex(vertex)
					triangle_count+=2
		mesh.surface_end()
	network.mesh=mesh

func clear() -> void:
	curves.clear()
	pipe_curves.clear()
	active_edges.clear()
	triangle_count=0
	network.mesh=null
