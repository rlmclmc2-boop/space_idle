extends RefCounted
# Fixed pulse flight appearance, matching Godot 4.7.2 native AA geometry.
# Preserve adjacent packet order; pool resources by run. Colors may differ by
# one RGBA8 level from native primitives; no texture, stroke or effect omission.
# Native AA construction adapted from Godot ed1daf0bf renderer_canvas_cull.cpp:
# https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_canvas_cull.cpp
# Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
const CYAN=Color("42edee")
const BLUE=Color("398bdf")
const WHITE=Color("f1ffff")
var mesh:ArrayMesh
var vertices=PackedVector3Array()
var colors=PackedColorArray()
var indices=PackedInt32Array()
func vertex(pos:Vector2,color:Color)->int:
 var i=vertices.size();vertices.append(Vector3(pos.x,pos.y,0));colors.append(color);return i
func quad(points:Array,weights:Array,color:Color)->void:
 var base=vertices.size()
 for i in 4:vertex(points[i],Color(color,color.a*weights[i]))
 indices.append_array(PackedInt32Array([base,base+1,base+2,base,base+2,base+3]))
func line(a:Vector2,b:Vector2,width:float,color:Color)->void:
 const feather=1.25
 if width<=feather*2.:width*=.5
 elif width<=feather*4.:width=remap(width,feather*2.,feather*4.,width*.5,width-feather*.5)
 else:width-=feather*.5
 var diff=(a-b).normalized();var dir=diff.orthogonal();var t=dir*width*.5
 var bl=a+t;var br=a-t;var el=b+t;var er=b-t
 var border_size=feather*(width if width<1. else 1.)
 var border=dir*border_size;var cap=diff*border_size
 quad([bl,br,er,el],[1,1,1,1],color)
 quad([bl,bl+border,el+border,el],[1,0,0,1],color)
 quad([br,br-border,er-border,er],[1,0,0,1],color)
 quad([bl,bl+cap,br+cap,br],[1,0,0,1],color)
 quad([el,el-cap,er-cap,er],[1,0,0,1],color)
 quad([bl,bl+cap,bl+border+cap,bl+border],[1,0,0,0],color)
 quad([br,br+cap,br-border+cap,br-border],[1,0,0,0],color)
 quad([el,el-cap,el+border-cap,el+border],[1,0,0,0],color)
 quad([er,er-cap,er-border-cap,er-border],[1,0,0,0],color)
func polygon(points:Array,color:Color)->void:
 var base=vertices.size()
 for p in points:vertex(p,color)
 for i in range(1,points.size()-1):indices.append_array(PackedInt32Array([base,base+i,base+i+1]))
func build()->void:
 line(Vector2(-11,0),Vector2(9,0),12,Color(BLUE,.2))
 polygon([Vector2(9,0),Vector2(0,-4.5),Vector2(-11,0),Vector2(0,4.5)],CYAN)
 polygon([Vector2(9,0),Vector2(1,-2.2),Vector2(-6,0),Vector2(1,2.2)],WHITE)
 for side in [-1.,1.]:line(Vector2(-11,-side*2),Vector2(-25,-side*3),1.8,Color(BLUE,.7))
 line(Vector2(2,5),Vector2(2,-5),1.2,Color(CYAN,.8))
 var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_COLOR]=colors;a[Mesh.ARRAY_INDEX]=indices
 mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
var pool:Array[MultiMesh]=[]
var cursor=0
var allocations=0
func _init()->void:build()
func begin()->void:cursor=0
func paint(surface:CanvasItem,packets:Array[Transform2D])->void:
 if packets.is_empty():return
 if cursor==pool.size():
  var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_2D;batch.mesh=mesh
  pool.append(batch);allocations+=1
 var batch=pool[cursor];cursor+=1
 if batch.instance_count<packets.size():
  var capacity=maxi(8,batch.instance_count)
  while capacity<packets.size():capacity*=2
  batch.instance_count=capacity;allocations+=1
 batch.visible_instance_count=packets.size()
 for i in packets.size():batch.set_instance_transform_2d(i,packets[i])
 surface.draw_multimesh(batch,null)
