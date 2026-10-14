extends RefCounted
## Immutable topology. Shader computes contact age/shape; CPU sends event records only.
const SHADER = preload("res://shaders/gpu_contacts.gdshader")
static func build(category:int)->ArrayMesh:
 var points:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray()
 var emit=func(op:int,x:float,y:float,code:float,alpha:float):
  points.append(Vector3(x,y,0));uv.append(Vector2(op,code));colors.append(Color(1,1,1,alpha))
 var quad=func(op:int,corners:Array):
  for index in [0,1,2,0,2,3]:
   var v:Array=corners[index];emit.call(op,v[0],v[1],v[2],v[3])
 for op in ([0,1,2,4,5] if category==0 else [8,9,12,13,14,15]):
  # x endpoint; y signed half-width; code=(cap+1)*2+outer; alpha feather.
  var bl=[0,1,2,1];var br=[0,-1,2,1];var el=[1,1,2,1];var er=[1,-1,2,1]
  quad.call(op,[bl,br,er,el])
  quad.call(op,[bl,[0,1,3,0],[1,1,3,0],el])
  quad.call(op,[br,[0,-1,3,0],[1,-1,3,0],er])
  quad.call(op,[bl,[0,1,4,0],[0,-1,4,0],br])
  quad.call(op,[el,[1,1,0,0],[1,-1,0,0],er])
  quad.call(op,[bl,[0,1,4,0],[0,1,5,0],[0,1,3,0]])
  quad.call(op,[br,[0,-1,4,0],[0,-1,5,0],[0,-1,3,0]])
  quad.call(op,[el,[1,1,0,0],[1,1,1,0],[1,1,3,0]])
  quad.call(op,[er,[1,-1,0,0],[1,-1,1,0],[1,-1,3,0]])
 var ring_op:=3 if category==0 else 10
 var count:=11 if category==0 else 4
 # Preserve native center, left feather, right feather command order.
 for band in 3:
  for i in count:
   var next:=(i+1)%count
   if band==0:quad.call(ring_op,[[i,1,0,1],[i,-1,0,1],[next,-1,0,1],[next,1,0,1]])
   else:
    var sign_value:=1 if band==1 else -1
    quad.call(ring_op,[[i,sign_value,0,1],[i,sign_value,1,0],[next,sign_value,1,0],[next,sign_value,0,1]])
 if category==1:
  # Reorder to original per-event primitive order (launch fill, lines; impact ring, fill, rays).
  for op in [6,7,11]:
   for index in ([0,1,2,0,2,3] if op==11 else [0,1,2]):emit.call(op,index,0,0,1)
 var order:Array=[]
 for i in range(0,points.size(),3):order.append(i)
 order.sort_custom(func(a,b):return uv[a].x<uv[b].x or (uv[a].x==uv[b].x and a<b))
 var sorted_points:=PackedVector3Array();var sorted_uv:=PackedVector2Array();var sorted_colors:=PackedColorArray()
 for start in order:
  for k in 3:sorted_points.append(points[start+k]);sorted_uv.append(uv[start+k]);sorted_colors.append(colors[start+k])
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=sorted_points;arrays[Mesh.ARRAY_TEX_UV]=sorted_uv;arrays[Mesh.ARRAY_COLOR]=sorted_colors
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.custom_aabb=AABB(Vector3(-8192,-8192,-1),Vector3(16384,16384,2))
 return mesh
