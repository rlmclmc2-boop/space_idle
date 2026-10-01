extends Control

const ROUTES := preload("res://scripts/reactor_routes.gd")
const CYAN := Color("37dfff")
const ORB_SHADER := preload("res://assets/ui/reactor/orb.gdshader")

var mode := "core"
var accent := CYAN
var ratio := 0.0
var trunk_ratio := 0.0
var phase := 0.0
var layers: Dictionary = {}
var hovered := false
var click_flash := 0.0
var preview_ratio := -1.0
var available_ratio := 1.0
var segment_styles: Dictionary = {}
var network_route := PackedVector2Array()
var network_length := 0.0
var route := PackedVector2Array()
var flow_source: Control
var flow_offset := 0.0
var flow_distance := 0.0
var static_start := 0.0
var inlet_point := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if (mode in ["network","branch","footer_conduit"] or mode.begins_with("scene_") or mode in ["track","busbar","pipe_horizontal","pipe_vertical"]) and ratio <= 0.0:set_process(false)
	if mode == "core":build_core_layers()
	if mode == "network":route = ROUTES.main_route()
	if not route.is_empty():
		network_route = route
		network_length = ROUTES.length_of(route)
	if mode == "conduit":set_process(false)
	if mode == "segments" or mode.begins_with("compact_"):set_process(false)

func build_core_layers() -> void:
	var orb := ColorRect.new()
	orb.color = Color.WHITE
	orb.size = size
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = ORB_SHADER
	material.set_shader_parameter("phase",0.0)
	material.set_shader_parameter("power",0.0)
	orb.material = material
	add_child(orb)
	layers.orb = orb

func _process(delta: float) -> void:
	if not is_visible_in_tree() or (mode == "track" and ratio <= 0.0 and not hovered and click_flash <= 0.0) or (mode in ["pipe_horizontal","pipe_vertical"] and ratio <= 0.0):return
	if mode == "core":
		phase = flow_source.phase/85.0 if is_instance_valid(flow_source) else fmod(phase+delta*(0.35+ratio*2.2),1000.0)
		layers.orb.material.set_shader_parameter("phase",phase)
	elif mode in ["network","branch","footer_conduit"]:
		if ratio <= 0.0 and not (mode == "branch" and trunk_ratio > 0.0):return
		if not is_instance_valid(flow_source):flow_distance+=delta*(65.0+ratio*95.0)
		phase = flow_source.phase if is_instance_valid(flow_source) else fmod(flow_distance,ROUTES.PULSE_SPACING*100.0)
		queue_redraw()
	elif mode.begins_with("scene_") or mode.begins_with("compact_"):
		phase = fmod(phase+delta*(0.3+ratio*1.7),64.0)
		queue_redraw()
	else:
		var travel := size.y if mode == "pipe_vertical" else size.x
		phase = fmod(phase+delta*90.0,maxf(1.0,travel))
		click_flash = maxf(0.0,click_flash-delta*3.0)
		queue_redraw()

func set_ratio(value: float) -> void:
	if is_equal_approx(ratio,value):return
	ratio = value
	if mode == "network" and ratio<=0.0:
		flow_distance=0.0
		phase=0.0
	if mode == "core" and layers.has("orb"):
		layers.orb.material.set_shader_parameter("power",ratio)
	else:queue_redraw()

func set_trunk_ratio(value: float) -> void:
	if is_equal_approx(trunk_ratio,value):return
	trunk_ratio = value
	queue_redraw()

func set_hovered(value: bool) -> void:
	if hovered == value:return
	hovered = value
	queue_redraw()

func set_preview_ratio(value: float) -> void:
	if is_equal_approx(preview_ratio,value):return
	preview_ratio = value
	queue_redraw()

func set_available_ratio(value: float) -> void:
	if is_equal_approx(available_ratio,value):return
	available_ratio = value
	queue_redraw()

func flash_click() -> void:
	click_flash = 1.0
	queue_redraw()

func _draw() -> void:
	if mode == "track":draw_track()
	elif mode == "busbar":draw_busbar()
	elif mode == "segments":draw_segments()
	elif mode.begins_with("compact_"):draw_compact_fx()
	elif mode == "conduit":draw_conduit()
	elif mode == "network":draw_network()
	elif mode == "branch":draw_branch()
	elif mode == "footer_conduit":draw_footer_conduit()
	elif mode == "node":draw_node()
	elif mode in ["pipe_horizontal","pipe_vertical"]:draw_pipe()
	elif mode.begins_with("scene_"):draw_scene_fx()

