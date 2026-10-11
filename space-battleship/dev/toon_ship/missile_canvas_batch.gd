extends "res://dev/toon_ship/missile_body_mesh.gd"
## Adjacent missiles only. Their trail, exhaust and body triangles remain in
## original painter order. One native submission per run; no deferred events.
var body_points:=PackedVector2Array()
var body_tints:=PackedColorArray()
var circle_points:=PackedVector2Array()
var chain_points:=PackedVector2Array()
var chain_tints:=PackedColorArray()
var stream_mode:=false
func _init()->void:
	build()
	for index in indices:
		body_points.append(vertices[index]);body_tints.append(colors[index])
	# Godot 4.7.2 non-AA circles use 64 segments, including the closing point.
	for index in 64:
		var a:=float(index)*TAU/64.0;var b:=float(index+1)*TAU/64.0
		circle_points.append_array(PackedVector2Array([Vector2.ZERO,Vector2(cos(a),sin(a)),Vector2(cos(b),sin(b))]))
	begin()
	line(Vector2(0,18),Vector2.ZERO,Color(Color("a7fff0"),0.5),3.35)
	line(Vector2(0,10),Vector2(0,-2),Color("f2fffc"),1.4)
	append_circle(Vector2.ZERO,3,Color("a7fff0"))
	for index in indices:
		chain_points.append(vertices[index]);chain_tints.append(colors[index])
	begin()
	stream_mode=true
func begin()->void:
	vertices.clear();colors.clear();indices.clear()
func append_circle(point:Vector2,radius:float,color:Color)->void:
	var points:PackedVector2Array=Transform2D(Vector2(radius,0),Vector2(0,radius),point)*circle_points
	var tints:=PackedColorArray();tints.resize(points.size());tints.fill(color)
	var base:=vertices.size();vertices.append_array(points);colors.append_array(tints)
	if not stream_mode:
		for index in points.size():indices.append(base+index)
func append_body(point:Vector2,axis:Vector2)->void:
	var points:PackedVector2Array=Transform2D(axis.angle()+PI/2,point)*body_points
	var base:=vertices.size();vertices.append_array(points);colors.append_array(body_tints)
	if not stream_mode:
		for index in points.size():indices.append(base+index)
func chain(point:Vector2,direction:Vector2)->void:
	var axis:Vector2=direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	var points:PackedVector2Array=Transform2D(axis.angle()+PI/2,point)*chain_points
	var base:=vertices.size();vertices.append_array(points);colors.append_array(chain_tints)
	if not stream_mode:
		for index in points.size():indices.append(base+index)
func polygon(points:PackedVector2Array,color:Color)->void:
	if not stream_mode:
		super.polygon(points,color);return
	var triangles:PackedVector2Array=points if points.size()==3 else PackedVector2Array()
	if points.size()!=3:
		for index in Geometry2D.triangulate_polygon(points):triangles.append(points[index])
	var tints:=PackedColorArray();tints.resize(triangles.size());tints.fill(color)
	vertices.append_array(triangles);colors.append_array(tints)
func strip(points:PackedVector2Array,tints:PackedColorArray)->void:
	if not stream_mode:
		super.strip(points,tints);return
	for i in points.size()-2:
		var a:int=i if i%2==0 else i+1
		var b:int=i+1 if i%2==0 else i
		vertices.append_array(PackedVector2Array([points[a],points[b],points[i+2]]))
		colors.append_array(PackedColorArray([tints[a],tints[b],tints[i+2]]))
