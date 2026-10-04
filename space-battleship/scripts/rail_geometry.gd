extends RefCounted
## Pixel geometry shared by the visible discharge and legendary hit strip.
static func width(trail_width: float,multiplier: float=1.0) -> float:
	return maxf(12.0,trail_width)*maxf(1.0,multiplier)
static func exit_point(origin: Vector2,direction: Vector2,bounds: Vector2,full_width: float) -> Vector2:
	var reach:=INF
	if direction.x>0.0001:reach=minf(reach,(bounds.x-origin.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-origin.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-origin.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,-origin.y/direction.y)
	return origin if not is_finite(reach) else origin+direction*(maxf(0.0,reach)+full_width)
static func contains(point: Vector2,origin: Vector2,end: Vector2,full_width: float) -> bool:
	var ray:=end-origin
	var along: float=(point-origin).dot(ray.normalized())
	return along>=0.0 and along<=ray.length() and Geometry2D.get_closest_point_to_segment(point,origin,end).distance_to(point)<=full_width*0.5
