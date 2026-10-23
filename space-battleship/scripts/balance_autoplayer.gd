extends RefCounted
## Replace this object to experiment with policies; all actions use BattleGame APIs.
const N = preload("res://scripts/growth_number.gd")
const DECISION_SECONDS := 1.0
const MAX_PURCHASES := 12
var strategy := "BALANCED"
var forced_weapon := ""
var respect_guard := false
var unlock_acknowledgements_per_visit := 1
var random := RandomNumberGenerator.new()
var last_refit := -60.0
var unlocked_count := 0

func configure(name: String, seed_value: int) -> void:
	strategy = name
	random.seed = seed_value ^ 0x51A7
	last_refit = -60.0
	unlocked_count = 0

func weapon_value(game: BattleGame, key: String, level: int) -> Variant:
	var row := game.db.equip(key,level)
	if row.is_empty() or float(row.get("cd",0)) <= 0:return 0.0
	var value: Variant = N.multiply(N.divide(game.equipment_stat(key,level),float(row.cd)),float(row.para1) if key == "missile" else 1.0)
	if key == "longLaser":
		# Six-second target horizon. Read the real beam multiplier, not a second damage formula.
		var active := maxf(0,6.0-float(row.get("para3",row.cd)))
		value = N.multiply(value,game.long_laser_multiplier(row,active/2.0)*active/6.0)
	return value

func act(game: BattleGame, elapsed: float) -> bool:
	for notification in clampi(unlock_acknowledgements_per_visit,0,32):
		if game.pending_unlocks.is_empty():break
		game.acknowledge_unlocks()
	if game.state == BattleGame.State.MAIN_MENU:game.start(1,false)
	elif game.state == BattleGame.State.LEVEL_CLEAR and not (respect_guard and game.guarding_here()):game.advance_after_clear()
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
		var value: Variant = weapon_value(game,best,int(entry.level))
		for key in BattleGame.WEAPON_KEYS:
			if not game.profile.unlocked.has(key):continue
			var candidate: Variant = weapon_value(game,key,int(entry.level))
			if N.compare(candidate,N.multiply(value,1.15))>0:
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
		var best_score: Variant = 0.0
		var danger: bool = N.compare(game.player.armour,N.multiply(game.stat("armour"),0.5))<0 or game.state == BattleGame.State.RETREAT
		for category in ["weapons","defence"]:
			for index in game.loadout_entries(category).size():
				var entry := game.slot_entry(category,index)
				if str(entry.key).is_empty() or not game.can_upgrade_slot(category,index):continue
				var cost: Variant = 0.0
				var costs := game.slot_upgrade_cost(category,index)
				for id in costs:
					cost = N.add(cost,N.divide(costs[id],N.maximum(game.economy.balance(id),1.0)))
				var before: Variant = game.jewel_equipment_stat(entry)
				var gain: Variant = N.divide(N.subtract(game.jewel_equipment_stat(entry,int(entry.level)+1),before),N.maximum(before,1.0))
				if N.compare(gain,0)<=0:continue
				affordable = true
				var weight := (4.0 if danger else 1.0) if category == "defence" else (1.0 if danger else 2.0)
				if strategy == "BALANCED":weight = (4.0 if danger else 2.0) if category == "defence" else 2.0
				elif strategy == "DAMAGE_FIRST":weight = (2.0 if danger else 1.0) if category == "defence" else 6.0
				elif strategy == "DEFENSE_FIRST":weight = 6.0 if category == "defence" else 1.0
				elif strategy == "ECONOMY_FIRST":weight = 1.0
				var score: Variant = N.divide(N.multiply(gain,weight),N.maximum(cost,0.000001))
				if strategy == "RANDOM_VALID" and N.compare(gain,0)>0:score = random.randf()
				if N.compare(score,best_score)>0:
					best_score = score
					best = {"category":category,"index":index}
		if best.is_empty():break
		game.upgrade_slot(best.category,best.index)
	# Automatic Lab decisions use the current Research owner's existing choice.
	# Keep an active selection and leave input ratios/amounts at their current values.
	if strategy == "RANDOM_VALID":random.randf_range(0.05,0.3) # Preserve the existing strategy RNG cadence.
	if game.research.selected().is_empty():
		var choice: String = game.research.shortest_available(game)
		if not choice.is_empty():game.select_tech(choice)
	if game.reactor_unlocked():
		var count := game.reactor_max_upgrades()
		if count > 0:game.upgrade_reactor(count)
		game.equalize_reactor_allocation()
	# Shared enhancement purchase cadence remains ten game seconds.
	if int(round(elapsed)) % 10 == 0 and game.enhancement_unlocked():
		game.upgrade_enhancement(-1)
	return affordable
