extends RefCounted
## Replace this object to experiment with policies; all actions use BattleGame APIs.
const DECISION_SECONDS := 1.0
const MAX_PURCHASES := 12
var strategy := "BALANCED"
var forced_weapon := ""
var respect_guard := false
var random := RandomNumberGenerator.new()
var last_refit := -60.0
var unlocked_count := 0

func configure(name: String, seed_value: int) -> void:
	strategy = name
	random.seed = seed_value ^ 0x51A7
	last_refit = -60.0
	unlocked_count = 0

func weapon_value(game: BattleGame, key: String, level: int) -> float:
	var row := game.db.equip(key,level)
	if row.is_empty() or float(row.get("cd",0)) <= 0:return 0.0
	var value: float = game.equipment_stat(key,level)/float(row.cd)*(float(row.para1) if key == "missile" else 1.0)
	if key == "longLaser":
		# Six-second target horizon. Read the real beam multiplier, not a second damage formula.
		var active := maxf(0,6.0-float(row.get("para3",row.cd)))
		value *= game.long_laser_multiplier(row,active/2.0)*active/6.0
	return value

func act(game: BattleGame, elapsed: float) -> bool:
	if not game.pending_unlocks.is_empty():game.acknowledge_unlocks()
	if game.state == BattleGame.State.MAIN_MENU:game.start(1,false)
	elif game.state == BattleGame.State.LEVEL_CLEAR and not (respect_guard and game.guarding_here()):game.advance_after_clear()
	if strategy == "ECONOMY_FIRST":buy_scientist(game,0.5)
	# Select an unlocked hull only if both enabled module counts are no worse.
	for ship in game.db.ships:
		if not game.ship_unlocked(ship):continue
		var weapons := game.active_slot_count("weapons",ship)
		var defence := game.active_slot_count("defence",ship)
		if weapons >= game.active_slot_count("weapons") and defence >= game.active_slot_count("defence") and weapons+defence > game.active_slot_count("weapons")+game.active_slot_count("defence"):
			game.switch_ship(ship)
	var available := []
	for key in BattleGame.WEAPON_KEYS:
		if game.profile.unlocked.has(key):available.append(key)
	var refit_due := elapsed-last_refit >= 60.0 or available.size() != unlocked_count
	for index in game.weapon_entries().size():
		var entry: Dictionary = game.weapon_entries()[index]
		var best := str(entry.key)
		var value := weapon_value(game,best,int(entry.level))
		for key in BattleGame.WEAPON_KEYS:
			if not game.profile.unlocked.has(key):continue
			var candidate := weapon_value(game,key,int(entry.level))
			if candidate > value*1.15:
				best = key
				value = candidate
		if strategy == "BALANCED" and not available.is_empty():best = available[(index+maxi(0,available.size()-game.weapon_entries().size())) % available.size()]
		elif strategy == "RANDOM_VALID":
			best = available[random.randi_range(0,available.size()-1)] if refit_due and not available.is_empty() else str(entry.key)
		if not forced_weapon.is_empty() and game.profile.unlocked.has(forced_weapon):best=forced_weapon
		if not best.is_empty() and best != str(entry.key):game.equip_slot("weapons",index,best)
	for index in game.defense_entries().size():
		var entry: Dictionary = game.defense_entries()[index]
		if not str(entry.key).is_empty() and strategy not in ["BALANCED","DEFENSE_FIRST","RANDOM_VALID"]:continue
		var preferred := "armour" if index % 2 == 0 else "shield"
		if strategy == "RANDOM_VALID":
			if not refit_due and not str(entry.key).is_empty():continue
			preferred = "shield" if index > 0 and random.randf() < 0.5 else "armour"
		if not game.profile.unlocked.has(preferred):preferred = "armour"
		if preferred != str(entry.key):game.equip_slot("defence",index,preferred)
	if refit_due:last_refit = elapsed
	unlocked_count = available.size()
	var affordable := false
	for _purchase in MAX_PURCHASES:
		var best := {}
		var best_score := 0.0
		var danger: bool = float(game.player.armour) < game.stat("armour")*0.5 or game.state == BattleGame.State.RETREAT
		for category in ["weapons","defence"]:
			for index in game.loadout_entries(category).size():
				var entry := game.slot_entry(category,index)
				if str(entry.key).is_empty() or not game.can_upgrade_slot(category,index):continue
				var cost := 0.0
				var costs := game.slot_upgrade_cost(category,index)
				for id in costs:
					cost += float(costs[id])/maxf(float(game.profile.resources.get(id,0)),1.0)
				var before: float = game.jewel_equipment_stat(entry)
				var gain := maxf(0,game.jewel_equipment_stat(entry,int(entry.level)+1)-before)/maxf(before,1.0)
				if gain <= 0:continue
				affordable = true
				var weight := (4.0 if danger else 1.0) if category == "defence" else (1.0 if danger else 2.0)
				if strategy == "BALANCED":weight = (4.0 if danger else 2.0) if category == "defence" else 2.0
				elif strategy == "DAMAGE_FIRST":weight = (2.0 if danger else 1.0) if category == "defence" else 6.0
				elif strategy == "DEFENSE_FIRST":weight = 6.0 if category == "defence" else 1.0
				elif strategy == "ECONOMY_FIRST":weight = 1.0
				var score := gain*weight/maxf(cost,0.000001)
				if strategy == "RANDOM_VALID" and gain > 0:score = random.randf()
				if score > best_score:
					best_score = score
					best = {"category":category,"index":index}
		if best.is_empty():break
		game.upgrade_slot(best.category,best.index)
	# Reserve at most 10% of each current resource balance for a scientist.
	if strategy != "ECONOMY_FIRST":buy_scientist(game,random.randf_range(0.05,0.3) if strategy == "RANDOM_VALID" else 0.1)
	if strategy == "ECONOMY_FIRST" and game.can_research(BattleGame.FURNACE):game.assign_scientist(BattleGame.FURNACE,game.idle_scientists())
	for key in game.db.data.get("hightech",{}):
		if game.can_research(key) and game.assigned_scientists(key) == 0:game.assign_scientist(key,1)
	if game.idle_scientists() > 0:game.distribute_scientists()
	if game.reactor_unlocked():
		var count := game.reactor_max_upgrades()
		if count > 0:game.upgrade_reactor(count)
		game.equalize_reactor_allocation()
	# Shared enhancement purchase cadence remains ten game seconds.
	if int(round(elapsed)) % 10 == 0 and game.enhancement_unlocked():
		game.upgrade_enhancement(-1)
	return affordable

func buy_scientist(game: BattleGame, fraction: float) -> void:
	var purchase := game.scientist_purchase(1)
	var cheap := int(purchase.count)>0
	for id in purchase.costs:
		if float(purchase.costs[id]) > float(game.profile.resources.get(id,0))*fraction:cheap = false
	if cheap:game.generate_scientist()
