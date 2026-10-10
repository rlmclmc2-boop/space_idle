extends RefCounted
## Immutable native stroke meshes. Vertex coefficients keep the exact local
## AA width/feather separate from animation size; no per-frame polygon upload.
const STROKE_SHADER=preload("res://scripts/resident_stroke.gdshader")
var assets:Dictionary={}
var meshes_built=0
func asset(kind:String)->Dictionary:
	if assets.has(kind):return assets[kind]
	var paths=[];var factor=0.045;var minimum=1.0;var color=Color("c2c9c9")
	if kind=="deck_physical":
		factor=0.018;minimum=0.8;color=Color("757f83")
		for stripe in 3:paths.append(PackedVector2Array([Vector2(-0.15,0.23+0.21+stripe*0.025),Vector2(0.15,0.23+0.21+stripe*0.025)]))
	elif kind=="deck_energy":
		for side in [-1,1]:
			var x=float(side)*0.19
			paths.append(PackedVector2Array([Vector2(x*0.65,0.23-0.24),Vector2(x,0.23-0.13),Vector2(x,0.23+0.13),Vector2(x*0.65,0.23+0.24)]))
	else:
		factor=0.10;color=Color("64b5ff")
		for side in [-1,1]:paths.append(PackedVector2Array([Vector2(side*0.49,0.20),Vector2(side*0.49,0.44)]))
	var mesh=build_mesh(paths,color)
	assets[kind]={"mesh":mesh,"factor":factor,"minimum":minimum};meshes_built+=1
	return assets[kind]
func material_for(packet:Dictionary)->ShaderMaterial:
	var material=ShaderMaterial.new();material.shader=STROKE_SHADER
	material.set_shader_parameter("stroke_factor",packet.factor)
	material.set_shader_parameter("minimum_width",packet.minimum)
	return material
func join_basis(previous:Vector2,next:Vector2)->Vector2:
	var bisector=(previous*next.length()-next*previous.length()).normalized()
	var angle=atan2(bisector.cross(previous),bisector.dot(previous))
	var divisor=sin(angle);var distance=1.0
	if not is_zero_approx(divisor) and not next.is_equal_approx(previous):distance=clampf(1.0/divisor,-3.0,3.0)
	else:bisector=next.orthogonal()
	if bisector.is_zero_approx():bisector=next.orthogonal()
	return bisector*distance
func item(point:Vector2,edge:Vector2,feather:Vector2,alpha:float)->Array:return [point,edge,feather,alpha]
func append_strip(strip:Array,vertices:PackedVector3Array,uvs:PackedVector2Array,custom:PackedFloat32Array,colors:PackedColorArray,indices:PackedInt32Array,color:Color)->void:
	var base=vertices.size()
	for entry in strip:
		vertices.append(Vector3(entry[0].x,entry[0].y,0));uvs.append(entry[1])
		custom.append_array(PackedFloat32Array([entry[2].x,entry[2].y,0,0]))
		colors.append(Color(color,float(entry[3])))
	for index in range(2,strip.size()):
		indices.append(base+index-2)
		indices.append(base+index-1 if index%2==0 else base+index)
		indices.append(base+index if index%2==0 else base+index-1)
func build_mesh(paths:Array,color:Color)->ArrayMesh:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var custom=PackedFloat32Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	for path in paths:
		var directions=[]
		for index in path.size()-1:directions.append((path[index+1]-path[index]).normalized())
		var bases=[]
		for index in path.size():bases.append(directions[0].orthogonal() if index==0 else directions[-1].orthogonal() if index==path.size()-1 else join_basis(directions[index-1],directions[index]))
		var core=[];var left=[];var right=[]
		var start:Vector2=path[0];var end:Vector2=path[-1];var first:Vector2=bases[0];var last:Vector2=bases[-1]
		var start_cap:Vector2=-directions[0];var end_cap:Vector2=directions[-1]
		core.append_array([item(start,first,start_cap,0),item(start,-first,start_cap,0)])
		left.append_array([item(start,first,start_cap,0),item(start,first,start_cap+first,0)])
		right.append_array([item(start,-first,start_cap,0),item(start,-first,start_cap-first,0)])
		for index in path.size():
			var point:Vector2=path[index];var edge:Vector2=bases[index]
			core.append_array([item(point,edge,Vector2.ZERO,1),item(point,-edge,Vector2.ZERO,1)])
			left.append_array([item(point,edge,Vector2.ZERO,1),item(point,edge,edge,0)])
			right.append_array([item(point,-edge,Vector2.ZERO,1),item(point,-edge,-edge,0)])
		core.append_array([item(end,last,end_cap,0),item(end,-last,end_cap,0)])
		left.append_array([item(end,last,Vector2.ZERO,1),item(end,last,end_cap+last,0),item(end,last,end_cap,0)])
		right.append_array([item(end,-last,Vector2.ZERO,1),item(end,-last,end_cap-last,0),item(end,-last,end_cap,0)])
		for strip in [core,left,right]:append_strip(strip,vertices,uvs,custom,colors,indices,color)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_CUSTOM0]=custom.to_byte_array()
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh
