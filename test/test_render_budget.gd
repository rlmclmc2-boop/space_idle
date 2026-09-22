extends SceneTree
## Native-window audit. Rendering probes and readback-based flicker probes are
## separate: GPU readback time is never counted as normal frame cost.
class ProfileUI extends "res://scripts/main.gd":
	var samples: Dictionary={}
	var recording := false
	func record(key: String, began: int) -> void:
		if recording:
			if not samples.has(key):samples[key]=[]
			samples[key].append(Time.get_ticks_usec()-began)
	func _process(dt: float) -> void:
		var began := Time.get_ticks_usec()
		super._process(dt)
		record("main_process",began)
	func refresh_visible_cards(dt := 0.0) -> void:
		var began := Time.get_ticks_usec()
		super.refresh_visible_cards(dt)
		record("visible_ui",began)
	func refresh_draw_layers(dt: float) -> void:
		var began := Time.get_ticks_usec()
		super.refresh_draw_layers(dt)
		record("draw_dependencies",began)
	func draw_stars() -> void:
		var began := Time.get_ticks_usec()
		super.draw_stars()
		record("stars_commands",began)
	func draw_battle() -> void:
		var began := Time.get_ticks_usec()
		super.draw_battle()
		record("battle_commands",began)

var scene: ProfileUI
var results: Array=[]
var checks := 0
var failures := 0
const COUNT := 120

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func stats(values: Array) -> Dictionary:
	if values.is_empty():return {"count":0,"mean":0,"p95":0,"max":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:total+=float(v)
	return {"count":sorted.size(),"mean":total/sorted.size(),"p95":sorted[int(sorted.size()*0.95)],"max":sorted[-1]}

func measure(label: String,page: int,paused: bool) -> void:
	scene.recording=false
	scene.game.paused=paused
	scene.equipment_tabs.current_tab=page
	for i in 10:
		scene._process(1.0/60)
		await process_frame
	scene.samples.clear()
	var wall: Array=[]
	var calls: Array=[]
	var cpu: Array=[]
	var gpu: Array=[]
	var mem_before := OS.get_static_memory_usage()
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	scene.recording=true
	for i in COUNT:
		var began := Time.get_ticks_usec()
		scene._process(1.0/60)
		await process_frame
		wall.append(Time.get_ticks_usec()-began)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	scene.recording=false
	var timings: Dictionary={}
	for key in scene.samples:timings[key]=stats(scene.samples[key])
	var result := {"mode":label,"frames":COUNT,"cpu_us":timings,"wall_frame_us":stats(wall),"draw_calls":stats(calls),
		"viewport_cpu_ms":stats(cpu),"viewport_gpu_ms":stats(gpu),
		"memory_bytes":OS.get_static_memory_usage(),"memory_delta_bytes":OS.get_static_memory_usage()-mem_before,
		"nodes_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes_before,
		"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources_before,
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}
	results.append(result)
	print(JSON.stringify(result))
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes_before,"Steady mode does not grow scene nodes: "+label)
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources_before+4,"Steady mode does not accumulate resources: "+label)

