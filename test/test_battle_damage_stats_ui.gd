extends SceneTree
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func _initialize()->void:call_deferred("run")

func run()->void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.profile.onboarding.completed=true
	scene.beginner_guide.hide()
	scene.game.state=BattleGame.State.COMBAT
	scene.game.spawn_group()
	scene.refresh_structure()
	var ui=scene.damage_stats_ui
	var chain_origin=Vector2(100,160)
	var chain_shot={"key":"chain","chain_weapon":"cannon","chain_hop":true,"launch_point":chain_origin,"mount":0,"x":chain_origin.x,"y":chain_origin.y,"hostile":false}
	check(scene.visual_muzzle(chain_shot)==chain_origin,"chain visual starts at hit enemy instead of player turret")
	var slice=preload("res://scripts/battle_slice_runtime.gd").new()
	check(slice.style(chain_shot)==3,"chain cannon impact keeps its source style")
	chain_shot.chain_weapon="missile"
	check(slice.style(chain_shot)==2,"chain missile impact keeps its source style")
	check(ui!=null and scene.guard_settings.get_popup().get_item_text(scene.guard_settings.get_popup().get_item_index(21))==UIText.t("battle.damage_stats.title"),"main scene exposes settings entry")
	ui.show();await process_frame
	check(not scene.game.damage_stats.enabled and not ui.enabled.button_pressed,"window opens stopped")
	ui.enabled.button_pressed=true
	check(scene.game.damage_stats.enabled,"switch enables observer")
	scene.game.damage_stats.advance(0.5)
	scene.game.damage_stats.record("module:0",50)
	scene.game.damage_stats.record("drone:private-source-123",20)
	ui.refresh();await process_frame
	check(ui.summary.text.contains("70") and ui.details.text.contains("武器槽 1") and ui.details.text.contains("无人机"),"total and source rows render")
	check(not ui.details.text.contains("private-source-123"),"internal source ID hidden")
	var evidence=OS.get_environment("DAMAGE_STATS_EVIDENCE")
	if DisplayServer.get_name()!="headless" and not evidence.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence)==OK,"main-scene screenshot saved")
	ui.dialog.hide();await process_frame
	check(not scene.game.damage_stats.enabled and scene.game.damage_stats.buckets.is_empty(),"window close clears observer")
	ui.show();ui.enabled.button_pressed=true
	check(scene.game.damage_stats.enabled and scene.game.damage_stats.total==0,"reopen starts fresh")
	ui.stop()
	check(not scene.game.damage_stats.enabled and ui.timer.is_stopped(),"switch off stops timer")
	scene.queue_free();await process_frame
	print("Damage statistics UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
