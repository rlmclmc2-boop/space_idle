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
	# The simulation point is the nose; the substantial rocket body trails it.
	for sign_value in [-1.0,1.0]:
		var fin:=PackedVector2Array([point-axis*16.0+side*sign_value*2.8,point-axis*24.0+side*sign_value*6.2,point-axis*22.0+side*sign_value*2.8])
		surface.draw_colored_polygon(fin,OUTLINE)
		surface.draw_line(point-axis*19.0+side*sign_value*3.4,point-axis*23.0+side*sign_value*5.0,RED,1.5,true)
	var body:=PackedVector2Array([point+axis,point-axis*7.0-side*3.1,point-axis*23.0-side*3.1,point-axis*25.0,point-axis*23.0+side*3.1,point-axis*7.0+side*3.1])
	surface.draw_colored_polygon(body,ARMOR)
	var edge:=PackedVector2Array(body);edge.append(body[0])
	surface.draw_polyline(edge,OUTLINE,1.0,true)
	surface.draw_colored_polygon(PackedVector2Array([point+axis,point-axis*7.0-side*3.1,point-axis*7.0+side*3.1]),RED)
	surface.draw_line(point-axis*9.0+side*1.5,point-axis*21.0+side*1.5,SHADOW,1.5,true)
	surface.draw_line(point-axis*9.0-side*1.7,point-axis*20.0-side*1.7,Color.WHITE,0.9,true)


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
