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
func capture(label: String) -> void:
	var folder := OS.get_environment("ONBOARDING_EVIDENCE")
	if folder.is_empty() or DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func run() -> void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	var g=scene.game;var panel=scene.equipment_panel;g.paused=true
	var card=panel.cards.weapons_0;var menu=card.name_button.get_popup()
	panel.refresh();panel.select_item("weapons_0");panel.refresh_detail({},true)
	check(card.equipment_options==["","laser"] and card.name_button.item_count==2,"Fresh inline selector omits all locked weapons")
	check(panel.slot_options==["","laser"] and panel.detail.slots.item_count==2,"Inspector omits locked weapons")
	check(panel.equipment_choices("defence")==["","armour"],"Locked shield is absent")
	check(panel.new_weapon_id.is_empty() and not panel.new_weapon.visible,"Fresh equipment never advertises a locked weapon")
	check(not panel.details_open and not panel.detail.stats.visible and panel.detail.basics.visible,"Default inspector collapses advanced attributes")
	for level in [1,2,5]:
		g.profile.cleared.append(level);g.profile.highestLevel=level+1;g.rebuild_unlocks();panel.refresh();panel.refresh_detail({},true)
		if level==1:
			check(panel.new_weapon_id=="missile" and panel.new_weapon.visible,"Earned unread missile persists on the equipment page")
			while not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
			panel.refresh_pending()
			check(panel.new_weapon_id=="missile","Three-second notice acknowledgement does not dismiss the weapon entry")
			await capture("weapon-entry-after-notice")
			panel.category_filter=2;panel.category_picker.select(2);panel.apply_filters()
			var original_key: String = g.slot_entry("weapons",0).key
			panel.new_weapon.pressed.emit()
			check(panel.category_filter==0 and panel.category_picker.selected==0 and card.visible,"Entry reveals weapon cards and reconciles the category selector")
			await capture("weapon-entry-existing-menu")
			check(menu.visible and card.equipment_options.has("missile"),"Entry opens the existing refit menu containing the earned weapon")
			check(g.slot_entry("weapons",0).key==original_key,"Discovery never auto-equips")
			check(g.profile.readUnlocks.has("missile") and panel.new_weapon_id.is_empty(),"Explicitly viewed choice uses the existing persistent read flag")
			menu.hide()
		if level==2:
			check(panel.new_weapon_id=="cannon","Next earned weapon has its own persistent entry")
			panel.new_weapon_dismiss.pressed.emit()
			panel.refresh_pending()
			check(g.profile.readUnlocks.has("cannon") and panel.new_weapon_id.is_empty(),"Explicit dismissal persists through the existing read flag")
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
	panel.refresh_detail({},true)
	panel.show_inspector()
	await capture("missile-default-basics")
	check(panel.detail.basics.text.contains("攻击间隔") and panel.detail.basics.text.contains("物理") and not panel.detail.basics.text.contains("暴击"),"Default missile detail retains actionable basics without unrelated zero probabilities")
	panel.toggle_details()
	check(panel.detail.stats.visible and not panel.detail.basics.visible,"Advanced details remain explicitly available")
	panel.toggle_details()
	check(not panel.detail.stats.visible and panel.detail.basics.visible,"Collapse restores the necessary basic view")
	# A distinct table gate must be honored without inventing a level threshold.
	g.profile.grantedUnlocks=[];g.db.data.unlock[g.db.unlock_id("equipment","longLaser")].level=99
	g.rebuild_unlocks();panel.refresh();panel.refresh_detail({},true)
	check(not card.equipment_options.has("longLaser") and not panel.slot_options.has("longLaser"),"Choices obey a distinct valid source gate")
	check(card.equipment_options.has("") and panel.slot_options.has(""),"Empty slot remains available")
	print("Visible equipment: %d checks, %d failures"%[checks,failures])
	scene.queue_free();await process_frame;quit(1 if failures else 0)
