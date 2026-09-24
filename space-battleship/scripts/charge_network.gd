extends Control
## Routes and particle positions share baked paths in this layer's coordinate space.
var routes: Dictionary = {}
var structure: Control
var flowing := false
var accumulator := 0.0
var geometry_revision := 0
const SPEED := 105.0
const SPACING := 150.0
const COLORS := {"charging":Color("43dbea"),"paused":Color("30495b"),"insufficient":Color("614c34"),"available":Color("285668"),"locked":Color("1c2c39")}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	structure=Control.new()
	structure.mouse_filter=Control.MOUSE_FILTER_IGNORE
	structure.show_behind_parent=true
	add_child(structure)
	structure.draw.connect(draw_structure)
	set_process(false)
	visibility_changed.connect(update_activity)

func anchor_position(anchor: Control) -> Vector2:
	return get_global_transform().affine_inverse()*(anchor.get_global_transform()*(anchor.size*0.5))

func sync_geometry(source: Control, ports: Dictionary, viewport: Control) -> void:
	var origin := anchor_position(source)
	var inverse := get_global_transform().affine_inverse()
	var left_top: Vector2 = inverse*(viewport.get_global_transform()*Vector2.ZERO)
	var right_bottom: Vector2 = inverse*(viewport.get_global_transform()*viewport.size)
	var changed := false
	var nearest_y := INF
	for port: Control in ports.values():
		nearest_y=minf(nearest_y,anchor_position(port).y)
	var bus_y := lerpf(origin.y,nearest_y,0.52) if not ports.is_empty() else origin.y
	for key in routes.keys():
		if not ports.has(key):
			routes.erase(key)
			changed=true
	for key in ports:
		var end := anchor_position(ports[key])
		var shown := end.x>=left_top.x+2 and end.x<=right_bottom.x-2 and end.y>=left_top.y+2 and end.y<=right_bottom.y-2
		var tap := Vector2(end.x,bus_y)
		if not routes.has(key):
			routes[key]={"state":"available","active":false,"distance":0.0,"signature":[]}
		var route: Dictionary = routes[key]
		var signature := [origin,end,shown,bus_y]
		if route.signature==signature:
			continue
		route.signature=signature
		route.origin=origin
		route.end=end
		route.tap=tap
		route.visible=shown
		route.points=rounded_path([origin,Vector2(origin.x,tap.y),tap,end])
		# The branch is a suffix of the same baked path used by packets.
		route.branch=PackedVector2Array()
		for point: Vector2 in route.points:
			if point.y>bus_y+0.01:
				route.branch.append(point)
		if route.branch.size()>0:
			route.tap=route.branch[0]
		route.lengths=PackedFloat32Array([0.0])
		var length := 0.0
		for i in range(1,route.points.size()):
			length+=route.points[i-1].distance_to(route.points[i])
			route.lengths.append(length)
		route.length=length
		changed=true
	if changed:
		geometry_revision+=1
		structure.queue_redraw()
		queue_redraw()
	update_activity()

static func rounded_path(vertices: Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point: Vector2 in vertices:
		if clean.is_empty() or clean[-1].distance_to(point)>0.01:
			clean.append(point)
	if clean.size()<3:
		return clean
	var path := PackedVector2Array([clean[0]])
	for i in range(1,clean.size()-1):
		var corner := clean[i]
		var radius := minf(8,minf(clean[i-1].distance_to(corner),corner.distance_to(clean[i+1]))*0.4)
		var entry := corner+(clean[i-1]-corner).normalized()*radius
		var leave := corner+(clean[i+1]-corner).normalized()*radius
		path.append(entry)
		for step in range(1,7):
			var t := step/6.0
			path.append(entry*(1-t)*(1-t)+corner*2*(1-t)*t+leave*t*t)
	path.append(clean[-1])
	return path

func set_status(key: String, state: String, active: bool) -> void:
	if not routes.has(key):
		return
	var route: Dictionary = routes[key]
	if route.state==state and route.active==active:
		return
	if route.state!=state:
		structure.queue_redraw()
	route.state=state
	route.active=active
	queue_redraw()
	update_activity()

func update_activity() -> void:
	flowing=routes.values().any(func(route):return route.active)
	set_process(is_visible_in_tree() and routes.values().any(func(route):return route.active and route.get("visible",false)))

func _process(delta: float) -> void:
	accumulator+=delta
	if accumulator<1.0/30.0:
		return
	for route in routes.values():
		if route.active and route.visible:
			route.distance=fmod(route.distance+accumulator*SPEED,SPACING)
	accumulator=0.0
	queue_redraw()

func point_at(route: Dictionary, distance: float) -> Vector2:
	distance=clampf(distance,0,route.length)
	for i in range(1,route.points.size()):
		if distance<=route.lengths[i]:
			var span: float = route.lengths[i]-route.lengths[i-1]
			return route.points[i-1].lerp(route.points[i],(distance-route.lengths[i-1])/maxf(span,0.001))
	return route.end

func draw_structure() -> void:
	for route in routes.values():
		if not route.visible or route.points.size()<2:
			continue
		structure.draw_polyline(route.points,Color("020910"),9,true)
		structure.draw_polyline(route.points,Color("183244"),5,true)
		structure.draw_polyline(route.points,Color("356276"),1,true)
	for route in routes.values():
		if not route.visible:
			continue
		var color: Color = COLORS[route.state]
		var branch: PackedVector2Array = route.branch
		if branch.size()<2:
			continue
		structure.draw_polyline(branch,Color(color,0.35),5,true)
		structure.draw_polyline(branch,color,1.5,true)
		structure.draw_circle(route.tap,4,Color("061422"))
		structure.draw_arc(route.tap,3,0,TAU,16,color,1.5,true)

func _draw() -> void:
	for route in routes.values():
		if not route.visible:
			continue
		if not route.active:
			continue
		for packet in range(ceili(route.length/SPACING)+1):
			var distance: float = route.distance+packet*SPACING
			if distance>route.length:
				continue
			var fade := clampf(minf(distance,route.length-distance)/18.0,0,1)
			var trail := PackedVector2Array()
			for sample in range(6):
				trail.append(point_at(route,maxf(0,distance-13+sample*2.6)))
			draw_polyline(trail,Color("24ddec",0.12*fade),7,true)
			draw_polyline(trail,Color("54edfb",0.65*fade),2,true)
			draw_circle(point_at(route,distance),2.1,Color("d9ffff",fade))
