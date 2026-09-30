extends SceneTree
# Saved-game replay. All source guards and wrappers are installed in a copied project.
class ReplayScene extends "res://scripts/main.gd":
	func show_chrono_login_report() -> void:pass
	func show_qa_tools() -> void:pass

class Meter:
	extends RefCounted
	var enabled := false
	var current := {}
	var ui_writes := {}
	var redraw_requests := 0
	var draw_events := 0
	var layout_events := 0
	var nodes_added := 0
	var nodes_removed := 0
	var save_writes := 0
	func begin() -> void:
		current.clear()
		ui_writes.clear()
		redraw_requests=0
		draw_events=0
		layout_events=0
		nodes_added=0
		nodes_removed=0
		save_writes=0
	func record(category: String, name: String, elapsed_us: int) -> void:
		if not enabled:return
		var row: Array=current.get(name,[category,0,0,0])
		row[1]+=1
		row[2]+=elapsed_us
		row[3]=maxi(row[3],elapsed_us)
		current[name]=row
	func ui_write(property: String) -> void:
		if enabled:ui_writes[property]=int(ui_writes.get(property,0))+1
	func redraw_request() -> void:
		if enabled:redraw_requests+=1
	func draw_event() -> void:
		if enabled:draw_events+=1
	func layout_event() -> void:
		if enabled:layout_events+=1
	func node_added() -> void:
		if enabled:nodes_added+=1
	func node_removed() -> void:
		if enabled:nodes_removed+=1
	func save_write() -> void:
		if enabled:save_writes+=1

var meter := Meter.new()
var render_pre_us := 0
var render_signal_ms := 0.0
var tracked := {}
var current_page := -1

func _initialize() -> void:
	Engine.set_meta("diag_meter",meter)
	call_deferred("run")

func on_render_pre() -> void:
	render_pre_us=Time.get_ticks_usec()

func on_render_post() -> void:
	if render_pre_us>0:render_signal_ms=float(Time.get_ticks_usec()-render_pre_us)/1000.0

func on_node_added(node: Node) -> void:
	meter.node_added()
	track_node(node)

func on_node_removed(_node: Node) -> void:
	meter.node_removed()

func track_node(node: Node) -> void:
	if tracked.has(node.get_instance_id()):return
	tracked[node.get_instance_id()]=true
	if node is CanvasItem:node.draw.connect(meter.draw_event)
	if node is Container:node.resized.connect(meter.layout_event)
	for child in node.get_children():track_node(child)

func distribution(values: Array) -> Dictionary:
	if values.is_empty():return {}
	var copy=values.duplicate()
	copy.sort()
	var sum := 0.0
	for value in copy:sum+=float(value)
	return {"mean":sum/copy.size(),"p50":copy[copy.size()/2],"p95":copy[mini(copy.size()-1,int(copy.size()*0.95))],"p99":copy[mini(copy.size()-1,int(copy.size()*0.99))],"max":copy[-1]}

