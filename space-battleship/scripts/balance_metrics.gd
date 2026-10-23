extends RefCounted
const N = preload("res://scripts/growth_number.gd")
const Timeline := preload("res://scripts/balance_timeline.gd")
## Lab-only cumulative statistics. Enemy records live only until death/retreat.
const THRESHOLDS := {"dominance":0.70,"unused":0.01,"ttk_low":0.25,"ttk_high":60.0,"idle_seconds":300.0,"surplus_minutes":30.0}
var time := 0.0
var combat_seconds := 0.0
var damage := {}
var income := {}
var spending := {}
var spending_by_system := {}
var uses := {}
var usage_seconds := {}
var last_used := {}
var born := {}
var ttk_sum := 0.0
var kills := 0
var boss_ttk_sum := 0.0
var boss_kills := 0
var encounter_start := 0.0
var received: Variant = 0.0
var shield_absorbed: Variant = 0.0
var health_lost: Variant = 0.0
var min_health: Variant = null
var min_shield: Variant = null
var deaths := 0
var first_death: Variant = null
var upgrades := 0
var last_upgrade := 0.0
var interval_sum := 0.0
var interval_count := 0
var longest_upgrade_gap := 0.0
var unaffordable_seconds := 0.0
var longest_unaffordable := 0.0
var overflow_seconds := {}
var longest_overflow := {}
var timeline = Timeline.new()
var current_stage := 1
var normal_kills := 0
var normal_ttk_sum := 0.0
var spawn_count := 0
var spawn_hp: Variant = 0.0
var blocked_marked := false

func initialize(game: BattleGame) -> void:
	for key in BattleGame.WEAPON_KEYS:damage[key] = 0.0
	for id in game.economy.resources():
		income[id] = 0.0
		spending[id] = 0.0
	income.jewel_fragments = 0.0
	spending.jewel_fragments = 0.0
	for system in ["weapons","defence","scientists","reactor","jewels"]:
		spending_by_system[system] = {}
		for id in spending:spending_by_system[system][id] = 0.0
	for key in ["upgrade","research","scientists","reactor_levels","jewel_pickup","enhancement_levels","equipment_equip","ship_switch"]:uses[key] = 0
	min_health = game.player.armour
	min_shield = game.player.shield
	current_stage = game.stage
	timeline.discover(game,0,true)

func add(target: Dictionary, key: String, amount: Variant) -> void:
	target[key] = N.add(target.get(key,0.0),amount)

func use(key: String, count := 1) -> void:
	add(uses,key,count)
	last_used[key] = time
	var decisions := {"upgrade":"UPGRADE","equipment_equip":"EQUIP","ship_switch":"EQUIP","scientists":"PURCHASE","reactor_levels":"REACTOR_UPGRADE","enhancement_levels":"ENHANCEMENT_UPGRADE"}
	if count > 0 and decisions.has(key):timeline.record(decisions[key],time,current_stage,{"system":key,"count":count},true)
	if count > 0 and key in ["upgrade","research","reactor_levels","enhancement_levels"]:timeline.growth(time)

func spend(system: String, costs: Dictionary) -> void:
	if not spending_by_system.has(system):spending_by_system[system] = {}
	for id in costs:
		add(spending,str(id),costs[id])
		add(spending_by_system[system],str(id),costs[id])

func upgraded(count: int) -> void:
	if upgrades > 0:
		interval_sum += time-last_upgrade
		interval_count += 1
	longest_upgrade_gap = maxf(longest_upgrade_gap,time-last_upgrade)
	last_upgrade = time
	upgrades += count

func on_event(kind: String, payload: Dictionary) -> void:
	if kind == "collect":add(income,str(payload.id),payload.amount)
	elif kind == "upgrade":
		spend("weapons" if str(payload.slot).begins_with("weapons") else "defence",payload.cost)
		upgraded(int(payload.levels))
		use("upgrade")
	elif kind == "hightech_complete":use("research")
	elif kind == "jewel_pickup":use("jewel_pickup")
	elif kind == "module_changed":use("equipment_equip")
	elif kind == "ship_changed":use("ship_switch")

