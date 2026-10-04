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
	check(await ui.popup_choice(menu,panel.cards["weapons_1"].equipment_options.find("laser")),"Actual popup item input closes selection")
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
	print("INPUT REACHABILITY: ",checks," checks, ",failures," failures")
	driver.close();await process_frame;quit(1 if failures else 0)
