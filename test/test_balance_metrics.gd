extends SceneTree
const LabGame := preload("res://scripts/balance_game.gd")
const RunDatabase := preload("res://scripts/balance_database.gd")
const Metrics := preload("res://scripts/balance_metrics.gd")
const AutoPlayer := preload("res://scripts/balance_autoplayer.gd")
const Report := preload("res://scripts/balance_report.gd")
class ReferenceGame extends BattleGame:
	var simulated_time := 0.0
	func economy_time() -> float:return simulated_time
	func tick(dt: float) -> void:
		simulated_time += dt
		super.tick(dt)

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func attach(game):
	game.metrics = Metrics.new()
	game.metrics.initialize(game)
	return game.metrics
func combat_fixture(game: BattleGame, weapon: String) -> void:
	game.rng.seed = 888
	game.profile.hightechSavedAt = 0.0
	game.profile.highestLevel = game.db.levels.size()
	game.profile.cleared = range(1,game.db.levels.size()+1)
	game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	game.db.config.equipmentSocket = 20
	game.equip_slot("weapons",0,weapon)
	for index in range(1,game.weapon_entries().size()):game.unequip_slot("weapons",index)
	for id in game.db.data.jewel:
		var gem := game.new_jewel(str(id),2)
		game.profile.jewels.append(gem)
		var category := "weapons" if game.jewel_allowed(str(id),"weapons") else "defence"
		var entry := game.slot_entry(category,0)
		game.socket_jewel(category,0,entry.get("sockets",[]).size(),int(gem.token))
	game.start(1,false)