func sample(game: BattleGame, seconds: float, affordable: bool) -> void:
	current_stage = game.stage
	timeline.discover(game,time)
	# One bounded inventory scan per strategy decision, never a per-frame scan.
	for category in ["weapons","defence"]:
		var present := {}
		for entry in game.loadout_entries(category):
			if not str(entry.key).is_empty():present[str(entry.key)] = true
		for key in present:
			add(usage_seconds,key,seconds)
			last_used[key] = time
	if affordable:unaffordable_seconds = 0
	else:unaffordable_seconds += seconds
	longest_unaffordable = maxf(longest_unaffordable,unaffordable_seconds)
	if unaffordable_seconds >= 30 and not blocked_marked:
		timeline.record("RESOURCE_BLOCKED",time,game.stage,{"seconds":unaffordable_seconds})
		blocked_marked = true
	elif affordable:blocked_marked = false
	for id in game.economy.resources():
		var rate: Variant = N.divide(income.get(id,0),maxf(time/60.0,1.0))
		if N.compare(rate,0)>0 and N.compare(game.economy.balance(id),N.multiply(rate,THRESHOLDS.surplus_minutes))>0:
			add(overflow_seconds,str(id),seconds)
		else:overflow_seconds[id] = 0.0
		longest_overflow[id] = maxf(float(longest_overflow.get(id,0)),float(overflow_seconds[id]))

func report(game: BattleGame) -> Dictionary:
	var total: Variant = 0.0
	for value in damage.values():total = N.add(total,value)
	var shares := {}
	var utilization := {}
	var unused_for := {}
	var system_unused_for := {}
	for system in uses:system_unused_for[system] = time-float(last_used.get(system,0))
	for key in BattleGame.EQUIPMENT:
		utilization[key] = float(usage_seconds.get(key,0))/maxf(time,0.000001)
		unused_for[key] = time-float(last_used.get(key,0))
	for key in damage:shares[key] = N.ratio(damage[key],total)
	var per_minute := {}
	var resource_shares := {}
	for id in income:per_minute[id] = N.divide(income[id],maxf(time/60.0,0.000001))
	for system in spending_by_system:
		resource_shares[system] = {}
		for id in spending_by_system[system]:
			resource_shares[system][id] = N.ratio(spending_by_system[system][id],N.maximum(spending.get(id,0),0.000001))
	var ttk: Variant = ttk_sum/kills if kills > 0 else null
	var warnings := []
	for key in shares:
		if shares[key] > THRESHOLDS.dominance:warnings.append({"code":"weapon_dominance","key":key,"value":shares[key]})
	if time >= THRESHOLDS.idle_seconds:
		for key in utilization:
			if utilization[key] < THRESHOLDS.unused:warnings.append({"code":"equipment_unused","key":key,"value":utilization[key],"unlocked":game.profile.unlocked.has(key)})
		for system in ["upgrade","research","scientists","reactor_levels","jewel_pickup","enhancement_levels"]:
			if uses.get(system,0) == 0:warnings.append({"code":"system_unused","key":system})
	if ttk != null and (ttk < THRESHOLDS.ttk_low or ttk > THRESHOLDS.ttk_high):warnings.append({"code":"ttk_outside_range","value":ttk})
	var gap := maxf(longest_upgrade_gap,time-last_upgrade)
	if gap >= THRESHOLDS.idle_seconds:warnings.append({"code":"upgrade_gap","value":gap})
	if longest_unaffordable >= THRESHOLDS.idle_seconds:warnings.append({"code":"unaffordable","value":longest_unaffordable})
	for id in longest_overflow:
		if longest_overflow[id] >= THRESHOLDS.idle_seconds:warnings.append({"code":"resource_surplus","key":id,"value":longest_overflow[id]})
	var balance: Dictionary = game.economy.resources().duplicate()
	balance.jewel_fragments = game.economy.balance("jewel")
	return {"game_seconds":time,"final_stage":game.stage,"highest_stage":game.profile.highestLevel,"wave":game.group_index,
		"dps":N.divide(total,maxf(time,0.000001)),"combat_dps":N.divide(total,maxf(combat_seconds,0.000001)),"combat_seconds":combat_seconds,
		"damage":damage.duplicate(),"weapon_damage_share":shares,"ttk":ttk,"kills":kills,
		"boss_ttk":boss_ttk_sum/boss_kills if boss_kills > 0 else null,"boss_kills":boss_kills,"unfinished_enemies":born.size(),
		"normal_ttk":normal_ttk_sum/normal_kills if normal_kills > 0 else null,"normal_kills":normal_kills,
		"defence":{"damage_received":received,"shield_absorbed":shield_absorbed,"health_lost":health_lost,"min_health":min_health,"min_shield":min_shield,"deaths":deaths,"first_death":first_death},
		"resources":{"income":income.duplicate(),"spending":spending.duplicate(),"per_minute":per_minute,"balance":balance,"by_system":spending_by_system.duplicate(true),"system_share":resource_shares},
		"upgrades":upgrades,"upgrade_interval":interval_sum/interval_count if interval_count > 0 else null,"longest_upgrade_gap":gap,
		"system_uses":uses.duplicate(),"system_unused_seconds":system_unused_for,"equipment_utilization":utilization,"equipment_unused_seconds":unused_for,
		"unlocked":Array(game.profile.unlocked),"timeline":timeline.report(time),"anomalies":warnings,"thresholds":THRESHOLDS.duplicate()}
