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
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=[]
	scene.game.profile.unlocked=["laser","armour"]
	# Explicit gates isolate display behavior from balance changes.
	for row in scene.db.data.hightech.values():
		row.unlock=2
	for row in scene.db.data.charge.values():
		row.unlock=1
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(0) and not scene.equipment_tabs.is_tab_hidden(1),"Starting equipment tabs are visible")
	check(scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.is_tab_hidden(3),"Hightech and charge hidden before unlock")
	scene.equipment_tabs.current_tab=1
	scene.game.profile.cleared=[1]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(3) and scene.equipment_tabs.is_tab_hidden(2),"Charge appears at its gate independently of hightech")
	check(scene.equipment_tabs.current_tab==1,"Unlocking a tab preserves selection")
	scene.equipment_tabs.current_tab=3
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==3,"Rebuilding preserves unlocked charge selection")
	scene.game.profile.cleared=[]
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(3) and scene.equipment_tabs.current_tab==0,"Relocked charge falls back to first unlocked tab")
	scene.db.data.charge.values()[0].unlock=0
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(3),"One unlocked charge item unlocks its tab")
	scene.game.profile.cleared=[2]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(2),"Hightech follows same visibility rule")
	scene.equipment_tabs.current_tab=0
	scene.game.profile.unlocked=["armour"]
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(0) and scene.equipment_tabs.current_tab==1,"Locked weapon tab hides and falls back to defence")
	scene.game.profile.unlocked=[]
	scene.game.profile.cleared=[]
	for row in scene.db.data.charge.values():
		row.unlock=1
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==-1,"No unlocked tabs leaves no selected locked page")
	for index in range(4):
		check(scene.equipment_tabs.is_tab_hidden(index),"All-locked page stays hidden: "+str(index))
	scene.game.profile.unlocked=["laser","armour"]
	scene.build_ui()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-before-unlock.png")
	scene.game.profile.cleared=[1]
	scene.build_ui()
	scene.equipment_tabs.current_tab=3
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-charge-unlocked.png")
	print("Tab unlocks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
