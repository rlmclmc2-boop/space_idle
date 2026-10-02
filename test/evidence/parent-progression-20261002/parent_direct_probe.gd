extends SceneTree

class ClockGame extends BattleGame:
	var qa_time := 0.0
	func economy_time() -> float:
		return qa_time
	func tick(dt: float) -> void:
		qa_time += dt
		super.tick(dt)

var actions: Array = []
var checkpoints: Array = []
var events: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func act(g: BattleGame, t: float) -> void:
	var record := {"time":t,"stage":g.stage,"wave":g.group_index,"purchases":0}
	if not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
	if g.state == BattleGame.State.MAIN_MENU:g.start(1,false)
	for ship in g.db.ships:
		if g.ship_unlocked(ship) and g.active_slot_count("weapons",ship) >= g.active_slot_count("weapons") and g.active_slot_count("defence",ship) >= g.active_slot_count("defence") and g.active_slot_count("weapons",ship)+g.active_slot_count("defence",ship)>g.active_slot_count("weapons")+g.active_slot_count("defence"):
			g.switch_ship(ship)
	var available: Array = []
	for key in BattleGame.WEAPON_KEYS:
		if g.profile.unlocked.has(key):available.append(key)
	for i in g.weapon_entries().size():
		if not available.is_empty():
			var key: String = str(available[i%available.size()])
			if str(g.slot_entry("weapons",i).key)!=key:g.equip_slot("weapons",i,key)
	for i in g.defense_entries().size():
		var key := "shield" if i%2==1 and g.profile.unlocked.has("shield") else "armour"
		if str(g.slot_entry("defence",i).key)!=key:g.equip_slot("defence",i,key)
	for purchase in 12:
		var best: Dictionary = {}
		var score := INF
		for category in ["weapons","defence"]:
			for i in g.loadout_entries(category).size():
				if not g.can_upgrade_slot(category,i):continue
				var costs: Dictionary = g.slot_upgrade_cost(category,i)
				var relative := 0.0
				for id in costs:relative += float(costs[id])/maxf(float(g.profile.resources.get(id,0)),1.0)
				if relative<score:
					score=relative
					best={"category":category,"index":i}
		if best.is_empty():break
		if g.upgrade_slot(best.category,int(best.index)):record.purchases+=1
	var ai: Dictionary = g.scientist_purchase(1)
	var buy_ai: bool = int(ai.count)>0
	for id in ai.costs:
		if float(ai.costs[id])>float(g.profile.resources.get(id,0))*0.1:buy_ai=false
	if buy_ai:g.generate_scientist()
	if g.idle_scientists()>0:g.distribute_scientists()
	if g.reactor_unlocked():
		var upgrades: int = g.reactor_max_upgrades()
		if upgrades>0:g.upgrade_reactor(upgrades)
		g.equalize_reactor_allocation()
	if g.enhancement_unlocked():g.upgrade_enhancement(-1)
	actions.append(record)

func run() -> void:
	var db := ShipDatabase.new()
	var g := ClockGame.new(db,false)
	g.stat_cache_enabled=true
	g.rng.seed=20261003
	g.event.connect(func(kind: String,_payload: Dictionary):events[kind]=int(events.get(kind,0))+1)
	var next_action := 0.0
	var next_checkpoint := 300.0
	var wall_start := Time.get_ticks_msec()
	for step in 216000:
		if g.qa_time+0.00001>=next_action or not g.pending_unlocks.is_empty():
			act(g,g.qa_time)
			next_action=g.qa_time+(10.0 if g.profile.cleared.size()<5 else 300.0)
		g.tick(1.0/60.0)
		if g.qa_time>=next_checkpoint:
			var row := {"time":g.qa_time,"stage":g.stage,"wave":g.group_index,"cleared":g.profile.cleared.duplicate(),"resources":g.profile.resources.duplicate(true),"actions":actions.size(),"events":events.duplicate()}
			checkpoints.append(row)
			print("PARENT_CHECKPOINT ",JSON.stringify(row))
			next_checkpoint+=300.0
		if Time.get_ticks_msec()-wall_start>300000:break
	var out := ProjectSettings.globalize_path("res://.runtime/parent-direct-first-hour")
	DirAccess.make_dir_recursive_absolute(out)
	var evidence := {"source_commit":"04a5a307bcef9325efa9026e1ca94affa577e10d","engine":Engine.get_version_info().string,"scope":"parent direct BattleGame fresh old-level diagnostic, not generated level acceptance","policy":"10s decisions before five clears then300s, unlock exception; affordable cheapest-normalized-cost up to12 buys per decision; mixed unlocked weapons; no planet/galaxy operator yet","game_seconds":g.qa_time,"wall_ms":Time.get_ticks_msec()-wall_start,"complete_hour":g.qa_time>=3599.99,"events":events,"actions":actions,"checkpoints":checkpoints,"profile":g.profile,"rng_state":str(g.rng.state)}
	var file := FileAccess.open(out.path_join("evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("PARENT_FINAL ",JSON.stringify({"stage":g.stage,"wave":g.group_index,"time":g.qa_time,"actions":actions.size(),"wall_ms":evidence.wall_ms,"output":out}))
	quit(0)
