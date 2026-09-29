extends RefCounted
## Bounded adaptive execution. Combat still uses the existing pure-logic path.
const Sampling := preload("res://scripts/fleet_battle_sampling.gd")
var sampling: RefCounted
var active_pair := -1
var validation_jobs: Array = []
const PlayerGenerator := preload("res://scripts/player_loadout_generator.gd")
const EnemyGenerator := preload("res://scripts/enemy_fleet_simulator.gd")
const RunDatabase := preload("res://scripts/balance_database.gd")
const Metrics := preload("res://scripts/balance_metrics.gd")
const STEP := 1.0/60.0 # Existing FAST scheduler requires this exact step.
var policy: Dictionary
var source: ShipDatabase
var database: ShipDatabase
var enemies: Array = []
var players: Array = []
var enemy_errors: Array = []
var player_errors: Array = []
var profiles: Array = []
var enemy_validator: RefCounted
var player_validator: RefCounted
var config := {}
var status := "idle"
var error := ""
var total := 0
var completed := 0
var validation_index := 0
var game: BattleGame
var metrics: RefCounted
var combat_enemies: Array = []
var elapsed := 0.0
var work_usec := 0
var max_hp := 0.0
var max_enemy_hp := 0.0
var current := {}
var results: Array = []
var aggregate := {}
var pair_aggregate := {}
var directory := ""
var trials_file: FileAccess
var pairs_file: FileAccess

func _init(database_source: ShipDatabase) -> void:
	source = database_source
	policy = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_fleet_analysis.json")).batch
	aggregate = empty_aggregate()

static func empty_aggregate() -> Dictionary:
	return {"attempted_count":0,"battle_count":0,"wins":0,"errors":0,"timeouts":0,"stopped":0,"win_rate":null,"avg_battle_time":null,"avg_player_hp_ratio":null,"avg_enemy_hp_ratio":null}

func busy() -> bool:return status in ["validating","running"]

