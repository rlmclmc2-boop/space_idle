extends SceneTree
const Transfer := preload("res://scripts/save_transfer.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func capture(label: String) -> void:
	var folder := OS.get_environment("UNLOCK_TUTORIAL_EVIDENCE")
	if folder.is_empty() or DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.beginner_guide.set_process(false)
	var g: BattleGame = scene.game
	g.save_enabled = false
	g.start(1,false)
	g.rebuild_unlocks()
	g.paused = true
	g.profile.onboarding.completed = true
	scene.beginner_guide.refresh()
	var tutorial = scene.unlock_tutorial
	var laser := g.db.unlock_id("equipment","laser")
	var missile := g.db.unlock_id("equipment","missile")
	var hyperspace_gate: int = int(g.hyperspace.config.unlock_stage)
	g.profile.highestLevel = hyperspace_gate-1
	check(not g.hyperspace.is_unlocked(g) and not g.tutorial_unlocks().has("hyperspace"),"Hyperspace archive stays absent before its authoritative gate")
	g.profile.highestLevel = hyperspace_gate
	check(g.hyperspace.is_unlocked(g) and g.tutorial_unlocks().has("hyperspace"),"Hyperspace archive appears at the same gate as navigation")
	g.hyperspace.config.unlock_stage = hyperspace_gate+2
	check(not g.tutorial_unlocks().has("hyperspace"),"Archive follows an alternative live configured gate without a second threshold")
	g.hyperspace.config.unlock_stage = hyperspace_gate
	g.profile.highestLevel = 1
	check(not g.tutorial_unlocks().has(missile),"Locked entry is absent")
	check(not g.read_tutorial_unlock(missile),"Locked entry cannot be marked read")
	g.profile.grantedUnlocks.append(missile)
	g.rebuild_unlocks()
	g.pending_unlocks.assign([laser,missile])
	scene.refresh_navigation()
	await process_frame
	var start: int = scene.unlock_notice_started_ms
	g.speed = 10.0
	scene.advance_unlock_notice(start+2999)
	check(g.pending_unlocks.size()==2,"X10 and pause do not acknowledge before three real UI seconds")
	await capture("01-unlock-countdown")
	scene.advance_unlock_notice(start+3000)
	check(g.pending_unlocks==[missile],"Three seconds acknowledges only the displayed page")
	check(not g.profile.readUnlocks.has(laser),"Automatic acknowledgement is not a read")
	var second_start: int = scene.unlock_notice_started_ms
	scene.advance_unlock_notice(second_start+2999)
	check(g.pending_unlocks==[missile],"Next notice receives a full interval")
	scene.select_system(0)
	scene.refresh_navigation()
	check(scene.unlock_notice_started_ms==second_start,"Page change does not reset notice deadline")
	scene.advance_unlock_notice(second_start+3000)
	check(g.pending_unlocks.is_empty(),"Second notice independently confirms")
	tutorial.refresh()
	check(tutorial.entry_badge.visible,"Tutorial entry shows unread red dot")
	scene.help_open = true
	scene.refresh_navigation()
	tutorial.set_archive(true)
	tutorial.select_system("equipment")
	await process_frame
	check(tutorial.category_buttons.equipment.badge.visible and tutorial.entry_buttons[missile].badge.visible,"Category and entry have unread dots")
	check(not g.profile.readUnlocks.has(missile),"Opening category does not read entries")
	await capture("02-unread-archive")
	tutorial.open_entry(missile)
	check(tutorial.description.text==str(g.db.data.unlock[missile].desc),"Content uses authoritative unlock description")
	check(g.profile.readUnlocks.has(missile) and not tutorial.entry_buttons[missile].badge.visible,"Opening entry removes its dot")
	await capture("03-read-entry")
	var entry_instance: int = tutorial.entry_buttons[missile].button.get_instance_id()
	tutorial.refresh()
	check(tutorial.entry_buttons[missile].button.get_instance_id()==entry_instance,"Read refresh reuses entry controls")
	g.profile.highestLevel = hyperspace_gate
	tutorial.select_system("hyperspace")
	check(tutorial.category_buttons.hyperspace.button.visible and tutorial.entry_buttons.hyperspace.badge.visible,"Unlocked hyperspace has an unread category and entry")
	check(not g.profile.readUnlocks.has("hyperspace"),"Opening the hyperspace category does not read the entry")
	tutorial.open_entry("hyperspace")
	check(tutorial.title.text==UIText.t("hyperspace.title") and tutorial.description.text==UIText.t("tutorial.hyperspace.description"),"Hyperspace entry projects registered content")
	check(g.profile.readUnlocks.has("hyperspace") and not tutorial.entry_buttons.hyperspace.badge.visible,"Explicit hyperspace read clears its entry badge")
	await capture("03b-hyperspace-read")
	scene.help_open = false
	scene.refresh_navigation()
	tutorial.open_entry(laser)
	check(not g.profile.readUnlocks.has(laser),"Hidden archive cannot mark a read")
	scene.help_open = true
	scene.refresh_navigation()
	for id in g.tutorial_unlocks():tutorial.open_entry(id)
	check(g.unread_tutorial_unlocks().is_empty() and not tutorial.entry_badge.visible,"Final read removes tutorial entrance dot")
	var saved := g.profile.duplicate(true)
	var restored := BattleGame.new(g.db,false)
	restored.load_progress_data(saved)
	check(restored.profile.readUnlocks==g.profile.readUnlocks,"Restart preserves reads")
	var portable: Dictionary = Transfer.clean(saved,Transfer.schema())
	check(portable.readUnlocks==saved.readUnlocks,"Portable whitelist preserves reads")
	var imported := BattleGame.new(g.db,false)
	imported.load_progress_data(portable)
	check(imported.unread_tutorial_unlocks().is_empty(),"Import/export retains read state")
	var transfer := Transfer.new()
	check(transfer.export_progress(g,"user://tutorial-export.json")==OK,"Real portable export succeeds")
	var preview := transfer.prepare("user://tutorial-export.json",g.db)
	check(preview.error.is_empty() and preview.data.readUnlocks==saved.readUnlocks,"Real import validation retains reads")
	var old := saved.duplicate(true)
	old.erase("readUnlocks")
	var legacy := BattleGame.new(g.db,false)
	legacy.load_progress_data(old)
	check(legacy.tutorial_unlocks().has(missile) and legacy.unread_tutorial_unlocks().has(missile),"Old save backfills earned entries as unread")
	check(legacy.pending_unlocks.is_empty() and legacy.profile.resources==restored.profile.resources,"Old save backfill gives no notice replay or reward")
	g.profile.grantedUnlocks.append(g.db.unlock_id("planet","1"))
	g.rebuild_unlocks()
	g.profile.planets["1"].buildings.shipyard.status = "built"
	var reads: Array = g.profile.readUnlocks.duplicate()
	check(g.reforge_planet("1"),"Reforge fixture is valid")
	check(g.profile.readUnlocks==reads and g.tutorial_unlocks().has(missile),"Reforge retains read state and earned archive")
	check(g.tutorial_unlocks().has("hyperspace") and g.profile.readUnlocks.has("hyperspace"),"Reforge preserves previously earned hyperspace knowledge and its read state")
	# Reforge deliberately rebuilds the UI; reacquire its new control owner.
	await process_frame
	await process_frame
	tutorial = scene.unlock_tutorial
	scene.beginner_guide.set_process(false)
	g.profile.onboarding.completed = true
	scene.beginner_guide.refresh()
	g.pending_unlocks.assign([laser,missile])
	scene.help_open = false
	scene.refresh_navigation()
	scene.continue_button.pressed.emit()
	check(g.pending_unlocks==[missile],"Manual acknowledgement still advances one page")
	g.pending_unlocks.assign([laser])
	g.speed = 10.0
	scene.refresh_navigation()
	var real_started := Time.get_ticks_msec()
	await create_timer(2.8).timeout
	scene.advance_unlock_notice()
	check(g.pending_unlocks==[laser],"Real clock does not confirm at 2.8 seconds")
	while Time.get_ticks_msec()-real_started < 3050:await process_frame
	scene.advance_unlock_notice()
	check(g.pending_unlocks.is_empty() and Time.get_ticks_msec()-real_started>=3000,"Real clock confirms after three seconds while paused at X10")
	for id in g.profile.planets:g.profile.planets[id].conquered = true
	g.profile.grantedUnlocks.assign(g.db.data.unlock.keys())
	g.rebuild_unlocks()
	scene.help_open = true
	scene.refresh_navigation()
	tutorial.set_archive(true)
	tutorial.select_system("equipment")
	await capture("04-all-systems")
	check(["equipment","ships","hightech","reactor","enhancement","crew","planets","galaxy"].all(func(id):return tutorial.category_buttons[id].button.visible),"Unlocked systems have archive categories")
	print("UNLOCK TUTORIAL: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
