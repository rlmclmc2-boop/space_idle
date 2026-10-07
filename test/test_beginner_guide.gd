extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:call_deferred("run")
func press(button: Button) -> void:
	if DisplayServer.get_name()=="headless":
		button.pressed.emit()
		return
	await process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var input := InputEventMouseButton.new()
		input.position = point
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		root.push_input(input,true)
		await process_frame
func capture(scene: Node, label: String) -> void:
	var folder := OS.get_environment("ONBOARDING_EVIDENCE")
	if folder.is_empty() or DisplayServer.get_name()=="headless":return
	scene.overlay_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
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
	await press(guide.action)
	check(guide.phase=="equip","Acknowledged intro targets an open module")
	var slot: String = guide.target_slot
	var index := int(slot.split("_")[1])
	guide.activate()
	check(scene.equipment_panel.selected==slot,"CTA selects semantic module target")
	var original_key: String = game.slot_entry("weapons",index).key
	check(original_key.is_empty(),"CTA never auto-equips")
	var laser_gate: int = scene.db.data.unlock.laser.level
	var earned: Array = game.profile.get("grantedUnlocks",[]).duplicate()
	scene.db.data.unlock.laser.level = 99
	game.profile.grantedUnlocks = earned.filter(func(id):return id!="laser")
	guide.refresh()
	check(not guide.has_equipment_choice("weapons",index) and guide.phase!="equip","An earned ID without any selectable weapon does not trap onboarding")
	scene.db.data.unlock.laser.level = laser_gate
	game.profile.grantedUnlocks = earned
	game.profile.onboarding.equipped = false
	guide.refresh()
	check(guide.phase=="equip","A real selectable weapon restores the equipment step")
	game.equip_slot("weapons",index,"laser")
	game.profile.resources = {"1":0.0,"2":0.0}
	guide.refresh()
	check(guide.phase=="waiting" and guide.body.text.contains(scene.cost_text(game.slot_upgrade_cost("weapons",0))),"Equip completes by actual state and insufficient resources show actual costs")
	game.profile.resources = {"1":1e12,"2":1e12}
	guide.refresh()
	check(guide.phase=="upgrade","Affordable upgrade appears without forced timing")
	guide.dismiss()
	check(not guide.panel.visible and not guide.reopen.visible,"Dismiss clears the battlefield without a persistent guide button")
	for repeat in 3:guide.refresh()
	check(not guide.panel.visible,"Repeated refresh does not reopen dismissed guidance")
	await capture(scene,"dismissed")
	scene.help_open = true
	scene.refresh_navigation()
	guide.refresh()
	check(guide.reopen.visible,"Help retains the explicit guide entry")
	await capture(scene,"help-entry")
	await press(guide.reopen)
	check(guide.panel.visible and guide.phase=="upgrade" and not scene.help_open,"Help entry resumes the current step and closes help")
	check(game.profile.onboarding.dismissed,"Temporary review preserves the saved dismissal")
	game.save_enabled = true
	game.save_progress()
	game.save_enabled = false
	var dismissed_restore := BattleGame.new(scene.db,false)
	dismissed_restore.load_progress()
	check(dismissed_restore.profile.onboarding.dismissed and not dismissed_restore.profile.onboarding.completed,"Saving during review keeps an unfinished guide dismissed on reload")
	guide.dismiss()
	guide.open_guide()
	game.upgrade_slot("weapons",int(guide.target_slot.split("_")[1]))
	guide.refresh()
	check(guide.phase=="defence" and guide.target_slot=="defence_1","After upgrade the guide points to a free defensive slot")
	guide.activate()
	check(scene.equipment_panel.selected=="defence_1","Defence CTA selects its actual slot")
	game.equip_slot("defence",1,"armour")
	guide.refresh()
	check(guide.phase=="progress","Actual defensive equip completes the survival step")
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
	check(game.profile.onboarding.completed and not guide.panel.visible and not guide.reopen.visible,"Equip, upgrade and clear finish automatically without a final click")
	for repeat in 3:guide.refresh()
	check(not guide.panel.visible,"Completion stays quiet across repeated refresh")
	await capture(scene,"completed")
	game.profile.onboarding.dismissed = false
	game.profile.onboarding.retreatSeen = false
	game.state = BattleGame.State.RETREAT
	guide.refresh()
	check(guide.panel.visible and guide.phase=="retreat" and game.profile.onboarding.retreatSeen,"First defeat still explains recovery after tutorial completion")
	guide.activate()
	guide.refresh()
	check(not guide.panel.visible,"Acknowledged first defeat stays quiet on the same retreat")
	game.state = BattleGame.State.COMBAT

	guide.open_guide()
	check(guide.phase=="review" and guide.panel.visible,"Completed guidance opens concise reference on explicit request")
	await capture(scene,"review")
	guide.dismiss()
	check(not guide.panel.visible and not guide.reopen.visible,"Closing the reference restores a clear battlefield")
	# Actual persisted boundary: old profile opts out, fresh profile opts in.
	var raw: Dictionary = game.profile.duplicate(true)
	raw.erase("onboarding")
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var legacy := BattleGame.new(scene.db,false)
	legacy.load_progress()
	check(legacy.profile.onboarding.completed and legacy.profile.onboarding.retreatSeen,"Legacy save with missing field stays quiet")
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
	check(restored.profile.onboarding.dismissed and restored.profile.onboarding.completed and restored.profile.onboarding.retreatSeen,"Normal save/load preserves dismiss, completion and the first-defeat receipt")
	# State reconciles pre-existing actions, even before a guide is first displayed.
	game.profile.onboarding = fresh.profile.onboarding.duplicate()
	guide.review = false
	guide.refresh()
	check(game.profile.onboarding.completed and not guide.panel.visible,"Out-of-order equip/upgrade/clear finish without repetition")
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
	# Earlier CTA opens a native picker. Close it and settle the actual card layout
	# before moving a visible anchor; hidden/clipped targets correctly have no outline.
	for card in scene.equipment_panel.cards.values():card.name_button.get_popup().hide()
	scene.equipment_panel.refresh()
	guide.activate()
	for card in scene.equipment_panel.cards.values():card.name_button.get_popup().hide()
	await process_frame
	guide.refresh()
	check(guide.outline.visible,"Moved-anchor fixture starts with a visible highlighted target")
	var old_position: Vector2 = guide.target.position
	guide.target.position += Vector2(10,10)
	guide.refresh()
	check(guide.outline.get_global_rect().grow(-3).is_equal_approx(guide.target.get_global_rect()),"Highlight follows moved semantic anchor")
	guide.target.position = old_position
	scene.queue_free()
	await process_frame
	print("Beginner guide: %d checks, %d failures" % [checks,failures])
	call_deferred("quit",1 if failures else 0)
