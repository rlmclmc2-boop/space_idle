extends SceneTree
class CountedGame extends BattleGame:
	var saves := 0
	func save_progress() -> void:
		saves+=1
		super.save_progress()
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(message)
func make_game() -> BattleGame:
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,41)
	g.profile.resources={"1":1000000.0,"2":1000000.0}
	return g
func _initialize() -> void:
	var counted := CountedGame.new(ShipDatabase.new(),false)
	counted.profile.resources={"1":1e6,"2":1e6}
	var events: Array=[]
	counted.event.connect(func(kind,info):events.append({"kind":kind,"info":info}))
	counted.saves=0
	counted.upgrade_equipment_batch("1")
	check(counted.saves==1,"Successful sweep saves exactly once")
	check(events.filter(func(e):return e.kind=="upgrade").size()==counted.loadout_entries("weapons").size()+counted.loadout_entries("defence").size(),"Per-module upgrade events remain available to consumers")
	check(events[-1].kind=="upgrades_completed","Completion event follows per-module events")
	check(counted._upgrade_costs.is_empty() and not counted._upgrade_batch,"Sweep cache is released synchronously")
	counted.saves=0
	counted.profile.resources={"1":0.0,"2":0.0}
	events.clear()
	counted.upgrade_equipment_batch("max")
	check(counted.saves==0 and events.is_empty(),"Unaffordable sweep does not save or refresh")
	counted.profile.resources={"1":1e6,"2":1e6}
	counted.upgrade_slot("weapons",0)
	check(counted.saves==1 and not events[-1].info.batch,"Manual upgrade still saves immediately")
	var stress := make_game()
	var reference := make_game()
	stress.profile.resources={"1":1e100,"2":1e100}
	reference.profile.resources=stress.profile.resources.duplicate()
	stress.upgrade_equipment_batch("max")
	for category in ["weapons","defence"]:
		for index in reference.loadout_entries(category).size():
			var amount: int=reference.max_upgrade_amount_slot(category,index)
			if amount>0:reference.upgrade_slot(category,index,amount)
	check(stress.profile.loadout==reference.profile.loadout and stress.profile.resources==reference.profile.resources,"Stress MAX matches uncached manual levels and exact resource balances")
	check(stress.player.armour==reference.player.armour and stress.player.shield==reference.player.shield,"Stress batch preserves manual armour and shield effects")
	# A later call must see changed configuration, not the preceding sweep's costs.
	var cost_key: String=stress.module_cost_key("weapons")
	stress.db.equipment[cost_key][0].cost_1=12345.0
	check(stress.upgrade_cost_for_level(cost_key,1)["1"]==12345.0,"Sweep leaves no stale costs after config changes")
	for mode in ["1","10","max"]:
		var g:=make_game()
		var manual:=make_game()
		check(g.crew.set_upgrade_mode(g,"navigator",mode),"Accept configured mode "+mode)
		check(g.assign_crew("navigator","equipment_upgrade","equipment"),"Assign equipment system "+mode)
		g.crew.advance(g,0.99)
		check(g.profile.loadout==manual.profile.loadout,"No upgrades before one second "+mode)
		for category in ["weapons","defence"]:
			for index in manual.loadout_entries(category).size():
				var amount: int=manual.max_upgrade_amount_slot(category,index) if mode=="max" else int(mode)
				if amount>0:manual.upgrade_slot(category,index,amount)
		g.crew.advance(g,0.01)
		check(g.profile.loadout==manual.profile.loadout,"All modules match manual unified upgrades "+mode)
		check(g.profile.resources==manual.profile.resources,"Exactly the manual resource costs "+mode)
		if mode!="max":
			for category in ["weapons","defence"]:
				for item in g.loadout_entries(category):check(int(item.level)==1+int(mode),"Every enabled module upgraded "+mode)
	var g:=make_game()
	g.assign_crew("navigator","equipment_upgrade","equipment")
	g.crew.set_upgrade_mode(g,"navigator","10")
	g.profile.resources=g.slot_upgrade_cost("weapons",0).duplicate()
	g.crew.advance(g,1)
	check(g.slot_entry("weapons",0).level==1,"Ten-level option does not silently downgrade to one level")
	g.profile.resources={"1":1000000.0,"2":1000000.0}
	g.profile.loadout.weapons.append({"key":"laser","level":1})
	var inactive: Dictionary=g.profile.loadout.weapons[-1]
	g.crew.advance(g,1)
	check(inactive.level==1,"Inactive tail module is not upgraded")
	g.add_crew_exp("navigator",300)
	var before:=int(g.slot_entry("weapons",0).level)
	g.crew.advance(g,0.9)
	check(g.slot_entry("weapons",0).level==before,"Crew levels do not accelerate one-second equipment timer")
	g.crew.advance(g,0.1)
	check(g.slot_entry("weapons",0).level==before+10,"High-level crew retains selected batch")
	check(not g.crew.set_upgrade_mode(g,"navigator","bad") and g.crew.entry(g,"navigator").upgradeMode=="10","Invalid mode rejected without state change")
	g.save_enabled=true
	g.save_progress()
	var restored:=BattleGame.new(g.db,false)
	restored.load_progress()
	check(restored.crew.entry(restored,"navigator").upgradeMode=="10","Selected amount round-trips through real save")
	var legacy: Array=[{"crewId":"navigator","level":2,"exp":17,"assignmentType":"weapon_upgrade","targetId":"weapons_0"},{"crewId":"engineer","level":1,"exp":0,"assignmentType":"defense_upgrade","targetId":"defence_0"}]
	g.crew.load_state(g,legacy)
	check(g.crew.entry(g,"navigator").assignmentType=="equipment_upgrade" and g.crew.entry(g,"navigator").targetId=="equipment","Legacy module assignment migrates to system")
	check(g.crew.entry(g,"navigator").upgradeMode=="1" and g.crew.entry(g,"navigator").exp==17,"Legacy save defaults to first configured mode and keeps growth")
	check(g.crew.entry(g,"engineer").assignmentType=="","Migration retains Excel capacity without duplicate system checks")
	g.crew.assign(g,"navigator","","")
	for id in g.db.data.crew:
		check(g.assign_crew(id,"equipment_upgrade","equipment"),"Every crew can do the same equipment work: "+id)
		g.assign_crew(id,"","")
	print("CREW EQUIPMENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