func brightness(img: Image,rect: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(rect.position.y,rect.end.y,4):
		for x in range(rect.position.x,rect.end.x,4):
			var p := img.get_pixel(x,y)
			total+=maxf(p.r,maxf(p.g,p.b))
			count+=1
	return total/maxi(1,count)

func rollover_probe() -> Dictionary:
	scene.game.paused=false
	scene.equipment_tabs.current_tab=1
	scene.game.profile.scientists=44
	var keys: Array=scene.hightech_progress.keys()
	for key in keys:
		scene.game.profile.scientistAssignments[key]=11
		scene.game.profile.techPoints[key]=scene.game.hightech_required(key)*0.15
		var c=scene.hightech_progress[key].construction
		c.completed=0
		c.completion_cooldown=0
		scene.refresh_hightech_card(key)
	await process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2i=Rect2i(scene.hightech_progress[keys[0]].construction.get_global_rect())
	var initial: Image=root.get_texture().get_image()
	var before := brightness(initial,rect)
	var values: Array=[]
	var deltas: Array=[]
	var sentinels := [Vector2i(60,200),Vector2i(380,200),Vector2i(780,200),Vector2i(1220,200),Vector2i(370,660),Vector2i(706,660),Vector2i(1042,660),Vector2i(1380,660),Vector2i(100,765),Vector2i(600,765),Vector2i(1300,765)]
	var reference: Array=[]
	for point in sentinels:reference.append(initial.get_pixelv(point))
	var flashes := 0
	for frame in 180:
		if frame in [12,36,150]:
			for key in keys:
				scene.game.profile.techPoints[key]=scene.game.hightech_required(key)-0.001
			scene.game.advance_hightech(0.01)
		scene.refresh_visible_cards(1.0/60)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image=root.get_texture().get_image()
		var light := brightness(img,rect)
		values.append(light)
		deltas.append(absf(light-before))
		before=light
		for i in sentinels.size():
			if img.get_pixelv(sentinels[i])!=reference[i]:
				flashes+=1
				break
		if frame in [11,12,13,35,36,86,87,88,89,149,150]:
			img.save_png("res://.runtime/rollover-%03d.png" % frame)
	check(flashes==0,"Fixed opaque panel pixels never flash during automatic completions")
	return {"frames":180,"building_brightness":values,"brightness_delta":stats(deltas),"panel_flash_frames":flashes}

func run() -> void:
	Engine.max_fps=60
	seed(19273)
	# Pin this isolated copy when unrelated configuration changes in parallel.
	# All writes stay inside the runner's disposable test project.
	var fixture := OS.get_environment("RENDER_AUDIT_DATA_DIR")
	if not fixture.is_empty():
		assert(ProjectSettings.globalize_path("res://").replace("\\","/").contains("/test/work/"))
		for name in ["game_data.json","ui_text.json","ui_text_contract.json"]:
			FileAccess.open("res://data/"+name,FileAccess.WRITE).store_string(FileAccess.get_file_as_string(fixture.path_join(name)))
		UIText.reload_catalog()
	scene=ProfileUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.rebuild_unlocks()
	scene.game.profile.resources={"1":1e12,"2":1e12}
	scene.game.profile.scientists=49
	for key in scene.db.data.hightech:
		scene.game.profile.hightechLevels[key]=303
		scene.game.profile.scientistAssignments[key]=11
		scene.game.profile.techPoints[key]=scene.game.hightech_required(key)*0.45
	scene.build_ui()
	var qa := root.get_node_or_null("QATools")
	if qa!=null:qa.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var rollover_only := OS.get_environment("RENDER_AUDIT_ROLLOVER_ONLY")=="1"
	for repeat in (0 if rollover_only else 2):
		await measure("research_active_%d" % repeat,1,false)
		await measure("research_paused_%d" % repeat,1,true)
		await measure("battle_active_%d" % repeat,0,false)
		await measure("charge_active_%d" % repeat,2,false)
		await measure("jewels_active_%d" % repeat,3,false)
	scene.equipment_tabs.current_tab=1
	scene.game.paused=true
	scene.refresh_visible_cards()
	var breakdown: Array=[]
	for variant in ([] if rollover_only else ["full","no_stars","no_fx","no_buildings"]):
		scene.stars_layer.visible=variant!="no_stars"
		for controls: Dictionary in scene.hightech_progress.values():
			controls.construction.visible=variant!="no_buildings"
			controls.construction.effects.visible=variant!="no_fx"
		for i in 5:await process_frame
		var calls: Array=[]
		for i in 20:
			await process_frame
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		breakdown.append({"mode":variant,"calls":stats(calls)})
	scene.stars_layer.show()
	for controls: Dictionary in scene.hightech_progress.values():
		controls.construction.show()
		controls.construction.effects.show()
	var rollover := await rollover_probe()
	check(rollover.brightness_delta.max<0.04,"Completion no longer causes a large single-frame building brightness jump")
	var projectile_sizes: Dictionary={}
	for key in scene.PROJECTILE_TEXTURES:
		projectile_sizes[key]=str(scene.PROJECTILE_TEXTURES[key].get_size())
	var report := {"scope":"Native 1440x810, 60 FPS cap, fixed 1/60 game step, two runs per page; timings instrumented. Readback flicker probe separate. Zero GPU timer may mean unsupported backend.","projectile_texture_sizes":projectile_sizes,"scenarios":results,"breakdown":breakdown,"rollover":rollover,"checks":checks,"failures":failures}
	FileAccess.open("res://.runtime/render-budget.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Render budget: %d checks, %d failures; rollover max brightness delta=%f" % [checks,failures,rollover.brightness_delta.max])
	quit(1 if failures else 0)
