extends RefCounted
## Presentation-only convex envelope; gap is measured perpendicular to every edge.
const ASPECT := 1.6

static func fit(points: PackedVector2Array, gap: float) -> PackedVector2Array:
	var half_width := 0.0
	var slope_normal_length := sqrt(0.25+1.0/(ASPECT*ASPECT))
	for point in points:
		half_width=maxf(half_width,absf(point.x)+gap)
		half_width=maxf(half_width,absf(point.x)*0.5+absf(point.y)/ASPECT+gap*slope_normal_length)
	var height := half_width*ASPECT
	return PackedVector2Array([Vector2(0,-height),Vector2(half_width,-height*0.5),Vector2(half_width,height*0.5),Vector2(0,height),Vector2(-half_width,height*0.5),Vector2(-half_width,-height*0.5)])

static func alpha_boundary(image: Image) -> PackedVector2Array:
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var points := PackedVector2Array()
	for y in height:
		var left := width
		var right := -1
		for x in width:
			if bytes[(y*width+x)*4+3]>0:left=mini(left,x);right=maxi(right,x)
		if right<0:continue
		# Pixel-cell corners cover alpha AA fringes, not just pixel centres.
		for point in [Vector2(left,y),Vector2(right+1,y),Vector2(right+1,y+1),Vector2(left,y+1)]:
			points.append((point-Vector2(width,height)/2.0)/float(width))
	return points

static func weapon_bounds(width: float, physical: bool) -> PackedVector2Array:
	var half := 0.24 if physical else 0.60
	var front := 0.73 if physical else 0.45
	return PackedVector2Array([Vector2(-half,-0.22)*width,Vector2(half,-0.22)*width,Vector2(half,front)*width,Vector2(-half,front)*width])

static func min_clearance(points: PackedVector2Array, polygon: PackedVector2Array) -> float:
	# Independent edge-distance audit, rather than the fitting inequalities above.
	var distance := INF
	for i in polygon.size():
		var start := polygon[i]
		var edge := polygon[(i+1)%polygon.size()]-start
		for point in points:distance=minf(distance,edge.cross(point-start)/edge.length())
	return distance
