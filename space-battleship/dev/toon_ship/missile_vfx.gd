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
const IMPACT_DURATION := 0.12
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


static func flight(surface: CanvasItem, point: Vector2, direction: Vector2, _age: float, _seed: int = 0, budget: float = 1.0, draw_body: bool = true, powered: bool = true) -> void:
	var axis:=_axis(direction)
	var side:=axis.orthogonal()
	var nozzle:=point-axis*5.0
	if powered:
		surface.draw_line(nozzle,nozzle-axis*3.5,Color(AMBER,0.40+clampf(budget,0.0,1.0)*0.18),1.3,true)
	if not draw_body:return
	# Twelve logical pixels long, with narrow folded fins. Every live shot stays
	# visible, but thirty-two simultaneous rockets must not become white confetti.
	var body:=PackedVector2Array([point+axis*7.0,point+axis*3.5-side*1.7,point-axis*5.0-side*1.7,point-axis*5.0+side*1.7,point+axis*3.5+side*1.7])
	surface.draw_colored_polygon(body,Color("b9c0c3"))
	surface.draw_colored_polygon(PackedVector2Array([point+axis*7.0,point+axis*3.5-side*1.7,point+axis*3.5+side*1.7]),RED)
	surface.draw_line(point-axis*3.0-side*1.0,point+axis*2.5-side*1.0,Color("e1e5df"),0.8,true)


static func trail(surface: CanvasItem, visual: Dictionary, project: Callable, offset: Vector2, core: bool, seed: int = 0, budget: float = 1.0) -> void:
	if visual.is_empty() or not project.is_valid():
		return
	var points: PackedVector2Array = visual.get("trail", PackedVector2Array())
	var times: PackedFloat32Array = visual.get("trail_times", PackedFloat32Array())
	var capacity := mini(points.size(), times.size())
	if capacity < 2:
		return
	var samples := mini(int(visual.get("samples", 0)), capacity)
	var head := posmod(int(visual.get("head", 0)), capacity)
	var shot_age := float(visual.get("age", 0.0))
	var head_point: Vector2 = project.call(points[head])
	var decoration := lerpf(0.38, 1.0, clampf(budget, 0.0, 1.0))
	var lifetime := SMOKE_DURATION * lerpf(0.70, 1.0, clampf(budget, 0.0, 1.0))
	var previous := head_point
	var path_length := 0.0
	var last_puff := head_point
	var drawn:=0
	# Iterate bounded history without adding, resampling or altering trajectory.
	for index in range(1, samples):
		var slot := posmod(head - index, capacity)
		var sample_point: Vector2 = project.call(points[slot])
		path_length += previous.distance_to(sample_point)
		previous = sample_point
		var age := shot_age - float(times[slot])
		if age > lifetime or path_length > 28.0:
			break
		if age < 0.0 or path_length < 17.0:
			continue
		if (core and index >= 4) or (not core and index < 4):
			continue
		if last_puff.distance_to(sample_point) < 7.0:
			continue
		last_puff = sample_point
		var t := clampf(age / lifetime, 0.0, 1.0)
		var fade := (1.0 - t) * (1.0 - t) * decoration
		var radius := 1.2 + t * 1.2
		var drift := Vector2(_noise(seed, slot * 2) - 0.5, _noise(seed, slot * 2 + 1) - 0.5) * t * 3.0
		var center := sample_point + offset + drift
		surface.draw_circle(center, radius, Color(SMOKE, fade * 0.18))
		surface.draw_circle(center + Vector2(-0.6, -0.7), radius * 0.60, Color(ARMOR, fade * 0.06))
		drawn+=1
		if drawn>=1:break


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
	# One compact contact glint, with only two short fragments. No smoke lobes.
	for index in 2:
		var radial:=axis.rotated(PI*0.5+PI*float(index))
		var reach:float=(3.0+7.0*t)*scale_value
		var end:=point+radial*reach
		surface.draw_line(end-radial*2.0,end,Color(AMBER,fade*0.55),1.0,true)
	var hot := clampf(1.0 - age / 0.065, 0.0, 1.0)
	surface.draw_circle(point, (2.5 + 1.0 * t) * scale_value, Color(HOT, hot * decoration))
