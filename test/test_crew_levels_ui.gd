extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;printerr(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view:=SubViewport.new()
	view.size=Vector2i(2048,1280)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	# Exercise UI state transitions with a fixed unlock fixture, not live thresholds.
	for gate in scene.db.data.unlock.values():gate.level=0
	var level_gate: Dictionary=scene.db.data.unlock[scene.db.unlock_id("feature","crew_level")]
	level_gate.level=1
	level_gate.mode="cleared"
	scene.db.data.crew_config.equip_bonus.des="Equipment {effect}"
	scene.db.data.crew_config.name_level.des="{name} Lv{level}"
	var bonus_text: String="%+.2f%%" % (float(scene.db.data.crew_config.equip_bonus.value)*100)
	scene.game.profile.cleared=[]
	scene.game.profile.grantedUnlocks=[]
	scene.game.rebuild_unlocks()
	scene.refresh_structure()
	scene.system_nav_buttons[5].pressed.emit()
	await process_frame
	await process_frame
	var panel=scene.crew_panel
	panel.refresh()
	check(not is_instance_valid(panel.experience),"No XP controls constructed before unlock")
	check(not panel.title.text.contains("Lv"),"No crew level in locked title")
	check(not panel.row_fields.navigator.name.text.contains("Lv"),"No crew level in locked row")
	var job_id: int=panel.jobs.get_instance_id()
	var row_id: int=panel.rows.navigator.get_instance_id()
	scene.game.assign_crew("navigator","equipment_upgrade","equipment")
	check(not scene.game.crew.tab_badge(scene.game,["equipment"]).tooltip.contains("Lv"),"No locked level tooltip")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../crew-level-locked.png")
	scene.game.profile.cleared.append(1)
	scene.game.rebuild_unlocks()
	scene.on_event("unlock",{})
	await process_frame
	await process_frame
	check(is_instance_valid(panel.experience),"XP controls appear upon unlock")
	check(panel.title.text.contains("Lv0"),"Unlocked title starts Lv0")
	check(scene.game.crew.entry(scene.game,"navigator").level==0 and panel.level_effect_label.text=="Equipment +0.00%","Unlock keeps Lv0 and no level bonus")
	check(scene.game.crew.tab_badge(scene.game,["equipment"]).tooltip.contains("+0.00%"),"System badge uses zero percent at Lv0")
	check(panel.jobs.get_instance_id()==job_id and panel.rows.navigator.get_instance_id()==row_id,"Unlock preserves existing controls")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../crew-level-zero.png")
	scene.game.add_crew_exp("navigator",maxf(1.0,roundf(float(scene.db.data.crew_config.base_exp.value))))
	check(panel.title.text.contains("Lv1"),"Level change refreshes immediately while paused")
	check(panel.level_effect_label.text=="Equipment "+bonus_text,"Level one bonus displays as percent with two decimals")
	check(scene.game.crew.tab_badge(scene.game,["equipment"]).tooltip.contains(bonus_text),"System badge shares percent formatting")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../crew-level-percent.png")
	scene.db.data.crew_config.equip_bonus.des="测试效果 {effect} {unrecognized}"
	panel.invalidate()
	check(panel.level_effect_label.text.begins_with("测试效果") and panel.level_effect_label.text.contains("{unrecognized}"),"Changed des immediately supplies display")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../crew-level-unlocked.png")
	print("crew level UI failures: ",failures)
	view.queue_free()
	await process_frame
	quit(1 if failures else 0)
