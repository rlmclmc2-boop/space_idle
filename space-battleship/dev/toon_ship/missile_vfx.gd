extends RefCounted
## Presentation-only guided rocket. Never advances a shot, samples RNG or emits hits.
## All positions/directions are in the destination CanvasItem's coordinates.
## flight: call once per actual visible projectile at its existing projected point.
## trail: pass the existing visual ring buffer, battle_point callable and draw offset;
## call core=false behind hulls, core=true with the rocket; dense volleys omit smoke. Input data is read-only.
## flash/impact: age is visual seconds since the real launch/contact event, never
## inferred from distance. seed may be shot.serial; budget only quiets decoration.
## Keep draw_body=false when the legacy 29 px missile texture is still drawn.
## Otherwise suppress that texture in the scoped consumer to avoid duplicate bodies.
const FLASH_DURATION := 0.10
const IMPACT_DURATION := 0.22
const SMOKE_DURATION := 0.09
const ARMOR := Color("f2eee3")
const SHADOW := Color("87949e")
const OUTLINE := Color("26313b")
const RED := Color("cc6354")
const AMBER := Color("ffad4c")
const HOT := Color("fff0be")
const SMOKE := Color("aaa4a1")

# Shared nose-relative geometry, uploaded once and never mutated.
# Keep the native antialiased strokes and their original draw order.
static var _fin_left_mesh := _polygon_mesh(PackedVector2Array([Vector2(-16,2.8),Vector2(-24,6.2),Vector2(-22,2.8)]))
static var _fin_right_mesh := _polygon_mesh(PackedVector2Array([Vector2(-16,-2.8),Vector2(-24,-6.2),Vector2(-22,-2.8)]))
static var _body_mesh := _polygon_mesh(PackedVector2Array([Vector2(1,0),Vector2(-7,3.1),Vector2(-23,3.1),Vector2(-25,0),Vector2(-23,-3.1),Vector2(-7,-3.1)]))
static var _body_edge := PackedVector2Array([Vector2(1,0),Vector2(-7,3.1),Vector2(-23,3.1),Vector2(-25,0),Vector2(-23,-3.1),Vector2(-7,-3.1),Vector2(1,0)])
static var _nose_mesh := _polygon_mesh(PackedVector2Array([Vector2(1,0),Vector2(-7,3.1),Vector2(-7,-3.1)]))

static func _polygon_mesh(points:PackedVector2Array)->ArrayMesh:
	var mesh:=ArrayMesh.new()
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(points)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh


static func _noise(seed: int, channel: int) -> float:
	# Bounded deterministic visual hash, independent of game/random generator state.
	return fposmod(sin(float(seed % 65521) * 12.9898 + float(channel) * 78.233) * 43758.5453, 1.0)


static func _axis(direction: Vector2) -> Vector2:
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP


static func flight(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,_seed:int=0,budget:float=1.0,draw_body:bool=true,powered:bool=true)->void:
	var axis:=_axis(direction)
	var side:=axis.orthogonal()
	var nozzle:=point-axis*23.0
	var thrust:=smoothstep(0.22,0.65,age) if powered else 0.0
	if powered and age>=0.22:
		var length:=lerpf(5.0,18.0,thrust)
		surface.draw_colored_polygon(PackedVector2Array([nozzle-side*2.4,nozzle-axis*length,nozzle+side*2.4]),Color(AMBER,0.82))
		surface.draw_colored_polygon(PackedVector2Array([nozzle-side*1.1,nozzle-axis*length*0.55,nozzle+side*1.1]),HOT)
		var ignition:=clampf(1.0-(age-0.22)/0.07,0.0,1.0)
		if ignition>0:surface.draw_circle(nozzle,3.5*ignition,Color(HOT,ignition))
	elif age<0.22:
		surface.draw_circle(nozzle-axis*3.0,2.5,Color(SMOKE,(1.0-age/0.22)*0.30))
	if not draw_body:return
	surface.draw_set_transform(point,axis.angle())
	surface.draw_mesh(_fin_left_mesh,null,Transform2D.IDENTITY,OUTLINE)
	surface.draw_line(Vector2(-19,3.4),Vector2(-23,5.0),RED,1.5,true)
	surface.draw_mesh(_fin_right_mesh,null,Transform2D.IDENTITY,OUTLINE)
	surface.draw_line(Vector2(-19,-3.4),Vector2(-23,-5.0),RED,1.5,true)
	surface.draw_mesh(_body_mesh,null,Transform2D.IDENTITY,ARMOR)
	surface.draw_polyline(_body_edge,OUTLINE,1.0,true)
	surface.draw_mesh(_nose_mesh,null,Transform2D.IDENTITY,RED)
	surface.draw_line(Vector2(-9,-1.5),Vector2(-21,-1.5),SHADOW,1.5,true)
	surface.draw_line(Vector2(-9,1.7),Vector2(-20,1.7),Color.WHITE,0.9,true)
	surface.draw_set_transform(Vector2.ZERO)


