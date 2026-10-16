extends SceneTree
# One fresh, save-disabled, continuous 18-point route. Purchases use collected resources.
var failures := 0
var g
var records: Array = []
var decisions: Array = []

func _initialize() -> void:
	call_deferred("run")

func buy(category: String, level: int, stage: int, point: int) -> void:
	var before := float(g.profile.resources.get("1", 0))
	var current: int = int(g.slot_entry(category, 0).level)
	if current >= level: return
	var ok: bool = g.upgrade_slot(category, 0, level - current)
	decisions.append({"before":str(stage)+"-"+str(point),"action":category+"_"+str(level),"iron_before":before,"iron_after":float(g.profile.resources.get("1",0)),"ok":ok})
	if not ok: failures += 1

func plan(stage: int, point: int) -> void:
	if stage == 2 and point == 1:
		var ok: bool = g.equip_slot("weapons", 0, "missile")
		decisions.append({"before":"2-1","action":"equip_missile","ok":ok})
		if not ok: failures += 1
	match str(stage)+"-"+str(point):
		"1-4": buy("weapons", 2, stage, point)
		"1-5": buy("defence", 2, stage, point)
		"2-2": buy("weapons", 2, stage, point)
		"2-3": buy("defence", 3, stage, point)
		"2-4": buy("weapons", 3, stage, point)
		"2-5": buy("weapons", 4, stage, point)
		"3-1": buy("defence", 4, stage, point)
		"3-2": buy("weapons", 5, stage, point)
		"3-4": buy("defence", 5, stage, point)
	if g.reactor_unlocked():
		if g.profile.reactorLevel == 1 and float(g.profile.resources.get("2",0)) >= float(g.reactor_upgrade_cost(1)):
			var uranium_before: float = float(g.profile.resources.get("2",0))
			var upgraded: bool = g.upgrade_reactor(1)
			decisions.append({"before":str(stage)+"-"+str(point),"action":"reactor_2","uranium_before":uranium_before,"uranium_after":float(g.profile.resources.get("2",0)),"ok":upgraded})
			if not upgraded: failures += 1
		var half := float(g.reactor_capacity()) / 2.0
		if int(g.profile.reactorAllocation.get("weapons",0)) != int(half): g.set_reactor_allocation("weapons", half)
		if int(g.profile.reactorAllocation.get("defence",0)) != int(half): g.set_reactor_allocation("defence", half)

func run() -> void:
	var db := ShipDatabase.new()
	g = preload("res://scripts/presented_battle_game.gd").new(db, false)
	g.native_execution_auto = true
	g.rng.seed = 1729
	if not g.start(1, false):
		printerr("ROUTE_START_FAILED"); quit(1); return
	var elapsed := 0.0
	var previous_state: int = g.state
	var entered := -1.0
	var armour_in := 0.0
	var shield_in := 0.0
	var active_stage := 0
	var active_point := 0
	var native_seen := false
	var retreat_count := 0
	var finished := false
	for step in 60000:
		g.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		# Active pickup is available in the UI; grab newly spawned drops before auto loss.
		for drop in g.drops.duplicate(): g.collect(drop, true)
		if previous_state != BattleGame.State.COMBAT and g.state == BattleGame.State.COMBAT:
			entered = elapsed
			active_stage = g.stage
			active_point = g.group_index
			armour_in = float(g.player.armour)
			shield_in = float(g.player.shield)
			native_seen = g.native_execution != null
		if entered >= 0 and previous_state == BattleGame.State.COMBAT and g.state != BattleGame.State.COMBAT:
			var stage: int = active_stage
			var point: int = active_point
			var result := "retreat" if g.state == BattleGame.State.RETREAT else "clear"
			var before_collect: float = float(g.profile.resources.get("1",0))
			if result == "clear":
				for drop in g.drops.duplicate(): g.collect(drop, true)
			var record := {"stage":stage,"point":point,"result":result,"combat_s":snapped(elapsed-entered,0.01),"armour_in":armour_in,"armour_out":float(g.player.armour),"shield_in":shield_in,"shield_out":float(g.player.shield),"iron_before_pickup":before_collect,"iron_after_pickup":float(g.profile.resources.get("1",0)),"uranium":float(g.profile.resources.get("2",0)),"weapon":str(g.slot_entry("weapons",0).key),"weapon_level":int(g.slot_entry("weapons",0).level),"defence":str(g.slot_entry("defence",0).key),"defence_level":int(g.slot_entry("defence",0).level),"reactor_level":int(g.profile.reactorLevel),"native_session":native_seen}
			records.append(record)
			print("APPROVED_ROUTE_POINT ", JSON.stringify(record))
			entered = -1.0
			if result == "retreat":
				retreat_count += 1
				if retreat_count >= 10: break
			else:
				if stage == 3 and point == 7:
					finished = true
					break
				if g.state != BattleGame.State.LEVEL_CLEAR:
					plan(stage, point + 1)
		if g.state == BattleGame.State.LEVEL_CLEAR and stage_transition_needed():
			while not g.pending_unlocks.is_empty(): g.acknowledge_unlocks()
			if not g.advance_after_clear():
				printerr("ADVANCE_FAILED stage=",g.stage); failures += 1; break
			plan(g.stage, 1)
		previous_state = g.state
		if elapsed > 900.0: break
	print("APPROVED_ROUTE_DECISIONS ", JSON.stringify(decisions))
	print("APPROVED_ROUTE_SUMMARY ", JSON.stringify({"points":records.size(),"retreats":retreat_count,"failures":failures,"finished":finished,"stage":g.stage,"state":g.state,"time_s":elapsed,"iron":g.profile.resources.get("1",0),"uranium":g.profile.resources.get("2",0)}))
	quit(1 if failures or not finished else 0)

func stage_transition_needed() -> bool:
	return g.stage < 3 and records.size() > 0 and int(records.back().stage) == g.stage and records.back().result == "clear"
