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
	g.db.config.equipmentSwitchCooldownSeconds=0
	g.economy.credit_many({"1":1e100,"2":1e100})
	g.profile.highestLevel = g.db.levels.size()
	g.profile.cleared = range(1,g.db.levels.size()+1)
	g.rebuild_unlocks()
	g.ensure_loadout()
	var armour_before: Variant = g.stat("armour")
	check(g.stat("armour") == armour_before, "Repeated stat read uses same value")
	check(float(g.sync_jewel_defence_damage().armour.total) == armour_before, "Defence capacity agrees with stat")
	check(g.upgrade_slot("defence",0,1), "Armour module upgrades")
	check(g.stat("armour") > armour_before, "Module upgrade invalidates armour stat")
	check(float(g.sync_jewel_defence_damage().armour.total) == g.stat("armour"), "Module upgrade invalidates defence capacity")
	var upgraded: Variant = g.stat("armour")
	check(g.set_reactor_allocation("defence",10), "Defence reactor allocation changes")
	check(g.stat("armour") > upgraded, "Reactor allocation invalidates armour stat")
	# Retired jewel sockets are covered by current enhancement-specific tests.
	var with_reactor: Variant = g.stat("armour")
	check(g.unequip_slot("defence",0), "Armour module unequips")
	check(g.stat("armour") < with_reactor, "Unequip invalidates armour stat")
	check(g.equip_slot("defence",0,"armour"), "Armour module equips")
	check(g.stat("armour") == with_reactor, "Equip restores armour stat")
	# Warmed reads follow actual domain installs without a global cache notification.
	g.enable_compiled_combat_rules()
	var raw:=g.equipment.save_data();raw.loadout.defence[0].level+=1
	var previous=g.stat("armour")
	check(g.equipment.install_snapshot(raw,g.db),"Install current equipment owner snapshot")
	check(g.N.compare(g.stat("armour"),previous)>0,"Snapshot version refreshes cached stat without notification")
	var stable=g.stat("armour")
	g.hyperspace.add_online_time(0.5);g.economy.credit("1",1);g.add_crew_exp("engineer",1)
	check(g.stat("armour")==stable,"Clock, wallet and sublevel XP do not change defence")
	g.stat_cache_enabled=false
	check(g.stat("armour")==stable,"Uncached and warmed defence agree after unrelated changes")
	g.stat_cache_enabled=true
	var research:=g.research.save_data();research.aiTechLevels.weapon_accuracy=2
	check(g.research.install_snapshot(research,g.db.data.ai_tech_tree),"Install current research snapshot")
	var cached=g.equipment_stat("laser",10)
	g.stat_cache_enabled=false
	check(g.equipment_stat("laser",10)==cached,"Research version projection agrees with uncached calculation")
	g.stat_cache_enabled=true
	var before_config=g.equipment_stat("laser",10)
	g.db.equipment.laser[0].dmg*=2.0;g.notify_configuration_changed()
	check(g.N.compare(g.equipment_stat("laser",10),before_config)>0,"Explicit config revision refreshes base rows")
	print("Stat snapshot: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
