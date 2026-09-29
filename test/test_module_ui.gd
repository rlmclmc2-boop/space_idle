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
		event.position=control.get_global_rect().get_center()*Vector2(root.size)/Vector2(2048,1280)
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
	check(panel.cards.weapons_0.fields.status.text==UIText.t("equipment.state.equipped") and panel.cards.weapons_0.fields.upgrade.text==UIText.t("equipment.state.upgradeable"),"Equipped and upgrade states stay separate")
	check(panel.cards.weapons_7.fields.status.text==UIText.t("equipment.state.unequipped") and panel.cards.weapons_7.fields.upgrade.text==UIText.t("equipment.state.upgradeable"),"Affordable empty module keeps both states")
	scene.game.profile.resources={"1":0.0,"2":0.0}
	panel.refresh()
	check(panel.cards.weapons_0.fields.status.text==UIText.t("equipment.state.equipped") and panel.cards.weapons_7.fields.status.text==UIText.t("equipment.state.unequipped"),"Insufficient resources restores equipment and empty states")
	scene.game.profile.resources={"1":1e20,"2":1e20}
	panel.refresh()
	var cards: Dictionary=panel.cards.duplicate()
	panel.select_item("weapons_0")
	await click(panel.detail.upgrade)
	check(scene.game.slot_entry("weapons",0).level==2,"Actual upgrade button upgrades selected module")
	check(scene.message=="W01 "+scene.NAMES["laser"]+" · 升级完成","Weapon upgrade notice uses card number and equipment name")
	panel.change_equipment("cannon")
	check(scene.game.slot_entry("weapons",0).key=="cannon" and scene.game.slot_entry("weapons",0).level==2,"Direct equipment replacement inherits module level")
	panel.act("remove")
	check(scene.game.slot_entry("weapons",0).key=="" and scene.game.slot_entry("weapons",0).level==2,"Unload keeps module growth")
	panel.act("upgrade")
	check(scene.game.slot_entry("weapons",0).level==3,"Empty module can upgrade")
	check(scene.message=="W01 "+UIText.t("equipment.vacant")+" · 升级完成","Empty module upgrade notice uses card number")
	scene.game.equip_slot("defence",1,"shield")
	scene.game.upgrade_slot("defence",1)
	check(scene.message=="D02 "+scene.NAMES[str(scene.game.slot_entry("defence",1).key)]+" · 升级完成","Defence upgrade notice uses card number and equipment name")
	panel.change_equipment("longLaser")
	panel.sort_mode=1
	panel.category_filter=1
	panel.apply_filters()
	var paused: bool=scene.game.paused
	check(panel.grid.columns==2 and panel.grid_scroll.position.y>=120 and panel.grid_scroll.size.y>900,"Two-column overview uses page height")
	check(panel.detail_frame.position.x>panel.grid_scroll.position.x+panel.grid_scroll.size.x and panel.detail_scroll.size.y>900,"Inspector stays beside overview")
	check(panel.cards.weapons_0.custom_minimum_size==Vector2(426,170),"Overview card has readable dimensions")
	check(panel.selected=="weapons_0" and panel.details_open and panel.sort_mode==1 and panel.category_filter==1,"Selection and filters preserved")
	check(scene.game.paused==paused and scene.workspace_frame.visible and scene.battle_layer.visible,"Equipment layout leaves battle active")
	check(panel.detail.primary.text.contains(panel.items.weapons_0.mainStatValue) and panel.detail.stats.visible,"Inspector shows core stat and full details")
	panel.toggle_details()
	check(not panel.detail.stats.visible and panel.detail.slots.position.y==405 and panel.selected=="weapons_0","Collapsed details keep selection and operations")
	panel.toggle_details()
	check(panel.detail.stats.visible and panel.detail.slots.position.y>=756,"Full inspector restores attributes above operations")
	var category_box: OptionButton=panel.filters.get_child(0)
	category_box.select(2)
	category_box.item_selected.emit(2)
	check(panel.cards.defence_0.visible and not panel.cards.weapons_0.visible,"Defence filter isolates defence cards")
	category_box.select(0)
	category_box.item_selected.emit(0)
	var overflow: Array[Control]=[]
	for i in 50:
		var placeholder := Control.new()
		placeholder.custom_minimum_size=Vector2(426,170)
		panel.grid.add_child(placeholder)
		overflow.append(placeholder)
	await process_frame
	await process_frame
	panel.grid_scroll.scroll_vertical=800
	await process_frame
	check(panel.grid_scroll.scroll_vertical>0 and panel.detail_frame.position.y==118,"Fifty more entries scroll only the overview")
	for placeholder in overflow:placeholder.queue_free()
	panel.grid_scroll.scroll_vertical=0
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
