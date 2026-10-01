extends SceneTree
const Tab = preload("res://scripts/equipment_tab.gd")
class ObservedTab extends Tab:
	var attribute_calls := 0
	var height_calls := 0
	func equipment_attributes(entry: Dictionary) -> String:
		attribute_calls+=1
		return super.equipment_attributes(entry)
	func update_detail_height(force := false) -> void:
		if force or (is_instance_valid(detail_frame) and detail_frame.is_visible_in_tree()):height_calls+=1
		super.update_detail_height(force)
class EagerTab extends ObservedTab:
	func refresh_detail(next_projection: Dictionary = {}, _force := false) -> void:super.refresh_detail(next_projection,true)
	func update_detail_height(_force := false) -> void:super.update_detail_height(true)
	func refresh_affordability_detail() -> void:
		if not items.has(selected):return
		var item: Dictionary=items[selected]
		for action in ["upgrade","ten","max"]:
			host.set_ui_value(detail[action],"disabled",not host.game.can_upgrade_slot(item.category,item.index,10 if action=="ten" else 1))
	func refresh_stats() -> void:
		var selected_changed := false
		var selected_preview: Dictionary={}
		for id in stats_dirty:
			if not items.has(id):continue
			var item: Dictionary = items[id]
			var entry: Dictionary = host.game.module_entry(item.category,item.index)
			var projection: Dictionary=host.equipment_display_snapshot(entry)
			var value = projection.expected
			var projection_changed: bool=item.projection!=projection
			if selected==id and not item.key.is_empty():
				selected_preview=host.equipment_display_snapshot(entry,mini(int(entry.level)+1,host.db.max_equipment_level(item.key)))
				selected_changed = selected_changed or GrowthNumber.compare(selected_preview.expected,selected_next_stat)!=0
				selected_changed = selected_changed or projection_changed
			if GrowthNumber.compare(value,item.mainStatNumber)==0 and not projection_changed:continue
			item.projection=projection
			item.tooltip=module_tooltip(entry,("W" if item.category=="weapons" else "D")+str(int(item.index)+1).pad_zeros(2),host.NAMES.get(item.key,UIText.t("equipment.vacant")),projection)
			item.mainStatNumber = value
			item.mainStatValue = host.number(value) if not item.key.is_empty() else "—"
			# A damage/probability-only event leaves its already quoted upgrade cost valid.
			cards[id].refresh(item,selected==id)
			sort_dirty = sort_dirty or sort_mode==2
			selected_changed = selected_changed or selected==id
		stats_dirty.clear()
		if sort_dirty:apply_filters()
		if selected_changed:refresh_detail(selected_preview)

class UI extends "res://scripts/battlefield.gd":
	var preview_calls := 0
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func show_chrono_login_report() -> void:pass
	func equipment_display_snapshot(entry: Dictionary, level := -1) -> Dictionary:
		if level>=0:preview_calls+=1
		return super.equipment_display_snapshot(entry,level)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(eager: bool):
	var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
	scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene);scene.set_process(false)
	var old=scene.equipment_panel
	scene.equipment_tabs.remove_child(old);old.queue_free()
	var panel=EagerTab.new() if eager else ObservedTab.new()
	panel.name="Equipment";scene.equipment_panel=panel
	scene.equipment_tabs.add_child(panel);scene.equipment_tabs.move_child(panel,0);panel.setup(scene)
	var g=scene.game
	g.speed=1;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":1e40,"2":1e40};g.profile.jewelFragments=1e40;g.profile.enhancementLevel=30
	g.profile.loadout={"weapons":[],"defence":[]}
	for key in ["laser","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
	for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
	g.profile.crew=g.profile.crew.filter(func(member):return g.crew.unlocked(g,str(member.crewId))).slice(0,13)
	g.profile.planets["1"].conquered=true;g.planet_buildings.sync(g,"1")
	for building in g.profile.planets["1"].buildings.values():building.status="built"
	g.invalidate_stat_cache();g.reset_player();g.rng.seed=1701
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0);panel.set_upgrade_amount(1)
	return scene
