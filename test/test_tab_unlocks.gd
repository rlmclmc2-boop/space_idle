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
	for key in scene.db.data.hightech:
		scene.db.unlock_row("hightech",key).level=2
	for key in scene.db.data.charge:
		scene.db.unlock_row("charge",key).level=1
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(0),"Starting equipment tabs are visible")
	check(scene.equipment_tabs.is_tab_hidden(1) and scene.equipment_tabs.is_tab_hidden(2),"Hightech and charge hidden before unlock")
	scene.equipment_tabs.current_tab=0
	scene.game.profile.cleared=[1]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.is_tab_hidden(1),"Charge appears at its gate independently of hightech")
	check(scene.equipment_tabs.current_tab==0,"Unlocking a tab preserves selection")
	scene.equipment_tabs.current_tab=2
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==2,"Rebuilding preserves unlocked charge selection")
	scene.game.profile.cleared=[]
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.current_tab==0,"Relocked charge falls back to first unlocked tab")
	scene.db.unlock_row("charge",scene.db.data.charge.keys()[0]).level=0
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(2),"One unlocked charge item unlocks its tab")
	var keys: Array = scene.charge_cards.keys()
	var first_card: Node = scene.charge_cards[keys[0]].title.get_parent()
	var second_card: Node = scene.charge_cards[keys[1]].title.get_parent()
	var tabs: Node = scene.equipment_tabs
	check(first_card.visible and second_card.visible and scene.charge_panel.state_for(keys[1])=="locked","Charge page includes inspectable locked modules")
	scene.equipment_tabs.current_tab=2
	scene.game.profile.cleared=[1]
	scene.refresh_structure()
	scene.refresh_visible_cards()
	check(second_card.visible and scene.charge_cards[keys[0]].title.get_parent()==first_card and scene.equipment_tabs==tabs,"Unlock reveals card locally and preserves existing controls")
	check(scene.equipment_tabs.current_tab==2,"Local charge unlock preserves selected tab")
	scene.game.profile.cleared=[]
	scene.refresh_structure()
	check(second_card.visible and first_card.visible and scene.charge_panel.state_for(keys[1])=="locked","Relocked individual charge updates state locally")
	scene.game.profile.cleared=[2]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(1),"Hightech follows same visibility rule")
	scene.equipment_tabs.current_tab=0
	scene.game.profile.unlocked=["armour"]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(0) and scene.equipment_tabs.current_tab==0,"Unified equipment remains visible with defense alone")
	scene.game.profile.unlocked=[]
	scene.game.profile.cleared=[]
	for key in scene.db.data.charge:
		scene.db.unlock_row("charge",key).level=1
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==-1 and scene.battle_return_button.visible,"No unlocked features falls back to battlefield")
	for index in range(3):
		check(scene.equipment_tabs.is_tab_hidden(index),"All-locked page stays hidden: "+str(index))
	scene.game.profile.unlocked=["laser","armour"]
	scene.build_ui()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-before-unlock.png")
	scene.game.profile.cleared=[1]
	scene.db.unlock_row("charge",scene.db.data.charge.keys()[1]).level=2
	scene.db.unlock_row("charge",scene.db.data.charge.keys()[2]).level=3
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-charge-unlocked.png")
	print("Tab unlocks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
