extends SceneTree
# Focused unified equipment acceptance. All data and imports live in test/work.
class FixtureGame extends BattleGame:
	var injected = false
	func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null) -> Variant:
		return 9.9e19 if injected else super.jewel_equipment_stat(entry,level,effects)
	func slot_upgrade_cost(category: String, index: int, levels := 1) -> Dictionary:
		return {"1":9.9e19*levels} if injected else super.slot_upgrade_cost(category,index,levels)
class FixtureUI extends "res://scripts/main.gd":
	var writes: Array = []
	func create_battle_game(_persist: bool) -> BattleGame:return FixtureGame.new(db,false)
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(str(control)+":"+str(property))
		super.set_ui_value(control,property,value)
var scene
var panel
var evidence: Array = []
var checks: Array = []
func _initialize() -> void:call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok:printerr(label)
func settle() -> void:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
func click(control: Control, local := Vector2(-1,-1)) -> void:
	var point: Vector2=control.get_global_rect().get_center() if local.x<0 else control.get_global_transform()*local
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
func capture(tag: String) -> void:
	await settle()
	var out=ProjectSettings.globalize_path("res://../")
	var native=DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	var status=OS.execute("import",["-display",OS.get_environment("DISPLAY"),"-window",str(native),out+tag+".png"])
	verify(status==0,tag+": native window screenshot")
	evidence.append({"tag":tag,"window":str(root.size),"columns":panel.grid.columns,"scroll":panel.grid_scroll.scroll_vertical})
func card_checks(tag: String) -> void:
	verify(panel.cards.size()==scene.game.module_entries("weapons").size()+scene.game.module_entries("defence").size(),tag+": every owned module has a card")
	verify(panel.grid.columns==panel.grid_defence.columns,tag+": same category grid density")
	for id in panel.cards:
		var c=panel.cards[id]
		verify(c.size.x>=310 and c.size.y==176,tag+": shared card footprint "+id)
		verify(c.picture.size==Vector2(64,64),tag+": common icon box "+id)
		verify(c.upgrade_button.size==Vector2(246,56),tag+": common upgrade button "+id)
		verify(absf(c.upgrade_button.get_rect().get_center().x-c.size.x/2)<0.1,tag+": centered upgrade "+id)
		verify(c.get_meta("slot_id")==id and c.upgrade_button.get_meta("slot_id")==id and c.equip_button.get_meta("slot_id")==id,tag+": semantic slots "+id)
		verify(panel.get_action_anchor("upgrade_action",id)==c.upgrade_button and panel.get_action_anchor("empty_module",id)==c.equip_button,tag+": stable anchors "+id)
		verify(not c.fields.title.get_rect().intersects(c.fields.level.get_rect()),tag+": title/level separated "+id)
		if c.equip_button.visible:
			verify(c.fields.level.get_rect().end.y<=c.equip_button.position.y and c.equip_button.get_rect().end.y<c.upgrade_button.position.y,tag+": empty slot actions do not overlap "+id)
		if c.fields.stat.visible:verify(c.fields.stat.get_rect().end.y<=c.upgrade_button.position.y,tag+": attribute/button separated "+id)
		for key in ["title","level","stat","cost"]:
			var l: Label=c.fields[key]
			if l.is_visible_in_tree():
				var width=l.get_theme_font("font").get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,l.get_theme_font_size("font_size")).x
				verify(width<=l.size.x,tag+": complete text "+id+" "+key)
