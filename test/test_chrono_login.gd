extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	var seed := BattleGame.new(db,false)
	seed.save_enabled=true
	seed.profile.chronoParticles=5.0
	seed.save_progress()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	raw.chronoSavedAt=Time.get_unix_time_from_system()-12.5
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw));file.close()
	var scene := preload("res://scripts/main.gd").new()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	var dialog: AcceptDialog=scene.chrono_login_dialog
	check(is_instance_valid(dialog) and dialog.visible,"Every normal startup opens the collection dialog")
	check(scene.game.login_chrono_particles>=12 and scene.game.login_chrono_particles<14 and dialog.dialog_text.contains(str(int(scene.game.login_chrono_particles))),"Dialog reports the actual newly collected particles")
	check(dialog.title==UIText.t("chrono.login_title") and dialog.ok_button_text==UIText.t("system.confirm"),"Dialog uses registered UI text")
	if DisplayServer.get_name() != "headless":
		check(root.get_node_or_null("QATools")==null,"Development QA window waits until the login report closes")
		await RenderingServer.frame_post_draw
		var texture := dialog.get_texture()
		if texture != null:texture.get_image().save_png("res://.runtime/chrono-login.png")
	var panel := scene.chrono_panel
	var particles_before := float(scene.game.profile.chronoParticles)
	var resources_before: Dictionary=scene.game.profile.resources.duplicate(true)
	dialog.confirmed.emit()
	await process_frame
	check(not is_instance_valid(dialog) and scene.chrono_panel==panel and scene.game.profile.chronoParticles==particles_before and scene.game.profile.resources==resources_before,"Dismissing report preserves particles, resources and page instances")
	scene.queue_free()
	await process_frame
	raw.chronoParticles=seed.chrono_capacity()
	raw.chronoSavedAt=Time.get_unix_time_from_system()-100
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw));file.close()
	var again := preload("res://scripts/main.gd").new()
	root.add_child(again)
	again.set_process(false)
	await process_frame
	check(again.game.login_chrono_particles==0 and is_instance_valid(again.chrono_login_dialog) and again.chrono_login_dialog.visible and again.chrono_login_dialog.dialog_text.contains("0"),"Next startup still reports zero when storage was already full")
	if DisplayServer.get_name() != "headless":
		var qa_tools := root.get_node_or_null("QATools")
		check(qa_tools==null or not qa_tools.visible,"Existing QA window stays behind the next login report")
	again.chrono_login_dialog.confirmed.emit()
	await process_frame
	again.queue_free()
	await process_frame
	print("Chrono login: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
