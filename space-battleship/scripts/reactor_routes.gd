extends RefCounted
## Page coordinates; the only authority for tube centers and pulse routes.
const ORIGIN := Vector2(345,245)
const TRUNK_X := 665.0
const VIEW_TOP := 420.0
const EQUIPMENT_AT := Vector2(80,15)
const DEVICE_INLETS := {"weapons":Vector2(58,86),"defence":Vector2(43,98),"smelting":Vector2(49,98),"condensation":Vector2(64,126)}
const PULSE_SPACING := 92.0

static func curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2) -> void:
	for i in range(1,17):
		var t := i/16.0
		points.append(a*(1.0-t)*(1.0-t)+b*2.0*(1.0-t)*t+c*t*t)

static func main_route() -> PackedVector2Array:
	var p := PackedVector2Array([Vector2(362,245),Vector2(362,360)])
	curve(p,Vector2(362,360),Vector2(362,384),Vector2(386,384))
	p.append(Vector2(629,384))
	curve(p,Vector2(629,384),Vector2(665,384),Vector2(665,420))
	p.append(Vector2(665,1120))
	curve(p,Vector2(665,1120),Vector2(665,1136),Vector2(681,1136))
	p.append(Vector2(733,1136))
	for i in p.size():p[i]-=ORIGIN
	return p

static func inlet(key: String) -> Vector2:
	return EQUIPMENT_AT+DEVICE_INLETS.get(key,Vector2(58,86))

static func branch_route(key: String) -> PackedVector2Array:
	var end := inlet(key)
	return PackedVector2Array([Vector2(17,end.y),end])

static func length_of(route: PackedVector2Array) -> float:
	var result := 0.0
	for i in range(1,route.size()):result+=route[i-1].distance_to(route[i])
	return result

static func point_at(route: PackedVector2Array, distance: float) -> Vector2:
	var remaining := maxf(0.0,distance)
	for i in range(1,route.size()):
		var span := route[i-1].distance_to(route[i])
		if remaining <= span:return route[i-1].lerp(route[i],remaining/maxf(0.001,span))
		remaining-=span
	return route[-1]

static func junction_distance(page_y: float) -> float:
	var route := main_route()
	# The curved header terminates exactly at the scroll viewport's top edge.
	var distance := 0.0
	for i in range(1,route.size()):
		if route[i-1].is_equal_approx(Vector2(TRUNK_X,VIEW_TOP)-ORIGIN):break
		distance+=route[i-1].distance_to(route[i])
	return distance+page_y-VIEW_TOP
