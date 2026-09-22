extends RefCounted
## Bounded samples and event marks; exact decision counters survive event truncation.
var interval := 30.0
var max_samples := 1200
var max_events := 5000
var next_sample := 30.0
var samples := []
var events := []
var dropped_events := 0
var event_total := 0
var decisions := 0
var decision_actions := {}
var decision_bins := {}
var decision_bin_seconds := 600.0
var last_decision := -1.0
var decision_interval_sum := 0.0
var longest_decision_gap := 0.0
var last_growth := 0.0
var longest_growth_gap := 0.0
var choices := {}
var available := {}
var previous := {}
var marks := {}

func configure(duration: float, requested: float, sample_cap: int, event_cap: int) -> void:
	max_samples = clampi(sample_cap,2,2000)
	max_events = maxi(1,event_cap)
	interval = maxf(requested,ceilf(duration/float(max_samples-1)))
	next_sample = interval
	# Keep density storage within the same per-job budget as trend samples.
	# Long runs explicitly report wider windows; never label them as ten minutes.
	decision_bin_seconds = maxf(600.0,ceilf(duration/(600.0*(max_samples-1)))*600.0)

func record(kind: String, time: float, stage: int, data: Dictionary = {}, decision := false) -> void:
	event_total += 1
	# Coalesce identical actions in one simulation instant (e.g. a batch of upgrades).
	if not events.is_empty() and events.back().kind == kind and is_equal_approx(float(events.back().time),time) and events.back().data == data:
		events.back().count += 1
	elif events.size() < max_events:events.append({"time":time,"stage":stage,"kind":kind,"data":data.duplicate(true),"count":1})
	else:dropped_events += 1
	marks[kind] = int(marks.get(kind,0))+1
	if not decision:return
	decision_actions[kind] = int(decision_actions.get(kind,0))+1
	# One opportunity per decision instant, not one synthetic click per module level.
	if last_decision >= 0 and absf(time-last_decision) < 0.000001:return
	var gap := time-maxf(last_decision,0)
	longest_decision_gap = maxf(longest_decision_gap,gap)
	if decisions > 0:decision_interval_sum += gap
	last_decision = time
	decisions += 1
	var bin := str(mini(max_samples-1,floori(time/decision_bin_seconds)))
	decision_bins[bin] = int(decision_bins.get(bin,0))+1

func growth(time: float) -> void:
	longest_growth_gap = maxf(longest_growth_gap,time-last_growth)
	last_growth = time

func discover(game: BattleGame, time: float, initial := false) -> void:
	var now := {}
	for key in game.profile.unlocked:now["equipment/"+str(key)] = true
	if game.jewels_unlocked():now["jewels"] = true
	for key in game.db.data.get("charge",{}):
		if game.charge_unlocked(key):now["charge/"+str(key)] = true
	for key in game.db.data.get("hightech",{}):
		if game.hightech_unlocked(key):now["research/"+str(key)] = true
	for key in game.db.ships:
		if game.ship_unlocked(key):now["ship/"+str(key)] = true
	for key in now:
		if available.has(key):continue
		choices[key] = time
		if not initial:
			var kind := "NEW_WEAPON" if key.trim_prefix("equipment/") in BattleGame.WEAPON_KEYS else "UNLOCK_SYSTEM"
			record(kind,time,game.stage,{"key":key},true)
	available = now

