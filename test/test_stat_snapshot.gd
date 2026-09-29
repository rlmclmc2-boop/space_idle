extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g := BattleGame.new(ShipDatabase.new(), false)
	g.stat_cache_enabled = true
	g.profile.resources = {"1":1e100,"2":1e100}
	g.profile.highestLevel = g.db.levels.size()
	g.profile.cleared = range(1,g.db.levels.size()+1)
	g.rebuild_unlocks()
	g.ensure_loadout()
	var armour_before := g.stat("armour")
	check(g.stat("armour") == armour_before, "Repeated stat read uses same value")
	check(float(g.sync_jewel_defence_damage().armour.total) == armour_before, "Defence capacity agrees with stat")
	check(g.upgrade_slot("defence",0,1), "Armour module upgrades")
	check(g.stat("armour") > armour_before, "Module upgrade invalidates armour stat")
	check(float(g.sync_jewel_defence_damage().armour.total) == g.stat("armour"), "Module upgrade invalidates defence capacity")
	var upgraded := g.stat("armour")
	check(g.set_reactor_allocation("defence",10), "Defence reactor allocation changes")
	check(g.stat("armour") > upgraded, "Reactor allocation invalidates armour stat")
	var reactor_value := g.stat("armour")
	g.slot_entry("defence",0).hits = 8
	g.invalidate_stat_cache()
	var gem := g.new_jewel("2",1)
	g.profile.jewels.append(gem)
	check(g.socket_jewel("defence",0,0,int(gem.token)), "Defence jewel sockets")
	check(g.stat("armour") > reactor_value, "Socketed jewel invalidates armour stat")
	var capacity_before_hit := float(g.sync_jewel_defence_damage().armour.total)
	g.jewel_defence_hit(0)
	check(float(g.sync_jewel_defence_damage().armour.total) > capacity_before_hit, "Defence hit invalidates adaptation capacity")
	var with_gem := g.stat("armour")
	check(g.unsocket_jewel("defence",0,0,int(gem.token)), "Defence jewel unsockets")
	check(g.stat("armour") < with_gem, "Unsocket invalidates armour stat")
	var with_reactor := g.stat("armour")
	check(g.unequip_slot("defence",0), "Armour module unequips")
	check(g.stat("armour") < with_reactor, "Unequip invalidates armour stat")
	check(g.equip_slot("defence",0,"armour"), "Armour module equips")
	check(g.stat("armour") == with_reactor, "Equip restores armour stat")
	print("Stat snapshot: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
