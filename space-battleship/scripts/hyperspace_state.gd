extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const R=preload("res://scripts/hyperspace_random.gd")
const Filter=preload("res://scripts/hyperspace_filter.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const VERSION:=4

static func fresh(c: Dictionary) -> Dictionary:
	var materials: Dictionary={}
	for route in c.routes.values():materials[route.material]=0
	return {"version":VERSION,"round_id":1,"next_run":1,"settled_run":0,"energy":float(c.energy_cap),"pending_time":0.0,"materials":materials,"history":{},"inventory":Bag.fresh(),"active":{},"auto":{"enabled":false,"route":"","level":0,"crew_id":""},"unlocked_drones":false,"blocked":false,"ultimate_cores":0,"hanging_modules":Rewards.module_progress(c),"random_state":R.initial_state(),"command_seq":1,"last_command":{},"filter":Filter.fresh(),"legendary_seen":[],"legendary_collection":[]}

static func schema() -> Dictionary:
	var affix: Dictionary={"key":"s","tier":"i","value":"n","locked":"b"}
	var drone: Dictionary={"id":"s","origin_quality":"s","weapon":"s","level":"i","planet_id":"s","hanging_slots":"i","preserved_hanging_slots":"i","omen":"b","forge_revision":"i","forge_rng_state":"s","legendary":"b","ultimate":"b","blue_source_bonus":"b","legendary_effect":{"effect_id":"s","parameters":{"*":"n"}},"ultimate_affix":affix,"affixes":[affix],"hangings":["s"]}
	var reward: Dictionary={"drone":drone,"materials":{"*":"i"},"ultimate_cores":"i","hanging_rewards":{"*":"i"}}
	return {"version":"i","round_id":"i","next_run":"i","settled_run":"i","energy":"n","pending_time":"n","late_supply_work":"n","materials":{"*":"i"},"history":{"*":{"*":"n"}},"inventory":{"drones":{"*":drone},"warehouse":["s"],"overflow":["s"],"equipped":["s"],"favorites":["s"],"presets":[{"name":"s","drone_ids":["s"],"hanging_loadouts":{"*":["s"]}}],"sealed":{"*":"i"},"reforge_count":"i","generation":"i"},"active":{"round_id":"i","run_id":"i","status":"s","mode":"s","route":"s","level":"i","crew_id":"s","return_state":preload("res://scripts/hyperspace_main_return.gd").schema(),"return_journey":{"stage":"i","distance":"n","groupIndex":"i","state":"i","guardArrived":"b","retreatBossPending":"b","pendingUnlocks":["s"],"loop":"b"},"ticket":"n","duration":"n","work":"n","reward":reward},"auto":{"enabled":"b","route":"s","level":"i","crew_id":"s"},"unlocked_drones":"b","blocked":"b","ultimate_cores":"i","hanging_modules":{"*":{"unlocked":"b","level":"i","exp":"n"}},"random_state":"s","command_seq":"i","last_command":{"seq":"i","fingerprint":"s","result_json":"s"},"filter":{"version":"i","enabled":"b","mode":"s","action":"s","conditions":[{"field":"s","value":"filter_value","key":"s","tier":"i"}]},"legendary_seen":["s"],"legendary_collection":["s"]}

static func valid_reward(reward: Dictionary,route: String,c: Dictionary) -> bool:
	if not c.routes.has(route) or not reward.get("drone") is Dictionary or not reward.get("materials") is Dictionary or not reward.get("hanging_rewards") is Dictionary:return false
	if not reward.drone.is_empty() and (not Bag.valid_drone(reward.drone,c) or reward.drone.weapon!=c.routes[route].weapon):return false
	if not C.integer(reward.get("ultimate_cores")) or reward.ultimate_cores<0 or reward.ultimate_cores>1:return false
	for key in reward.materials:
		if key!=c.routes[route].material or not C.integer(reward.materials[key]) or reward.materials[key]<0:return false
	for key in reward.hanging_rewards:
		if not c.hanging_modules.has(key) or not C.integer(reward.hanging_rewards[key]) or reward.hanging_rewards[key]<0 or reward.hanging_rewards[key]>10:return false
	return true

static func valid(s: Dictionary,c: Dictionary,max_stage: int) -> bool:
	if s.get("version")!=VERSION:return false
	if not R.valid_state(s.get("random_state")) or not C.integer(s.get("ultimate_cores")) or s.ultimate_cores<0 or not C.integer(s.get("command_seq")) or s.command_seq<1:return false
	if not s.get("last_command") is Dictionary or not s.get("filter") is Dictionary or not Filter.valid(s.filter,c):return false
	if not s.last_command.is_empty():
		if not C.integer(s.last_command.get("seq")) or s.last_command.seq!=s.command_seq-1 or not s.last_command.get("fingerprint") is String or not s.last_command.get("result_json") is String or s.last_command.result_json.length()>65536:return false
		if not JSON.parse_string(s.last_command.result_json) is Dictionary:return false
	if not s.get("hanging_modules") is Dictionary or s.hanging_modules.size()!=c.hanging_modules.size():return false
	for key in s.hanging_modules:
		var progress=s.hanging_modules[key]
		if not c.hanging_modules.has(key) or not progress is Dictionary or not progress.get("unlocked") is bool or not C.integer(progress.get("level")) or progress.level<0 or not C.number(progress.get("exp")) or progress.exp<0:return false
		var needed:=float(c.hanging_modules[key].base_exp)*pow(1.0+float(c.hanging_modules[key].exp_growth),int(progress.level))
		if not is_finite(needed) or progress.exp>=needed:return false
	for field in ["legendary_seen","legendary_collection"]:
		if not s.get(field) is Array:return false
		var seen: Dictionary={}
		for key in s[field]:
			if not c.legendary_effects.has(key) or seen.has(key):return false
			seen[key]=true
	for key in s.legendary_collection:
		if not s.legendary_seen.has(key):return false
	for key in ["round_id","next_run","settled_run"]:
		if not C.integer(s.get(key)):return false
	if s.round_id<1 or s.next_run<1 or s.settled_run<0 or s.settled_run>=s.next_run:return false
	if not C.number(s.get("pending_time")) or s.pending_time<0:return false
	if s.has("late_supply_work") and (not C.number(s.late_supply_work) or s.late_supply_work<0 or not c.has("late_supply_ramp_seconds") or s.late_supply_work>float(c.late_supply_ramp_seconds)):return false
	if not C.number(s.get("energy")) or s.energy<0:return false # Refund may exceed cap.
	for key in ["unlocked_drones","blocked"]:
		if not s.get(key) is bool:return false
	if not s.get("materials") is Dictionary or not s.get("history") is Dictionary or not s.get("inventory") is Dictionary or not s.get("active") is Dictionary or not s.get("auto") is Dictionary:return false
	var known_materials: Array=c.routes.values().map(func(r):return r.material)
	if s.materials.size()!=known_materials.size():return false
	for key in s.materials:
		if not known_materials.has(key) or not C.integer(s.materials[key]) or s.materials[key]<0:return false
	if not Bag.valid(s.inventory,c):return false
	for drone in s.inventory.drones.values():
		if int(drone.level)>max_stage:return false
	for route in s.history:
		if not c.routes.has(route) or not s.history[route] is Dictionary:return false
		for level in s.history[route]:
			if not level is String or not level.is_valid_int() or str(int(level))!=level or int(level)<int(c.minimum_level) or int(level)>max_stage or not C.number(s.history[route][level]) or s.history[route][level]<=0:return false
	var auto: Dictionary=s.auto
	if not auto.get("enabled") is bool or not auto.get("route") is String or not C.integer(auto.get("level")) or not auto.get("crew_id") is String:return false
	if auto.enabled and (not c.routes.has(auto.route) or auto.level<int(c.minimum_level) or auto.level>max_stage or auto.crew_id.is_empty()):return false
	if s.next_run!=s.settled_run+(1 if s.active.is_empty() else 2):return false
	if not s.active.is_empty():
		var a: Dictionary=s.active
		for key in ["round_id","run_id","level"]:
			if not C.integer(a.get(key)):return false
		if a.round_id!=s.round_id or a.run_id!=s.next_run-1 or a.run_id<=s.settled_run:return false
		if not a.get("status") in ["started","completed_pending"] or not a.get("mode") in ["manual","auto"] or not c.routes.has(a.get("route")) or a.level<int(c.minimum_level) or a.level>max_stage:return false
		for key in ["ticket","duration","work"]:
			if not C.number(a.get(key)) or a[key]<0:return false
		if not a.get("return_journey") is Dictionary:return false
		if a.has("return_state"):
			if not a.return_state is Dictionary or (a.mode=="manual" and a.status=="started" and a.return_state.is_empty()):return false
			if not a.return_state.is_empty() and (a.mode!="manual" or a.status!="started" or not preload("res://scripts/hyperspace_main_return.gd").valid(a.return_state,a.return_journey,max_stage)):return false
		if not a.get("crew_id") is String or (a.mode=="auto" and a.crew_id.is_empty()):return false
		if not a.get("reward") is Dictionary:return false
		if a.mode=="auto" and (a.duration<float(c.minimum_duration) or a.work>a.duration):return false
		if a.status=="started" and not a.reward.is_empty():return false
		if a.status=="completed_pending":
			if not valid_reward(a.reward,a.route,c):return false
			if not a.reward.drone.is_empty() and (a.reward.drone.level!=a.level or a.reward.drone.id!="space:%d:%d"%[int(a.round_id),int(a.run_id)]):return false
	return true
