extends RefCounted

# Research is measured in unaccelerated game seconds. Resource inputs are
# integer units per game second; only paid intervals contribute their factor.
const N = preload("res://scripts/growth_number.gd")

const LEVEL_LIMIT := 9007199254740991
var _state: Dictionary = fresh()
var revision := 0
var contribution_revision:=0
var _level_revision := 0
var _factor_level_revision := -1
var _factor_config_revision := -1
var _factor_database_id:=0
var _factor_cache: Dictionary = {}

static func fresh() -> Dictionary:
	return {"aiTechLevels":{},"aiTechProgress":{},"aiTechActive":"","aiTechInput":{"1":0,"2":0},"aiIncomePeak":{"1":0.0,"2":0.0,"jewel":0.0},"aiTechCompletionUnread":false}

func reset() -> void:
	_state = fresh()
	_level_revision += 1
	contribution_revision+=1
	revision += 1

func save_data() -> Dictionary:
	return _state.duplicate(true)

func selected() -> String:
	return str(_state.aiTechActive)

func progress(id: String) -> float:
	return float(_state.aiTechProgress.get(id,0.0))

func completion_unread() -> bool:
	return bool(_state.aiTechCompletionUnread)

func read_completion() -> bool:
	if not completion_unread():return false
	_state.aiTechCompletionUnread = false
	revision += 1
	return true

static func required_at(rows: Dictionary, id: String, current: int) -> float:
	var row: Dictionary = rows.get(id,{})
	if row.is_empty():return INF
	var exponent := float(current) * log(float(row.growth))
	if exponent > 700.0:return INF
	return float(row.base_seconds) * exp(exponent)

static func valid_snapshot(raw: Dictionary, rows: Dictionary) -> bool:
	for field in ["aiTechLevels","aiTechProgress","aiTechInput","aiIncomePeak"]:
		if not raw.get(field) is Dictionary:return false
	if not raw.get("aiTechCompletionUnread") is bool or not raw.get("aiTechActive") is String:return false
	if not raw.aiTechActive.is_empty() and not rows.has(raw.aiTechActive):return false
	for id in raw.aiTechLevels:
		var value = raw.aiTechLevels[id]
		if not rows.has(id) or not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > LEVEL_LIMIT or value != floorf(float(value)):return false
	for id in raw.aiTechProgress:
		var value = raw.aiTechProgress[id]
		if not rows.has(id) or not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value >= required_at(rows,id,int(raw.aiTechLevels.get(id,0))):return false
	if raw.aiTechInput.size()!=2 or raw.aiIncomePeak.size()!=3:return false
	for id in ["1","2"]:
		var value = raw.aiTechInput.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > LEVEL_LIMIT or value != floorf(float(value)):return false
	for id in ["1","2","jewel"]:
		if not N.valid(raw.aiIncomePeak.get(id)):return false
	return true

func install_snapshot(raw: Dictionary, rows: Dictionary) -> bool:
	if not valid_snapshot(raw,rows):return false
	var next := fresh()
	for field in next:next[field] = raw[field].duplicate(true) if raw[field] is Dictionary else raw[field]
	for id in next.aiTechLevels:next.aiTechLevels[id] = int(next.aiTechLevels[id])
	for id in next.aiTechInput:next.aiTechInput[id] = int(next.aiTechInput[id])
	if _state.aiTechLevels != next.aiTechLevels:_level_revision += 1
	if _state.aiTechLevels!=next.aiTechLevels or _state.aiIncomePeak!=next.aiIncomePeak:contribution_revision+=1
	_state = next
	revision += 1
	return true

func level(_game, id: String) -> int:
	return int(_state.aiTechLevels.get(id, 0))

func ai_count(game) -> int:
	return 1 + level(game, "singularity")

func research_speed(game) -> float:
	# Existing drone module remains an AI-speed consumer after the tree migration.
	var bonus := float(game.hyperspace_totals().hangings.get("distributed_algorithm",0.0))
	return float(ai_count(game)+9)/10.0 * (1.0+bonus)

func required(game, id: String) -> float:
	return required_at(game.db.data.ai_tech_tree,id,level(game,id))

