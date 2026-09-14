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
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.build_ui()
	check(scene.number(4300.0)=="4.3K" and scene.number(10249.0)=="10K" and scene.number(105739.0)=="100K", "Equipment display uses KMBT formatting")
	check(scene.equipment_tabs.get_tab_title(0)=="武器","Weapons first")
	check(scene.upgrade_buttons.size()==2,"Starting unlocked equipment retained")
	check(not scene.upgrade_buttons.armour.is_visible_in_tree(),"Defence hidden on weapons page")
	scene.equipment_tabs.current_tab = 1
	check(scene.upgrade_buttons.armour.is_visible_in_tree(),"Defence switch exposes armour")
	scene.game.profile.resources["1"] = 1000000
	scene.game.profile.resources["2"] = 1000000
	var level := int(scene.game.profile.levels.armour)
	scene.build_ui()
	scene.upgrade_buttons.armour.pressed.emit()
	check(scene.game.profile.levels.armour==level+1,"Upgrade still works")
	check(scene.equipment_tabs.current_tab==1,"Upgrade preserves selected page")
	scene.game.profile.unlocked = ["armour","shield","laser","cannon","missile"]
	scene.build_ui()
	check(scene.upgrade_buttons.size()==5,"All equipment retained across pages")
	scene.equipment_tabs.current_tab = 0
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-weapons.png")
	scene.equipment_tabs.current_tab = 1
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-defence.png")
	check(scene.equipment_tabs.get_rect().end.y<=778,"Tabs stay above footer")
	print("Equipment tabs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
