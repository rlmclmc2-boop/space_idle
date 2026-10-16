extends SceneTree
# Mounted, save-disabled main UI captures for authored encounters.
var scene: Node
var directory := ""
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func capture(stage: int, point: int, name: String, weapon: String, defence: String) -> void:
	var g = scene.game
	g.profile.cleared = range(1, stage)
	g.rebuild_unlocks()
	g.profile.resources["1"] = 10000.0
	g.profile.resources["2"] = 100.0
	if not g.equip_slot("weapons", 0, weapon) or not g.equip_slot("defence", 0, defence):
		printerr("CAPTURE_EQUIP_FAILED ", name); failures += 1; return
	g.profile.resources["1"] = 0.0
	g.profile.resources["2"] = 0.0
	if not g.start(stage, false):
		printerr("CAPTURE_START_FAILED ", name); failures += 1; return
	var level: Dictionary = scene.db.levels[stage - 1]
	g.group_index = point - 1
	g.distance = 0.0 if point == 1 else float(level.groups[point - 2].position) * float(level.length)
	var entered := false
	for step in 2000:
		g.tick(1.0 / 60.0)
		if g.state == BattleGame.State.COMBAT:
			entered = true
			break
	if not entered:
		printerr("CAPTURE_COMBAT_MISSING ", name); failures += 1; return
	for step in 40: g.tick(1.0 / 60.0)
	scene.refresh_structure()
	scene.refresh_tab_visibility()
	scene.select_system(0)
	scene.refresh_navigation()
	scene.refresh_draw_layers(0)
	scene.overlay_layer.queue_redraw()
	scene.resource_layer.queue_redraw()
	scene.beginner_guide.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := directory.path_join(name + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("CAPTURE_SAVE_FAILED ", path); failures += 1
	else:
		print("APPROVED_UI_CAPTURE ", path)

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	directory = ProjectSettings.globalize_path("res://../test/evidence/single-slot-20261016")
	DirAccess.make_dir_recursive_absolute(directory)
	scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	await capture(1, 1, "approved-ui-1-1", "laser", "armour")
	await capture(2, 1, "approved-ui-2-1-swarm", "missile", "armour")
	await capture(3, 3, "approved-ui-3-3-slow-energy", "laser", "shield")
	await capture(3, 5, "approved-ui-3-5-slow-energy", "missile", "shield")
	await capture(3, 7, "approved-ui-3-7-final", "missile", "armour")
	scene.queue_free()
	quit(1 if failures else 0)
