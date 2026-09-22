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
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1,16)
	scene.game.profile.scientists = 7
	var keys: Array = scene.game.hightech_slots().filter(func(key):return not str(key).is_empty())
	for i in keys.size():
		scene.game.profile.scientistAssignments[keys[i]] = 7 if i == 0 else 0
	scene.equipment_page = 1
	scene.build_ui()
	check(scene.game.idle_scientists() == 0, "Video fixture has no idle scientists")
	# Inspect BEFORE _process/refresh_scientists can hide a first-frame error.
	for key in scene.scientist_assignment_buttons:
		for action in scene.scientist_assignment_buttons[key]:
			check(action.disabled, "Initial bulk assignment disabled: " + key)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/flicker-before.png")
	scene.on_event("state",{})
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/flicker-rebuilt.png")
	for key in scene.scientist_assignment_buttons:
		for action in scene.scientist_assignment_buttons[key]:
			check(action.disabled, "First rendered frame remains disabled: " + key)
	scene.refresh_scientists()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/flicker-refreshed.png")
	scene.game.profile.scientists = 8
	scene.build_ui()
	for key in scene.scientist_assignment_buttons:
		for action in scene.scientist_assignment_buttons[key]:
			check(not action.disabled, "Idle scientist enables assignment at creation: " + key)
	print("Hightech flicker: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
