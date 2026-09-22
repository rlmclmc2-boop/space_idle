extends SceneTree
var checks := 0
var failures := 0
const F := BattleGame.FURNACE
const E := BattleGame.ENERGY_FOCUS
const A := BattleGame.DENSE_ARMOUR
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	db.config.scientistCost="1.3,1|100,2|10"
	db.config.techPointGet=1
	db.config.hightechLimit=0.8
	for row in db.data.hightech.values():
		row.tpCostBase=10
		row.tpCostMutiple=0.2
	var g := BattleGame.new(db,false)
	check(g.hightech_level(F)==0 and g.hightech_level(E)==0 and g.hightech_level(A)==0,"All tech starts at zero")
	check(g.equipment_stat("laser",1)==float(db.equip("laser",1).dmg) and g.equipment_stat("shield",1)==float(db.equip("shield",1).para1),"Zero level has no stat effects")
	check(g.hightech_description(E)=="未研发，无效果","Zero-level description explicitly states no effect")
	check(not g.generate_scientist(),"Locked page cannot generate scientists")
	g.profile.cleared=db.data.hightech.keys().map(func(key):return int(db.unlock_row("hightech",key).level))
	check(not g.generate_scientist(),"Insufficient resources rejected")
	g.profile.resources={"1":10000.0,"2":1000.0}
	check(g.scientist_cost()=={"1":100.0,"2":10.0},"First scientist costs base")
	check(g.generate_scientist() and g.profile.resources["1"]==9900 and g.profile.resources["2"]==990,"All currencies charged together")
	check(g.scientist_cost()=={"1":130.0,"2":13.0},"Second cost multiplies base")
	g.generate_scientist()
	check(g.scientist_cost()=={"1":169.0,"2":17.0},"Third cost compounds and rounds half up")
	g.generate_scientist()
	check(g.assign_scientist(F,1) and g.assign_scientist(E,1) and g.assign_scientist(A,1),"All technologies research simultaneously")
	check(not g.assign_scientist(F,1) and g.idle_scientists()==0,"Cannot overallocate")
	check(g.research_rate(F)==1,"One scientist basic rate")
	g.advance_hightech(5)
	check(g.profile.techPoints[F]==5 and g.profile.techPoints[E]==5,"Parallel point accumulation")
	g.assign_scientist(F,-1)
	g.assign_scientist(E,1)
	check(g.research_rate(E)==2,"Multiple scientists use rounded power")
	g.advance_hightech(5)
	check(g.profile.techPoints[F]==5 and g.hightech_level(F)==0,"Withdrawal preserves progress")
	check(g.hightech_level(E)==1 and g.profile.techPoints[E]==5,"Surplus points enter next level")
	check(g.hightech_required(E)==12,"Point cost grows with level")
	check(g.hightech_level(A)==1,"Other assigned tech completes independently")
	g.assign_scientist(F,1)
	check(not g.assign_scientist(F,-1),"Cannot withdraw nonexistent assignment")
	var before: Dictionary = g.profile.techPoints.duplicate(true)
	g.paused=true
	g.tick(2)
	check(g.profile.techPoints==before,"Pause freezes research")
	g.paused=false
	g.profile.scientists=10
	g.profile.scientistAssignments={E:10}
	check(g.research_rate(E)==6,"Ten scientists decay and round to six points")
	g.profile.hightechSavedAt=Time.get_unix_time_from_system()
	g.save_enabled=true
	g.save_progress()
	var loaded := BattleGame.new(db)
	loaded.save_enabled=false
	check(loaded.profile.scientists==10 and loaded.assigned_scientists(E)==10 and loaded.hightech_level(E)==1,"Save reload restores new system")
	var offline: Dictionary = g.profile.duplicate(true)
	offline.hightechSavedAt=Time.get_unix_time_from_system()-20
	offline.hightechLevels={}
	offline.techPoints={}
	offline.scientistAssignments={E:1}
	offline.scientists=1
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(offline))
	file.close()
	var resumed := BattleGame.new(db)
	resumed.save_enabled=false
	check(resumed.hightech_level(E)==1 and absf(float(resumed.profile.techPoints[E])-10)<0.5,"Offline advances assigned research at real one-times rate")
	var legacy := g.profile.duplicate(true)
	legacy.erase("hightechVersion")
	legacy.hightechResearch={F:{"remaining":1,"duration":60}}
	var old := BattleGame.new(db,false)
	old.load_hightech(legacy)
	check(old.hightech_level(E)==0 and old.profile.scientists==0 and old.profile.techPoints.values().all(func(value):return value==0),"Old hightech progress discarded")
	check(not old.profile.has("hightechResearch"),"Old timer schema removed")
	# Preserve still-current effect/description coverage from the retired timer tests.
	var effects := BattleGame.new(db,false)
	effects.player.armour=17
	effects.player.shield=7
	effects.profile.hightechLevels={E:3,A:3}
	for key in ["laser","cannon","missile"]:
		check(effects.equipment_stat(key,1)==ceilf(float(db.equip(key,1).dmg)*pow(1.0+float(db.data.hightech[E].para1),3)),"All weapons retain compound research effect: "+key)
	for key in ["armour","shield"]:
		check(effects.equipment_stat(key,1)==ceilf(float(db.equip(key,1).para1)*pow(1.0+float(db.data.hightech[A].para1),3)),"Both defences retain compound research effect: "+key)
	check(effects.player.armour==17 and effects.player.shield==7,"Research effects do not refill current defence")
	effects.reset_player()
	check(effects.player.armour==effects.stat("armour"),"Recovery uses enhanced maximum")
	var row := {"para1":30,"para2":0.5}
	check(effects.format_description(row,"para1 / para2 / {para1*(等级+1),向上取整}",2)=="30 / 0.5 / 90","Description repeated tokens and arithmetic")
	check(effects.format_description(row,"{1/2}",1)=="0.5","Description retains fractional division")
	check(effects.format_description(row,"{load(1)}",1)=="？","Description rejects function calls")
	check(effects.format_description(row,"{1.003,百分比显示,保留两位小数,即100.3%展示为100%}",1)=="100%","Description percentage truncates")
	check(effects.format_description(row,"{（1+0.1）^等级,百分比显示}",3)=="130%","Description power preserves compact percentage formatting")
	var capped := BattleGame.new(db,false)
	capped.profile.cleared=g.profile.cleared.duplicate()
	capped.profile.scientists=1
	capped.profile.scientistAssignments={E:1}
	var capped_raw := capped.profile.duplicate(true)
	capped_raw.hightechSavedAt=Time.get_unix_time_from_system()-1000
	db.config.offlineMax=0.01
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(capped_raw))
	file.close()
	capped=BattleGame.new(db)
	check(capped.hightech_level(E)==3 and absf(float(capped.profile.techPoints[E]))<0.001,"Offline cap crosses exact research completion boundaries")
	var capped_again := BattleGame.new(db)
	check(capped_again.hightech_level(E)==3 and float(capped_again.profile.techPoints[E])<0.5,"Reload cannot claim the offline interval twice")
	db.config.offlineMax=0
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(capped_raw))
	file.close()
	capped=BattleGame.new(db)
	check(capped.hightech_level(E)==0 and float(capped.profile.techPoints.get(E,0))==0,"Zero offline cap disables research")
	var bulk := BattleGame.new(db,false)
	bulk.profile.cleared=g.profile.cleared.duplicate()
	bulk.profile.resources={"1":100000.0,"2":10000.0}
	var singles := BattleGame.new(db,false)
	singles.profile=bulk.profile.duplicate(true)
	for i in range(10):
		singles.generate_scientist()
	check(bulk.generate_scientist(10) and bulk.profile.resources==singles.profile.resources,"Ten purchase equals ten sequential rounded costs")
	check(bulk.generate_scientist(-1) and not bulk.can_generate_scientist(),"MAX consumes all affordable purchases")
	var balance: Dictionary = bulk.profile.resources.duplicate(true)
	check(not bulk.generate_scientist(10) and bulk.profile.resources==balance,"Unaffordable ten purchase is atomic")
	bulk.profile.scientists=11
	bulk.profile.scientistAssignments={}
	check(bulk.assign_scientist(F,10) and bulk.assigned_scientists(F)==10,"Assign ten")
	check(bulk.assign_scientist(E,10) and bulk.assigned_scientists(E)==1,"Assign ten clamps to idle")
	bulk.profile.techPoints={F:3.0}
	check(bulk.distribute_scientists() and bulk.assigned_scientists(F)==4 and bulk.assigned_scientists(E)==4 and bulk.assigned_scientists(A)==3 and bulk.idle_scientists()==0,"Redistribution preserves all scientists and deterministic remainder")
	check(bulk.profile.techPoints[F]==3,"Redistribution preserves research")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile=scene.game.fresh_profile()
	scene.game.profile.cleared=[]
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(2),"Hightech page remains hidden before unlock")
	scene.game.profile.cleared=db.data.hightech.keys().map(func(key):return int(db.unlock_row("hightech",key).level))
	scene.game.profile.resources={"1":10000.0,"2":1000.0}
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	check(scene.scientist_distribute_button.disabled,"Zero scientists disables distribution")
	var first_cost_text: String = scene.scientist_cost_label.text
	for id in scene.game.scientist_cost():
		check(first_cost_text.contains("%s %s" % [scene.db.data.resources[id],scene.number(scene.game.scientist_cost()[id])]),"Visible generation cost includes resource and amount")
	scene.scientist_generate_button.pressed.emit()
	await process_frame
	check(not scene.scientist_distribute_button.disabled and scene.scientist_cost_label.text!=first_cost_text,"Generation refreshes visible cost and enables distribution")
	scene.hightech_buttons[F].pressed.emit()
	await process_frame
	check(not scene.scientist_distribute_button.disabled,"Fully assigned scientists can still be redistributed")
	scene.scientist_distribute_button.pressed.emit()
	await process_frame
	check(scene.game.assigned_scientists(F)==1 and scene.game.idle_scientists()==0,"Distribution button redistributes existing scientists")
	scene.game.advance_hightech(5)
	scene.refresh_hightech_progress(F)
	check(scene.game.assigned_scientists(F)==1 and scene.hightech_progress[F].label.text.contains("点/秒"),"UI generates and assigns scientist with point progress")
	scene.scientist_remove_buttons[F].pressed.emit()
	await process_frame
	check(scene.game.idle_scientists()==1 and scene.game.profile.techPoints[F]==5,"UI withdrawal preserves points")
	await process_frame
	scene.scientist_bulk_buttons[10].pressed.emit()
	await process_frame
	check(scene.game.profile.scientists==11,"UI ten generation button")
	scene.scientist_assignment_buttons[F][0].pressed.emit()
	await process_frame
	check(scene.game.assigned_scientists(F)==10,"UI ten assignment button")
	scene.scientist_assignment_buttons[F][1].pressed.emit()
	await process_frame
	check(scene.game.assigned_scientists(F)==11,"UI MAX assignment button")
	scene.game.profile.techPoints[F]=scene.game.hightech_required(F)*0.5
	scene.game.paused=true
	scene.refresh_hightech_progress(F)
	var progress: Dictionary=scene.hightech_progress[F]
	check(is_equal_approx(progress.bar.get_child(0).size.x,progress.bar.size.x*0.5) and progress.label.text.contains("50%"),"Point progress fills half the bar and agrees with percentage")
	check(progress.bar.get_child(0).color==scene.ORANGE,"Paused research bar stays orange")
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==2 and scene.hightech_progress[F].label.text.contains("50%"),"Rebuild retains selected tab and point progress")
	for key in scene.hightech_progress:
		var controls: Dictionary=scene.hightech_progress[key]
		check(controls.bar.position.y+controls.bar.size.y<=112 and controls.bar.position.x+controls.bar.size.x<scene.hightech_buttons[key].position.x,"Research bar fits before the action button")
	scene.db.data.hightech[F].description="界面模板 {等级}"
	scene.game.profile.hightechLevels[F]=2
	scene._process(0)
	check(scene.hightech_descriptions[F].text=="界面模板 2" and scene.hightech_descriptions[F].tooltip_text=="界面模板 2","UI refresh reads description and updates tooltip without rebuild")
	var description: Label=scene.hightech_descriptions[F]
	check(description.size.x<=423 and description.get_rect().end.y<=79,"Description stays within its card")
	check(scene.equipment_tabs.get_rect().end.y<=778,"Research cards stay above footer")
	check(scene.scientist_distribute_button.get_rect().end.y<=scene.scientist_cost_label.position.y and scene.scientist_cost_label.get_rect().end.y<=scene.scientist_generate_button.position.y,"Visible cost fits between distribution and generation buttons")
	scene.game.event.emit("hightech_complete",{"key":F})
	check(scene.message==F+"研发完成","Completion event retains its toast")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scientists.png")
	print("Scientists: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
