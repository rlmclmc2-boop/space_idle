extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const PlayerInput=preload("res://qa/player_input.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func select_popup(ui,menu:PopupMenu,index:int)->bool:
	for attempt in menu.item_count+1:
		if menu.get_focused_item()==index:return await ui.popup_choice(menu,index)
		if not await ui.popup_focus_step(menu,index):return false
	return false
func run()->void:
	root.size=Vector2i(1373,883)
	root.grab_focus()
	var g=Game.new(ShipDatabase.new())
	var driver=Driver.new();driver.ui_refresh_seconds=1.0;driver.setup(self,g)
	var ui=PlayerInput.new();ui.setup(driver.scene,self)
	g.start(1,false);g.paused=false;g.pending_unlocks.clear()
	await process_frame;await process_frame
	var panel=driver.scene.equipment_panel
	var button=panel.cards["defence_0"].upgrade_button
	g.profile.resources["1"]=0;panel.refresh()
	var budget:=float(g.slot_upgrade_cost("defence",0)["1"])+7.0
	g.profile.resources["1"]=budget
	check(g.can_upgrade_slot("defence",0),"Fixture budget meets live authored cost")
	driver.after_tick(1.0/60.0)
	check(button.disabled,"Reproduce legacy one-second throttle stale disabled")
	var level:int=g.slot_entry("defence",0).level
	check(not await ui.press(button),"Stale disabled button cannot dispatch actual input")
	check(g.slot_entry("defence",0).level==level and g.profile.resources["1"]==budget,"Rejected disabled input does not spend")
	driver.ui_refresh_seconds=0.0;driver.production_ui_ticks=true;driver.after_tick(1.0/60.0)
	check(not button.disabled,"Production per-tick refresh enables same resources and same control")
	check(await ui.press(button),"Actual native input hits enabled upgrade control")
	check(g.slot_entry("defence",0).level==level+1 and g.profile.resources["1"]==7,"Actual upgrade result72to7, level1to2")
	var picker=panel.cards["weapons_1"].name_button
	check(await ui.press(picker),"Actual mouse opens native refit popup")
	var menu=picker.get_popup()
	check(menu.visible and not ui.modal_windows().is_empty(),"Native modal detected")
	g.profile.resources["1"]=93
	var drop={"uid":999999,"x":250.0,"y":100.0,"age":0.0,"id":"1","amount":141.0,"speed":40.0}
	g.drops.append(drop)
	check(driver.scene.resource_input_blocked(),"Production blocks pickup during popup")
	check(ui.pickup_point(drop)==null and not await ui.pickup(drop),"No popup pickup passthrough")
	check(g.profile.resources["1"]==93 and g.drops.has(drop),"Modal keeps141drop and93balance untouched")
	check(not await ui.press(driver.scene.system_nav_buttons[7]),"Modal prevents background navigation")
	check(await select_popup(ui,menu,panel.cards["weapons_1"].equipment_options.find("laser")),"Actual popup item input closes selection")
	check(g.slot_entry("weapons",1).key=="laser","Actual popup selection equips requested distinct option")
	check(not menu.visible,"Popup selection resolves before other actions")
	await process_frame
	var outside={"uid":999998,"x":250.0,"y":950.0,"age":0.0,"id":"1","amount":500.0,"speed":40.0}
	g.drops.append(outside)
	check(ui.pickup_point(outside)==null,"Logical drop outside actual clipped viewport is unavailable")
	var point=ui.pickup_point(drop)
	if point==null:printerr("PICKUP DIAGNOSTIC blocked=",driver.scene.resource_input_blocked()," focus=",root.has_focus()," help=",driver.scene.help_open," pending=",g.pending_unlocks," battle=",driver.scene.battle_layer.visible," point=",driver.scene.battle_layer.get_global_transform_with_canvas()*driver.scene.drop_render_position(drop)," field=",driver.scene.battle_clip.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,driver.scene.battle_clip.size))
	check(point!=null,"After popup, actual viewport drop becomes reachable")
	check(await ui.pickup(drop),"Production motion handler collects reachable drop")
	check(g.profile.resources["1"]==234,"Pickup93to234 only after popup dismissal")
	check(await ui.press(driver.scene.system_nav_buttons[7]),"Actual navigation input after popup")
	check(driver.scene.equipment_tabs.current_tab==7,"Actual nav changes visible page")
	check(not await ui.press(button),"Hidden equipment control cannot dispatch")
	check(g.drops.has(outside),"Offscreen drop remains uncollected")
	# Separate synthetic UI fixture: expose earned pages to verify the actual
	# hull and allocation controls. This is not a progression/balance run.
	g.profile.highestLevel=61;g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear()
	driver.scene.refresh_tab_visibility();driver.scene.refresh_navigation()
	check(await ui.press(driver.scene.system_nav_buttons[3]),"Actual ship-page navigation")
	var ships=driver.scene.ship_controls.page
	var old_slots:int=g.active_slot_count("weapons")+g.active_slot_count("defence")
	var target:=""
	for key in ships.choices:
		if g.active_slot_count("weapons",key)+g.active_slot_count("defence",key)>old_slots and ui.available(ships.choices[key]) and ui.clipped_rect(ships.choices[key]).size.y>2:
			target=key;break
	check(not target.is_empty(),"Larger earned hull has an exposed choice")
	if not target.is_empty():
		check(await ui.press(ships.choices[target]),"Select larger hull through its actual choice")
		check(await ui.press(ships.confirm),"Confirm hull through its actual button")
		check(g.profile.selectedShip==target and g.active_slot_count("weapons")+g.active_slot_count("defence")>old_slots,"Actual confirmation adds module slots")
	driver.before_tick(1.0/60.0);driver.after_tick(1.0/60.0)
	g.profile.scientists=5;g.profile.scientistAssignments={}
	check(await ui.press(driver.scene.system_nav_buttons[1]),"Actual workshop navigation after new slots")
	driver.after_tick(1.0/60.0)
	check(await ui.press(driver.scene.hightech_page.distribute),"Actual scientist redistribute button after new slots")
	check(g.idle_scientists()==0,"Actual redistribution assigns fixture scientists")
	g.profile.reactorLevel=3;g.profile.reactorAllocation={"weapons":0,"defence":0,"smelting":0,"condensation":0}
	check(await ui.press(driver.scene.system_nav_buttons[2]),"Actual reactor navigation after new slots")
	driver.after_tick(1.0/60.0)
	check(await ui.press(driver.scene.reactor_panel.equalize_button),"Actual reactor reallocation button")
	check(g.reactor_allocated()==floori(g.reactor_capacity()),"Actual reallocation uses current capacity")
	for viewport_size in [Vector2i(1373,883),Vector2i(960,540)]:
		root.size=viewport_size;await process_frame;await process_frame
		for target_key in ["laser","missile","cannon","longLaser"]:
			var gate:int=int(g.db.data.unlock[g.db.unlock_id("equipment",target_key)].level)
			var fresh_game=Game.new(g.db)
			g.profile=fresh_game.profile.duplicate(true)
			var saved:Dictionary=fresh_game.portable_save_data()
			saved.merge({"highestLevel":gate+1,"cleared":range(1,gate+1),"grantedUnlocks":[]},true)
			g.load_progress_data(saved)
			g.start(1,false);g.pending_unlocks.clear();g.paused=false
			driver.scene.ui_rebuild_pending=true;driver.before_tick(1.0/60.0);driver.after_tick(1.0/60.0)
			await process_frame;await process_frame
			if driver.scene.equipment_tabs.current_tab!=0:check(await ui.press(driver.scene.system_nav_buttons[0]),"Return to actual equipment page")
			var card=driver.scene.equipment_panel.cards["weapons_0"]
			var index:int=card.equipment_options.find(target_key)
			check(index>=0,"Earned menu includes "+target_key)
			check(await ui.press(card.name_button),"Open "+target_key+" menu at "+str(viewport_size))
			var selected_ok:bool=await select_popup(ui,card.name_button.get_popup(),index)
			print("LONG MENU ",viewport_size," target=",target_key," options=",card.equipment_options," selected=",card.name_button.selected," key=",g.slot_entry("weapons",0).key," gate=",ui.last_gate)
			check(selected_ok and g.slot_entry("weapons",0).key==target_key,"Actual item selection "+target_key+" at "+str(viewport_size))
	# Synthetic native menu: separators, disabled rows, large fonts and scroll.
	for viewport_size in [Vector2i(1373,883),Vector2i(960,540)]:
		root.size=viewport_size;await process_frame;await process_frame
		var picker_fixture:=OptionButton.new()
		picker_fixture.position=Vector2(25,25);picker_fixture.size=Vector2(180,45)
		root.add_child(picker_fixture)
		picker_fixture.add_item("First",101);picker_fixture.add_separator("Group")
		picker_fixture.add_item("Disabled",202);picker_fixture.set_item_disabled(2,true)
		for n in 9:picker_fixture.add_item("Item "+str(n),300+n)
		var native_menu:=picker_fixture.get_popup()
		native_menu.add_theme_font_size_override("font_size",32)
		native_menu.add_theme_constant_override("v_separation",18)
		native_menu.max_size=Vector2i(300,180)
		await process_frame;await process_frame
		check(await ui.press(picker_fixture),"Open large-font scrolling native menu "+str(viewport_size))
		check(not await ui.popup_choice(native_menu,11) and native_menu.visible,"Mismatched native focus refuses activation")
		check(not await ui.popup_focus_step(native_menu,2),"Disabled target refuses focus gesture")
		check(not await ui.popup_focus_step(native_menu,1),"Separator target refuses focus gesture")
		check(await select_popup(ui,native_menu,11),"Native navigation skips separator/disabled and scrolls to last item")
		check(picker_fixture.selected==11 and picker_fixture.get_selected_id()==308,"Actual selection preserves authored ID mapping")
		picker_fixture.queue_free();await process_frame
	var guard=PlayerInput.ProgressGuard.new()
	check(not guard.observe("selection/request/loadout",false),"First failure keeps diagnostic retry")
	check(not guard.observe("open/request/loadout",true),"Opening a popup is not failed selection progress")
	check(not guard.observe("selection/request/loadout",false),"Second same-state failure keeps bounded retry")
	check(guard.observe("selection/request/loadout",false),"Third repeated failure stops invalid route")
	check(not guard.observe("selection/request/loadout",true) and not guard.observe("selection/request/loadout",false),"Actual effect resets only its request failure count")
	print("INPUT REACHABILITY: ",checks," checks, ",failures," failures")
	driver.close();await process_frame;quit(1 if failures else 0)
