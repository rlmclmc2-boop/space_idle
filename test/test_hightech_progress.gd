extends SceneTree
var failures := 0
var checks := 0
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
	scene.game.save_enabled=false
	scene.game.profile.cleared=scene.db.data.hightech.values().map(func(row):return int(row.unlock))
	scene.game.profile.hightechResearch.clear()
	scene.game.profile.hightechOrder=[]
	scene.game.pending_unlocks.clear()
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	var f := BattleGame.FURNACE
	var e := BattleGame.ENERGY_FOCUS
	var a := BattleGame.DENSE_ARMOUR
	check(scene.hightech_progress.size()==3,"All unlocked cards have progress bars")
	check(scene.hightech_progress[f].bar.get_child(0).size.x==0,"Unstarted progress is empty")
	scene.hightech_buttons[f].pressed.emit()
	await process_frame
	var duration := float(scene.game.profile.hightechResearch[f].duration)
	scene.game.advance_hightech(duration*0.5)
	scene.refresh_hightech_progress(f)
	check(is_equal_approx(scene.hightech_progress[f].bar.get_child(0).size.x,151.5),"Half elapsed fills half the bar")
	check(scene.hightech_progress[f].label.text.contains("50%"),"Percentage agrees with bar")
	scene.hightech_buttons[e].pressed.emit()
	await process_frame
	check(scene.hightech_buttons[f].text=="继续研发" and is_equal_approx(scene.hightech_progress[f].bar.get_child(0).size.x,151.5),"Switched job retains visible progress")
	check(scene.hightech_progress[f].bar.get_child(0).color==scene.ORANGE,"Suspended progress uses orange")
	scene.hightech_buttons[f].pressed.emit()
	await process_frame
	scene.game.advance_hightech(duration*0.5)
	await process_frame
	check(scene.hightech_progress[f].bar.get_child(0).size.x==0 and scene.hightech_buttons[f].text=="连续研发中","Next level restarts bar automatically")
	scene.game.profile.hightechResearch[f].remaining=float(scene.game.profile.hightechResearch[f].duration)*0.25
	scene.game.paused=true
	scene._process(0.1)
	check(is_equal_approx(scene.hightech_progress[f].bar.get_child(0).size.x,227.25),"Game pause preserves progress")
	scene.build_ui()
	await process_frame
	check(scene.equipment_tabs.current_tab==2 and is_equal_approx(scene.hightech_progress[f].bar.get_child(0).size.x,227.25),"Rebuild retains progress and selected tab")
	for key in [f,e,a]:
		var controls: Dictionary=scene.hightech_progress[key]
		check(controls.bar.position.y+controls.bar.size.y<=112 and controls.bar.position.x+controls.bar.size.x<scene.hightech_buttons[key].position.x,"Bar fits card without overlapping action")
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://hightech-progress.png")
	print("Hightech progress: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
