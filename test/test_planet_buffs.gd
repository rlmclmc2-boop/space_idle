extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	var buffs: Dictionary = db.data.planet_buff
	check(buffs.values().all(func(row):return not (str(row.buff_type)=="level_bonus" and str(row.target)=="hightech")),"No planetary hightech level reward remains")
	check(g.equipment_level_bonus()==0 and g.gem_drop_level_bonus()==0 and g.charge_free_ratio()==0,"No rewards before conquest")
	check(not g.reforge_planet("1"),"Reforge requires completed planet")
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	g.profile.planets["1"].degree=300
	g.planet_buildings.sync(g,"1")
	g.profile.planets["1"].buildings.shipyard.status="ready"
	check(g.planet_buildings.activate(g,"1","shipyard"),"First shipyard activates")
	check(g.reforge_planet("1"),"First planet is conquered")
	check(g.equipment_level_bonus()==35 and g.gem_drop_level_bonus()==1 and is_equal_approx(g.charge_free_ratio(),0.1),"First conquest activates its three nontech modifiers")
	check(g.effective_equipment_level(1)==36 and g.permanent_level_text(1,"equipment")=="1 (+35)","Equipment virtual level remains")
	check(g.permanent_level_tooltip(1,"equipment").contains("36"),"Equipment effective level is explained")
	for key in db.data.hightech:
		g.profile.hightechLevels[key]=1
		check(g.effective_hightech_level(key)==g.hightech_level(key),"Planet does not change researched technology level: "+key)
	check(g.planet_buffs.rows(g,"1","conquer").all(func(row):return str(row.target)!="hightech"),"Active reward copy omits hightech level")
	check(not g.reforge_planet("1"),"Conquest cannot repeat")
	g.load_planets(g.profile.planets.duplicate(true))
	g.profile.planets["2"].unlocked=true
	g.profile.planets["2"].degree=300
	g.planet_buildings.sync(g,"2")
	var second_shipyard := ""
	for row in g.planet_buildings.rows(g,"2"):
		if str(row.type)=="shipyard":second_shipyard=str(row.id)
	check(not second_shipyard.is_empty(),"Second planet has a configured shipyard")
	if not second_shipyard.is_empty():
		g.profile.planets["2"].buildings[second_shipyard].status="ready"
		check(g.planet_buildings.activate(g,"2",second_shipyard),"Second shipyard activates")
	check(g.reforge_planet("2"),"Second planet is conquered")
	check(g.equipment_level_bonus()==50 and g.gem_drop_level_bonus()==2 and is_equal_approx(g.charge_free_ratio(),0.2),"Two planets add configured nontech rewards")
	var extra: Dictionary=buffs["11"].duplicate(true)
	extra.id=100
	extra.value=5
	buffs["100"]=extra
	check(g.equipment_level_bonus()==55,"Added configuration row takes effect")
	buffs["100"].stack="mul"
	buffs["100"].value=2
	check(g.equipment_level_bonus()==100,"Multiplicative stack applies")
	buffs["100"].stack="max"
	buffs["100"].value=110
	check(g.equipment_level_bonus()==110,"Maximum stack applies")
	buffs["100"].source="building"
	buffs["100"].condition="building_complete"
	buffs["100"].source_id="station"
	check(g.equipment_level_bonus()==50,"Incomplete building does not activate reward")
	g.profile.planets["2"].buildings.station.status="built"
	check(g.equipment_level_bonus()==110,"Completed building activates reward")
	print("PLANET BUFFS: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
