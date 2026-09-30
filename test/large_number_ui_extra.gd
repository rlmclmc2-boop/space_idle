extends "large_number_ui_audit.gd"
var click_checks: Array = []
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
func run() -> void:
	output=ProjectSettings.globalize_path("res://..").trim_suffix("/")
	root.gui_embed_subwindows=true
	root.size=Vector2i(1373,883)
	scene=FixtureUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.onboarding.completed=true
	scene.game.profile.onboarding.dismissed=true
	scene.game.injected=true
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	for sample in [{"name":"100000T","value":1e17},{"name":"999999T","value":9.99999e17},{"name":"scientific","value":1.23456e100}]:
		scene.game.fixture_value=sample.value
		scene.game.profile.resources={"1":sample.value,"2":sample.value}
		panel.refresh()
		scene.refresh_draw_layers(0)
		for resolution in [Vector2i(1373,883),Vector2i(960,540)]:
			root.size=resolution
			await settle()
			panel.detail_frame.hide()
			var base="initial-"+sample.name+"-"+str(resolution.x)+"x"+str(resolution.y)
			await capture(base)
			for i in [1,2,0]:
				await click(panel.amount_buttons[i])
				click_checks.append({"scenario":base,"action":"amount","expected":[1,10,0][i],"actual":panel.upgrade_amount,"pass":panel.upgrade_amount==[1,10,0][i]})
			await click(panel.footer_buttons.details)
			click_checks.append({"scenario":base,"action":"detail_open","pass":panel.detail_frame.visible})
			await capture(base+"-detail-click")
			panel.detail_frame.hide()
	scene.game.profile.cleared=range(1,60)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.switch_ship("Heavy_Battleship")
	for i in 8:scene.game.equip_slot("weapons",i,BattleGame.WEAPON_KEYS[i%4])
	for i in 4:scene.game.equip_slot("defence",i,BattleGame.DEFENSE_KEYS[i%2])
	scene.game.fixture_value=9.99999e19
	scene.game.profile.resources={"1":9.99999e19,"2":{"m":1.23456,"e":350}}
	for category in ["weapons","defence"]:
		for i in scene.game.active_slot_count(category):scene.game.module_entry(category,i).level=10000000
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	scene.refresh_draw_layers(0)
	for resolution in [Vector2i(1373,883),Vector2i(960,540)]:
		root.size=resolution
		await settle()
		for i in [0,1,2]:
			await click(panel.amount_buttons[i])
			click_checks.append({"scenario":"heavy-upper-T","action":"amount","expected":[1,10,0][i],"actual":panel.upgrade_amount,"pass":panel.upgrade_amount==[1,10,0][i]})
			await capture("heavy-upper-T-"+str(resolution.x)+"x"+str(resolution.y)+"-"+str([1,10,0][i]))
	var f=FileAccess.open(output+"/extra-measurements.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"snapshots":snapshots,"click_checks":click_checks},"\t"))
	print("CLICK_CHECKS ",JSON.stringify(click_checks))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()
