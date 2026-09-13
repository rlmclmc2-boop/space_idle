extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.resources["1"] = 123
	scene.game.profile.resources["2"] = 45
	check(scene.resource_display("1")=="123" and scene.resource_display("2")=="45", "Default displays unchanged totals")
	scene.resource_mode_button.pressed.emit()
	check(scene.resource_rate_mode and scene.resource_display("1")=="0.00/秒", "Button switches to empty rate")
	for manual in [true,false]:
		var drop := {"uid":90 if manual else 91,"x":500.0,"y":300.0,"age":0.0,"id":"1" if manual else "2","amount":60.0}
		scene.game.drops.append(drop)
		scene.game.collect(drop,manual)
	check(scene.resource_display("1")=="1.00/秒", "Manual credit divided by full minute")
	var auto_amount := ceilf(60.0*(1.0-float(scene.db.config.autoCollectReduce)))
	check(scene.resource_display("2")=="%.2f/秒" % (auto_amount/60.0) and scene.game.profile.resources["2"]==45+auto_amount, "Auto rate uses actual credit")
	scene.game.profile.resources["1"] -= 100
	check(scene.resource_display("1")=="1.00/秒", "Spending does not reduce acquisition rate")
	scene.build_ui()
	check(scene.resource_rate_mode and scene.resource_mode_button.text=="资源：每秒", "UI rebuild retains selected mode")
	scene.resource_samples.assign([{"time":40.0,"id":"1","amount":600.0},{"time":40.1,"id":"1","amount":30.0},{"time":99.0,"id":"2","amount":15.0}])
	check(scene.resource_display("1",100.0)=="0.50/秒" and scene.resource_display("2",100.0)=="0.25/秒", "Rolling window excludes exact 60-second boundary and separates resources")
	check(scene.resource_display("1",160.0)=="0.00/秒", "No recent income expires to zero")
	scene.resource_mode_button.pressed.emit()
	check(not scene.resource_rate_mode and scene.resource_display("1")=="83", "Second click restores current total")
	if DisplayServer.get_name() != "headless":
		scene.resource_mode_button.pressed.emit()
		scene.resource_samples.assign([{"time":Time.get_unix_time_from_system(),"id":"1","amount":75.0}])
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://resource-rate.png")
	print("Resource display: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
