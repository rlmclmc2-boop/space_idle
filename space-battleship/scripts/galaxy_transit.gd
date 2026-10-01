extends Node3D
## Static navigation corridors read the logic-owned parent graph. No layout or gameplay RNG.
var curves := {}
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

func ribbon(lines: Array,curve: Curve3D,start: float,end: float,half_width: float,color: Color) -> void:
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
		lines.append([a,b,side,color])

func rebuild(snapshot: Dictionary) -> void:
	curves.clear()
	active_edges.clear()
	triangle_count=0
	var mesh := ImmediateMesh.new()
	var lines := {"planned":[],"operating":[],"building":[]}
	var states := {"core":"active"}
	var depths := {}
	for node in snapshot.nodes:
		states[str(node.node_id)]=str(node.status)
		depths[str(node.node_id)]=int(node.depth)
	for edge in snapshot.edges:
		var id := int(str(edge.to).trim_prefix("node_"))
		var curve := Curve3D.new()
		# All X/Z positions and widths are supplied by the saved blueprint.
		for point in edge.path:curve.add_point(Vector3(float(point[0]),1.3,float(point[1])))
		curves[id]=curve
		var status: String=states[str(edge.to)]
		var group := "planned" if status=="empty" else "building" if status=="constructing" else "operating"
		if status in ["active","upgrading"] and states[str(edge.from)] in ["active","upgrading"]:active_edges.append(id)
		var depth: int=depths[str(edge.to)]
		var length := curve.get_baked_length()
		var width := float(edge.width)
		if group!="planned" and depth<=2:
			# Opaque primary corridor and small navigation dashes. No transparent halo.
			var color := Color("37555e") if group=="operating" else Color("786444")
			ribbon(lines[group],curve,0,length,width*0.24,color)
		var spacing := 4.6 if group=="planned" else 3.6
		var dash := 1.25 if group=="planned" else 1.6
		var color := Color("293f4c") if group=="planned" else Color("bb9a63") if group=="building" else Color("77aca8") if depth<=2 else Color("41646c")
		var half_width := width*(0.035 if depth<=2 and group!="planned" else 0.055)
		for index in maxi(1,ceili(length/spacing)):
			var start := minf(index*spacing,length)
			ribbon(lines[group],curve,start,minf(start+dash,length),half_width,color)
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
		mesh.surface_end()
	network.mesh=mesh

func clear() -> void:
	curves.clear()
	active_edges.clear()
	triangle_count=0
	network.mesh=null
