extends Control
## Vector instrument only; its port is the physical anchor read by the network.
const COLORS := {"charging":Color("65f3ff"),"paused":Color("647f93"),"insufficient":Color("c08c51"),"available":Color("43899f"),"locked":Color("344a59")}
const COMPLETION_DURATION := 0.16
var core := false
var flowing := false
var viewport_active := true
var frozen := false
var selected := false
var hovered := false
var icon_kind := "module"
var visual_state := "available"
var progress := 0.0
var display_progress := 0.0
var phase := 0.0
var accumulator := 0.0
var completion_remaining := 0.0
var last_level := -1
var last_count := 0.0
var observed_running := false
var port: Control
var percent_label: Label
var write_value: Callable
var structure: Control
var tween_from := 0.0
var tween_elapsed := 0.1

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	structure=Control.new()
	structure.mouse_filter=Control.MOUSE_FILTER_IGNORE
	structure.show_behind_parent=true
	add_child(structure)
	structure.draw.connect(draw_structure)
	port=Control.new()
	port.mouse_filter=Control.MOUSE_FILTER_IGNORE
	port.size=Vector2(14,10)
	add_child(port)
	resized.connect(layout_instrument)
	visibility_changed.connect(update_activity)
	layout_instrument()
	update_activity()

func center() -> Vector2:
	return size*0.5 if core else Vector2(size.x*0.5,96)

func radius() -> float:
	return 78.0 if core else minf(60.0,size.x*0.37)

func layout_instrument() -> void:
	if is_instance_valid(port):
		var point := center()+Vector2(0,radius()+20 if core else -radius()-16)
		port.position=point-port.size*0.5
	structure.queue_redraw()
	queue_redraw()

func set_selected(value: bool) -> void:
	if selected==value:
		return
	selected=value
	structure.queue_redraw()
	queue_redraw()

func set_hovered(value: bool) -> void:
	if hovered==value:
		return
	hovered=value
	structure.queue_redraw()
	queue_redraw()

func set_state(value: String) -> void:
	if visual_state==value:
		return
	visual_state=value
	structure.queue_redraw()
	queue_redraw()

func set_frozen(value: bool) -> void:
	if frozen==value:
		return
	frozen=value
	update_activity()

func set_flow(value: bool) -> void:
	if flowing==value:
		return
	flowing=value
	update_activity()
	queue_redraw()

func set_viewport_active(value: bool) -> void:
	if viewport_active==value:
		return
	viewport_active=value
	if not value:
		completion_remaining=0
		display_progress=progress
	update_activity()
	if value:
		queue_redraw()

func set_job_progress(value: float, level: int, count: float) -> void:
	var completed := last_level>=0 and (level>last_level or (level==last_level and count>last_count))
	if completed and (flowing or observed_running) and not frozen and viewport_active and is_visible_in_tree():
		completion_remaining=COMPLETION_DURATION
	last_level=level
	last_count=count
	observed_running=flowing
	# A round boundary resets the progress, never interpolates backwards from
	# the previous round. Completion is an independent, fading outer accent.
	if completed or value<progress:
		display_progress=value
		tween_from=value
		tween_elapsed=0.1
	elif value!=progress:
		tween_from=display_progress
		tween_elapsed=0.0
	progress=value
	if not flowing or not viewport_active or frozen:
		display_progress=value
	update_percent()
	update_activity()
	if not is_processing() and is_visible_in_tree() and viewport_active:
		if not has_meta("resting_progress") or get_meta("resting_progress")!=display_progress:
			set_meta("resting_progress",display_progress)
			queue_redraw()

func update_percent() -> void:
	if is_instance_valid(percent_label):
		var value := "%d%%" % roundi(progress*100)
		if percent_label.text!=value:
			write_value.call(percent_label,"text",value)

func update_activity() -> void:
	var active := is_visible_in_tree() and viewport_active and not frozen and (flowing or completion_remaining>0)
	if is_processing()!=active:
		set_process(active)
		queue_redraw()
	if not is_visible_in_tree():
		completion_remaining=0

func _process(delta: float) -> void:
	accumulator+=delta
	if accumulator<1.0/30.0:
		return
	phase=fmod(phase+accumulator*0.04,1.0)
	if completion_remaining>0:
		completion_remaining=maxf(0,completion_remaining-accumulator)
	tween_elapsed=minf(0.1,tween_elapsed+accumulator)
	display_progress=lerpf(tween_from,progress,tween_elapsed/0.1)
	accumulator=0
	update_percent()
	queue_redraw()
	update_activity()

func polygon_ring(c: Vector2, r: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides+1):
		points.append(c+Vector2.from_angle(-PI/2+i*TAU/sides)*r)
	return points

