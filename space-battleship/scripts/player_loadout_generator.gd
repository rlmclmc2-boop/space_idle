extends RefCounted
## Test records use the original profile.loadout schema and BattleGame rules.
## One save-disabled, scene-free rules object per generation context; never ticked.
const POLICY_PATH := "res://data/enemy_fleet_analysis.json"
const EnemySimulator := preload("res://scripts/enemy_fleet_simulator.gd")
var db: ShipDatabase
var policy: Dictionary
var fingerprint: String
var rules: BattleGame
var ships: Array = []
var weapons: Array = []
var defences: Array = []
var equipment_stats := {}
var reference := {}

func _init(database: ShipDatabase) -> void:
	db = database
	policy = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH)).player
	fingerprint = JSON.stringify({"data":db.data,"policy":policy}).sha256_text()

func default_options() -> Dictionary:
	var result: Dictionary = policy.defaults.duplicate(true)
	if int(result.cleared_through) < 0:result.cleared_through = db.levels.size()
	result.available_ships = [db.ships.keys()[0]] if not db.ships.is_empty() else []
	return result

func options_error(options: Dictionary) -> String:
	for key in ["count","seed","cleared_through","module_level"]:
		var value = options.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)):return "invalid_input"
	if options.count < 1 or options.count > policy.max_results or absf(float(options.seed)) > float(policy.max_seed):return "invalid_input"
	if options.cleared_through < 0 or options.cleared_through > db.levels.size():return "invalid_input"
	if options.module_level < 1 or options.module_level > policy.max_module_level:return "invalid_input"
	if options.has("available_ships"):
		if not options.available_ships is Array or options.available_ships.is_empty():return "invalid_input"
		for key in options.available_ships:
			if not key is String or not db.ships.has(key):return "invalid_input"
	return ""

func configure(options: Dictionary) -> void:
	rules = BattleGame.new(db, false)
	apply_progress(rules, int(options.cleared_through))
	ships.clear()
	weapons.clear()
	defences.clear()
	equipment_stats.clear()
	reference = {"burst":0.0,"sustained":0.0,"attack_rate":0.0,"survival":0.0}
	for key in db.ships:
		# Missing whitelist preserves replay compatibility with older records.
		if options.has("available_ships") and not options.available_ships.has(key):continue
		if rules.ship_unlocked(str(key)) and rules.active_slot_count("weapons",key)>0 and rules.active_slot_count("defence",key)>0:ships.append(key)
	ships.sort()
	for key in BattleGame.EQUIPMENT:
		if not rules.profile.unlocked.has(key) or db.equip(key,int(options.module_level)).is_empty():continue
		if BattleGame.WEAPON_KEYS.has(key):weapons.append(key)
		elif BattleGame.DEFENSE_KEYS.has(key):defences.append(key)
	weapons.sort()
	defences.sort()
	# Shared stat functions supply modifiers; no copied weapon attribute table.
	for key in weapons + defences:
		var entry := {"key":key,"level":int(options.module_level)}
		var row := db.equip(key,int(options.module_level))
		var value:Variant = rules.jewel_equipment_stat(entry)
		var stats := {"value":value,"burst":0.0,"sustained":0.0,"attack_rate":0.0,"multi_target":0.0}
		if weapons.has(key) and float(row.cd)>0:
			var critical := rules.jewel_critical(entry)
			var expected:Variant = value * (1.0 + critical.x * (critical.y - 1.0))
			var salvo := int(row.para1) if key == "missile" else 1
			stats.burst = expected * salvo
			stats.attack_rate = 1.0 / float(row.cd)
			stats.sustained = stats.burst * stats.attack_rate
			if key == "longLaser":
				stats.sustained *= rules.long_laser_multiplier(row,maxf(0,float(row.para1)))
				stats.burst *= rules.long_laser_multiplier(row,0)
			stats.multi_target = 1.0 if salvo>1 else 0.0
			for metric in ["burst","sustained","attack_rate"]:reference[metric] = maxf(reference[metric],stats[metric])
		else:reference.survival = maxf(reference.survival,value)
		equipment_stats[key] = stats

