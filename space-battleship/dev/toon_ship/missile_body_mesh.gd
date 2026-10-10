extends RefCounted
## Owner-local immutable rocket body. Triangles retain the original primitive
## order, line widths, closed joins and transparent antialiasing feathers.
## Line construction follows Godot 4.7.2 renderer_canvas_cull.cpp (MIT):
## https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_canvas_cull.cpp
# Copyright (c) 2014-present Godot Engine contributors.
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
const VFX=preload("res://dev/toon_ship/missile_vfx.gd")
const FEATHER=1.25
var vertices=PackedVector2Array()
var colors=PackedColorArray()
var indices=PackedInt32Array()

func polygon(points:PackedVector2Array,color:Color)->void:
 var base=vertices.size()
 vertices.append_array(points)
 for point in points:colors.append(color)
 for index in Geometry2D.triangulate_polygon(points):indices.append(base+index)

func strip(points:PackedVector2Array,tints:PackedColorArray)->void:
 var base=vertices.size()
 vertices.append_array(points);colors.append_array(tints)
 for i in points.size()-2:
  if i%2==0:indices.append_array(PackedInt32Array([base+i,base+i+1,base+i+2]))
  else:indices.append_array(PackedInt32Array([base+i+1,base+i,base+i+2]))

func quad(points:PackedVector2Array,tints:PackedColorArray)->void:
 var base=vertices.size()
 vertices.append_array(points);colors.append_array(tints)
 indices.append_array(PackedInt32Array([base,base+1,base+2,base,base+2,base+3]))

func line(from:Vector2,to:Vector2,color:Color,width:float)->void:
 # All four body lines are below 2*FEATHER: preserve native width compensation.
 width*=0.5
 var diff=from-to;var dir=diff.orthogonal().normalized();var t=dir*width*0.5
 var bl=from+t;var br=from-t;var el=to+t;var er=to-t
 var border_size=FEATHER*width if width<1.0 else FEATHER
 var border=dir*border_size;var border2=diff.normalized()*border_size
 var clear=Color(color,0.0)
 quad(PackedVector2Array([bl,br,er,el]),PackedColorArray([color,color,color,color]))
 quad(PackedVector2Array([bl,bl+border,el+border,el]),PackedColorArray([color,clear,clear,color]))
 quad(PackedVector2Array([br,br-border,er-border,er]),PackedColorArray([color,clear,clear,color]))
 quad(PackedVector2Array([bl,bl+border2,br+border2,br]),PackedColorArray([color,clear,clear,color]))
 quad(PackedVector2Array([el,el-border2,er-border2,er]),PackedColorArray([color,clear,clear,color]))
 quad(PackedVector2Array([bl,bl+border2,bl+border+border2,bl+border]),PackedColorArray([color,clear,clear,clear]))
 quad(PackedVector2Array([br,br+border2,br-border+border2,br-border]),PackedColorArray([color,clear,clear,clear]))
 quad(PackedVector2Array([el,el-border2,el+border-border2,el+border]),PackedColorArray([color,clear,clear,clear]))
 quad(PackedVector2Array([er,er-border2,er-border-border2,er-border]),PackedColorArray([color,clear,clear,clear]))

func closed_outline(points:PackedVector2Array,color:Color,width:float)->void:
 width*=0.5
 var border_size=FEATHER*width if width<1.0 else FEATHER
 var center=PackedVector2Array();var left=PackedVector2Array();var right=PackedVector2Array()
 var center_colors=PackedColorArray();var edge_colors=PackedColorArray()
 var clear=Color(color,0.0)
 for i in points.size()+1:
  var at=i%points.size();var before=(at+points.size()-1)%points.size();var after=(at+1)%points.size()
  var previous=(points[at]-points[before]).normalized();var direction=(points[after]-points[at]).normalized()
  var bisector=(previous*direction.length()-direction*previous.length()).normalized()
  var sine=sin(atan2(bisector.cross(previous),bisector.dot(previous)))
  var length=1.0
  if not is_zero_approx(sine) and not direction.is_equal_approx(previous):length=clampf(1.0/sine,-3.0,3.0)
  else:bisector=direction.orthogonal()
  if bisector.is_zero_approx():bisector=direction.orthogonal()
  var base=bisector*length;var edge=base*(width*0.5);var border=base*border_size;var point=points[at]
  center.append_array(PackedVector2Array([point+edge,point-edge]));center_colors.append_array(PackedColorArray([color,color]))
  left.append_array(PackedVector2Array([point+edge,point+edge+border]))
  right.append_array(PackedVector2Array([point-edge,point-edge-border]))
  edge_colors.append_array(PackedColorArray([color,clear]))
 strip(center,center_colors);strip(left,edge_colors);strip(right,edge_colors)

func build()->ArrayMesh:
 var axis=Vector2.UP;var side=axis.orthogonal()
 for sign_value in [-1.0,1.0]:
  polygon(PackedVector2Array([-axis*16.0+side*sign_value*2.8,-axis*24.0+side*sign_value*6.2,-axis*22.0+side*sign_value*2.8]),VFX.OUTLINE)
  line(-axis*19.0+side*sign_value*3.4,-axis*23.0+side*sign_value*5.0,VFX.RED,1.5)
 var body=PackedVector2Array([axis,-axis*7.0-side*3.1,-axis*23.0-side*3.1,-axis*25.0,-axis*23.0+side*3.1,-axis*7.0+side*3.1])
 polygon(body,VFX.ARMOR);closed_outline(body,VFX.OUTLINE,1.0)
 polygon(PackedVector2Array([axis,-axis*7.0-side*3.1,-axis*7.0+side*3.1]),VFX.RED)
 line(-axis*9.0+side*1.5,-axis*21.0+side*1.5,VFX.SHADOW,1.5)
 line(-axis*9.0-side*1.7,-axis*20.0-side*1.7,Color.WHITE,0.9)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
 return mesh
