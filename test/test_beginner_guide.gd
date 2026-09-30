extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\","/")
	if not user_dir.contains("/test/work/") and not user_dir.begins_with("/tmp/onboarding-user/"):
		printerr("Run this save-boundary test with an isolated user directory under test/work.")
		quit(1)
		return
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	var game: BattleGame = scene.game
	game.pending_unlocks.clear()
	game.start(1,false)
	var guide = scene.beginner_guide
	guide.set_process(false)
	await process_frame
	guide.refresh()
	check(guide.phase=="intro" and guide.panel.visible,"Fresh profile starts guidance after battle begins")
	game.state = BattleGame.State.MAIN_MENU
	guide.refresh()
	check(not guide.panel.visible and not guide.reopen.visible,"Menu does not expose guide")
	game.state = BattleGame.State.COMBAT
	guide.refresh()
	guide.action.pressed.emit()
	check(guide.phase=="equip","Acknowledged intro targets an open module")
	var slot: String = guide.target_slot
	var index := int(slot.split("_")[1])
	guide.activate()
	check(scene.equipment_panel.selected==slot,"CTA selects semantic module target")
	var original_key: String = game.slot_entry("weapons",index).key
	check(original_key.is_empty(),"CTA never auto-equips")
	game.equip_slot("weapons",index,"laser")
	game.profile.resources = {"1":0.0,"2":0.0}
	guide.refresh()
	check(guide.phase=="waiting" and guide.body.text.contains(scene.cost_text(game.slot_upgrade_cost("weapons",0))),"Equip completes by actual state and insufficient resources show actual costs")
	game.profile.resources = {"1":1e12,"2":1e12}
	guide.refresh()
	check(guide.phase=="upgrade","Affordable upgrade appears without forced timing")
	guide.dismiss()
	check(not guide.panel.visible and guide.reopen.visible,"Dismiss leaves a reopen control")
	guide.open_guide()
	check(guide.panel.visible and guide.phase=="upgrade","Reopen resumes current step")
	game.upgrade_slot("weapons",0)
	guide.refresh()
	check(guide.phase=="progress","Actual level change completes upgrade")
	game.paused = true
	guide.refresh()
	check(guide.phase=="paused","Pause does not hide instructions or unpause battle")
	scene.help_open = true
	guide.refresh()
	check(not guide.panel.visible,"Existing help hides guide")
	scene.help_open = false
	game.state = BattleGame.State.RETREAT
	guide.refresh()
	check(guide.phase=="retreat","Retreat explanation is contextual")
	game.state = BattleGame.State.COMBAT
	game.profile.cleared = [1]
	guide.refresh()
	check(guide.phase=="clear","Clear completes meaningful loop without requiring defeat")
	guide.activate()
	check(game.profile.onboarding.completed and not guide.panel.visible,"Finish remains quiet")
	guide.open_guide()
	check(guide.phase=="review","Completed guidance opens concise reference")
	# Actual persisted boundary: old profile opts out, fresh profile opts in.
	var raw: Dictionary = game.profile.duplicate(true)
	raw.erase("onboarding")
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var legacy := BattleGame.new(scene.db,false)
	legacy.load_progress()
	check(legacy.profile.onboarding.completed,"Legacy save with missing field stays quiet")
	for category in ["weapons","defence"]:
		for module_index in game.active_slot_count(category):
			var before := game.slot_entry(category,module_index)
			var after := legacy.slot_entry(category,module_index)
			check(before.key==after.key and before.level==after.level,"Legacy onboarding migration preserves module identity and level")
	var fresh := BattleGame.new(scene.db,false)
	check(not fresh.profile.onboarding.completed,"Fresh/reset construction opts in independently of legacy field")
	game.profile.onboarding.dismissed = true
	game.save_enabled = true
	game.save_progress()
	game.save_enabled = false
	var restored := BattleGame.new(scene.db,false)
	restored.load_progress()
	check(restored.profile.onboarding.dismissed and restored.profile.onboarding.completed,"Normal save/load preserves dismiss and completion")
	# State reconciles pre-existing actions, even before a guide is first displayed.
	game.profile.onboarding = fresh.profile.onboarding.duplicate()
	guide.review = false
	guide.refresh()
	check(guide.phase=="clear","Out-of-order equip/upgrade/clear require no repetition")
	game.profile.onboarding = fresh.profile.onboarding.duplicate()
	game.profile.cleared.clear()
	game.profile.loadout = fresh.profile.loadout.duplicate(true)
	guide.equip_target = ""
	guide.refresh()
	guide.activate()
	game.pending_unlocks.append(str(scene.db.data.unlock.keys()[0]))
	guide.refresh()
	check(guide.phase=="unlock" and guide.target==scene.continue_button,"Unlock notice gets its actual Continue anchor")
	guide.activate()
	check(game.pending_unlocks.is_empty(),"Guide Continue reuses existing unlock acknowledgement")
	guide.refresh()
	var old_position: Vector2 = guide.target.position
	guide.target.position += Vector2(10,10)
	guide.refresh()
	check(guide.outline.get_global_rect().grow(-3).is_equal_approx(guide.target.get_global_rect()),"Highlight follows moved semantic anchor")
	guide.target.position = old_position
	scene.queue_free()
	await process_frame
	print("Beginner guide: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
