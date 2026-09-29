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
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.cleared = []
	scene.game.profile.unlocked = ["laser","armour"]
	for key in scene.db.data.hightech:scene.db.unlock_row("hightech",key).level = 2
	scene.db.unlock_row("feature","reactor").level = 1
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(0),"Starting equipment visible")
	check(scene.equipment_tabs.is_tab_hidden(1) and scene.equipment_tabs.is_tab_hidden(2),"Research and reactor locked")
	check(not scene.system_nav_buttons[1].visible,"Research navigation hidden before first unlock")
	var research_page = scene.hightech_page
	scene.game.profile.cleared = [1,2]
	scene.refresh_structure()
	check(not scene.equipment_tabs.is_tab_hidden(1) and scene.system_nav_buttons[1].visible,"First research unlock reveals tab and navigation")
	check(scene.hightech_page == research_page,"Research unlock preserves page instance")
	scene.game.profile.cleared = [1]
	scene.refresh_structure()
	check(not scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.is_tab_hidden(1),"Reactor unlocks independently")
	var panel = scene.reactor_panel
	var slider: HSlider = panel.module_controls.weapons.slider
	scene.equipment_tabs.current_tab = 2
	scene.refresh_structure()
	check(scene.equipment_tabs.current_tab == 2 and scene.reactor_panel == panel and panel.module_controls.weapons.slider == slider,"Unlock preserves reactor controls")
	scene.game.profile.cleared = []
	scene.game.profile.grantedUnlocks = []
	scene.refresh_structure()
	check(scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.current_tab != 2,"Relocked reactor returns to an available page")
	scene.db.unlock_row("feature","reactor").level = 0
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(2),"Level zero gate reveals reactor")
	scene.game.profile.unlocked = []
	scene.db.unlock_row("feature","reactor").level = 1
	scene.refresh_structure()
	check(scene.equipment_tabs.current_tab == 7 and scene.system_nav_buttons[7].visible,"Chrono remains when others locked")
	await process_frame
	print("Tab unlocks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