func start(enemy_rows: Array, player_rows: Array, options: Dictionary = {}) -> String:
	if busy():return "already_running"
	if not source.mon_source_error.is_empty():return source.mon_source_error
	var request: Dictionary = policy.defaults.duplicate(true)
	request.merge(options,true)
	for key in ["runs","seed","max_seconds","max_total","max_per_pair","samples_per_tag"]:
		var value = request.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):return "invalid_input"
	if request.runs!=floorf(request.runs) or request.runs<1 or request.runs>policy.max_repeats:return "invalid_input"
	for key in ["max_total","max_per_pair","samples_per_tag"]:
		if request[key]<1 or request[key]!=floorf(request[key]):return "invalid_input"
	if request.max_total>policy.max_battles or request.max_per_pair>policy.max_repeats or request.samples_per_tag>policy.sampling.max_samples_per_tag or request.runs>request.max_per_pair:return "invalid_input"
	if request.seed!=floorf(request.seed) or absf(float(request.seed))>2147483647:return "invalid_input"
	if request.max_seconds<=0 or request.max_seconds>policy.max_seconds or request.mode not in ["fast","exact"]:return "invalid_input"
	var power: Variant=request.get("power_multiplier",1.0)
	if not (power is int or power is float) or not is_finite(float(power)):return "invalid_input"
	if float(power)!=1.0 and float(power)!=2.0 and float(power)!=3.0:return "invalid_input"
	var module_delta: Variant=request.get("module_delta",0)
	if not (module_delta is int or module_delta is float) or not is_finite(float(module_delta)) or module_delta!=floorf(module_delta) or module_delta<0 or module_delta>1000:return "invalid_input"
	if int(module_delta)>0 and float(power)!=1.0:return "invalid_input"
	if enemy_rows.is_empty() or player_rows.is_empty():return "empty_selection"
	if not request.get("focus_pairs",[]) is Array:return "invalid_input"
	for focus in request.get("focus_pairs",[]):
		if not focus is Dictionary:return "invalid_input"
		for key in ["enemy_index","player_index"]:
			var value=focus.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(value) or value<0 or value>=(enemy_rows.size() if key=="enemy_index" else player_rows.size()):return "invalid_input"
	if request.get("focus_pairs",[]).size()>mini(int(policy.sampling.max_pairs),int(request.max_total)):return "invalid_input"
	if request.has("explicit_pairs"):
		if not request.explicit_pairs is Array or request.explicit_pairs.is_empty() or request.explicit_pairs.size()>int(policy.sampling.max_pairs):return "invalid_input"
		var explicit_seen := {}
		for pair in request.explicit_pairs:
			if not pair is Dictionary:return "invalid_input"
			for key in ["enemy_index","player_index","runs"]:
				var value=pair.get(key)
				if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(value) or value<0:return "invalid_input"
			if pair.enemy_index>=enemy_rows.size() or pair.player_index>=player_rows.size() or pair.runs<1 or pair.runs>request.max_per_pair:return "invalid_input"
			var identity := "%d:%d" % [pair.enemy_index,pair.player_index]
			if explicit_seen.has(identity):return "invalid_input"
			explicit_seen[identity]=true
	if request.get("retest_saved_inputs",false) and (request.get("data_sha256","")!=JSON.stringify(source.data).sha256_text() or not request.has("explicit_pairs")):return "invalid_input"
	reset()
	config = request
	total = int(request.max_total)
	enemies = enemy_rows.duplicate(true)
	players = player_rows.duplicate(true)
	sampling=Sampling.new(policy.sampling,config)
	sampling.build(enemies,players)
	enemy_errors.resize(enemies.size())
	player_errors.resize(players.size())
	profiles.resize(players.size())
	var seen := {}
	for pair in sampling.pairs:
		for side in ["enemy","player"]:
			var index: int=pair[side+"_index"]
			var key: String=side+str(index)
			if not seen.has(key):
				seen[key]=true
				validation_jobs.append({"side":side,"index":index})
	database = RunDatabase.new() # Read once per batch, never once per fight.
	database.data = source.data.duplicate(true)
	database.equipment = database.data.equipment
	database.enemies = database.data.enemies
	database.groups = database.data.groups
	database.levels = database.data.levels
	database.config = database.data.config
	database.defaults = database.data.defaults
	database.ships = database.data.ship
	# Validators use the unmodified source snapshot; combat changes only private group/level.
	enemy_validator = EnemyGenerator.new(source)
	player_validator = PlayerGenerator.new(source)
	directory = str(request.get("directory",ProjectSettings.globalize_path("res://../test/work/fleet_battles"))).path_join("batch_%s_%s" % [str(Time.get_unix_time_from_system()).replace(".","_"),Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return fail_output()
	trials_file = FileAccess.open(directory.path_join("battles.jsonl"),FileAccess.WRITE)
	pairs_file = FileAccess.open(directory.path_join("pairs.jsonl"),FileAccess.WRITE)
	if trials_file==null or pairs_file==null:return fail_output()
	var inputs := FileAccess.open(directory.path_join("inputs.json"),FileAccess.WRITE)
	if inputs==null:return fail_output()
	var names := {"equipment":{}}
	for key in source.equipment:
		var binding := UIText.data_key("equipment",str(key),"name")
		names.equipment[str(key)]=UIText.t(binding) if not binding.is_empty() else str(source.equip(str(key),1).get("name",""))
	inputs.store_string(JSON.stringify({"config":config,"sampling_policy":policy.sampling,"sampling":sampling.report(),"display_names":names,"enemy_fleets":enemies,"player_loadouts":players,"data_sha256":JSON.stringify(source.data).sha256_text(),"engine":Engine.get_version_info().string,"step_seconds":STEP},"  "))
	inputs.flush()
	if inputs.get_error()!=OK:return fail_output()
	status = "validating"
	return ""

func fail_output() -> String:
	error = "output_error"
	status = "error"
	release_game()
	trials_file = null
	pairs_file = null
	database=null
	enemy_validator=null
	player_validator=null
	profiles.clear()
	return error

func process(budget_usec := -1) -> void:
	if not busy():return
	var deadline := Time.get_ticks_usec() + (int(policy.frame_budget_usec) if budget_usec<0 else budget_usec)
	while busy() and Time.get_ticks_usec()<deadline:
		if status=="validating":
			validate_next()
			continue
		if game==null:
			begin_battle()
			if not busy() or game==null:continue
		var started := Time.get_ticks_usec()
		game.tick(STEP)
		work_usec += Time.get_ticks_usec()-started
		elapsed += STEP
		if not is_finite(float(game.player.armour)) or not is_finite(enemy_remaining()):finish_battle("error","nonfinite_state")
		elif metrics.deaths>0 or game.player.armour<=0:finish_battle("loss")
		elif game.state==BattleGame.State.LEVEL_CLEAR:finish_battle("win")
		elif game.state!=BattleGame.State.COMBAT:finish_battle("error","unexpected_state")
		elif elapsed+0.000000001>=float(config.max_seconds):finish_battle("timeout")
		elif work_usec>int(policy.max_work_usec):finish_battle("error","work_limit")

func validate_next() -> void:
	if validation_index>=validation_jobs.size():status="running";return
	var job: Dictionary=validation_jobs[validation_index]
	if job.side=="enemy":
		var row = enemies[int(job.index)]
		var message := "invalid_enemy_fleet"
		if row is Dictionary and row.get("generation_options") is Dictionary and PlayerGenerator.valid_seed(row.get("seed")):
			var replay: Dictionary = enemy_validator.replay(row)
			if not replay.has("error") and PlayerGenerator.same_record(replay,row):message=""
			elif config.get("retest_saved_inputs",false) and valid_enemy_snapshot(row,enemy_validator):message=""
		enemy_errors[int(job.index)]=message
	else:
		var row = players[int(job.index)]
		var valid: bool = row is Dictionary and player_validator.validate_record(row)
		player_errors[int(job.index)]="" if valid else "invalid_player_loadout"
		var profile: Dictionary=player_validator.rules.profile.duplicate(true) if valid else {}
		if valid and int(config.get("module_delta",0))>0:
			profile=PlayerGenerator.upgraded_profile(source,row,profile,int(config.module_delta))
			if profile.has("error"):
				player_errors[int(job.index)]=str(profile.error)
				profile={}
		profiles[int(job.index)]=profile
	validation_index += 1
	if validation_index==validation_jobs.size():
		# Release validation projections before running; each input was checked once.
		enemy_validator=null
		player_validator=null
		status="running"

static func valid_enemy_snapshot(row: Dictionary,validator: RefCounted) -> bool:
	# The data hash was checked at start. Old layout policies may change replay,
	# but combat still consumes these original slots and current enemy definitions.
	if not row.get("slots") is Array or row.slots.size()!=validator.slot_count or not row.get("composition") is Dictionary:return false
	if not PlayerGenerator.valid_seed(row.get("seed")) or not row.get("generation_options") is Dictionary:return false
	if not row.generation_options.get("available_enemies") is Array:return false
	var composition := {}
	var strength := 0.0
	var count := 0
	for value in row.slots:
		if value==null:continue
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(value):return false
		var id := str(int(value))
		if not validator.projections.has(id) or not row.generation_options.get("available_enemies",[]).has(id):return false
		composition[id]=int(composition.get(id,0))+1
		strength+=float(validator.projections[id].strength)
		count+=1
	if count<1 or row.get("count")!=count or row.get("signature")!=validator.signature_for(row):return false
	if not PlayerGenerator.same_record(composition,row.composition):return false
	if not (row.get("strength") is int or row.get("strength") is float) or not is_equal_approx(float(row.strength),strength):return false
	return true

func begin_battle() -> void:
	if completed>=total:finalize("budget_reached");return
	active_pair=sampling.choose()
	if active_pair<0:finalize("completed");return
	var pair: Dictionary=sampling.pairs[active_pair]
	var enemy_index: int=pair.enemy_index
	var player_index: int=pair.player_index
	var repeat_index := int(pair.summary.get("attempted_count",0))
	var enemy = enemies[enemy_index]
	var player = players[player_index]
	current = {"enemy_fleet_id":"enemy_"+str(enemy.get("signature","invalid_%d" % enemy_index)).sha256_text() if enemy is Dictionary else "invalid_%d" % enemy_index,"player_loadout_id":str(player.get("loadout_id","invalid_%d" % player_index)) if player is Dictionary else "invalid_%d" % player_index,"enemy_index":enemy_index,"player_index":player_index,"repeat_index":repeat_index,"seed":int(config.seed)+completed,"simulation_mode":config.mode,"win":null,"battle_time":0.0,"player_hp_ratio":null,"enemy_hp_ratio":null,"player_deaths":0,"damage_by_weapon":{}}
	if repeat_index==0:
		pair.summary=empty_aggregate()
		pair.summary.merge({"enemy_fleet_id":current.enemy_fleet_id,"player_loadout_id":current.player_loadout_id,"enemy_index":enemy_index,"player_index":player_index})
	pair_aggregate=pair.summary
	current.sequence=completed
	current.test_reasons=pair.reasons.duplicate()
	elapsed=0
	work_usec=0
	if not str(enemy_errors[enemy_index]).is_empty():
		finish_battle("error",enemy_errors[enemy_index])
		return
	if not str(player_errors[player_index]).is_empty():
		finish_battle("error",player_errors[player_index])
		return
	var started := Time.get_ticks_usec()
	game = PlayerGenerator.start_validated_battle(database,enemy,player,current.seed,config.mode,profiles[player_index],float(config.get("power_multiplier",1.0)))
	game.skip_empty_batch_research=true
	metrics = Metrics.new()
	metrics.timeline.configure(config.max_seconds,config.max_seconds,2,8)
	metrics.initialize(game)
	game.metrics=metrics
	metrics.encounter_start=0.0
	for target in game.enemies:metrics.born[target.uid]=0.0
	# Retreat clears game.enemies; keep references to retain actual enemy HP on defeat.
	combat_enemies=game.enemies.duplicate()
	max_hp=game.stat("armour")
	max_enemy_hp=enemy_remaining()
	work_usec=Time.get_ticks_usec()-started
	if max_hp<=0 or max_enemy_hp<=0:finish_battle("error","invalid_initial_hp")

func enemy_remaining() -> float:
	var hp := 0.0
	for enemy in combat_enemies:hp+=maxf(0,float(enemy.hp))
	return hp

func finish_battle(outcome: String, message := "") -> void:
	current.status=outcome
	current.error=message
	current.win = outcome=="win" if outcome in ["win","loss"] else null
	current.battle_time=elapsed
	if game!=null:
		current.player_hp_ratio=clampf(float(game.player.armour)/maxf(max_hp,0.000001),0,1)
		current.enemy_hp_ratio=clampf(enemy_remaining()/maxf(max_enemy_hp,0.000001),0,1)
		current.player_deaths=int(metrics.deaths)
		current.damage_by_weapon=metrics.damage.duplicate(true)
	update_aggregate(aggregate,current)
	update_aggregate(pair_aggregate,current)
	sampling.observe(sampling.pairs[active_pair],current)
	results.append(current)
	if results.size()>int(policy.retained_results):results.pop_front()
	completed+=1
	trials_file.store_line(JSON.stringify(current))
	if completed%int(policy.flush_every)==0:
		trials_file.flush()
		pairs_file.flush()
	release_game()
	current={}
	if trials_file.get_error()!=OK or pairs_file.get_error()!=OK:
		fail_output()
		return
	if completed==total:finalize("stopped" if outcome=="stopped" else "budget_reached")

static func update_aggregate(summary: Dictionary, row: Dictionary) -> void:
	summary.attempted_count+=1
	if row.status not in ["win","loss"]:
		summary[{"error":"errors","timeout":"timeouts","stopped":"stopped"}[row.status]]+=1
		return
	summary.battle_count+=1
	if row.win:summary.wins+=1
	summary.win_rate=float(summary.wins)/summary.battle_count
	for metric in ["battle_time","player_hp_ratio","enemy_hp_ratio"]:
		var key: String = "avg_"+metric
		var old := 0.0 if summary[key]==null else float(summary[key])
		summary[key]=old+(float(row[metric])-old)/summary.battle_count

func stop() -> void:
	if not busy():return
	if game!=null:finish_battle("stopped")
	if busy():finalize("stopped")

func finalize(next_status: String) -> void:
	status=next_status
	for pair in sampling.pairs:
		var record: Dictionary=pair.summary.duplicate(true)
		record.merge({"enemy_index":pair.enemy_index,"player_index":pair.player_index,"focus":pair.focus,"enemy_tags":pair.enemy_tags,"player_tags":pair.player_tags,"test_reasons":pair.reasons,"stop_reason":pair.stop_reason if not pair.stop_reason.is_empty() else next_status})
		var enemy= enemies[int(pair.enemy_index)]
		var player= players[int(pair.player_index)]
		if enemy is Dictionary:
			record.enemy_fleet_id="enemy_"+str(enemy.get("signature","")).sha256_text()
			record.enemy_tags=enemy.get("primary_tags",[]).duplicate()+enemy.get("secondary_tags",[])
		if player is Dictionary:
			record.player_loadout_id=player.get("loadout_id","")
			record.player_tags=player.get("tags",[]).duplicate()
			record.weapons=player.get("weapons",[]).duplicate(true)
		record.time_m2=pair.time_m2
		pairs_file.store_line(JSON.stringify(record))
	trials_file.flush()
	pairs_file.flush()
	if trials_file.get_error()!=OK or pairs_file.get_error()!=OK:
		fail_output()
		return
	var file := FileAccess.open(directory.path_join("summary.json"),FileAccess.WRITE)
	if file==null:
		fail_output()
		return
	file.store_string(JSON.stringify({"status":status,"budget":total,"completed_count":completed,"remaining_budget":total-completed,"sampling":sampling.report(),"aggregate":aggregate,"config":config},"  "))
	file.flush()
	if file.get_error()!=OK:
		fail_output()
		return
	trials_file=null
	pairs_file=null
	enemy_validator=null
	player_validator=null
	profiles.clear()
	database=null

func release_game() -> void:
	if game!=null:game.metrics=null
	game=null
	metrics=null
	combat_enemies.clear()

func reset() -> void:
	if busy():stop()
	release_game()
	database=null
	enemy_validator=null
	player_validator=null
	enemies.clear()
	players.clear()
	enemy_errors.clear()
	player_errors.clear()
	profiles.clear()
	results.clear()
	aggregate=empty_aggregate()
	pair_aggregate={}
	config={}
	current={}
	status="idle"
	error=""
	completed=0
	total=0
	validation_index=0
	sampling=null
	active_pair=-1
	validation_jobs.clear()
	directory=""
	trials_file=null
	pairs_file=null