func eligibility(game, id: String) -> Dictionary:
	var row: Dictionary = game.db.data.ai_tech_tree.get(id, {})
	if row.is_empty():return {"ok":false,"reason":"unknown"}
	if not game.ai_tech_factory_unlocked():return {"ok":false,"reason":"factory_locked"}
	if row.has("legacy_unlock") and not game.content_unlocked("hightech",str(row.legacy_unlock)):
		return {"ok":false,"reason":"legacy_locked"}
	if str(row.get("unlock", "")) == "enhancement" and not game.enhancement_unlocked():
		return {"ok":false,"reason":"enhancement_locked"}
	var target := level(game, id) + 1
	for prerequisite in row.get("requirements", {}):
		var condition = row.requirements[prerequisite]
		var minimum := 10 * target + 1 if condition is String and condition == "10*k+1" else int(condition)
		if level(game, prerequisite) < minimum:
			return {"ok":false,"reason":"prerequisite","id":prerequisite,"level":minimum}
	return {"ok":true}

func select(game, id: String) -> bool:
	if id == _state.aiTechActive:return false
	if not id.is_empty() and not bool(eligibility(game, id).ok):return false
	_state.aiTechActive = id
	revision += 1
	return true

func set_input(game, resource_id: String, amount: int) -> bool:
	if not game.ai_tech_factory_unlocked():return false
	if resource_id not in ["1", "2"] or amount < 0 or amount > 9007199254740991:return false
	if int(_state.aiTechInput.get(resource_id, 0)) == amount:return false
	_state.aiTechInput[resource_id] = amount
	revision += 1
	return true

func input_factor(amount: int) -> float:
	return 1.0 if amount <= 0 else 1.0 + log(float(amount)) / log(10.0) / 4.0

func income_factor(game, id: String) -> Variant:
	if _factor_level_revision != _level_revision or _factor_config_revision != game.configuration_revision or _factor_database_id!=game.db.get_instance_id():
		_factor_cache.clear()
		_factor_level_revision = _level_revision
		_factor_config_revision = game.configuration_revision
		_factor_database_id=game.db.get_instance_id()
	if _factor_cache.has(id):return _factor_cache[id]
	var result: Variant = 1.0
	for tech in game.db.data.ai_tech_tree:
		var row: Dictionary = game.db.data.ai_tech_tree[tech]
		if id in str(row.effect).split(",") and tech != "unification" and tech != "singularity":
			result = N.multiply(result, N.power(float(row.factor), level(game, tech)))
	_factor_cache[id] = result
	return result

func peak_product(game) -> Variant:
	var value: Variant = 1.0
	for id in ["1", "2", "jewel"]:
		var peak = _state.aiIncomePeak.get(id, 0.0)
		if N.compare(peak,0) > 0:value = N.multiply(value,N.maximum(1.0,1.0 + N.logarithm(peak) / 5.0))
	return value

func peak_factor(game) -> Variant:
	return 1.0 if level(game, "unification") == 0 else N.multiply(float(level(game, "unification")),peak_product(game))

func combat_factor(game, id: String) -> Variant:
	return N.multiply(income_factor(game, id), peak_factor(game))

func income_peak_proposal(game, id: String) -> Dictionary:
	if id not in ["1", "2", "jewel"]:return {}
	var rate = N.divide(game.resource_minute_total(id),60.0)
	if N.compare(rate,_state.aiIncomePeak.get(id,0.0)) <= 0:return {}
	return {"id":id,"rate":rate,"revision":revision,"affects_combat":level(game,"unification")>0}

func commit_income_peak(proposal: Dictionary) -> bool:
	if proposal.revision != revision:return false
	_state.aiIncomePeak[proposal.id] = proposal.rate
	if proposal.affects_combat:contribution_revision+=1
	revision += 1
	return true