static func apply_progress(game: BattleGame, cleared_through: int) -> void:
	game.profile.cleared = []
	for stage in range(1,cleared_through+1):game.profile.cleared.append(stage)
	# No synthetic grants: the original cleared/reached/initial rules decide.
	game.profile.grantedUnlocks = []
	game.rebuild_unlocks()

func generate(options: Dictionary) -> Dictionary:
	var result := {"results":[],"attempts":0,"status":"complete","requested":options.get("count",0),"batch_seed":options.get("seed",0),"coverage":{},"unavailable_types":[]}
	var invalid := options_error(options)
	if not invalid.is_empty():
		result.status = invalid
		return result
	configure(options)
	if ships.is_empty() or weapons.is_empty() or not defences.has("armour"):
		result.status = "no_legal_loadouts"
		return result
	var modes: Array = []
	for mode in policy.modes:
		var required := 3 if mode=="balanced" else 2 if mode=="dual" else 1
		if weapons.size()>=required and ships.any(func(ship):return rules.active_slot_count("weapons",ship)>=required):modes.append(mode)
		else:result.unavailable_types.append(mode)
	var random := RandomNumberGenerator.new()
	random.seed = int(options.seed)
	var seen := {}
	var budget := mini(int(policy.max_attempts),int(options.count)*int(policy.attempts_per_result))
	while result.results.size()<int(options.count) and result.attempts<budget:
		var mode: String = modes[result.attempts % modes.size()]
		result.attempts += 1
		var candidate_seed := int(random.randi())
		var candidate := sample(candidate_seed,mode,options)
		if candidate.is_empty():continue
		var signature := signature_for(candidate.ship,candidate.equipment)
		if seen.has(signature):continue
		seen[signature] = true
		var row := describe(candidate.ship,candidate.equipment)
		row.merge({"loadout_id":"player_"+signature,"signature":signature,"seed":candidate_seed,"batch_seed":int(options.seed),"generation_type":mode,"generation_options":options.duplicate(true),"config_fingerprint":fingerprint})
		result.results.append(row)
		result.coverage[mode] = int(result.coverage.get(mode,0))+1
	if result.results.size()<int(options.count):result.status = "attempt_limit"
	return result

func sample(candidate_seed: int, mode: String, options: Dictionary) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = candidate_seed
	var required := 3 if mode=="balanced" else 2 if mode=="dual" else 1
	var available := ships.filter(func(ship):return rules.active_slot_count("weapons",ship)>=required)
	if available.is_empty() or weapons.size()<required:return {}
	var ship: String = available[random.randi_range(0,available.size()-1)]
	var loadout := rules.empty_loadout(ship)
	var pool: Array = weapons.duplicate()
	shuffle(pool,random)
	var types := pool.size() if mode=="random" else mini(pool.size(),loadout.weapons.size()) if mode=="balanced" else required
	for index in range(loadout.weapons.size()):
		loadout.weapons[index] = {"key":pool[random.randi_range(0,types-1)] if mode=="random" else pool[index%types],"level":int(options.module_level)}
	for index in range(loadout.defence.size()):
		loadout.defence[index] = {"key":"armour" if index==0 else defences[random.randi_range(0,defences.size()-1)],"level":int(options.module_level)}
	shuffle(loadout.weapons,random)
	shuffle(loadout.defence,random,1)
	if not rules.valid_loadout(ship,loadout):return {}
	return {"ship":ship,"equipment":loadout}

