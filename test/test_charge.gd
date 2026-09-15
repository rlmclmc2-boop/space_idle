extends SceneTree

var checks := 0
var failures := 0
const ATTACK := "攻击充能"
const DEFENCE := "防御充能"
const SMELT := "熔炼器充能"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	# Fixed cost fixture; growing costs have their own boundary regression.
	for row in db.data.charge.values():
		row.para_2=5
		row.para_5=1
		row.para_6=2
		row.para_7=0
	check(db.data.get("charge",{}).size()==3,"Three charge rows projected")
	var g := BattleGame.new(db,false)
	check(not g.toggle_charge(ATTACK) and g.charge_job(ATTACK).level==0,"Locked charge cannot start; starts at zero")
	g.profile.cleared=[1]
	g.profile.resources["2"]=1000.0
	for key in db.data.charge:
		check(g.toggle_charge(key),"All three can run together: "+key)
	g.advance_charge(2.5)
	check(g.profile.resources["2"]==961 and g.charge_job(ATTACK).elapsed==2.5 and g.charge_job(ATTACK).credit==0.5,"Integer debit retains already paid fractional charging time")
	g.profile.resources["2"]=15.0
	g.advance_charge(10)
	for key in db.data.charge:
		check(is_equal_approx(g.charge_job(key).elapsed,3.6) and g.charge_job(key).level==0,"Shortage shares whole resources equally: "+key)
	check(g.profile.resources["2"]==0,"Resources never become negative")
	g.advance_charge(100)
	check(is_equal_approx(g.charge_job(ATTACK).elapsed,3.6),"No resource preserves partial charge")
	g.profile.resources["2"]=21
	g.advance_charge(1.4)
	check(g.charge_job(ATTACK).level==1 and g.charge_job(ATTACK).count==0 and g.charge_job(ATTACK).elapsed==0,"Refill resumes to first level")
	g.profile.resources["2"]=1000.0
	g.advance_charge(5)
	check(g.charge_job(ATTACK).level==1 and g.charge_job(ATTACK).count==1,"Next level needs increased charge count")
	g.toggle_charge(ATTACK)
	g.advance_charge(5)
	check(g.charge_job(ATTACK).count==1 and g.charge_job(DEFENCE).level==2,"Manual pause preserves counts while other jobs advance")
	g.toggle_charge(ATTACK)
	g.advance_charge(5)
	check(g.charge_job(ATTACK).level==2,"Resume retains completed charge count")
	g.profile.charge.clear()
	g.toggle_charge(ATTACK)
	g.profile.resources["2"]=10000.0
	g.advance_charge(36.25)
	check(g.charge_job(ATTACK).level==3 and g.charge_job(ATTACK).count==0 and is_equal_approx(g.charge_job(ATTACK).elapsed,1.25),"Large step crosses geometric thresholds and retains remainder")
	check(g.charge_description(ATTACK)=="所有武器伤害提高133%","des rounds to integer percent rather than truncating significant digits")
	check(g.format_description({},"{1.003,百分比显示,保留两位小数,即100.3%展示为100%}",0)=="100%","Existing hightech percentage truncation remains unchanged")
	check(g.format_description({},"{1/2}",0)=="0.5","Shared description keeps fractional division")
	check(g.format_description({},"{load(1)} {1/0}",0)=="？ ？","Shared description rejects calls and arithmetic errors")
	check(g.format_description({},"{过去一分钟的铁生成量} / {过去一分钟的铁生成量,不含自身}",0,55,20)=="55 / 20","Shared description preserves per-expression income source")
	db.data.charge[ATTACK].para_3=0.105
	g.charge_job(ATTACK).level=1
	check(g.charge_description(ATTACK)=="所有武器伤害提高111%","Percentage midpoint rounds up")
	db.data.charge[ATTACK].para_3=0.1
	g.charge_job(ATTACK).level=3
	# stat() totals installed slots; unlocking alone leaves those slots empty.
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	check(g.equip_slot("weapons",1,"cannon"),"Install cannon for charge effect")
	check(g.equip_slot("weapons",2,"missile"),"Install missile for charge effect")
	check(g.equip_slot("defence",1,"shield"),"Install shield before measuring defence bonus")
	for key in ["laser","cannon","missile"]:
		check(g.stat(key)==ceilf(float(db.equip(key,1).dmg)*pow(1.1,3)),"All player weapons receive attack multiplier: "+key)
	g.profile.hightechLevels[BattleGame.ENERGY_FOCUS]=2
	check(g.stat("laser")==ceilf(ceilf(float(db.equip("laser",1).dmg)*pow(1+float(db.data.hightech[BattleGame.ENERGY_FOCUS].para1),2))*pow(1.1,3)),"Charge composes with existing hightech")
	var hp: float=g.player.armour
	var shield: float=g.player.shield
	g.charge_job(DEFENCE).level=2
	check(g.stat("armour")==ceilf(float(db.equip("armour",1).para1)*pow(1.1,2)) and g.max_shield()==ceilf(float(db.equip("shield",1).para1)*pow(1.1,2)),"Defence increases both capacities")
	check(g.player.armour==hp and g.player.shield==shield,"Capacity bonus preserves current health and shield")
	g.charge_job(SMELT).level=2
	g.drops.clear()
	var enemy := {"hp":1.0,"armourType":0,"x":800.0,"y":400.0,"res_ratio":1.25,"drops":[{"resourceId":1,"amount":100.0,"chance":1.0},{"resourceId":2,"amount":100.0,"chance":1.0}]}
	g.hit_enemy(enemy,100,0)
	check(g.drops.size()==2 and g.drops[0].amount==152 and g.drops[1].amount==125,"Smelter multiplies only killed enemies' iron before rounding")
	g.drops.clear()
	db.config.autoGenRes="1,1,100,40"
	g.state=BattleGame.State.TRAVEL
	g.advance_auto_gen(1)
	check(g.drops.size()==1 and g.drops[0].amount==ceilf(100*g.ratio("resRatio")),"Smelter does not multiply auto-generated iron")
	g.drops.clear()
	g.state=BattleGame.State.MAIN_MENU
	g.profile.hightechLevels[BattleGame.FURNACE]=1
	g.profile.furnaceIncomePeak=100.0
	g.profile.furnaceElapsed=0.0
	g.advance_furnace(float(db.data.hightech[BattleGame.FURNACE].para1),Time.get_unix_time_from_system(),1.0)
	check(g.drops.size()==1 and g.drops[0].amount==ceilf(100*float(db.data.hightech[BattleGame.FURNACE].para2)),"Smelter does not multiply hightech furnace output")
	g.drops.clear()
	var saved_elapsed: float=g.charge_job(ATTACK).elapsed
	g.paused=true
	g.tick(10)
	check(g.charge_job(ATTACK).elapsed==saved_elapsed,"Pause freezes charging")
	g.paused=false
	g.profile.charge.clear()
	g.toggle_charge(ATTACK)
	g.speed=5
	g.tick(0.5) # main passes delta * speed to tick.
	check(g.charge_job(ATTACK).elapsed==0.5,"Charging follows simulation time")
	var immediate := BattleGame.new(db,false)
	immediate.profile.cleared=[1]
	immediate.profile.resources["2"]=100
	immediate.toggle_charge(ATTACK)
	immediate.save_enabled=true
	immediate.tick(0.5)
	var immediate_raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(float(immediate_raw.resources["2"])==97,"Charge resource debit is persisted immediately")
	# Actual save/load: integer resources and already paid charging time persist.
	g.profile.resources["2"]=10
	g.toggle_charge(ATTACK)
	g.save_enabled=true
	g.save_progress()
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.resources["2"]==10 and loaded.charge_job(ATTACK).elapsed==0.5 and loaded.charge_job(ATTACK).credit==0.5 and not loaded.charge_job(ATTACK).active,"Saved progress, pause and prepaid charging time survive reopen")
	loaded.profile.charge.clear()
	for key in db.data.charge:
		loaded.toggle_charge(key)
	loaded.profile.resources["2"]=150.0
	loaded.save_progress()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	raw.hightechSavedAt=Time.get_unix_time_from_system()-100
	raw.offlineRates={}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	loaded=BattleGame.new(db,true)
	check(loaded.profile.resources["2"]==0,"Offline charging consumes available resources")
	for key in db.data.charge:
		check(loaded.charge_job(key).level==1 and loaded.charge_job(key).count==1,"Offline shortage shares resources: "+key)
	db.config.offlineMax=1.0/3600.0
	loaded.profile.resources["2"]=100.0
	loaded.save_progress()
	raw=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	raw.hightechSavedAt=Time.get_unix_time_from_system()-100
	raw.offlineRates={}
	file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	loaded=BattleGame.new(db,true)
	check(loaded.profile.resources["2"]==85 and loaded.charge_job(ATTACK).elapsed==1,"Offline charge shares existing offlineMax cap at real-time speed")
	var legacy := BattleGame.new(db,false)
	legacy.load_charge({})
	check(legacy.charge_job(ATTACK).level==0 and not legacy.charge_job(ATTACK).active,"Old saves initialize charge at zero and inactive")
	var order_game := BattleGame.new(db,false)
	order_game.profile.cleared=[1]
	for key in [DEFENCE,SMELT,ATTACK]:
		order_game.toggle_charge(key)
	order_game.profile.resources["2"]=1
	order_game.advance_charge(1)
	check(order_game.charge_job(DEFENCE).elapsed==0.2 and order_game.charge_job(SMELT).elapsed==0 and order_game.charge_job(ATTACK).elapsed==0,"Last one resource goes to first started job rather than first table row")
	order_game.profile.resources["2"]=5
	order_game.advance_charge(1)
	check(is_equal_approx(order_game.charge_job(DEFENCE).elapsed,0.6) and order_game.charge_job(SMELT).elapsed==0.4 and order_game.charge_job(ATTACK).elapsed==0.2,"Equal integer shares distribute remainder in activation order")
	order_game.save_enabled=true
	order_game.save_progress()
	var order_raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	var restored := BattleGame.new(db,false)
	restored.profile.cleared=[1]
	restored.load_charge(order_raw)
	restored.profile.resources["2"]=1
	restored.advance_charge(1)
	check(is_equal_approx(restored.charge_job(DEFENCE).elapsed,0.8),"Saved activation order preserves remainder priority")
	var fine := BattleGame.new(db,false)
	fine.profile.cleared=[1]
	fine.toggle_charge(ATTACK)
	fine.profile.resources["2"]=100
	for i in range(100):
		fine.advance_charge(0.01)
	check(fine.profile.resources["2"]==95 and is_equal_approx(fine.charge_job(ATTACK).elapsed,1),"Small frames do not round up per-frame resource costs")
	# UI uses actual controls and remains on the selected tab after rebuilding.
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.game.save_enabled=false
	for row in scene.db.data.charge.values():
		row.para_2=5
		row.para_5=1
		row.para_6=2
		row.para_7=0
	scene.game.profile.cleared=[1]
	scene.game.profile.charge.clear()
	scene.game.profile.resources["2"]=30.0
	scene.build_ui()
	scene.equipment_tabs.current_tab=3
	check(scene.charge_cards.size()==3 and scene.equipment_tabs.get_tab_title(3)=="充能","Charge tab contains three cards")
	for key in db.data.charge:
		scene.charge_cards[key].button.pressed.emit()
	scene.game.advance_charge(10)
	scene._process(0)
	check(scene.charge_cards[ATTACK].status.text=="资源不足" and scene.charge_cards[ATTACK].progress.text.contains("2/5秒"),"Card shows retained progress and resource wait")
	check(is_equal_approx(scene.charge_cards[ATTACK].charge_bar.get_child(0).size.x,303*0.4) and is_equal_approx(scene.charge_cards[ATTACK].level_bar.get_child(0).size.x,303*0.4),"Bars show current charge and total level progress during shortage")
	scene.build_ui()
	check(scene.equipment_tabs.current_tab==3,"UI rebuild preserves charge tab")
	scene.game.charge_job(ATTACK).level=3
	scene._process(0)
	check(scene.charge_cards[ATTACK].description.text=="所有武器伤害提高133%","Live description uses des and current level")
	scene.game.charge_job(ATTACK).count=3
	scene.refresh_charge_card(ATTACK)
	check(is_equal_approx(scene.charge_cards[ATTACK].level_bar.get_child(0).size.x,303*3.4/8.0),"Level bar includes completed charges and the current partial charge")
	scene.charge_cards[ATTACK].button.pressed.emit()
	check(scene.charge_cards[ATTACK].status.text=="已暂停" and is_equal_approx(scene.charge_cards[ATTACK].charge_bar.get_child(0).size.x,303*0.4),"Pause retains progress bars")
	scene.game.profile.resources["2"]=100
	scene.refresh_charge_card(DEFENCE)
	check(scene.charge_cards[DEFENCE].status.text=="充能中","Resource refill clears waiting status")
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(scene.charge_cards[ATTACK].charge_bar.size.y==6 and scene.charge_cards[ATTACK].level_bar.size.y==6,"Progress bars retain compact height without overlapping labels")
	root.get_texture().get_image().save_png("res://charge.png")
	print("Charge: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