func checkpoint(scene: ReplayScene, minute: int, recent: Array) -> Dictionary:
	var timers := 0
	var signals := 0
	var canvas := 0
	var containers := 0
	var stack: Array=[root]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Timer:timers+=1
		if node is CanvasItem:canvas+=1
		if node is Container:containers+=1
		for signal_info in node.get_signal_list():
			signals+=node.get_signal_connection_list(signal_info.name).size()
		for child in node.get_children():stack.append(child)
	var values: Array=[]
	for row in recent:values.append(row.frame_ms)
	return {"minute":minute,"frame_stats":distribution(values),"memory_bytes":OS.get_static_memory_usage(),"nodes":get_node_count(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"projectiles":scene.game.projectiles.size(),"enemies":scene.game.enemies.size(),"timers":timers,"signal_connections":signals,"canvas_items":canvas,"containers":containers,"stage":scene.game.stage}

func sample_frame(scene: ReplayScene, page: int, index: int, detail: bool) -> Dictionary:
	meter.begin()
	meter.enabled=detail
	var started := Time.get_ticks_usec()
	scene._process(1.0/60.0)
	var manual_cpu_ms := float(Time.get_ticks_usec()-started)/1000.0
	await RenderingServer.frame_post_draw
	var render_cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	var render_gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var render_setup_cpu_ms := RenderingServer.get_frame_setup_time_cpu()
	var process_span_ms := float(render_pre_us-started)/1000.0 if render_pre_us>=started else -1.0
	var active_counts := {"battle":scene.game.enemies.size(),"simulation":1,"projectile":scene.game.projectiles.size(),"enemy":scene.game.enemies.size(),"weapon":scene.turret_visuals.size(),"collision":scene.game.projectiles.size()+scene.game.enemies.size(),"ui":1,"text":int(meter.ui_writes.get("text",0)),"layout":meter.layout_events,"animation":scene.turret_visuals.size()+scene.projectile_visuals.size(),"effect":scene.particles.size()+scene.floats.size()+scene.pickup_effects.size(),"render":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"data":1,"stat":1}
	var row := {"page":page,"index":index,"cpu_ms":manual_cpu_ms,"cpu_total_ms":process_span_ms+render_cpu_ms+render_setup_cpu_ms,"gpu_ms":render_gpu_ms,"render_ms":render_cpu_ms+render_setup_cpu_ms,"render_viewport_ms":render_cpu_ms,"render_setup_ms":render_setup_cpu_ms,"render_signal_ms":render_signal_ms,
		"process_ms":process_span_ms,"process_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory_bytes":OS.get_static_memory_usage(),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"enemies":scene.game.enemies.size(),"projectiles":scene.game.projectiles.size(),"projectile_visuals":scene.projectile_visuals.size(),"particles":scene.particles.size(),"floats":scene.floats.size(),"drops":scene.game.drops.size(),
		"ui_writes":meter.ui_writes.duplicate(true),"redraw_requests":meter.redraw_requests,"draw_events":meter.draw_events,"layout_events":meter.layout_events,"nodes_added":meter.nodes_added,"nodes_removed":meter.nodes_removed,"save_writes":meter.save_writes,"modules":meter.current.duplicate(true),"active_counts":active_counts,"stage":scene.game.stage,"state":scene.game.state}
	await process_frame
	row.frame_ms=float(Time.get_ticks_usec()-started)/1000.0
	meter.enabled=false
	return row

func shader_materials(node: Node, disable: bool) -> int:
	var count := 0
	if node is CanvasItem and node.material is ShaderMaterial:
		count+=1
		if disable:node.visible=false
	for child in node.get_children():count+=shader_materials(child,disable)
	return count

func measure_page(scene: ReplayScene, page: int, detail: bool) -> Dictionary:
	scene.equipment_tabs.current_tab=page
	var shader_count=shader_materials(root,Engine.get_meta("diag_mode","")=="shader_off")
	for i in 60:
		await sample_frame(scene,page,i,false)
	var frames: Array=[]
	for i in 300:
		frames.append(await sample_frame(scene,page,i,detail))
	var wall: Array=[]
	var cpu: Array=[]
	var gpu: Array=[]
	var render: Array=[]
	for row in frames:
		wall.append(row.frame_ms)
		cpu.append(row.cpu_ms)
		gpu.append(row.gpu_ms)
		render.append(row.render_ms)
	var traces: Array=[]
	for row in frames:
		if row.frame_ms>20.0:traces.append(row)
	var sorted=frames.duplicate()
	sorted.sort_custom(func(a,b):return a.frame_ms>b.frame_ms)
	for i in mini(5,sorted.size()):
		if not traces.has(sorted[i]):traces.append(sorted[i])
	return {"page":page,"shader_materials":shader_count,"frame_stats":distribution(wall),"cpu_stats":distribution(cpu),"gpu_stats":distribution(gpu),"render_stats":distribution(render),"frames":frames,"traces":traces}

func run() -> void:
	var cap := 0
	var speed := 1.0
	var mode := "baseline"
	var minutes := 0
	var name := "baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diag-fps="):cap=int(arg.get_slice("=",1))
		if arg.begins_with("--diag-speed="):speed=float(arg.get_slice("=",1))
		if arg.begins_with("--diag-mode="):mode=arg.get_slice("=",1)
		if arg.begins_with("--diag-long-minutes="):minutes=int(arg.get_slice("=",1))
		if arg.begins_with("--diag-name="):name=arg.get_slice("=",1)
	Engine.set_meta("diag_mode",mode)
	Engine.max_fps=cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(1701)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	RenderingServer.frame_pre_draw.connect(on_render_pre)
	RenderingServer.frame_post_draw.connect(on_render_post)
	var scene=ReplayScene.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.rng.seed=1701
	await process_frame
	if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
	var qa=root.get_node_or_null("QATools")
	if qa:qa.hide()
	if speed>0:scene.game.speed=speed
	var detail=name.ends_with("detail")
	if detail:
		track_node(root)
		node_added.connect(on_node_added)
		node_removed.connect(on_node_removed)
	var report := {"stage":scene.game.stage,"speed":scene.game.speed,"mode":mode,"fps_cap":cap,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"size":"1373x883","seed":1701,"warmup_frames":60,"sample_frames":300,"pages":[],"long_run":[]}
	for page in [0,1,2,5,6,8]:
		if scene.equipment_tabs.is_tab_hidden(page):continue
		var result=await measure_page(scene,page,detail)
		report.pages.append(result)
		print("PAGE ",page," ",JSON.stringify(result.frame_stats)," gpu=",JSON.stringify(result.gpu_stats))
	if minutes>0:
		scene.equipment_tabs.current_tab=5
		var recent: Array=[]
		for i in 300:recent.append(await sample_frame(scene,5,i,false))
		var long_start := Time.get_ticks_msec()
		var long_traces: Array=[]
		var long_peak: Array=[]
		var first_point=checkpoint(scene,0,recent)
		report.long_run.append(first_point)
		print("LONGRUN ",JSON.stringify(first_point))
		var last_reported := 0
		while true:
			var elapsed_min := float(Time.get_ticks_msec()-long_start)/60000.0
			if elapsed_min>=float(minutes):break
			var frame=await sample_frame(scene,5,recent.size(),detail)
			recent.append(frame)
			if recent.size()>300:recent.pop_front()
			if frame.frame_ms>33.0:long_traces.append(frame)
			if frame.frame_ms>20.0:
				long_peak.append(frame)
				long_peak.sort_custom(func(a,b):return a.frame_ms>b.frame_ms)
				if long_peak.size()>100:long_peak.pop_back()
			for minute in [0,5,15]:
				if minute<=minutes and elapsed_min>=float(minute) and minute>last_reported:
					var point=checkpoint(scene,minute,recent)
					report.long_run.append(point)
					print("LONGRUN ",JSON.stringify(point))
					last_reported=minute
		if minutes>=15 and last_reported<15:
			var point=checkpoint(scene,15,recent)
			report.long_run.append(point)
			print("LONGRUN ",JSON.stringify(point))
		report.long_run_traces=long_traces
		report.long_run_top100=long_peak
	FileAccess.open("res://.runtime/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	scene.equipment_tabs.current_tab=0
	scene.game.paused=true
	scene.music.stop()
	for voice in scene.railgun_audio.values():voice.stop()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	Engine.remove_meta("diag_meter")
	Engine.remove_meta("diag_mode")
	quit()