static func shuffle(values: Array, random: RandomNumberGenerator, first := 0) -> void:
	for index in range(values.size()-1,first,-1):
		var other := random.randi_range(first,index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value

static func signature_for(ship: String, equipment: Dictionary) -> String:
	# Mount order affects muzzle positions; retain it rather than conflating layouts.
	return JSON.stringify({"ship":ship,"equipment":equipment}).sha256_text()

func describe(ship: String, equipment: Dictionary) -> Dictionary:
	rules.profile.selectedShip = ship
	rules.profile.loadout = equipment
	var stats := {"armour":rules.stat("armour"),"shield":rules.max_shield(),"movement":rules.ship_movement(),"burst":0.0,"sustained":0.0,"attack_rate":0.0,"multi_target":0.0,"aoe":0.0,"range":0.0}
	var counts := {}
	for entry in equipment.weapons:
		counts[entry.key] = int(counts.get(entry.key,0))+1
		for key in ["burst","sustained","attack_rate","multi_target"]:stats[key] += float(equipment_stats[entry.key][key])
	var scores := {}
	for key in ["burst","sustained","attack_rate"]:
		scores[key] = clampf(stats[key] / equipment.weapons.size() / maxf(reference[key],0.000001),0,1)
	scores.survival = clampf((stats.armour+stats.shield)/equipment.defence.size()/maxf(reference.survival,0.000001),0,1)
	scores.single_target = 1.0-stats.multi_target/equipment.weapons.size()
	scores.multi_target = 1.0-scores.single_target
	scores.aoe = 0.0
	# Range is unknown, not short. Only defined features participate in tags.
	scores.balanced = 1.0-float(counts.values().max()-counts.values().min())/equipment.weapons.size() if counts.size()>=3 else 0.0
	var tags: Array = []
	for rule in policy.tags:
		if scores.has(rule.feature) and float(scores[rule.feature])>=float(rule.threshold):tags.append(rule.id)
	return {"ship":ship,"weapons":equipment.weapons.duplicate(true),"equipment":equipment.duplicate(true),"stats":stats,"feature_scores":scores,"tags":tags,"analysis_version":policy.version,"notes":policy.notes.duplicate(true)}

func weapon_role(key: String) -> String:
	var stats: Dictionary=equipment_stats[key]
	if float(stats.multi_target)>0:return "multi_target"
	var burst:=float(stats.burst)/maxf(float(reference.burst),0.000001)
	var sustained:=float(stats.sustained)/maxf(float(reference.sustained),0.000001)
	if burst>sustained*1.2:return "burst"
	if sustained>burst*1.2:return "sustained"
	return "rapid" if float(stats.attack_rate)/maxf(float(reference.attack_rate),0.000001)>=0.7 else "general"

func generate_canonical(options: Dictionary,max_loadouts: int) -> Dictionary:
	var result: Dictionary={"results":[],"status":"complete","requested":max_loadouts,"coverage":{}}
	var request:=options.duplicate(true)
	request.count=max_loadouts
	var invalid:=options_error(request)
	if not invalid.is_empty() or max_loadouts<1:return {"results":[],"status":"invalid_input"}
	configure(request)
	if ships.is_empty() or weapons.is_empty() or not defences.has("armour"):return {"results":[],"status":"no_legal_loadouts"}
	var buckets: Dictionary={"mono":[],"same_role":[],"synergy":[],"balanced":[]}
	var seen: Dictionary={}
	for ship in ships:
		var slots:=rules.active_slot_count("weapons",ship)
		var role_keys: Dictionary={}
		for key in weapons:
			var role:=weapon_role(str(key))
			if not role_keys.has(role):role_keys[role]=[]
			role_keys[role].append(str(key))
			append_canonical(buckets.mono,seen,ship,[key],"mono",request)
		if slots>=2:
			for role in role_keys:
				if role_keys[role].size()>=2:append_canonical(buckets.same_role,seen,ship,role_keys[role].slice(0,2),"same_role",request)
			for roles in [["multi_target","burst"],["multi_target","sustained"],["burst","sustained"]]:
				if role_keys.has(roles[0]) and role_keys.has(roles[1]):append_canonical(buckets.synergy,seen,ship,[role_keys[roles[0]][0],role_keys[roles[1]][0]],"synergy",request)
		if slots>=3:
			var distinct: Array=[]
			for role in role_keys:distinct.append(role_keys[role][0])
			if distinct.size()>=3:append_canonical(buckets.balanced,seen,ship,distinct.slice(0,3),"balanced",request)
	var kinds: Array=["mono","same_role","synergy","balanced"]
	for kind in kinds:
		var by_ship: Dictionary={}
		for row in buckets[kind]:
			if not by_ship.has(row.ship):by_ship[row.ship]=[]
			by_ship[row.ship].append(row)
		buckets[kind]=[]
		var more:=true
		while more:
			more=false
			for ship in ships:
				if by_ship.has(ship) and not by_ship[ship].is_empty():
					buckets[kind].append(by_ship[ship].pop_front())
					more=true
	while result.results.size()<max_loadouts:
		var added:=false
		for kind in kinds:
			if buckets[kind].is_empty():continue
			var row: Dictionary=buckets[kind].pop_front()
			result.results.append(row)
			result.coverage[kind]=int(result.coverage.get(kind,0))+1
			added=true
			if result.results.size()>=max_loadouts:break
		if not added:break
	if result.results.size()<max_loadouts:result.status="limited_catalog"
	return result

func append_canonical(bucket: Array,seen: Dictionary,ship: String,keys: Array,kind: String,options: Dictionary) -> void:
	var loadout:=rules.empty_loadout(ship)
	for i in range(loadout.weapons.size()):loadout.weapons[i]={"key":str(keys[i%keys.size()]),"level":int(options.module_level)}
	for i in range(loadout.defence.size()):loadout.defence[i]={"key":"armour" if i==0 or not defences.has("shield") else "shield","level":int(options.module_level)}
	if not rules.valid_loadout(ship,loadout):return
	var weapon_keys: Array=[]
	var defence_keys: Array=[]
	for entry in loadout.weapons:weapon_keys.append(str(entry.key))
	for entry in loadout.defence:defence_keys.append(str(entry.key))
	weapon_keys.sort()
	defence_keys.sort()
	var identity:=JSON.stringify({"ship":ship,"weapons":weapon_keys,"defence":defence_keys})
	if seen.has(identity):return
	seen[identity]=true
	var row:=describe(ship,loadout)
	var signature:=signature_for(ship,loadout)
	row.merge({"loadout_id":"player_"+signature,"signature":signature,"seed":int(options.seed),"batch_seed":int(options.seed),"generation_type":"canonical_"+kind,"generation_options":options.duplicate(true),"config_fingerprint":fingerprint})
	bucket.append(row)

static func upgraded_profile(database: ShipDatabase,record: Dictionary,base_profile: Dictionary,delta: int) -> Dictionary:
	if delta<0:return {"error":"invalid_level"}
	if delta==0:return base_profile.duplicate(true)
	var game:=BattleGame.new(database,false)
	game.profile=base_profile.duplicate(true)
	game.profile.selectedShip=record.ship
	game.profile.loadout=record.equipment.duplicate(true)
	game.state=BattleGame.State.RETREAT
	for category in ["weapons","defence"]:
		for index in range(game.profile.loadout[category].size()):
			if str(game.profile.loadout[category][index].get("key"," ")).strip_edges().is_empty():continue
			var costs: Dictionary=game.slot_upgrade_cost(category,index,delta)
			if costs.is_empty():return {"error":"level_cap"}
			for id in costs:game.profile.resources[id]=maxf(float(game.profile.resources.get(id,0)),float(costs[id]))
			if not game.upgrade_slot(category,index,delta):return {"error":"upgrade_failed"}
	return game.profile.duplicate(true)

func replay(record: Dictionary) -> Dictionary:
	if record.get("config_fingerprint","")!=fingerprint:return {"error":"config_changed"}
	if not record.get("generation_options") is Dictionary or not valid_seed(record.get("seed")):return {"error":"invalid_input"}
	var options: Dictionary = record.get("generation_options",{})
	if str(record.get("generation_type","")).begins_with("canonical_"):
		var canonical:=generate_canonical(options,int(options.get("count",0)))
		for row in canonical.results:
			if row.loadout_id==record.get("loadout_id"):return row
		return {"error":"invalid_input"}
	if not options_error(options).is_empty() or not policy.modes.has(record.get("generation_type","")):return {"error":"invalid_input"}
	configure(options)
	var candidate := sample(int(record.seed),record.generation_type,options)
	if candidate.is_empty():return {"error":"no_legal_loadouts"}
	var result := describe(candidate.ship,candidate.equipment)
	var signature := signature_for(candidate.ship,candidate.equipment)
	result.merge({"loadout_id":"player_"+signature,"signature":signature,"seed":int(record.seed),"batch_seed":int(options.seed),"generation_type":record.generation_type,"generation_options":options.duplicate(true),"config_fingerprint":fingerprint})
	return result

func validate_record(record: Dictionary) -> bool:
	# Reject altered/stale records, including level, mount, unlock and stat tampering.
	var expected := replay(record)
	return not expected.has("error") and same_record(expected,record)

static func valid_seed(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=4294967295.0

static func same_record(left: Dictionary, right: Dictionary) -> bool:
	# JSON numbers load as floats; compare their serialized precision, not int tags.
	return JSON.parse_string(JSON.stringify(left))==JSON.parse_string(JSON.stringify(right))

static func matches_filter(record: Dictionary, weapon: String, tag: String) -> bool:
	return (weapon.is_empty() or record.weapons.any(func(entry):return entry.key==weapon)) and (tag.is_empty() or record.tags.has(tag))

func pair(enemy_fleet: Dictionary, player_loadout: Dictionary, battle_seed: int) -> Dictionary:
	return {"enemy_fleet":enemy_fleet.duplicate(true),"player_loadout":player_loadout.duplicate(true),"seed":battle_seed}

func pair_by_index(enemy_fleets: Array, player_loadouts: Array, battle_seed: int) -> Array:
	var result: Array = []
	for index in range(mini(enemy_fleets.size(),player_loadouts.size())):result.append(pair(enemy_fleets[index],player_loadouts[index],battle_seed+index))
	return result

func create_battle(matchup: Dictionary) -> Dictionary:
	# Explicit future-runner boundary. Generation never invokes this adapter.
	if not matchup.get("player_loadout") is Dictionary or not matchup.get("enemy_fleet") is Dictionary:return {"error":"invalid_pair"}
	var player_loadout: Dictionary = matchup.player_loadout
	if not validate_record(player_loadout):return {"error":"invalid_player_loadout"}
	var enemy_fleet: Dictionary = matchup.enemy_fleet
	if not enemy_fleet.get("generation_options") is Dictionary or not valid_seed(enemy_fleet.get("seed")):return {"error":"invalid_enemy_fleet"}
	var enemy_analyzer := EnemySimulator.new(db)
	var enemy_replay := enemy_analyzer.replay(enemy_fleet)
	if enemy_replay.has("error") or not same_record(enemy_replay,enemy_fleet):return {"error":"invalid_enemy_fleet"}
	# Private database uses the same schema. No edits to formal groups or levels.
	var private_db := ShipDatabase.new()
	private_db.data = db.data.duplicate(true)
	private_db.equipment = private_db.data.equipment
	private_db.enemies = private_db.data.enemies
	private_db.groups = private_db.data.groups
	private_db.levels = private_db.data.levels
	private_db.config = private_db.data.config
	private_db.defaults = private_db.data.defaults
	private_db.ships = private_db.data.ship
	return {"game":start_validated_battle(private_db,enemy_fleet,player_loadout,int(matchup.get("seed",0)))}

static func start_validated_battle(private_db: ShipDatabase, enemy_fleet: Dictionary, player_loadout: Dictionary, battle_seed: int, mode := "exact", prepared_profile: Dictionary = {}, power_multiplier := 1.0) -> BattleGame:
	# Only callers that validated both immutable input records may use this helper.
	# A serial runner can reuse its private database; each game still owns fresh state.
	var group_id := str(int(private_db.levels[0].groups[0].id))
	private_db.groups[group_id] = enemy_fleet.duplicate(true)
	private_db.levels[0].groups = [{"id":int(group_id),"position":0.0}]
	for ratio in ["lifeRatio","atkRatio","resRatio"]:private_db.levels[0][ratio] = 1.0
	var game = preload("res://scripts/balance_game.gd").new(private_db)
	game.simulation_mode = mode
	game.player_power_multiplier = power_multiplier
	if prepared_profile.is_empty():apply_progress(game,int(player_loadout.generation_options.cleared_through))
	else:game.profile = prepared_profile.duplicate(true)
	game.profile.selectedShip = player_loadout.ship
	if prepared_profile.is_empty():game.profile.loadout = player_loadout.equipment.duplicate(true)
	game.rng.seed = battle_seed
	game.start(1,false)
	game.spawn_group()
	return game
