extends SceneTree

class PolicyGame extends BattleGame:
	var elapsed := 0.0
	var attempts := 0
	var builds := 0
	func save_clock_seconds() -> float:return elapsed
	func save_progress() -> void:
		attempts += 1
		super.save_progress()
	func _build_save_data() -> Dictionary:
		builds += 1
		return super._build_save_data()

class FailureWriter extends "res://scripts/progress_writer.gd":
	var fail_install := false
	var fail_restore := false
	func _rename(from: String, to: String) -> Error:
		if fail_install and from.ends_with(".tmp"):return ERR_FILE_CANT_WRITE
		if fail_restore and from.ends_with(".bak"):return ERR_FILE_CANT_WRITE
		return super._rename(from,to)

class PartialWriter extends "res://scripts/progress_writer.gd":
	func _store_buffer(file: FileAccess, bytes: PackedByteArray) -> bool:
		file.store_buffer(bytes.slice(0,bytes.size()/2))
		return true

class SaveScene extends "res://scripts/main.gd":
	func show_chrono_login_report() -> void:pass
	func show_qa_tools() -> void:pass

var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:call_deferred("run")

func activate(control: BaseButton) -> void:
	if DisplayServer.get_name()=="headless":
		control.pressed.emit()
		return
	await process_frame
	var viewport := control.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	if viewport is Window and viewport != root:
		motion.position += Vector2(viewport.position)
		viewport = root
	viewport.push_input(motion,true)
	for pressed in [true,false]:
		var input := InputEventMouseButton.new()
		input.position = motion.position
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		viewport.push_input(input,true)
		await process_frame