func snapshot(game: BattleGame, metrics, force := false) -> void:
	var time: float = metrics.time
	if not force and time+0.000001 < next_sample:return
	if not samples.is_empty() and absf(float(samples.back().game_time)-time) < 0.000001:return
	if samples.size() >= max_samples:return
	var elapsed := time-float(previous.get("time",0))
	var total := 0.0
	for value in metrics.damage.values():total += float(value)
	var delta_damage := total-float(previous.get("damage",0))
	var shares := {}
	for key in metrics.damage:
		var value := float(metrics.damage[key])-float(previous.get("weapons",{}).get(key,0))
		shares[key] = value/delta_damage if delta_damage > 0 else 0.0
	var kills := int(metrics.kills)-int(previous.get("kills",0))
	var normal_kills := int(metrics.normal_kills)-int(previous.get("normal_kills",0))
	var spawn_count := int(metrics.spawn_count)-int(previous.get("spawn_count",0))
	var income := {}
	for id in metrics.income:income[id] = (float(metrics.income[id])-float(previous.get("income",{}).get(id,0)))*60.0/maxf(elapsed,0.000001)
	var balance: Dictionary = game.profile.resources.duplicate()
	balance.jewel_fragments = game.profile.jewelFragments
	var interval_count := int(metrics.interval_count)-int(previous.get("interval_count",0))
	var upgrade_interval: Variant = (float(metrics.interval_sum)-float(previous.get("interval_sum",0)))/interval_count if interval_count > 0 else null
	var health := float(game.player.armour)/maxf(game.stat("armour"),0.000001)
	var shield := float(game.player.shield)/maxf(game.max_shield(),0.000001)
	var upgrades := int(metrics.upgrades)-int(previous.get("upgrades",0))
	var received := float(metrics.received)-float(previous.get("received",0))
	var combat := float(metrics.combat_seconds)-float(previous.get("combat",0))
	samples.append({"game_time":time,"window_seconds":elapsed,"stage":game.stage,"highest_stage":game.profile.highestLevel,"wave":game.group_index,
		"dps":delta_damage/maxf(elapsed,0.000001),"damage":delta_damage,"combat_seconds":combat,
		"enemy_hp":(float(metrics.spawn_hp)-float(previous.get("spawn_hp",0)))/spawn_count if spawn_count > 0 else null,
		"ttk":(float(metrics.ttk_sum)-float(previous.get("ttk_sum",0)))/kills if kills > 0 else null,
		"normal_ttk":(float(metrics.normal_ttk_sum)-float(previous.get("normal_ttk_sum",0)))/normal_kills if normal_kills > 0 else null,
		"kills":kills,"normal_kills":normal_kills,"resource_income":income,"resource_balance":balance,
		"upgrade_interval":upgrade_interval,"upgrade_idle":time-float(metrics.last_upgrade),"upgrades":upgrades,
		"player_survivability":{"health_ratio":health,"shield_ratio":shield,"damage_received":received,"received_per_combat_second":received/maxf(combat,0.000001)},
		"deaths":int(metrics.deaths)-int(previous.get("deaths",0)),"weapon_damage_share":shares,
		"system_uses":metrics.uses.duplicate(),"decisions":decisions,"choice_count":choices.size(),"growth_idle":time-last_growth,
		"resource_blocked_seconds":metrics.unaffordable_seconds,"marks":marks.duplicate()})
	marks.clear()
	previous = {"time":time,"damage":total,"weapons":metrics.damage.duplicate(),"kills":metrics.kills,"ttk_sum":metrics.ttk_sum,
		"normal_kills":metrics.normal_kills,"normal_ttk_sum":metrics.normal_ttk_sum,"spawn_count":metrics.spawn_count,"spawn_hp":metrics.spawn_hp,
		"income":metrics.income.duplicate(),"upgrades":metrics.upgrades,"interval_count":metrics.interval_count,"interval_sum":metrics.interval_sum,
		"received":metrics.received,"deaths":metrics.deaths,"combat":metrics.combat_seconds}
	next_sample = time+interval

func report(time: float) -> Dictionary:
	var bins := decision_bins.duplicate()
	for index in mini(max_samples,maxi(1,ceili(time/decision_bin_seconds))):
		if not bins.has(str(index)):bins[str(index)] = 0
	return {"interval_seconds":interval,"max_samples":max_samples,"samples":samples.duplicate(true),"events":events.duplicate(true),
		"event_count":event_total,"dropped_events":dropped_events,"choices":choices.duplicate(),
		"decision_density":{"count":decisions,"actions":decision_actions.duplicate(),"per_10_minutes":bins if decision_bin_seconds == 600.0 else {},
		"window_seconds":decision_bin_seconds,"per_window":bins,
		"average_interval":decision_interval_sum/(decisions-1) if decisions > 1 else null,
		"longest_gap":maxf(longest_decision_gap,time-maxf(last_decision,0)),"longest_growth_gap":maxf(longest_growth_gap,time-last_growth)}}