func draw_structure() -> void:
	var c := center()
	var r := radius()
	var color: Color = Color("6befff") if core else COLORS[visual_state]
	var running := core or visual_state=="charging"
	if running:
		for halo in range(3):
			structure.draw_circle(c,r+19-halo*3,Color(color,0.025+halo*0.012))
	var chassis := polygon_ring(c,r+13,12 if core else 8)
	structure.draw_colored_polygon(chassis.slice(0,chassis.size()-1),Color("07101b"))
	structure.draw_polyline(chassis,Color("243d50"),2,true)
	structure.draw_circle(c,r+8,Color("122c3f"))
	structure.draw_arc(c,r+9,PI,TAU,64,Color("527285"),2,true)
	structure.draw_arc(c,r+9,0,PI,64,Color("030b13"),4,true)
	structure.draw_circle(c,r+3,Color("020a12"))
	for layer in range(12):
		var fraction := layer/11.0
		structure.draw_circle(c,r-1-layer*1.4,Color("102c40").lerp(Color("06131f"),fraction))
	structure.draw_arc(c,r-2,0,TAU,80,Color(color,0.17),1,true)
	for i in range(36 if core else 28):
		var angle := -PI/2+i*TAU/(36 if core else 28)
		var inner := r+11 if i%4 else r+8
		structure.draw_line(c+Vector2.from_angle(angle)*inner,c+Vector2.from_angle(angle)*(r+14),Color(color,0.42),1,true)
	if selected or hovered:
		for i in range(4):
			var angle := i*PI/2+PI/8
			structure.draw_arc(c,r+17,angle,angle+PI/4,14,Color("57dbe9"),1 if selected else 0.6,true)
	if is_instance_valid(port):
		var socket := port.position+port.size*0.5
		var shoulder := c+Vector2(0,r+9 if core else -r-9)
		structure.draw_line(shoulder,socket,Color("112c3e"),12,true)
		structure.draw_line(shoulder,socket,Color(color,0.6),3,true)
		structure.draw_rect(port.get_rect(),Color("081522"))
		structure.draw_rect(port.get_rect(),Color(color,0.7),false,1)
		structure.draw_circle(socket,2,color)

func _draw() -> void:
	var c := center()
	var r := radius()
	var color: Color = Color("6befff") if core else COLORS[visual_state]
	var running := core or visual_state=="charging"
	if core:
		draw_core(c,r,color)
		return
	draw_arc(c,r,0,TAU,80,Color("1c394a"),4,true)
	if display_progress>0:
		draw_arc(c,r,-PI/2,-PI/2+TAU*display_progress,80,color,4,true)
		if running:
			var end := c+Vector2.from_angle(-PI/2+TAU*display_progress)*r
			draw_circle(end,5,Color(color,0.14))
			draw_circle(end,2,Color("ddffff"))
	if completion_remaining>0:
		var pulse := completion_remaining/COMPLETION_DURATION
		draw_arc(c,r+12*(1-pulse),0,TAU,80,Color("d4ffff",pulse*0.6),2,true)
		if pulse>0.4:
			draw_circle(c,r-4,Color(color,0.06*pulse))
	draw_icon(c+Vector2(0,-20),color)

func draw_core(c: Vector2, r: float, color: Color) -> void:
	var breath := 0.5+0.5*sin(phase*TAU)
	for band in range(3):
		var angle := band*TAU/3+phase*TAU
		draw_arc(c,r-8,angle,angle+1.25,32,Color(color,0.55),3,true)
	for i in range(3):
		draw_arc(c,r*(0.30+i*0.17),0,TAU,72,Color(color,0.14),1,true)
	for i in range(6):
		var angle := i*TAU/6+phase*TAU
		var point := c+Vector2.from_angle(angle)*(r*0.53)
		draw_line(c,point,Color(color,0.25),1,true)
		draw_circle(point,2,color)
	for glow in range(9,0,-1):
		draw_circle(c,glow*2.5,Color(color,0.035+breath*0.009))
	draw_line(c-Vector2(0,r*0.62),c+Vector2(0,r*0.62),Color(color,0.14),7,true)
	draw_line(c-Vector2(0,r*0.62),c+Vector2(0,r*0.62),Color(color,0.6),1,true)
	draw_circle(c,5,Color("d9ffff"))

func draw_icon(c: Vector2, color: Color) -> void:
	if icon_kind=="shield":
		var shape := PackedVector2Array([c+Vector2(0,-21),c+Vector2(18,-12),c+Vector2(14,9),c+Vector2(0,22),c+Vector2(-14,9),c+Vector2(-18,-12),c+Vector2(0,-21)])
		draw_colored_polygon(shape.slice(0,shape.size()-1),Color(color,0.13))
		draw_polyline(shape,color,2,true)
		draw_line(c+Vector2(0,-17),c+Vector2(0,15),Color(color,0.7),2,true)
	elif icon_kind=="attack":
		var shape := PackedVector2Array([c+Vector2(12,-23),c+Vector2(-15,3),c+Vector2(-2,4),c+Vector2(-12,23),c+Vector2(16,-4),c+Vector2(3,-5)])
		draw_colored_polygon(shape,color)
	else:
		var shape := polygon_ring(c,21,6)
		draw_colored_polygon(shape.slice(0,shape.size()-1),Color(color,0.08))
		draw_polyline(shape,color,2,true)
		for i in range(3):
			draw_line(c,shape[i*2],color,1.5,true)