static func trail(surface: CanvasItem, visual: Dictionary, project: Callable, offset: Vector2, core: bool, _seed: int = 0, budget: float = 1.0) -> void:
	if not core or visual.is_empty():return
	var points:PackedVector2Array=visual.get("trail",PackedVector2Array())
	var head:=int(visual.get("head",0))
	var count:=mini(int(visual.get("samples",0)),4)
	if count<2:return
	var ribbon:=PackedVector2Array()
	var axis:=Vector2.from_angle(float(visual.get("angle",0.0)))
	var newest:Vector2=project.call(points[head])-axis*23.0
	for index in count:
		var point:Vector2=project.call(points[(head-index+14)%14])-axis*23.0
		var displacement:=point-newest
		if displacement.length()>28.0:
			ribbon.append(newest+displacement.normalized()*28.0+offset);break
		ribbon.append(point+offset)
	if ribbon.size()>1:surface.draw_polyline(ribbon,Color(AMBER,0.22+clampf(budget,0.0,1.0)*0.16),1.4,true)


static func flash(surface: CanvasItem, point: Vector2, direction: Vector2, age: float, budget: float = 1.0) -> void:
	if age < 0.0 or age >= FLASH_DURATION:
		return
	var axis := _axis(direction)
	var side := axis.orthogonal()
	var t := age / FLASH_DURATION
	var fade := (1.0 - t) * lerpf(0.40, 1.0, clampf(budget, 0.0, 1.0))
	# Minimal ejector glint; no extra smoke behind dense salvoes.
	var hot := clampf(1.0 - age / 0.045, 0.0, 1.0)
	surface.draw_line(point - axis * 3.0, point + axis * 5.0, Color(HOT, hot * fade), 2.5, true)


static func impact(surface: CanvasItem, point: Vector2, direction: Vector2, age: float, critical: bool, budget: float = 1.0, seed: int = 0) -> void:
	if age < 0.0 or age >= IMPACT_DURATION:
		return
	var axis := _axis(direction)
	var t := age / IMPACT_DURATION
	var decoration := lerpf(0.45, 1.0, clampf(budget, 0.0, 1.0))
	var fade := (1.0 - t) * (1.0 - t) * decoration
	var scale_value := 1.12 if critical else 1.0
	# A compact warhead burst distinguishes each heavy rocket from a bullet.
	for index in 3:
		var radial:=axis.rotated(float(index)*TAU/3.0+0.4)
		var center:=point+radial*(2.0+6.0*t)
		var radius:=4.0+3.0*t
		surface.draw_circle(center,radius,Color(SMOKE,fade*0.32))
		var fire:=clampf(1.0-age/0.13,0.0,1.0)
		surface.draw_circle(center,radius*0.8,Color(AMBER,fire*decoration))
	for index in 3:
		var radial:=axis.rotated(float(index)*TAU/3.0)
		var reach:float=(4.0+14.0*t)*scale_value
		var end:=point+radial*reach
		surface.draw_line(end-radial*3.0,end,Color(AMBER,fade*0.6),1.3,true)
	var hot := clampf(1.0 - age / 0.065, 0.0, 1.0)
	surface.draw_circle(point, (4.0 + 1.0 * t) * scale_value, Color(HOT, hot * decoration))


static func retire(surface:CanvasItem,point:Vector2,direction:Vector2,age:float)->void:
	# Neutral casing breakup: no warhead flash, hit ring, damage cue or shake.
	var t:=clampf(age/0.18,0.0,1.0)
	for index in 3:
		var axis:=direction.rotated(float(index-1)*1.4)
		var center:=point+axis*(2.0+7.0*t)
		surface.draw_line(center-axis*1.5,center+axis*1.5,Color(SHADOW,(1.0-t)*0.8),1.4,true)
