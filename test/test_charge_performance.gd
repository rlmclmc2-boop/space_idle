extends SceneTree
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures+=1
		printerr("FAIL: ",label)

class ProbeUI extends "res://scripts/main.gd":
	var refresh_us := 0
	var refresh_calls := 0
	var writes := 0
	func refresh_visible_cards(delta := 0.0) -> void:
		var start := Time.get_ticks_usec()
		super.refresh_visible_cards(delta)
		refresh_us+=Time.get_ticks_usec()-start
		refresh_calls+=1
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:
			writes+=1
		super.set_ui_value(control,property,value)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := ProbeUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.game.save_enabled=false
	scene.game.profile.cleared=range(1,51)
	scene.game.profile.resources={"1":1000000,"2":1000000}
	var template: Dictionary = scene.db.data.charge.values()[0]
	for i in range(30):
		var key := "probe_%d" % i
		scene.db.data.charge[key]=template.duplicate(true)
		scene.game.profile.charge[key]={"level":0,"count":0.0,"elapsed":1.0,"active":true,"started":1,"credit":0.0}
	scene.build_ui()
	var panel = scene.charge_panel
	scene.equipment_tabs.current_tab=scene.equipment_tabs.get_tab_idx_from_control(panel)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await create_timer(1).timeout
	var draws := [0,0,0]
	var static_draws := [0,0]
	panel.draw.connect(func():draws[0]+=1)
	panel.core_feed.draw.connect(func():draws[1]+=1)
	panel.cards.probe_0.circuit.draw.connect(func():draws[2]+=1)
	panel.core_feed.structure.draw.connect(func():static_draws[0]+=1)
	panel.cards.probe_0.circuit.structure.draw.connect(func():static_draws[1]+=1)
	var geometry_before: int = panel.geometry_scans
	var samples_before: int = panel.sample_count
	scene.refresh_us=0
	scene.refresh_calls=0
	scene.writes=0
	var frames: Array[float] = []
	var cpu := 0.0
	var gpu := 0.0
	var previous := Time.get_ticks_usec()
	var end := previous+3000000
	while Time.get_ticks_usec()<end:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous=now
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	frames.sort()
	print("PROFILE samples=",panel.sample_count-samples_before," layout_scans=",panel.geometry_scans-geometry_before," static_network_gauge=",static_draws)
	check(panel.geometry_scans==geometry_before,"Progress must not measure layout")
	check(panel.sample_count-samples_before<=31 and panel.sample_count-samples_before>=20,"UI samples at approximately 100 ms")
	check(static_draws==[0,0],"Animation must not redraw static instruments or pipes")
	print("PROFILE frames=",frames.size()," p50_ms=",frames[frames.size()/2]," p95_ms=",frames[int(frames.size()*0.95)]," render_cpu_ms=",cpu/frames.size()," render_gpu_ms=",gpu/frames.size()," refresh_us_per_frame=",float(scene.refresh_us)/frames.size()," writes=",scene.writes," draws_panel_network_gauge=",draws)
	scene.set_process(false)
	var start := Time.get_ticks_usec()
	for i in range(300):
		panel.refresh_animation_visibility()
	print("PROFILE geometry_scan_us=",(Time.get_ticks_usec()-start)/300.0)
	start=Time.get_ticks_usec()
	for i in range(300):
		panel.refresh_core()
	print("PROFILE core_us=",(Time.get_ticks_usec()-start)/300.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://charge-performance.png")
	# Geometry updates must be driven by layout signals, without manual refresh.
	var gauge = panel.cards.probe_0.circuit
	var original: Vector2 = gauge.position
	gauge.position+=Vector2(11,5)
	await process_frame
	await process_frame
	check(panel.core_feed.routes.probe_0.end.distance_to(panel.core_feed.anchor_position(gauge.port))<0.01,"Instrument movement invalidates geometry automatically")
	gauge.position=original
	panel.turn_page(1)
	await process_frame
	await process_frame
	check(panel.core_feed.routes.probe_0.end.distance_to(panel.core_feed.anchor_position(gauge.port))<0.01,"Paging invalidates geometry automatically")
	panel.turn_page(-1)
	await process_frame
	await process_frame
	scene.game.paused=true
	panel.refresh_sample()
	await process_frame
	await RenderingServer.frame_post_draw
	var write_before := scene.writes
	var draw_before := draws.duplicate()
	for i in range(15):
		panel.refresh_sample(1.0/60.0)
		await process_frame
	check(scene.writes==write_before and draws==draw_before,"Global pause leaves unchanged controls and rendering idle")
	scene.equipment_tabs.current_tab=0
	await process_frame
	check(not panel.reactor.is_processing() and not panel.core_feed.is_processing(),"Hidden page stops all core and packet animation")
	check(panel.cards.values().all(func(card):return not card.circuit.is_processing()),"Hidden and offscreen gauges stop animation")
	print("Performance regression failures: ",failures)
	quit(1 if failures else 0)
