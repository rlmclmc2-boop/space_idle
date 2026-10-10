extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(message)

func _initialize() -> void:
	var db:=ShipDatabase.new()
	db.config.offlineMax=0
	var g:=BattleGame.new(db,false)
	g.profile.cleared=range(1,60)
	g.profile.highestLevel=50
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.profile.resources={"1":1e20,"2":1e20}
	var c=g.crew
	check(g.profile.crew.size()==6,"Configured crew initialized")
	check(c.entry(g,"navigator").keys().size()==7,"Only dynamic crew fields including upgrade preference")
	check(c.gain_exp(g,"navigator",99) and c.entry(g,"navigator").level==0,"Below XP threshold")
	check(c.gain_exp(g,"navigator",1) and c.entry(g,"navigator").level==1 and c.entry(g,"navigator").exp==0,"Next-level row XP threshold")
	check(c.gain_exp(g,"navigator",201) and c.entry(g,"navigator").level==2 and is_equal_approx(c.entry(g,"navigator").exp,81),"Formula upgrade retains surplus experience")
	check(is_equal_approx(c.required_exp(g,0),100) and is_equal_approx(c.required_exp(g,1),120) and is_equal_approx(c.required_exp(g,2),144),"Config defines first three experience thresholds")
	check(c.gain_exp(g,"navigator",63) and c.entry(g,"navigator").level==3,"Crew advances beyond former level-three cap")
	check(is_equal_approx(c.required_exp(g,3),173),"Experience threshold rounds formula to an integer")
	c.gain_exp(g,"navigator",172)
	check(c.entry(g,"navigator").level==3,"Rounded threshold does not upgrade early")
	c.gain_exp(g,"navigator",8.5)
	check(c.entry(g,"navigator").level==4 and is_equal_approx(c.entry(g,"navigator").exp,8),"Rounded reward preserves integer surplus")
	var level_save: Array=g.profile.crew.duplicate(true)
	level_save[0].exp=7.5
	c.load_state(g,level_save)
	check(c.entry(g,"navigator").level==4 and is_equal_approx(c.entry(g,"navigator").exp,8),"Old fractional experience rounds on load without losing levels")
	check(not db.data.has("crew_level") and not db.data.crew.navigator.has("maxLevel"),"Obsolete table and crew level fields are absent")
	c.load_state(g,[])
	check(not c.gain_exp(g,"navigator",-1) and not c.gain_exp(g,"navigator",NAN),"Reject invalid experience")
	check(not c.assign(g,"navigator","unknown","weapons_0"),"Reject unknown job")
	check(not c.assign(g,"navigator","equipment_upgrade","defence_0"),"Individual modules are no longer assignment targets")
	check(c.assign(g,"navigator","equipment_upgrade","equipment"),"Weapon assignment")
	check(not c.assign(g,"engineer","equipment_upgrade","equipment"),"Capacity enforced")
	check(is_equal_approx(c.effect_value(g,c.entry(g,"navigator")),1.0),"Equipment interval stays fixed at every crew level")
	var before:=int(g.slot_entry("weapons",0).level)
	var costs: Dictionary=g.slot_upgrade_cost("weapons",0)
	var resources: Dictionary=g.profile.resources.duplicate()
	c.advance(g,0.9)
	check(g.slot_entry("weapons",0).level==before,"No checks before effective interval")
	c.advance(g,0.1)
	check(g.slot_entry("weapons",0).level==before+1,"One lowest equipment slot upgrades")
	for id in costs:check(g.profile.resources[id]==resources[id]-costs[id],"Normal resource cost "+id)
	g.profile.resources={"1":0,"2":0}
	c.advance(g,1)
	check(g.slot_entry("weapons",0).level==before+1,"Insufficient resources block upgrade")
	c.assign(g,"navigator","","")
	g.profile.resources={"1":1e20,"2":1e20}
	c.advance(g,1)
	check(g.slot_entry("weapons",0).level==before+1,"Release cancels scheduler")
	check(c.assign(g,"engineer","equipment_upgrade","equipment"),"Defense assignment")
	for category in ["weapons","defence"]:
		for index in g.loadout_entries(category).size():g.slot_entry(category,index).level=5
	g.slot_entry("defence",0).level=1
	g.invalidate_stat_cache()
	var defense:=int(g.slot_entry("defence",0).level)
	g.paused=true
	g.tick(31)
	check(g.slot_entry("defence",0).level==defense,"Paused scheduler")
	g.paused=false
	c.advance(g,1)
	check(g.slot_entry("defence",0).level==defense+1,"Lowest defense slot upgrades")
	c.assign(g,"engineer","","")
	var tech: String=g.hightech_slots()[0]
	g.profile.scientists=1
	g.profile.scientistAssignments[tech]=1
	var rate:=g.research_rate(tech)
	check(not db.data.crew_assignment.has("hightech_efficiency") and not c.assign(g,"navigator","hightech_efficiency",tech),"Removed research-efficiency job cannot be assigned")
	check(c.assign(g,"navigator","hightech_scientists","hightech"),"Hightech job targets scientist automation")
	check(c.get_modifier(g,"hightech",tech,"EFFICIENCY")==0,"Hightech job provides no research-efficiency modifier")
	check(is_equal_approx(g.research_rate(tech),rate),"Hightech assignment leaves research rate unchanged")
	check(c.get_modifier(g,"hightech","missing","EFFICIENCY")==0,"Modifier target isolation")
	var base_data: Dictionary=db.data.hightech.duplicate(true)
	g.profile.hightechLevels[g.FURNACE]=1
	g.profile.hightechLevels[g.JEWEL_FURNACE]=1
	g.profile.furnaceIncomePeak=1000
	g.profile.jewelFurnaceIncomePeak=1000
	check(not c.assign(g,"navigator","production_output",g.FURNACE),"Removed production job cannot be assigned")
	c.assign(g,"navigator","","")
	check(is_equal_approx(g.research_rate(tech),rate),"Moving away from hightech leaves research rate unchanged")
	check(c.assign(g,"researcher","jewel_auto","jewels"),"Jewel system assignment")
	check(c.get_modifier(g,"smelting",g.JEWEL_FURNACE,"SPEED")==0,"Jewel automation does not change furnace speed")
	g.drops.clear()
	g.profile.furnaceElapsed=0
	g.advance_furnace(float(db.data.hightech[g.FURNACE].para1),1000,1)
	var expected:=ceilf(1000*float(db.data.hightech[g.FURNACE].para2))
	check(g.drops.any(func(drop):return drop.id=="1" and drop.amount==expected),"Removed production job leaves furnace output unchanged")
	check(db.data.hightech==base_data,"No base data mutations")
	# Adding a row for an existing effect requires no handler/core edits.
	var job: Dictionary={"id":"passive_fixture","targetType":"production","effectType":"OUTPUT","baseValue":0.1,"levelScale":0,"powerScale":1,"interval":0,"maxCrew":1,"description":"fixture","titleTextId":"","descTextId":"","targetCategory":""}
	job.id="smelting_output"
	job.targetType="smelting"
	db.data.crew_assignment[job.id]=job
	var speed_job: Dictionary=job.duplicate()
	speed_job.id="smelting_fast_test"
	speed_job.effectType="SPEED"
	db.data.crew_assignment[speed_job.id]=speed_job
	c.assign(g,"researcher",speed_job.id,g.JEWEL_FURNACE)
	check(not c.assign(g,"engineer",job.id,g.JEWEL_FURNACE),"Different jobs cannot share one system target")
	c.assign(g,"researcher","","")
	check(c.assign(g,"engineer",job.id,g.JEWEL_FURNACE),"New Excel-style existing-effect row works")
	check(c.get_modifier(g,"smelting",g.JEWEL_FURNACE,"OUTPUT")>0,"New row aggregates")
	var old_multi:=BattleGame.new(db,false)
	old_multi.crew.load_state(old_multi,[{"crewId":"navigator","level":2,"exp":7,"assignmentType":"production_output","targetId":g.FURNACE},{"crewId":"engineer","level":2,"exp":9,"assignmentType":"production_output","targetId":g.FURNACE}])
	check(old_multi.crew.entry(old_multi,"navigator").assignmentType=="" and old_multi.crew.entry(old_multi,"engineer").assignmentType=="" and old_multi.crew.entry(old_multi,"engineer").exp==9,"Removed production assignments become idle and preserve growth")
	# Exercise every passive adapter against real production, not just aggregation.
	for item in g.profile.crew:c.assign(g,item.crewId,"","")
	for target in ["production","smelting"]:
		var key: String=g.FURNACE if target=="production" else g.JEWEL_FURNACE
		for effect in ["SPEED","OUTPUT","EFFICIENCY"]:
			var extra: Dictionary=job.duplicate()
			extra.targetType=target
			extra.effectType=effect
			extra.id="passive_test"
			db.data.crew_assignment[extra.id]=extra
			check(c.assign(g,"navigator",extra.id,key),"Existing handler accepts "+target+"/"+effect)
			g.profile.furnaceElapsed=0
			g.profile.jewelFurnaceElapsed=0
			g.drops.clear()
			var step:=float(db.data.hightech[key].para1)/(1.1 if effect=="SPEED" else 1.0)
			g.advance_furnace(step,1000,1)
			var resource: String="1" if target=="production" else "jewel"
			var output:=ceilf(1000*float(db.data.hightech[key].para2)*(1.1 if effect!="SPEED" else 1.0))
			check(g.drops.any(func(drop):return drop.id==resource and drop.amount==output),"Real production consumes "+target+"/"+effect)
			c.assign(g,"navigator","","")
	# Existing module identity persists while a smaller hull disables its tail.
	c.assign(g,"engineer","equipment_upgrade","equipment")
	var ship: Dictionary=db.ships[g.profile.selectedShip]
	var capacity=ship.weaponSlots
	var defense_capacity=ship.defenseSlots
	ship.weaponSlots=0
	ship.defenseSlots=0
	check(not c.active(g,c.entry(g,"engineer")) and c.entry(g,"engineer").targetId=="equipment","Inactive module retains dormant assignment")
	c.load_state(g,g.profile.crew.duplicate(true))
	check(c.entry(g,"engineer").targetId=="equipment" and not c.active(g,c.entry(g,"engineer")),"Dormant target survives load")
	ship.weaponSlots=capacity
	ship.defenseSlots=defense_capacity
	check(c.active(g,c.entry(g,"engineer")),"Reactivated module restores assignment")
	var saved: Array=g.profile.crew.duplicate(true)
	g.save_enabled=true
	g.save_progress()
	var disk=JSON.parse_string(FileAccess.get_file_as_string(g.SAVE_PATH))
	check(disk.crew==JSON.parse_string(JSON.stringify(saved)) and disk.crewEquipment=={},"Real save stores only dynamic state and reserved equipment")
	var restored:=BattleGame.new(db,false)
	restored.load_progress()
	check(restored.profile.crew==saved,"Real load round trip")
	c.load_state(g,[{"crewId":"navigator","level":INF,"exp":-99,"assignmentType":"missing","targetId":"bad","name":"forged"},{"crewId":"unknown"}])
	check(c.entry(g,"navigator").level==0 and c.entry(g,"navigator").assignmentType=="" and not c.entry(g,"navigator").has("name"),"Malformed and unknown crew sanitized")
	c.load_state(g,[])
	check(g.profile.crew.size()==6 and c.entry(g,"navigator").level==0,"Old saves initialize configured crew")
	check(c.equipment_slots(g,"navigator")==[null,null] and c.crew_equipment(g,"none").is_empty(),"Equipment API reserved only")
	var attempts: Array=[0]
	c.register_handler("equipment","AUTO_UPGRADE",func(game,item):
		attempts[0]+=1
		c.auto_upgrade(game,item))
	g.assign_crew("navigator","equipment_upgrade","equipment")
	for i in 9:c.advance(g,0.1)
	check(attempts[0]==0,"Scheduler never invokes checks each frame")
	c.advance(g,0.2)
	check(attempts[0]==1,"Scheduler invokes exactly one due check")
	c.advance(g,3000)
	check(attempts[0]==2,"Missed deadlines do not burst spending")
	c.register_handler("equipment","AUTO_UPGRADE",c.auto_upgrade)
	db.data.crew_config.base_exp.value=50
	db.data.crew_config.exp_multiplier.value=2
	c.load_state(g,[])
	g.add_crew_exp("navigator",350)
	check(c.entry(g,"navigator").level==3 and is_zero_approx(c.entry(g,"navigator").exp),"Changed config alone controls multiple level-ups")
	db.data.crew_config.exp_multiplier.value=1
	g.add_crew_exp("navigator",1000000)
	check(c.entry(g,"navigator").level==20003,"Constant-cost configuration upgrades in one bounded step")
	print("CREW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
