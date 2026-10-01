extends Node3D
## Static navigation corridors read the logic-owned parent graph. No layout or gameplay RNG.
var curves := {}
var active_edges: Array[int] = []
var network := MeshInstance3D.new()
var planned := StandardMaterial3D.new()
var operating := StandardMaterial3D.new()
var building := StandardMaterial3D.new()

func _ready() -> void:
	add_child(network)
	for pair in [[planned,"294252"],[operating,"608f92"],[building,"ba9864"]]:
		pair[0].albedo_color=Color(pair[1])
		pair[0].shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		pair[0].cull_mode=BaseMaterial3D.CULL_DISABLED
	network.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func rebuild(snapshot: Dictionary) -> void:
	curves.clear()
	active_edges.clear()
	var mesh := ImmediateMesh.new()
	var lines := {"planned":[],"operating":[],"building":[]}
	var states := {"core":"active"}
	for node in snapshot.nodes:states[str(node.node_id)]=str(node.status)
	for edge in snapshot.edges:
		var id := int(str(edge.to).trim_prefix("node_"))
		var curve := Curve3D.new()
		# All X/Z route positions and widths are supplied by the saved blueprint.
		for point in edge.path:curve.add_point(Vector3(float(point[0]),1.3,float(point[1])))
		curves[id]=curve
		var status: String=states[str(edge.to)]
		var group := "planned" if status=="empty" else "building" if status=="constructing" else "operating"
		if status!="empty" and states[str(edge.from)] in ["active","upgrading"]:active_edges.append(id)
		var length := curve.get_baked_length()
		var spacing := 2.5 if group=="planned" else 1.8
		for index in maxi(1,ceili(length/spacing)):
			var start := minf(index*spacing,length)
			var end := minf(start+(0.75 if group=="planned" else 1.0),length)
			if end-start<0.01:continue
			var a := curve.sample_baked(start)
			var b := curve.sample_baked(end)
			var side := Vector3(-(b-a).z,0,(b-a).x).normalized()
			for offset in [-float(edge.width)*0.34,float(edge.width)*0.34]:
				lines[group].append([a+side*offset,b+side*offset,side*0.09])
	for group in ["planned","operating","building"]:
		if lines[group].is_empty():continue
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,planned if group=="planned" else operating if group=="operating" else building)
		for line in lines[group]:
			var a: Vector3=line[0]
			var b: Vector3=line[1]
			var width: Vector3=line[2]
			for vertex in [a-width,b-width,b+width,a-width,b+width,a+width]:mesh.surface_add_vertex(vertex)
		mesh.surface_end()
	network.mesh=mesh

func clear() -> void:
	curves.clear()
	active_edges.clear()
	network.mesh=null
