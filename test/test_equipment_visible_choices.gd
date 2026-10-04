extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	var g=scene.game;var panel=scene.equipment_panel;g.paused=true
	var card=panel.cards.weapons_0;var menu=card.name_button.get_popup()
	panel.refresh();panel.select_item("weapons_0");panel.refresh_detail({},true)
	check(card.equipment_options==["","laser"] and card.name_button.item_count==2,"Fresh inline selector omits all locked weapons")
	check(panel.slot_options==["","laser"] and panel.detail.slots.item_count==2,"Inspector omits locked weapons")
	check(panel.equipment_choices("defence")==["","armour"],"Locked shield is absent")
	for level in [1,2,5]:
		g.profile.cleared.append(level);g.profile.highestLevel=level+1;g.rebuild_unlocks();panel.refresh();panel.refresh_detail({},true)
		for key in BattleGame.WEAPON_KEYS:
			check(card.equipment_options.has(key)==g.content_unlocked("equipment",key),"Inline choices match real unlock")
			check(panel.slot_options.has(key)==g.content_unlocked("equipment",key),"Inspector choices match real unlock")
		check(is_same(card,panel.cards.weapons_0) and is_same(menu,card.name_button.get_popup()),"Unlock preserves controls")
		check(card.equipment_options[card.name_button.selected]==g.slot_entry("weapons",0).key,"Selection remains mapped by key")
	var index:int=card.equipment_options.find("cannon")
	card.name_button.item_selected.emit(index)
	check(g.slot_entry("weapons",0).key=="cannon","Inline remapped selection equips intended item")
	panel.refresh();panel.refresh_detail({},true)
	panel.choose_equipment(panel.slot_options.find("missile"));panel.confirm_equipment()
	check(g.slot_entry("weapons",0).key=="missile","Inspector remapped selection equips intended item")
	# A distinct table gate must be honored without inventing a level threshold.
	g.profile.grantedUnlocks=[];g.db.data.unlock[g.db.unlock_id("equipment","longLaser")].level=99
	g.rebuild_unlocks();panel.refresh();panel.refresh_detail({},true)
	check(not card.equipment_options.has("longLaser") and not panel.slot_options.has("longLaser"),"Choices obey a distinct valid source gate")
	check(card.equipment_options.has("") and panel.slot_options.has(""),"Empty slot remains available")
	print("Visible equipment: %d checks, %d failures"%[checks,failures])
	scene.queue_free();await process_frame;quit(1 if failures else 0)