func run() -> void:
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
	scene.game.profile.cleared=range(1,60)
	scene.game.profile.highestLevel=60
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e6,"2":1e6}
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	await capture("01-initial-slots")
	card_checks("initial")
	# Exercise actual pointer targets on a free slot and its picker/confirmation.
	scene.game.unequip_slot("weapons",0)
	panel.refresh()
	await settle()
	await click(panel.get_action_anchor("empty_module","weapons_0"))
	verify(panel.detail_frame.visible and panel.picker_open,"free equip opens selection panel")
	var option=panel.slot_options.find("laser")
	panel.detail.slots.select(option)
	panel.detail.slots.item_selected.emit(option)
	var resources=scene.game.profile.resources.duplicate(true)
	await click(panel.get_action_anchor("equip_confirm","weapons_0"))
	verify(scene.game.slot_entry("weapons",0).key=="laser" and scene.game.profile.resources==resources,"confirm equips without resource cost")
	await settle()
	var level=int(scene.game.slot_entry("weapons",0).level)
	await click(panel.get_action_anchor("upgrade_action","weapons_0"))
	verify(int(scene.game.slot_entry("weapons",0).level)==level+1,"card upgrade pointer applies exactly once")
	await click(panel.cards.weapons_0,Vector2(90,20))
	await click(panel.get_action_anchor("module_detail"))
	verify(panel.detail_frame.visible and panel.selected=="weapons_0","card selection and inspector remain accessible")
	panel.detail_frame.hide()
	await click(panel.get_action_anchor("swap_module"))
	option=panel.slot_options.find("cannon")
	panel.detail.slots.select(option)
	panel.detail.slots.item_selected.emit(option)
	await click(panel.get_action_anchor("equip_confirm","weapons_0"))
	verify(scene.game.slot_entry("weapons",0).key=="cannon","refit confirmation preserves action routing")
	for i in [1,2,0]:
		await click(panel.amount_buttons[i])
		verify(panel.upgrade_amount==[1,10,0][i],"quantity button routing "+str(i))
	await click(panel.get_action_anchor("gems"))
	verify(scene.jewel_panel.visible and scene.jewel_panel.category=="weapons" and scene.jewel_panel.equipment_index==0,"gem overlay opens the selected module")
	scene.jewel_panel.hide()
	# Five hulls: preserve active/dormant semantics without rebuilding cards.
	var instances=panel.cards.duplicate()
	var hulls=scene.db.ships.keys()
	hulls.reverse()
	for hull in hulls:
		scene.game.switch_ship(hull)
		panel.refresh()
		await settle()
		for id in panel.cards:
			if instances.has(id):verify(is_same(instances[id],panel.cards[id]),"card retained across hull change "+hull+" "+id)
			else:instances[id]=panel.cards[id]
			var item=panel.items[id]
			verify(item.locked==(item.index>=scene.game.active_slot_count(item.category)),"capacity lock "+hull+" "+id)
			if item.locked:verify(panel.cards[id].upgrade_button.disabled and not panel.cards[id].equip_button.visible,"dormant actions disabled "+hull+" "+id)
			if item.locked:verify(panel.cards[id].fields.status.visible and not panel.cards[id].fields.stat.visible and not panel.cards[id].fields.caption.visible,"dormant status has its own row "+hull+" "+id)
	scene.game.switch_ship("Heavy_Battleship")
	for i in 8:scene.game.equip_slot("weapons",i,BattleGame.WEAPON_KEYS[i%4])
	for i in 4:scene.game.equip_slot("defence",i,BattleGame.DEFENSE_KEYS[i%2])
	panel.refresh()
	scene.refresh_draw_layers(0)
	await capture("02-heavy-normal")
	card_checks("full")
	verify(panel.cards.size()==12,"full heavy hull exposes all 12 slots")
	scene.writes.clear()
	panel.refresh()
	verify(scene.writes.is_empty(),"unchanged panel refresh performs no set_ui_value writes")
	scene.game.injected=true
	scene.game.profile.resources={"1":9.9e19,"2":9.9e19}
	for category in ["weapons","defence"]:
		for i in scene.game.active_slot_count(category):scene.game.module_entry(category,i).level=10000000
	panel.refresh()
	scene.refresh_draw_layers(0)
	await capture("03-heavy-large")
	card_checks("large")
	for id in panel.cards:verify(panel.cards[id].fields.stat.text=="99Qi" and panel.cards[id].fields.cost.text.contains("99Qi"),"shared quantity format "+id)
	var normal_columns=panel.grid.columns
	root.size=Vector2i(960,540)
	await settle()
	verify(panel.grid.columns<normal_columns,"narrow viewport reduces both category columns")
	await capture("04-narrow-top")
	card_checks("narrow")
	panel.grid_scroll.scroll_vertical=9999
	await settle()
	verify(panel.grid_scroll.get_global_rect().intersects(panel.cards.defence_3.get_global_rect()),"last defence slot reachable by scrolling")
	await click(panel.cards.defence_3,Vector2(90,20))
	verify(panel.selected=="defence_3","last slot remains clickable after scrolling")
	await capture("05-narrow-bottom")
	var f=FileAccess.open("res://../unified-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"evidence":evidence,"checks":checks},"\t"))
	var failures=checks.filter(func(c):return not c["pass"])
	print("UNIFIED_CARDS ",checks.size()," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
