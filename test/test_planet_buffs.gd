extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	check(g.equipment_level_bonus()==0 and g.hightech_level_bonus()==0 and g.charge_free_ratio()==0 and g.gem_drop_level_bonus()==0,"No reward before conquest")
	check(not g.reforge_planet("1") and g.equipment_level_bonus()==0,"Rejected reforge never activates rewards")
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	g.profile.planets["1"].degree=300
	g.planet_buildings.sync(g,"1")
	g.profile.planets["1"].buildings.shipyard.status="ready"
	check(g.planet_buildings.activate(g,"1","shipyard"),"Activate shipyard before reforge")
	check(g.reforge_planet("1"),"Completed shipyard reforges")
	check(g.equipment_level_bonus()==10 and g.hightech_level_bonus()==20 and is_equal_approx(g.charge_free_ratio(),.1) and g.gem_drop_level_bonus()==2,"Conquest enables four configured modifiers")
	check(g.effective_hightech_level(BattleGame.ENERGY_FOCUS)==0 and g.reactor_multiplier("weapons")==1,"Rewards do not unlock reset systems early")
	check(not g.reforge_planet("1"),"Conquest cannot repeat")
	for key in ["laser","missile","cannon","longLaser","armour","shield"]:
		var row: Dictionary=db.equip(key,11)
		check(g.equipment_stat(key,1)==float(row.para1 if key in ["armour","shield"] else row.dmg),"Ordinary effect uses level eleven: "+key)
	check(g.weapon_entries()[0].level==1 and db.equip("laser",1).level==1,"Actual equipment level stays one")
	check(g.permanent_level_text(1,"equipment")=="1 (+10)" and g.permanent_level_tooltip(1,"equipment").contains("11"),"Display separates actual and effective levels")
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	for key in db.data.hightech:
		g.profile.hightechLevels[key]=1
		var required: float=g.hightech_required(key)
		check(g.hightech_level(key)==1 and g.effective_hightech_level(key)==11,"Tech effect level: "+key)
		g.profile.planets["1"].conquered=false
		check(g.hightech_required(key)==required,"Research time stays actual: "+key)
		g.profile.planets["1"].conquered=true
	var capacity: int=g.reactor_capacity()
	for key in g.reactor_available_modules():
		check(is_equal_approx(g.reactor_effective_ratio(key),.1),"Every module independently receives free energy: "+key)
	check(g.reactor_allocated()==0 and g.reactor_capacity()==capacity,"Free energy uses no capacity")
	check(g.set_reactor_allocation("weapons",capacity),"All original capacity remains assignable")
	check(is_equal_approx(g.reactor_effective_ratio("weapons"),1.1),"Effective charge exceeds full allocation")
	check(is_equal_approx(g.reactor_multiplier("weapons"),1+pow(capacity*1.1,float(db.config.reactorBoostExponent))/float(db.config.reactorPercentScale)),"Overfull charge follows existing formula")
	var inventory: Array=[]
	var result: Dictionary=g.generate_jewels_into(inventory,g.jewel_create_cost(),0,g.rng)
	check(inventory.size()==1 and inventory[0].level==3 and result.fragments==0,"New level one gem becomes actual level three")
	check(g.new_jewel("1",3).level==3,"Copy/combine constructor does not reapply bonus")
	check(g.jewel_valid({"id":"1","level":db.jewel_max_level("1")+2}),"Generated real levels above original recipe ceiling remain valid")
	g.profile.jewels=inventory
	g.jewel_serial=int(result.serial)
	g.save_enabled=true
	g.save_progress()
	var loaded:=BattleGame.new(db,false)
	loaded.load_progress()
	check(loaded.profile.jewels[0].level==3 and loaded.equipment_level_bonus()==10,"Save/load keeps real gem level and permanent activation once")
	# A later planet reset retains the first planet's rewards, with no copied reward state.
	db.data.planet["2"]=db.data.planet["1"].duplicate(true)
	db.data.planet["2"].id=2
	g.load_planets(g.profile.planets.duplicate(true))
	g.profile.planets["2"].unlocked=true
	g.profile.planets["2"].degree=300
	g.planet_buildings.sync(g,"2")
	g.profile.planets["2"].buildings.shipyard.status="ready"
	check(g.planet_buildings.activate(g,"2","shipyard"),"Activate second shipyard before reforge")
	check(g.reforge_planet("2") and g.equipment_level_bonus()==10,"Later reforge preserves earlier conquest reward")
	for id in ["1","2","3","4"]:
		var row: Dictionary=db.data.planet_buff[id].duplicate(true)
		row.id=int(id)+4;row.planet_id=2
		db.data.planet_buff[str(row.id)]=row
	check(g.equipment_level_bonus()==20 and g.hightech_level_bonus()==20 and is_equal_approx(g.charge_free_ratio(),.2) and g.gem_drop_level_bonus()==4,"Same buff types add across conquered planets")
	db.data.planet_buff["5"].value=5
	check(g.equipment_level_bonus()==15,"Configuration edits refresh without fixed multiplier cache")
	db.data.planet_buff["5"].stack="mul";db.data.planet_buff["5"].value=2
	check(g.equipment_level_bonus()==20,"Multiplicative stack")
	db.data.planet_buff["5"].stack="max";db.data.planet_buff["5"].value=30
	check(g.equipment_level_bonus()==30,"Maximum stack")
	db.data.planet_buff["5"].source="building";db.data.planet_buff["5"].condition="building_complete";db.data.planet_buff["5"].source_id="station"
	check(g.equipment_level_bonus()==10,"Building condition ignores incomplete buildings")
	g.profile.planets["2"].buildings.station.status="built"
	check(g.equipment_level_bonus()==30,"Building completion activates configured source")
	var rows: Array=g.planet_buffs.rows(g,"1","conquer")
	check(rows.size()==4 and rows[0].des==db.data.planet_buff["1"].des and rows[3].id==4,"Conquest descriptions come from ordered table rows")
	print("PLANET BUFFS: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
