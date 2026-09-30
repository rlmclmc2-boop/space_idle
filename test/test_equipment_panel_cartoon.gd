extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL "+message)
	else:print("PASS "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	await process_frame
	await process_frame
	var panel = scene.equipment_panel
	print("PANEL_SIZE ",panel.size)
	check(panel.cards.size()>0,"Slot cards build")
	panel.open_picker("weapons_1")
	panel.detail.slots.select(panel.slot_options.find("laser"))
	panel.detail.slots.item_selected.emit(panel.slot_options.find("laser"))
	var before: Dictionary=scene.game.profile.resources.duplicate()
	panel.detail.equip.pressed.emit()
	check(scene.game.module_entry("weapons",1).key=="laser","Explicit free equip")
	check(scene.game.profile.resources==before,"Free equip does not spend")
	scene.game.profile.resources={"1":1e20,"2":1e20}
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	panel.refresh()
	panel.cards.weapons_1.upgrade_button.pressed.emit()
	check(scene.game.module_entry("weapons",1).level==2,"Direct card upgrade")
	panel.open_picker("weapons_1")
	panel.detail.slots.select(panel.slot_options.find("cannon"))
	panel.detail.slots.item_selected.emit(panel.slot_options.find("cannon"))
	check(scene.game.module_entry("weapons",1).key=="laser","Picker preview is read only")
	panel.detail.equip.pressed.emit()
	check(scene.game.module_entry("weapons",1).key=="cannon" and scene.game.module_entry("weapons",1).level==2,"Swap preserves slot level")
	scene.game.profile.cleared=range(1,100)
	scene.game.switch_ship("Heavy_Battleship")
	panel.refresh()
	check(panel.cards.size()==12,"Heavy hull exposes 12 slots")
	scene.game.switch_ship("Frigate")
	panel.refresh()
	panel.open_picker("weapons_7")
	check(panel.detail.equip.disabled and panel.detail.slots.disabled and panel.cards.weapons_7.upgrade_button.disabled,"Overflow actions disabled")
	check(panel.section_labels.weapons.text.contains(UIText.t("equipment.overflow",{"count":"5"})),"Overflow labeled")
	check(panel.get_action_anchor("empty_module","weapons_2")!=null,"Semantic empty anchor")
	check(panel.detail_frame.position.x+panel.detail_frame.size.x<=panel.size.x,"Inspector stays in equipment workspace")
	print("RESULT failures=",failures)
	quit(failures)