func run() -> void:
	var area := ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\","/")
	check(OS.get_user_data_dir().replace("\\","/").begins_with(area),"Player data stays inside isolated test directory")
	var db := ShipDatabase.new()
	var g := PolicyGame.new(db,false)
	g.progress_writer.clear_files()
	g.save_enabled = true
	check(g.save_interval_minutes==1 and g.next_timed_save_at==60 and g.attempts==0 and g.builds==0,"Startup builds no save snapshot and schedules one real minute")
	for speed in [1.0,2.0,20.0]:
		g.speed = speed
		g.elapsed = 59.999
		g.check_timed_save()
	check(g.attempts==0 and g.builds==0,"Different game speeds do not advance the real-time deadline")
	g.elapsed = 60
	g.check_timed_save()
	check(g.attempts==1 and g.builds==1 and g.last_save_error==OK and g.last_successful_save_at>0,"Exactly one snapshot/write at the first real minute")
	var saved := FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	g.check_timed_save()
	g.elapsed = 500
	g.check_timed_save()
	check(g.attempts==2 and g.next_timed_save_at==560,"Missed periods cause one save and a new deadline from now")
	g.check_timed_save()
	check(g.attempts==2,"No backlog or same-frame repeat")
	for input in ["0","-1","1.5","","abc","999999999999999999999999"]:
		check(not g.set_save_interval(input) and g.save_interval_minutes==1,"Reject invalid interval: "+input)
	check(g.set_save_interval(" 002 ") and g.save_interval_minutes==2 and g.next_timed_save_at==620 and g.attempts==2,"Positive integer setting changes schedule without building/writing")
	g.save_progress()
	check(g.attempts==3 and g.builds==3 and g.next_timed_save_at==620,"Manual save writes once without resetting periodic cadence")
	g.elapsed = 619.999
	g.check_timed_save()
	check(g.attempts==3,"Two-minute boundary has not arrived")
	g.paused = true
	g.speed = 50
	g.elapsed = 620
	g.check_timed_save()
	check(g.attempts==4 and g.next_timed_save_at==740,"Pause and multiplier do not suppress the real-time save")
	var loaded := PolicyGame.new(db,true)
	check(loaded.save_interval_minutes==2 and loaded.attempts==0 and loaded.builds==0 and loaded.last_successful_save_at==g.last_successful_save_at,"Interval and last success reload without startup write")

	# Business operations work normally even when creating a temporary file fails.
	var business := PolicyGame.new(db,false)
	business.save_enabled = true
	business.profile.highestLevel = int(db.unlock_row("feature","jewels").level)+1
	business.profile.resources["1"] = 1.0e9
	business.profile.resources["2"] = 1.0e9
	business.start(1,false)
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	var iron := float(business.profile.resources["1"])
	var drop := {"uid":999,"id":"1","amount":37.0,"x":0.0,"y":0.0,"age":0.0}
	business.drops.append(drop)
	business.collect(drop,true)
	check(business.profile.resources["1"]==iron+37 and not business.drops.has(drop) and business.run_resources["1"]==37,"Pickup awards exactly once with unavailable storage")
	var category := "defence"
	var entry := business.slot_entry(category,0)
	var level := int(entry.level)
	var cost := db.equipment_cost(business.module_cost_key(category),level+1)
	var resources: Dictionary = business.profile.resources.duplicate()
	check(business.upgrade_slot(category,0,1) and int(entry.level)==level+1,"Upgrade remains successful with unavailable storage")
	for id in cost:
		check(business.profile.resources[id]==resources[id]-cost[id],"Upgrade debits configured cost once: "+str(id))
	business.db.config.jewelCombine = 3
	business.db.data.jewel["1"].maxLevel = 3
	business.profile.jewels.clear()
	for i in 3:business.profile.jewels.append(business.new_jewel("1",1))
	var serial := business.jewel_serial
	var combo := business.combine_all_jewels()
	check(combo.ok and combo.count==1 and business.profile.jewels.size()==1 and business.profile.jewels[0].level==2 and business.jewel_serial==serial+1,"Gem operation commits rewards and serial without consulting disk")
	business.clear_level()
	business.acknowledge_unlocks()
	business.set_guard_death(1)
	business.tick(6.0)
	business.check_timed_save()
	check(business.attempts==0 and business.builds==0,"Combat/state/settlement/upgrade/gem operations never build or write a save")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")

	# Actual safe-write failures retain committed bytes and live business results.
	g.paused = false
	g.profile.resources["1"] = 100
	g.save_progress()
	saved = FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	var last_success := g.last_successful_save_at
	var failed := FailureWriter.new()
	failed.fail_install = true
	g.progress_writer = failed
	g.profile.resources["1"] = 200
	var errors := [0]
	g.event.connect(func(kind,_payload):
		if kind=="save_error":errors[0]+=1)
	g.elapsed = 740
	g.check_timed_save()
	check(errors[0]==1 and g.save_dirty and g.last_save_error!=OK and g.profile.resources["1"]==200,"Timed failure reports clearly and never rolls back live progress")
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved and g.last_successful_save_at==last_success,"Failed installation preserves prior bytes and success timestamp")
	var attempts := g.attempts
	for i in 3:g.check_timed_save()
	check(g.attempts==attempts and errors[0]==1,"Failure waits for next deadline or manual save")
	g.elapsed = g.next_timed_save_at
	g.check_timed_save()
	check(g.attempts==attempts+1 and errors[0]==2 and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved,"The next real-time deadline retries once and protects the old commit again")
	failed.fail_restore = true
	g.save_progress()
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH+".bak")==saved,"Failed restoration leaves byte-identical recovery copy")
	var recovered := PolicyGame.new(db,true)
	check(recovered.profile.resources["1"]==100 and recovered.attempts==0,"Load recovers old progress from backup without rewriting it")
	var corrupt := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	g.save_progress()
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH+".bak")==saved,"Corrupt primary plus failed save never overwrites a valid backup")
	recovered = PolicyGame.new(db,true)
	check(recovered.profile.resources["1"]==100,"Corrupt primary falls back to valid recovery data")
	failed.fail_install = false
	failed.fail_restore = false
	g.save_progress()
	check(g.last_save_error==OK and not g.save_dirty and JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)).resources["1"]==200,"Explicit retry commits current memory after recovery")
	saved = FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	g.progress_writer = PartialWriter.new()
	g.profile.resources["1"] = 300
	g.save_progress()
	check(g.last_save_error!=OK and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved and g.profile.resources["1"]==300,"Truncated temporary write preserves disk and does not undo memory")
	g.progress_writer = preload("res://scripts/progress_writer.gd").new()
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	g.save_progress()
	check(g.last_save_error!=OK and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved,"Temporary open failure preserves prior save")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")

	# UI integration: actual connected controls, draft preservation and failure text.
	var scene := SaveScene.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.event.disconnect(scene.on_event)
	scene.game = PolicyGame.new(db,true)
	scene.game.event.connect(scene.on_event)
	scene.game.paused = true
	if DisplayServer.get_name()!="headless":
		await activate(scene.guard_settings)
		check(scene.guard_settings.get_popup().visible,"Real header click opens settings without overlapping another button")
		scene.guard_settings.get_popup().hide()
	scene.guard_settings.get_popup().id_pressed.emit(30)
	var dialog_id := scene.save_settings_dialog.get_instance_id()
	var apply := scene.save_settings_dialog.find_child("ApplySaveInterval",true,false) as Button
	var manual := scene.save_settings_dialog.find_child("ManualSave",true,false) as Button
	scene.save_interval_input.text = "0"
	await activate(apply)
	check(scene.game.save_interval_minutes==2 and scene.game.attempts==0 and scene.save_interval_feedback.text==UIText.t("save.invalid_interval"),"Invalid UI interval has visible feedback and no save")
	scene.save_interval_input.text = "3"
	await activate(apply)
	check(scene.game.save_interval_minutes==3 and scene.game.next_timed_save_at==180 and scene.game.attempts==0,"Settings button accepts whole minutes without writing")
	scene.save_interval_input.text = "unfinished"
	await activate(manual)
	check(scene.game.attempts==1 and scene.game.builds==1 and scene.save_interval_input.text=="unfinished","Manual button saves once without replacing unrelated edit draft")
	check(scene.last_save_label.text.contains(Time.get_datetime_string_from_unix_time(int(scene.game.last_successful_save_at)+int(Time.get_time_zone_from_system().bias)*60,true)),"UI shows last successful local save time")
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	await activate(manual)
	check(scene.game.last_save_error!=OK and not scene.save_status_label.text.is_empty() and scene.message==scene.save_status_label.text,"Manual failure stays visible in settings and toast")
	var ui_attempts: int = scene.game.attempts
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	scene.equipment_tabs.current_tab = 1
	scene.refresh_navigation()
	scene._process(0.016)
	check(scene.game.attempts==ui_attempts and scene.game.builds==ui_attempts and scene.save_settings_dialog.get_instance_id()==dialog_id,"Focus/tab/close/frame refresh do not save or rebuild the settings dialog")
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		check(scene.save_settings_dialog.size.y < 600 and scene.save_settings_dialog.get_ok_button().is_visible_in_tree(),"Settings remain compact with visible confirmation and failure warning")
		scene.get_viewport().get_texture().get_image().save_png("res://.runtime/preview-save-settings.png")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	saved = FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	scene.free()
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved,"Scene exit writes nothing")
	g.progress_writer.clear_files()
	var legacy := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version":2,"resources":{"1":73,"2":19}}))
	legacy.close()
	var old := PolicyGame.new(db,true)
	check(old.profile.resources=={"1":73.0,"2":19.0} and old.profile.version==BattleGame.SAVE_VERSION and old.save_interval_minutes==1 and old.attempts==0 and old.builds==0,"Legacy v2 save migrates in memory with the default interval and no startup write")
	g.progress_writer.clear_files()
	check(not FileAccess.file_exists(BattleGame.SAVE_PATH) and not FileAccess.file_exists(BattleGame.SAVE_PATH+".bak") and not FileAccess.file_exists(BattleGame.SAVE_PATH+".tmp"),"Clear removes main, temporary and recovery files")
	print("Save policy: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