func draw_scene_fx() -> void:
	if ratio <= 0.0:return
	var strength := 0.35+0.6*sqrt(ratio)
	if mode == "scene_weapons":
		var charge := 0.5+0.5*sin(phase*3.7)
		draw_arc(Vector2(798,76),22,PI*0.58,PI*1.42,28,Color(1.0,0.59,0.19,strength*charge*0.62),3.0,true)
		draw_line(Vector2(925,76),Vector2(1105,76),Color(1.0,0.65,0.22,strength*charge*0.22),2.0,true)
		var shot := fposmod(phase*0.43,1.0)
		if shot > 0.63:
			var x := 1150.0+(shot-0.63)/0.37*115.0
			draw_line(Vector2(x-28,76),Vector2(x,76),Color(1.0,0.46,0.08,strength*0.28),6.0,true)
			draw_circle(Vector2(x,76),5.0,Color(1.0,0.83,0.42,strength))
	elif mode == "scene_defence":
		var sweep_x := 705.0+fposmod(phase*110.0,420.0)
		draw_line(Vector2(sweep_x,36),Vector2(sweep_x+26,77),Color(0.65,0.93,1.0,strength*0.18),3.0,true)
		for emitter_x in [708.0,888.0,1090.0]:
			draw_circle(Vector2(emitter_x,43),8.0+2.0*sin(phase*4.0+emitter_x),Color(0.65,0.93,1.0,strength*0.17))
	elif mode == "scene_smelting":
		var stream := PackedVector2Array()
		for index in 11:
			var t := float(index)/10.0
			stream.append(Vector2(1028.0+47.0*t+sin(phase*2.4+t*5.0)*2.0,87.0+29.0*t))
		draw_polyline(stream,Color(1.0,0.32,0.04,strength*0.34),8.0,true)
		draw_polyline(stream,Color(1.0,0.82,0.34,strength*0.62),3.0,true)
		for index in 8:
			var progress := fposmod(phase*0.3+float(index)*0.173,1.0)
			var x := 935.0+sin(float(index)*2.7)*45.0
			var y := 91.0-progress*42.0
			draw_circle(Vector2(x,y),1.0+float(index%3),Color(1.0,0.65,0.25,strength*(1.0-progress)*0.64))
	else:
		var scan_x := 756.0+fposmod(phase*108.0,500.0)
		draw_line(Vector2(scan_x,18),Vector2(scan_x+42.0,18),Color(accent.r,accent.g,accent.b,strength*0.14),4.0,true)
		draw_arc(Vector2(1012,42),24.0,phase*0.7,phase*0.7+PI*0.7,28,Color(accent.r,accent.g,accent.b,strength*0.25),2.0,true)

func draw_pipe() -> void:
	if ratio <= 0.0:return
	var vertical := mode == "pipe_vertical"
	var travel := size.y if vertical else size.x
	for index in 6:
		var position := fmod(phase+index*travel/6.0,travel)
		var center := Vector2(size.x*0.5,position) if vertical else Vector2(position,size.y*0.5)
		draw_circle(center,5.0,Color(0.35,0.86,1.0,0.09+ratio*0.1))
		draw_circle(center,2.0,Color(0.73,0.97,1.0,0.35+ratio*0.55))

func network_point(distance: float) -> Vector2:
	return ROUTES.point_at(route,distance)

func draw_conduit() -> void:
	if route.size()<2:return
	var tube := PackedVector2Array([ROUTES.point_at(route,static_start)])
	var distance := 0.0
	for i in range(1,route.size()):
		distance+=route[i-1].distance_to(route[i])
		if distance>static_start:tube.append(route[i])
	for layer in [[30.0,Color("243d50")],[23.0,Color("ecebdc")],[12.0,Color("355d6a")],[3.0,Color("669599")]]:
		draw_polyline(tube,layer[1],layer[0],true)
	for end in ([tube[0],tube[-1]] if static_start>0.0 else [tube[-1]]):
		draw_circle(end,15.0,Color("243d50"))
		draw_circle(end,11.5,Color("ecebdc"))
		draw_circle(end,6.0,Color("355d6a"))

	if static_start==0.0:
		# Open the T junction, using the same trunk center as this branch route.
		draw_line(route[0]-Vector2(0,15),route[0]+Vector2(0,15),Color("355d6a"),12.0,true)
		draw_line(route[0]-Vector2(0,15),route[0]+Vector2(0,15),Color("669599"),3.0,true)