func append_ribbon(points:PackedVector2Array,color:Color)->void:
	if points.size()<2:return
	const width=0.7 # native compensated 1.4px AA polyline
	const border_size=FEATHER*width
	var clear:=Color(color,0)
	var center:=PackedVector2Array();var left:=PackedVector2Array();var right:=PackedVector2Array()
	var ct:=PackedColorArray();var lt:=PackedColorArray();var rt:=PackedColorArray()
	var first:=Vector2.ZERO;var last:=Vector2.ZERO
	for i in range(1,points.size()):
		first=(points[i]-points[i-1]).normalized()
		if not first.is_zero_approx():break
	for i in range(points.size()-1,0,-1):
		last=(points[i]-points[i-1]).normalized()
		if not last.is_zero_approx():break
	var previous:=Vector2.ZERO
	for i in points.size():
		var direction:Vector2=previous if i==points.size()-1 else (points[i+1]-points[i]).normalized()
		if direction.is_zero_approx():direction=previous
		var base:Vector2
		if i==0:base=first.orthogonal()
		elif i==points.size()-1:base=last.orthogonal()
		else:
			var bisector:Vector2=(previous*direction.length()-direction*previous.length()).normalized()
			var sine:=sin(atan2(bisector.cross(previous),bisector.dot(previous)))
			var length:=1.0
			if not is_zero_approx(sine) and not direction.is_equal_approx(previous):length=clampf(1.0/sine,-3.0,3.0)
			else:bisector=direction.orthogonal()
			if bisector.is_zero_approx():bisector=direction.orthogonal()
			base=bisector*length
		var edge:=base*(width*0.5);var border:=base*border_size;var point:=points[i]
		if i==0:
			var cap:Vector2=-direction*border_size
			center.append_array(PackedVector2Array([point+edge+cap,point-edge+cap]));ct.append_array(PackedColorArray([clear,clear]))
			left.append_array(PackedVector2Array([point+edge+cap,point+edge+cap+border]));lt.append_array(PackedColorArray([clear,clear]))
			right.append_array(PackedVector2Array([point-edge+cap,point-edge+cap-border]));rt.append_array(PackedColorArray([clear,clear]))
		center.append_array(PackedVector2Array([point+edge,point-edge]));ct.append_array(PackedColorArray([color,color]))
		left.append_array(PackedVector2Array([point+edge,point+edge+border]));lt.append_array(PackedColorArray([color,clear]))
		right.append_array(PackedVector2Array([point-edge,point-edge-border]));rt.append_array(PackedColorArray([color,clear]))
		if i==points.size()-1:
			var cap:Vector2=previous*border_size
			center.append_array(PackedVector2Array([point+edge+cap,point-edge+cap]));ct.append_array(PackedColorArray([clear,clear]))
			left.append_array(PackedVector2Array([point+edge,point+edge+cap+border,point+edge+cap]));lt.append_array(PackedColorArray([color,clear,clear]))
			right.append_array(PackedVector2Array([point-edge,point-edge+cap-border,point-edge+cap]));rt.append_array(PackedColorArray([color,clear,clear]))
		previous=direction
	strip(center,ct);strip(left,lt);strip(right,rt)
func flight(point:Vector2,axis:Vector2,age:float,powered:bool,visual:Dictionary,project:Callable,offset:Vector2,budget:float)->void:
	axis=VFX._axis(axis)
	if powered and age>=0.22:
		var samples:PackedVector2Array=visual.get("trail",PackedVector2Array())
		var count:=mini(int(visual.get("samples",0)),4);var head:=int(visual.get("head",0))
		if count>=2:
			var newest:Vector2=project.call(samples[head])-axis*23.0
			var ribbon:=PackedVector2Array()
			for index in count:
				var p:Vector2=project.call(samples[(head-index+14)%14])-axis*23.0
				var delta:=p-newest
				if delta.length()>28.0:ribbon.append(newest+delta.normalized()*28.0+offset);break
				ribbon.append(p+offset)
			append_ribbon(ribbon,Color(VFX.AMBER,0.22+clampf(budget,0,1)*0.16))
	var side:=axis.orthogonal();var nozzle:=point-axis*23.0
	if powered and age>=0.22:
		var thrust:=smoothstep(0.22,0.65,age);var length:=lerpf(5,18,thrust)
		polygon(PackedVector2Array([nozzle-side*2.4,nozzle-axis*length,nozzle+side*2.4]),Color(VFX.AMBER,0.82))
		polygon(PackedVector2Array([nozzle-side*1.1,nozzle-axis*length*0.55,nozzle+side*1.1]),VFX.HOT)
		var ignition:=clampf(1.0-(age-0.22)/0.07,0,1)
		if ignition>0:append_circle(nozzle,3.5*ignition,Color(VFX.HOT,ignition))
	elif age<0.22:append_circle(nozzle-axis*3,2.5,Color(VFX.SMOKE,(1.0-age/0.22)*0.30))
	append_body(point,axis)
func paint(surface:CanvasItem)->void:
	if vertices.is_empty():return
	RenderingServer.canvas_item_add_triangle_array(surface.get_canvas_item(),indices,vertices,colors)
	begin()
