extends SceneTree
# Compare cached projections with direct calculation across real mutation paths.
class ClockGame extends BattleGame:
	var now := 1000000.0
	func economy_time() -> float:return now

var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func snapshot(g: BattleGame) -> Dictionary:
	var profile := g.profile.duplicate(true)
	profile.erase("hightechSavedAt")
	profile.erase("chronoSavedAt")
	return {"profile":profile,"player":g.player,"enemies":g.enemies,"projectiles":g.projectiles,"drops":g.drops,"cooldowns":g.cooldowns,"rng":g.rng.state,"state":g.state,"stage":g.stage,"group":g.group_index,"distance":g.distance,"damage":g.jewel_defence_damage,"repeats":g.jewel_repeats}

func compare(a: BattleGame, b: BattleGame, label: String) -> void:
	check(snapshot(a)==snapshot(b),label+" state and RNG")
	check(a.permanent_modifiers()==b.permanent_modifiers(),label+" planet modifiers")
	check(a.planet_equipment_multiplier()==b.planet_equipment_multiplier(),label+" equipment multiplier")
	check(a.planet_resource_multiplier()==b.planet_resource_multiplier(),label+" resource multiplier")
	for key in BattleGame.EQUIPMENT:check(a.stat(key)==b.stat(key),label+" "+key)
	for category in ["weapons","defence"]:
		for index in a.module_entries(category).size():
			var first: Dictionary=a.module_entry(category,index)
			var second: Dictionary=b.module_entry(category,index)
			check(a.jewel_equipment_stat(first)==b.jewel_equipment_stat(second),label+" module "+str(index))
	# Read projections must leave authoritative state unchanged.
	check(snapshot(a)==snapshot(b),label+" read purity")

func _initialize() -> void:
	var a := ClockGame.new(ShipDatabase.new(),false)
	var b := ClockGame.new(ShipDatabase.new(),false)
	for g in [a,b]:
		if FileAccess.file_exists(BattleGame.SAVE_PATH):
			# The launcher supplies only an isolated copy of the player's snapshot.
			g.load_progress()
		else:
			g.profile.cleared=range(1,101)
			g.rebuild_unlocks()
			g.profile.resources={"1":1e100,"2":1e100}
			g.profile.loadout.weapons=[{"key":"laser","level":10},{"key":"missile","level":10}]
			g.profile.loadout.defence=[{"key":"shield","level":10},{"key":"armour","level":10}]
			g.db.config.equipmentSocket=10
			g.profile.loadout.weapons[0].sockets=[g.new_jewel("4",2)]
			g.profile.loadout.defence[0].sockets=[g.new_jewel("6",2)]
		g.profile.chronoParticles=0.0
		g.rng.seed=91531
		g.resume_progress()
	a.stat_cache_enabled=true
	a.invalidate_stat_cache()
	compare(a,b,"initial")
	var effects := a.jewel_effects(a.module_entry("weapons",0))
	if not effects.is_empty():
		effects[0].source=999
		check(not a.jewel_effects(a.module_entry("weapons",0))[0].has("source"),"Projectile effect annotations cannot mutate cached socket effects")
	for frame in 600:
		var dt := 1.0/60.0 if frame<300 else 1.0/15.0
		for g in [a,b]:
			g.now+=dt
			g.tick(dt)
		compare(a,b,"tick "+str(frame))
		if failures>0:break
	for g in [a,b]:
		g.profile.resources={"1":1e200,"2":1e200}
		check(g.upgrade_slot("weapons",0,1),"Weapon upgrade accepted")
		check(g.upgrade_slot("defence",0,1),"Defence upgrade accepted")
	compare(a,b,"upgrade")
	for g in [a,b]:check(g.unequip_slot("weapons",0),"Unequip accepted")
	compare(a,b,"unequip")
	for g in [a,b]:check(g.equip_slot("weapons",0,"longLaser"),"Refit accepted")
	compare(a,b,"refit")
	for g in [a,b]:
		if not g.profile.crew.is_empty():
			var member: Dictionary=g.profile.crew[0]
			g.add_crew_exp(str(member.crewId),g.crew.required_exp(g,int(member.level)))
	compare(a,b,"crew growth")
	# Independent fixture for activation, degree growth and permanent conquest.
	a=ClockGame.new(ShipDatabase.new(),false)
	b=ClockGame.new(ShipDatabase.new(),false)
	for g in [a,b]:
		g.rng.seed=91531
		g.profile.cleared=range(1,101)
		g.rebuild_unlocks()
		g.profile.planets["1"].degree=300
		g.planet_buildings.sync(g,"1")
		for building in g.profile.planets["1"].buildings.values():building.status="ready"
		g.invalidate_stat_cache()
	a.stat_cache_enabled=true
	compare(a,b,"before activation")
	for row in a.planet_buildings.rows(a,"1"):
		for g in [a,b]:g.planet_buildings.activate(g,"1",str(row.id))
		compare(a,b,"activate "+str(row.id))
	for g in [a,b]:
		g.start_planet_exploration("1","navigator")
		g.advance_planets(g.planet_duration("1"))
	compare(a,b,"planet trip")
	for g in [a,b]:check(g.reforge_planet("1"),"reforge accepted")
	compare(a,b,"reforge")
	print("STAT CACHE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