func draw_network() -> void:
	if ratio <= 0.0 or route.size()<2:return
	draw_flow()

func draw_flow(points := PackedVector2Array(), offset := -1.0, power := -1.0) -> void:
	var draw_route: PackedVector2Array = route if points.is_empty() else points
	var draw_offset: float = flow_offset if offset < 0.0 else offset
	var draw_power: float = ratio if power < 0.0 else power
	var draw_length := ROUTES.length_of(draw_route)
	var supplied_distance: float = flow_source.flow_distance if is_instance_valid(flow_source) else flow_distance
	var strength := 0.40+0.55*sqrt(clampf(draw_power,0.0,1.0))
	var head := fposmod(phase-draw_offset,ROUTES.PULSE_SPACING)
	while head < draw_length+20.0:
		for part in 7:
			var distance := head-18.0+part*3.0
			if distance>=0.0 and distance+3.0<=draw_length and draw_offset+distance+3.0<=supplied_distance:
				draw_line(ROUTES.point_at(draw_route,distance),ROUTES.point_at(draw_route,distance+3.0),Color(0.62,0.97,0.94,strength*(0.25+part*0.12)),3.5,true)
		if head>=0.0 and head<=draw_length and draw_offset+head<=supplied_distance:draw_circle(ROUTES.point_at(draw_route,head),3.5,Color(0.91,1.0,0.93,strength))
		head+=ROUTES.PULSE_SPACING

func draw_branch() -> void:
	if trunk_ratio>0.0:
		draw_flow(PackedVector2Array([route[0]-Vector2(0,15),route[0]+Vector2(0,15)]),flow_offset-15.0,trunk_ratio)
	if ratio<=0.0:return
	draw_flow()
	# A receiving ring blooms only when a packet reaches the actual inlet.
	var arrival := fposmod(phase-flow_offset-network_length,ROUTES.PULSE_SPACING)/ROUTES.PULSE_SPACING
	var reached: bool = is_instance_valid(flow_source) and flow_source.flow_distance>=flow_offset+network_length
	var pulse := maxf(0.0,1.0-arrival*4.0) if reached else 0.0
	draw_arc(route[-1],8.0+pulse*3.0,-PI*0.5,PI*0.5,20,Color(0.53,0.92,0.86,0.25+pulse*0.65),2.0,true)

func draw_footer_conduit() -> void:
	pass # The fixed manifold owns the complete terminal path.

func draw_node() -> void:
	var center := size*0.5
	var glow := 0.5+0.5*sin(phase*0.07)
	draw_circle(center,13.0,Color(accent.r,accent.g,accent.b,0.05+ratio*(0.08+glow*0.2)))
	draw_circle(center,8.0,Color("092d41"))
	draw_arc(center,7.0,0,TAU,28,accent.darkened(0.55 if ratio <= 0.0 else 0.0),2.0,true)
	draw_circle(center,3.0,accent.lightened(0.35) if ratio > 0.0 else Color("28556a"))

func draw_segments() -> void:
	draw_style_box(track_segment_style(Color("243d50")),Rect2(Vector2.ZERO,size))
	var filled := clampf(ratio,0.0,1.0)*(size.x-6.0)
	if filled > 0.0:
		draw_style_box(track_segment_style(accent.darkened(0.55)),Rect2(3,3,filled,size.y-6))
		for index in 5:
			var x := (index+1)*size.x/6.0
			draw_line(Vector2(x,size.y-6),Vector2(x,size.y-3),Color("83cfcb"),2.0,true)