func run() -> void:
	# Both sides execute the existing combat implementation; only one collects metrics.
	for weapon in BattleGame.WEAPON_KEYS:
		var live := ReferenceGame.new(ShipDatabase.new(),false)
		var lab = LabGame.new(RunDatabase.new())
		attach(lab)
		combat_fixture(live,weapon)
		combat_fixture(lab,weapon)
		for step in 1800:
			live.tick(1.0/60.0)
			lab.tick(1.0/60.0)
		check(live.profile == lab.profile,"core profile unchanged with all compatible gems: "+weapon)
		check(live.player == lab.player and live.enemies == lab.enemies,"core battle unchanged: "+weapon)
		check(live.rng.state == lab.rng.state,"instrumentation consumes no RNG: "+weapon)
		check(lab.metrics.damage[weapon] > 0,"actual damage attributed to active weapon: "+weapon)
		check(not lab.tick_effects_active and lab.tick_effect_entries.is_empty() and lab.tick_effect_values.is_empty(),"tick effects released: "+weapon)
		check(not lab.repair_cache_active and lab.repair_entries.is_empty() and lab.repair_effects.is_empty() and lab.repair_stats.is_empty(),"repair temporaries released: "+weapon)
		# Derived repair values must not outlive one synchronous repair call.
		# Exercise changing all of their inputs between calls, including direct
		# fixture edits that emit no invalidation event.
		for phase in range(5):
			for subject in [live,lab]:
				for entry in subject.defense_entries():
					entry.level = int(entry.level)+1
					entry.hits = int(entry.get("hits",0))+100
					for gem in entry.get("sockets",[]):
						if not gem.is_empty():gem.level = int(gem.level)+1
					subject.profile.hightechLevels[BattleGame.DENSE_ARMOUR] = phase+1
					subject.charge_job("防御充能").level = phase+1
				subject.db.config.equipmentSocket = 0 if phase == 3 else 20
				subject.player.armour *= 0.7
				subject.player.shield *= 0.6
				subject.since_hit = 100
				subject.advance_jewel_repair(0.25)
			check(live.player == lab.player and live.jewel_defence_damage == lab.jewel_defence_damage,"repair matches original after dependency changes %s/%d" % [weapon,phase])
	# Research query reuse must expire before assignments/configuration change.
	var research_live := ReferenceGame.new(ShipDatabase.new(),false)
	var research_lab = LabGame.new(RunDatabase.new())
	for subject in [research_live,research_lab]:
		subject.rng.seed = 888
		subject.profile.hightechSavedAt = 0.0
	for phase in 5:
		for subject in [research_live,research_lab]:
			subject.profile.cleared = range(1,subject.db.levels.size()+1)
			subject.profile.highestLevel = subject.db.levels.size()
			for research_key in subject.db.data.hightech:
				subject.profile.scientistAssignments[research_key] = phase+1
				subject.profile.techPoints[research_key] = 1e21 if phase == 4 else 0.0
			subject.db.config.techPointGet = phase+1
			subject.advance_hightech(10.0,10.0,phase*10.0+10.0)
		check(research_live.profile == research_lab.profile and research_live.drops == research_lab.drops,"research/furnace boundaries and bulk match original phase "+str(phase))
		check(research_live.rng.state == research_lab.rng.state,"research reuse preserves RNG")
		check(not research_lab.research_scope and research_lab.research_rates.is_empty() and research_lab.research_active.is_empty(),"research scope released")
	# Charge counts and payments cross several real requirement boundaries.
	var db := ShipDatabase.new()
	var key: String = db.data.charge.keys()[0]
	db.data.charge[key].merge({"para_1":2,"para_2":2,"para_4":1,"para_5":1,"para_6":2,"para_7":1},true)
	db.unlock_row("charge",key).level=0
	var game = LabGame.new(db)
	var metrics = attach(game)
	game.profile.resources["2"] = 100
	game.toggle_charge(key)
	game.advance_charge(8)
	check(metrics.uses.charge_cycles == 8 and metrics.uses.charge_levels == 3,"charge cycles count across levels without changing jobs")
	check(metrics.spending["2"] == 58 and game.profile.resources["2"] == 42,"charge actual paid resources")
	check(game.charge_required(key,0) == 1 and game.charge_job(key).level == 3,"historical requirement query is read only")
	# Generate, combine and socket through the same policy used by the runner.
	game = LabGame.new(ShipDatabase.new())
	metrics = attach(game)
	game.profile.highestLevel = (int(game.db.unlock_row("feature","jewels").level)+1)
	game.db.config.equipmentSocket = 3
	game.settle_jewel_fragments(game.jewel_create_cost()*40,"drop",1.0)
	check(metrics.uses.jewel_acquired == 40,"gem generation counted")
	check(is_equal_approx(metrics.income.jewel_fragments-metrics.spending.jewel_fragments,float(game.profile.jewelFragments)),"fragment ledger conserves resource")
	for index in game.jewel_combine_count():game.profile.jewels.append(game.new_jewel("1",1))
	AutoPlayer.new().act(game,10)
	check(metrics.uses.jewel_combine > 0 and metrics.uses.jewel_equip > 0,"autoplayer combines and equips gems")
	# Actual HP removal excludes overkill and still attributes recursive explosion damage.
	game.start(1,false)
	game.spawn_group()
	var target: Dictionary = game.enemies[0]
	var hp := float(target.hp)
	game.source_weapon = "laser"
	game.hit_enemy(target,1e20,0)
	check(metrics.damage.laser == hp,"damage capped at actual target HP")
	check(metrics.kills == 1,"single death counted once")
	game.hit_enemy(target,1e20,0)
	check(metrics.kills == 1 and metrics.damage.laser == hp,"dead target cannot double count")
	var stage_before: int = game.stage
	game.hit_player(1e20,0)
	check(metrics.deaths == 1 and metrics.first_death.stage == stage_before,"first death captures stage before retreat")
	game.hit_player(1e20,0)
	check(metrics.deaths == 1,"hits during the same retreat do not count another death")
	check(metrics.min_health == 0 and metrics.received == metrics.health_lost+metrics.shield_absorbed,"defence actual loss and minimum")
	metrics.time = 600
	metrics.longest_unaffordable = 400
	metrics.longest_overflow["1"] = 400
	var result: Dictionary = metrics.report(game)
	var codes := []
	for anomaly in result.anomalies:codes.append(anomaly.code)
	for code in ["weapon_dominance","equipment_unused","system_unused","upgrade_gap","unaffordable","resource_surplus"]:
		check(codes.has(code),"threshold warning "+code)
	var aggregate := Report.summarize_metrics([result,result])
	check(aggregate["defence/deaths"].count == 2 and aggregate["defence/deaths"].stddev == 0,"nested metrics aggregate")
	print("Balance Metrics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