func snapshot(game) -> Dictionary:
	var selected := str(_state.aiTechActive)
	var inputs := {}
	var acceleration := research_speed(game)
	for resource_id in ["1", "2"]:
		var amount := int(_state.aiTechInput.get(resource_id, 0))
		var affordable := amount == 0 or N.compare(game.economy.balance(resource_id), 0) > 0
		var factor := input_factor(amount) if affordable else 1.0
		inputs[resource_id] = {"amount":amount,"factor":factor,"shortage":amount > 0 and not affordable}
		acceleration *= factor
	var nodes := []
	for id in game.db.data.ai_tech_tree:
		var row: Dictionary = game.db.data.ai_tech_tree[id]
		var cost := required(game, id)
		var progress := float(_state.aiTechProgress.get(id, 0.0))
		var current: Variant = N.power(float(row.factor),level(game,id))
		var next: Variant = N.power(float(row.factor),level(game,id)+1)
		if id == "singularity":
			current = ai_count(game)
			next = ai_count(game)+1
		elif id == "unification":
			current = peak_factor(game)
			next = N.multiply(float(level(game,id)+1),peak_product(game))
		nodes.append({"id":id,"name":str(row.name),"description":str(row.description),"tier":str(row.tier),"level":level(game,id),"effect":str(row.effect),"factor":float(row.factor),"current_multiplier":current,"next_multiplier":next,"requirements":row.get("requirements",{}),"eligibility":eligibility(game,id),"required_seconds":cost,"progress_seconds":progress,"percent":clampi(int(floor(100.0*progress/cost)),0,99) if is_finite(cost) else 0})
	var remaining := INF
	if not selected.is_empty() and acceleration > 0.0:
		remaining = maxf(0.0, required(game, selected)-float(_state.aiTechProgress.get(selected,0.0)))/acceleration
	return {"nodes":nodes,"selected":selected,"inputs":inputs,"ai_count":ai_count(game),"speed":acceleration,"remaining_seconds":remaining,"status":"idle" if selected.is_empty() else "researching"}

func prepare_advance(game, dt: float) -> Dictionary:
	if dt <= 0.0 or not is_finite(dt) or selected().is_empty():return {}
	var id := selected()
	var next := save_data()
	var resources: Dictionary = game.economy.resources()
	var remaining := dt
	var paid := {}
	var changed := false
	var iterations := 0
	var completed := false
	var stopped := false
	while remaining > 0.0000000001 and iterations < 256:
		iterations += 1
		if not bool(eligibility(game,id).ok):
			next.aiTechActive = "";changed = true;stopped = true
			break
		var step := remaining
		var speed := research_speed(game)
		var factors := {}
		for resource_id in ["1", "2"]:
			var amount := int(next.aiTechInput.get(resource_id,0))
			if amount <= 0 or N.compare(resources[resource_id],0) <= 0:continue
			if N.compare(resources[resource_id],float(amount)*remaining) < 0:
				step = minf(step,float(resources[resource_id])/float(amount))
			factors[resource_id] = amount
			speed *= input_factor(amount)
		var cost := required(game,id)
		if not is_finite(cost):break
		var before := float(next.aiTechProgress.get(id,0.0))
		if cost-before <= maxf(1.0,cost)*1e-12:completed = true
		else:
			step = minf(step,maxf(0.0,cost-before)/speed)
			var expenses := {}
			if step <= 0.0000000001:
				for resource_id in factors:
					if N.compare(resources[resource_id],float(factors[resource_id])*0.0000000001) < 0:expenses[resource_id] = resources[resource_id]
			else:
				for resource_id in factors:expenses[resource_id] = N.minimum(resources[resource_id],float(factors[resource_id])*step)
			var debited: Dictionary = game.economy.prepare_research_resources(resources,expenses)
			if debited.is_empty():break
			resources = debited
			for resource_id in expenses:paid[resource_id] = true
			if not expenses.is_empty():changed = true
			if step <= 0.0000000001:continue
			next.aiTechProgress[id] = before + step*speed
			remaining -= step
			changed = true
			completed = float(next.aiTechProgress[id]) + maxf(1.0,cost)*1e-12 >= cost
		if completed:
			next.aiTechProgress[id] = 0.0
			next.aiTechLevels[id] = level(game,id)+1
			next.aiTechActive = ""
			next.aiTechCompletionUnread = true
			changed = true
			break
	if not changed:return {}
	return {"state":next,"resources":resources,"paid":paid.keys(),"revision":revision,"resource_revision":game.economy.resource_revision,"completed":completed,"stopped":stopped,"id":id}

func proposal_current(proposal: Dictionary) -> bool:
	return proposal.revision == revision

func commit_advance(proposal: Dictionary) -> void:
	if _state.aiTechLevels != proposal.state.aiTechLevels:_level_revision += 1;contribution_revision+=1
	_state = proposal.state.duplicate(true)
	revision += 1
