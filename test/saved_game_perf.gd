extends SceneTree
# Run only in a copied project/user directory via saved_game_perf.py.
class ReplayScene extends "res://scripts/main.gd":
	# Startup dialogs are outside the measured gameplay and need user input.
	func show_chrono_login_report() -> void:pass
	func show_qa_tools() -> void:pass
class Meter:
	extends RefCounted
	var enabled := false
	var times := {}
	func record(key: String, elapsed: int) -> void:
		if not enabled:return
		if not times.has(key):times[key]=[0,0,0]
		times[key][0]+=1
		times[key][1]+=elapsed
		times[key][2]=maxi(times[key][2],elapsed)
var meter := Meter.new()
func _initialize() -> void:
	Engine.set_meta("saved_perf",meter)
	call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values:total+=value
	return {"mean_ms":total/values.size()/1000.0,"p50_ms":values[values.size()/2]/1000.0,"p95_ms":values[int(values.size()*0.95)]/1000.0,"p99_ms":values[int(values.size()*0.99)]/1000.0,"max_ms":values[-1]/1000.0}
func run() -> void:
	var cap := 0
	var speed := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-fps="):cap=int(arg.get_slice("=",1))
		if arg.begins_with("--perf-speed="):speed=float(arg.get_slice("=",1))
	Engine.max_fps=cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(1701)
	var scene=ReplayScene.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.rng.seed=1701
	await process_frame
	if is_instance_valid(scene.chrono_login_dialog):scene.chrono_login_dialog.hide()
	var qa=root.get_node_or_null("QATools")
	if qa:qa.hide()
	if speed>0:scene.game.speed=speed
	var report := {"stage":scene.game.stage,"speed":scene.game.speed,"crew":scene.game.profile.crew.size(),"pages":[]}
	for page in [0,1,2,5,6,8]:
		if scene.equipment_tabs.is_tab_hidden(page):continue
		scene.equipment_tabs.current_tab=page
		var frames := []
		var cpu := []
		meter.enabled=false
		meter.times.clear()
		for i in range(360):
			if i==60:meter.enabled=true
			var start := Time.get_ticks_usec()
			scene._process(1.0/60.0)
			var elapsed := Time.get_ticks_usec()-start
			await process_frame
			if i>=60:
				frames.append(Time.get_ticks_usec()-start)
				cpu.append(elapsed)
		meter.enabled=false
		var row := {"page":page,"frame":stats(frames),"main":stats(cpu),"timings":meter.times.duplicate(true),"projectiles":scene.game.projectiles.size(),"nodes":get_node_count()}
		report.pages.append(row)
		print(JSON.stringify(row))
		if page==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/saved-perf.png")
	FileAccess.open("res://.runtime/saved-perf.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("Measurements saved")
	scene.equipment_tabs.current_tab=0
	scene.game.paused=true
	scene.music.stop()
	for voice in scene.railgun_audio.values():voice.stop()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	print("Render cleanup complete")
	Engine.remove_meta("saved_perf")
	quit()
