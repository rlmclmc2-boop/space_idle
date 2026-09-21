extends SceneTree
class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,60)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e20,"2":1e20}
	scene.game.switch_ship("Heavy_Battleship")
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	await process_frame
	await process_frame
	var panel: Control=scene.equipment_panel
	check(panel.cards.size()==12,"Every module has an independent card")
	check(panel.cards.weapons_0.fields.status.text==UIText.t("equipment.state.upgradeable") and panel.cards.weapons_0.fields.status.modulate==scene.ORANGE,"Affordable equipped module shows highlighted upgrade status")
	check(panel.cards.weapons_7.fields.status.text==UIText.t("equipment.state.upgradeable"),"Affordable empty module also shows upgrade status")
	scene.game.profile.resources={"1":0.0,"2":0.0}
	panel.refresh()
	check(panel.cards.weapons_0.fields.status.text==UIText.t("equipment.state.equipped") and panel.cards.weapons_7.fields.status.text==UIText.t("equipment.state.unequipped"),"Insufficient resources restores equipment and empty states")
	scene.game.profile.resources={"1":1e20,"2":1e20}
	panel.refresh()
	var cards: Dictionary=panel.cards.duplicate()
	panel.select_item("weapons_0")
	await click(panel.detail.upgrade)
	check(scene.game.slot_entry("weapons",0).level==2,"Actual upgrade button upgrades selected module")
	panel.change_equipment("cannon")
	check(scene.game.slot_entry("weapons",0).key=="cannon" and scene.game.slot_entry("weapons",0).level==2,"Direct equipment replacement inherits module level")
	panel.act("remove")
	check(scene.game.slot_entry("weapons",0).key=="" and scene.game.slot_entry("weapons",0).level==2,"Unload keeps module growth")
	panel.act("upgrade")
	check(scene.game.slot_entry("weapons",0).level==3,"Empty module can upgrade")
	panel.change_equipment("longLaser")
	panel.toggle_details()
	panel.sort_mode=1
	panel.category_filter=1
	panel.apply_filters()
	var paused: bool=scene.game.paused
	await click(panel.expand_button)
	await create_timer(0.3).timeout
	check(panel.equipment_view_mode=="expanded" and scene.equipment_tabs.position.y==120,"Actual expand button raises shared panel")
	check(panel.grid.columns==4 and int(panel.grid_scroll.size.y/47)*4>=30,"Expanded grid fits at least 30 compact cards without enlarging them")
	check(panel.cards.weapons_0.size==Vector2(235,43),"Cards retain compact dimensions")
	check(panel.selected=="weapons_0" and panel.details_open and panel.sort_mode==1 and panel.category_filter==1,"View state preserved")
	check(scene.game.paused==paused,"Expand does not pause battle")
	check(panel.battlefield_shade.visible,"Expanded background dimmed")
	panel.detail_scroll.scroll_vertical=100
	await process_frame
	var offset: int=panel.detail_scroll.scroll_vertical
	var esc := InputEventKey.new()
	esc.keycode=KEY_ESCAPE
	esc.pressed=true
	Input.parse_input_event(esc)
	await create_timer(0.3).timeout
	check(panel.equipment_view_mode=="compact" and scene.game.paused==paused,"Escape collapses without pausing")
	panel.set_view_mode("expanded")
	await create_timer(0.3).timeout
	check(panel.detail_scroll.scroll_vertical==offset,"Expanded detail scroll restored")
	for key in cards:check(is_same(cards[key],panel.cards[key]),"Module card instance retained: "+key)
	panel.refresh()
	await process_frame
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty(),"Static equipment refresh performs no property writes")
	scene.equipment_tabs.current_tab=3
	await process_frame
	var ship: Control=scene.ship_controls.page
	await click(ship.choices.Frigate)
	check(scene.game.profile.selectedShip=="Heavy_Battleship","Candidate selection is read-only")
	var player: Dictionary=scene.game.player
	await click(ship.confirm)
	check(scene.game.profile.selectedShip=="Frigate" and is_same(player,scene.game.player),"Hull confirmation preserves battle player")
	await click(ship.mounts.weapons_0)
	await create_timer(0.3).timeout
	check(scene.equipment_tabs.current_tab==0 and panel.selected=="weapons_0","Hull mount opens corresponding module")
	check(panel.items.weapons_7.locked and panel.cards.size()==12,"Dormant modules remain visible")
	check(panel.cards.weapons_7.fields.status.text==UIText.t("equipment.state.locked"),"Dormant module never advertises an upgrade")
	panel.select_item("weapons_7")
	check(panel.detail.upgrade.disabled and panel.detail.slots.disabled,"Dormant module actions disabled")
	panel.category_filter=0
	panel.apply_filters()
	panel.select_item("weapons_0")
	panel.detail_scroll.scroll_vertical=0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://module-equipment.png")
	scene.equipment_tabs.current_tab=3
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://module-ship.png")
	print("Module UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