func controls(node, skip):
	if node==skip:return null
	var row={"children":[]}
	if node is Control:row.visible=node.visible;row.tooltip=node.tooltip_text;row.modulate=node.modulate
	if node is Label or node is Button or node is RichTextLabel:row.text=node.text
	if node is BaseButton:row.disabled=node.disabled;row.pressed=node.button_pressed
	if node is OptionButton:
		row.selected=node.selected;row.options=[]
		for i in node.item_count:row.options.append([node.get_item_text(i),node.is_item_disabled(i)])
	for child in node.get_children():row.children.append(controls(child,skip))
	return row
func compare(a,b,label: String,opened: bool):
	var x=a.game.profile.duplicate(true);var y=b.game.profile.duplicate(true)
	x.erase("hightechSavedAt");y.erase("hightechSavedAt")
	check(x==y and a.game.player==b.game.player and a.game.rng.state==b.game.rng.state,label+" gameplay/RNG")
	check(a.equipment_panel.items==b.equipment_panel.items,label+" all card data")
	check(controls(a.equipment_panel,null if opened else a.equipment_panel.detail_frame)==controls(b.equipment_panel,null if opened else b.equipment_panel.detail_frame),label+" control output")
	if opened:check(a.equipment_panel.selected_next_stat==b.equipment_panel.selected_next_stat,label+" preview")
func _initialize() -> void:call_deferred("run")
func run():
	var a=fixture(true);var b=fixture(false);current_scene=b
	await process_frame
	compare(a,b,"initial closed",false)
	for action in ["planet","selection","upgrade","replace","enhancement","ship","stats","resources"]:
		for scene in [a,b]:
			var p=scene.equipment_panel;var g=scene.game
			p.detail_frame.hide();p.attribute_calls=0;p.height_calls=0;scene.preview_calls=0
			match action:
				"planet":
					g.profile.planets["1"].crewId="navigator";g.profile.planets["1"].elapsed=g.planet_duration("1")-1.0/120.0;g.advance_planets(1.0/60.0)
				"selection":p.select_item(g.slot_id("weapons",1))
				"upgrade":check(g.upgrade_slot("weapons",1,1),"upgrade +1 succeeds")
				"replace":check(g.equip_slot("weapons",1,"laser"),"replace succeeds")
				"enhancement":check(g.upgrade_enhancement(1)==1,"enhancement +1 succeeds")
				"ship":check(g.switch_ship(g.first_ship()),"ship change succeeds")
				"stats":g.record_enhancement_attack()
				"resources":g.profile.resources={"1":0.0,"2":0.0}
			p.refresh_pending()
		check(b.equipment_panel.attribute_calls==0 and b.preview_calls==0 and b.equipment_panel.height_calls==0,action+" hidden skips expensive detail work")
		check(b.equipment_panel.detail_dirty,action+" marked dirty")
		compare(a,b,action+" closed",false)
		for scene in [a,b]:scene.equipment_panel.show_inspector()
		compare(a,b,action+" first open",true)
		check(not b.equipment_panel.detail_dirty,action+" clean before draw")
		for scene in [a,b]:scene.game.record_enhancement_attack();scene.equipment_panel.refresh_pending()
		compare(a,b,action+" visible stats refresh",true)
	for scene in [a,b]:
		scene.equipment_panel.detail_frame.hide()
		scene.equipment_panel.open_picker(scene.game.slot_id("weapons",0))
	compare(a,b,"picker opens latest",true)
	for scene in [a,b]:
		scene.select_system(4);scene.game.record_enhancement_attack();scene.select_system(0);scene.equipment_panel.refresh_pending()
	compare(a,b,"page hide/reveal",true)
	for scene in [a,b]:
		scene.equipment_panel.toggle_details()
		scene.equipment_panel.detail_frame.hide()
		scene.game.record_enhancement_attack()
		scene.equipment_panel.show_inspector()
	compare(a,b,"collapsed inspector reopens latest",true)
	for scene in [a,b]:
		scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free()
	await process_frame;await process_frame
	print("LAZY EQUIPMENT INSPECTOR: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