func draw_compact_fx() -> void:
	if ratio <= 0.0:return
	var strength := 0.4+0.6*sqrt(ratio)
	if is_instance_valid(flow_source) and flow_source.flow_distance>=flow_offset:
		var received := maxf(0.0,1.0-fposmod(flow_source.phase-flow_offset,ROUTES.PULSE_SPACING)/ROUTES.PULSE_SPACING*4.0)
		draw_circle(inlet_point+Vector2(9,0),5.0+received*2.0,Color(0.63,0.99,0.85,received*0.7))
		draw_line(inlet_point,inlet_point+Vector2(18,0),Color(0.63,0.99,0.85,received*0.7),3.0,true)
	if mode == "compact_defence":
		var center := Vector2(124,83)
		var radius := 29.0
		draw_circle(center,radius+5.0,Color(0.03,0.4,1.0,0.18*strength))
		draw_circle(center,radius,Color(0.02,0.28,0.75,0.65*strength))
		draw_arc(center,radius,0,TAU,64,Color(0.2,0.85,1.0,strength),2.0,true)
		for column in range(-2,3):
			for row in range(-2,3):
				var point := center+Vector2(column*13.0,row*15.0+abs(column%2)*7.5)
				if point.distance_to(center) > 21.0:continue
				var hexagon := PackedVector2Array()
				for corner in 7:
					var angle := TAU*corner/6.0
					hexagon.append(point+Vector2(cos(angle),sin(angle))*8.3)
				draw_polyline(hexagon,Color(0.3,0.91,1.0,strength*(0.65+0.2*sin(phase*3.0))),1.0,true)
	elif mode == "compact_weapons":
		var charge := 0.5+0.5*sin(phase*4.0)
		draw_arc(Vector2(87,84),17,PI*0.6,PI*1.4,24,Color(1.0,0.64,0.2,strength*charge),2.0,true)
		draw_line(Vector2(134,87),Vector2(204,87),Color(1.0,0.68,0.24,strength*charge*0.6),2.0,true)
	elif mode == "compact_condensation":
		var center := Vector2(116,74)
		draw_circle(center,27,Color(accent.r,accent.g,accent.b,0.08*strength))
		for index in 12:
			var progress := fposmod(phase*0.42+index/12.0,1.0)
			var angle := index*TAU/12.0+phase*0.25
			var point := center+Vector2(cos(angle),sin(angle))*lerpf(68.0,7.0,progress)
			draw_line(point,point+Vector2(cos(angle),sin(angle))*5.0,Color(accent.r,accent.g,accent.b,sin(progress*PI)*strength),1.3,true)
			draw_circle(point,1.5,Color(0.94,0.85,1.0,sin(progress*PI)*strength))
	elif mode == "compact_smelting":
		for index in 9:
			var progress := fposmod(phase*0.36+index*0.117,1.0)
			var point := Vector2(129+sin(index*2.3+phase)*12,96-progress*44)
			draw_circle(point,1.0+index%2,Color(1.0,0.65,0.12,(1.0-progress)*strength))
	else:
		draw_arc(size*0.5,28,phase,phase+PI,32,Color(accent.r,accent.g,accent.b,strength),2.0,true)

func draw_track() -> void:
	var fill := clampf(preview_ratio if preview_ratio >= 0.0 else ratio,0.0,1.0)
	draw_style_box(track_segment_style(Color("243d50")),Rect2(Vector2.ZERO,size))
	if fill > 0.0:
		draw_style_box(track_segment_style(accent.darkened(0.55)),Rect2(2,2,maxf(2.0,(size.x-4.0)*fill),size.y-4))
	var available_x := size.x*clampf(available_ratio,0.0,1.0)
	if available_ratio < 0.999:
		draw_line(Vector2(available_x,3),Vector2(available_x,size.y-3),Color("6c858c"),2.0,true)
	var thumb_x := clampf(fill*size.x,4.0,size.x-4.0)
	draw_style_box(track_segment_style(Color("f4eddc")),Rect2(thumb_x-4,-2,8,4))
	draw_style_box(track_segment_style(Color("f4eddc")),Rect2(thumb_x-4,size.y-2,8,4))
	if hovered:
		draw_line(Vector2(6,size.y+3),Vector2(size.x-6,size.y+3),accent,2.0,true)

func track_segment_style(color: Color) -> StyleBoxFlat:
	if segment_styles.has(color):return segment_styles[color]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	segment_styles[color] = style
	return style

func draw_busbar() -> void:
	var bounds := Rect2(Vector2.ZERO,size)
	draw_rect(bounds,Color(0.01,0.06,0.11,0.72),true)
	draw_rect(bounds,Color(0.26,0.52,0.61,0.68),false,1.0)
	var inner_width := size.x-8.0
	var fill_width := inner_width*clampf(ratio,0.0,1.0)
	if fill_width > 0.0:
		draw_rect(Rect2(4,1,fill_width,size.y-2),Color(0.04,0.44,0.62,0.65),true)
		draw_line(Vector2(5,2),Vector2(4+fill_width,2),Color("a1f5ff"),1.0,true)
		draw_line(Vector2(5,size.y-2),Vector2(4+fill_width,size.y-2),Color("36b9dc"),1.0,true)
		for index in 8:
			var x := 4.0+fposmod(phase+float(index)*101.0,maxf(1.0,fill_width))
			draw_line(Vector2(x,size.y*0.5),Vector2(minf(x+12.0,4.0+fill_width),size.y*0.5),Color(0.75,0.97,1.0,0.42),1.0,true)
