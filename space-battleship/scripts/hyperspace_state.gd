extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const VERSION:=1

static func fresh(c: Dictionary) -> Dictionary:
	var materials: Dictionary={}
	for route in c.routes.values():materials[route.material]=0
	return {"version":VERSION,"round_id":1,"next_run":1,"settled_run":0,"energy":float(c.energy_cap),"pending_time":0.0,"materials":materials,"history":{},"inventory":Bag.fresh(),"active":{},"auto":{"enabled":false,"route":"","level":0,"crew_level":0},"unlocked_drones":false,"blocked":false}

static func schema() -> Dictionary:
	var affix: Dictionary={"key":"s","tier":"i","value":"n","locked":"b"}
	var drone: Dictionary={"id":"s","origin_quality":"s","weapon":"s","level":"i","legendary":"b","ultimate":"b","blue_source_bonus":"b","legendary_effect":{"effect_id":"s","value":"n"},"ultimate_affix":affix,"affixes":[affix],"hangings":["s"]}
	var reward: Dictionary={"drone":drone,"materials":{"*":"i"}}
	return {"version":"i","round_id":"i","next_run":"i","settled_run":"i","energy":"n","pending_time":"n","materials":{"*":"i"},"history":{"*":{"*":"n"}},"inventory":{"drones":{"*":drone},"warehouse":["s"],"overflow":["s"],"equipped":["s"],"favorites":["s"],"presets":[{"name":"s","drone_ids":["s"],"hanging_loadouts":{"*":["s"]}}],"sealed":{"*":"i"},"reforge_count":"i","generation":"i"},"active":{"round_id":"i","run_id":"i","status":"s","mode":"s","route":"s","level":"i","ticket":"n","duration":"n","work":"n","reward":reward},"auto":{"enabled":"b","route":"s","level":"i","crew_level":"i"},"unlocked_drones":"b","blocked":"b"}

static func valid_reward(reward: Dictionary,route: String,c: Dictionary) -> bool:
	if not c.routes.has(route) or not reward.get("drone") is Dictionary or not Bag.valid_drone(reward.drone,c) or reward.drone.weapon!=c.routes[route].weapon:return false
	if not reward.get("materials") is Dictionary:return false
	# Success-only dedicated material; ordinary drops remain the combat owner's job.
	for key in reward.materials:
		if key!=c.routes[route].material or not C.integer(reward.materials[key]) or reward.materials[key]<0:return false
	return true

static func valid(s: Dictionary,c: Dictionary,max_stage: int) -> bool:
	if s.get("version")!=VERSION:return false
	for key in ["round_id","next_run","settled_run"]:
		if not C.integer(s.get(key)):return false
	if s.round_id<1 or s.next_run<1 or s.settled_run<0 or s.settled_run>=s.next_run:return false
	if not C.number(s.get("pending_time")) or s.pending_time<0:return false
	if not C.number(s.get("energy")) or s.energy<0:return false # Refund may exceed cap.
	for key in ["unlocked_drones","blocked"]:
		if not s.get(key) is bool:return false
	if not s.get("materials") is Dictionary or not s.get("history") is Dictionary or not s.get("inventory") is Dictionary or not s.get("active") is Dictionary or not s.get("auto") is Dictionary:return false
	var known_materials: Array=c.routes.values().map(func(r):return r.material)
	if s.materials.size()!=known_materials.size():return false
	for key in s.materials:
		if not known_materials.has(key) or not C.integer(s.materials[key]) or s.materials[key]<0:return false
	if not Bag.valid(s.inventory,c):return false
	for route in s.history:
		if not c.routes.has(route) or not s.history[route] is Dictionary:return false
		for level in s.history[route]:
			if not level is String or not level.is_valid_int() or str(int(level))!=level or int(level)<int(c.minimum_level) or int(level)>max_stage or not C.number(s.history[route][level]) or s.history[route][level]<=0:return false
	var auto: Dictionary=s.auto
	if not auto.get("enabled") is bool or not auto.get("route") is String or not C.integer(auto.get("level")) or not C.integer(auto.get("crew_level")) or auto.crew_level<0:return false
	if auto.enabled and (not c.routes.has(auto.route) or auto.level<int(c.minimum_level) or auto.level>max_stage):return false
	if s.next_run!=s.settled_run+(1 if s.active.is_empty() else 2):return false
	if not s.active.is_empty():
		var a: Dictionary=s.active
		for key in ["round_id","run_id","level"]:
			if not C.integer(a.get(key)):return false
		if a.round_id!=s.round_id or a.run_id!=s.next_run-1 or a.run_id<=s.settled_run:return false
		if not a.get("status") in ["started","completed_pending"] or not a.get("mode") in ["manual","auto"] or not c.routes.has(a.get("route")) or a.level<int(c.minimum_level) or a.level>max_stage:return false
		for key in ["ticket","duration","work"]:
			if not C.number(a.get(key)) or a[key]<0:return false
		if not a.get("reward") is Dictionary:return false
		if a.mode=="auto" and (a.duration<float(c.minimum_duration) or a.work>a.duration):return false
		if a.status=="started" and not a.reward.is_empty():return false
		if a.status=="completed_pending" and (not valid_reward(a.reward,a.route,c) or a.reward.drone.level!=a.level or a.reward.drone.id!="space:%d:%d"%[int(a.round_id),int(a.run_id)]):return false
	return true
