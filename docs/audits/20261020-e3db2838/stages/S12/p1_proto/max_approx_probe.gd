extends "res://max_binary_probe.gd"

const Bound = preload("res://approx_bounds.gd")
const RULE := "MAX-APPROX-v1"
const FINITE_ORACLE_SHA := "ae82b2236152806048a4a18eaf62f0a0210d340f185dcf15930c4ab4604975fb"
const ACTUAL_CONFIG_PATH := "res://actual_equipment_main31e793.json"
class HostState:
	extends RefCounted
	var profile: Dictionary
	var generation := 0
	var config: Dictionary
	var config_generation := 0
	func _init(source_profile: Dictionary, source_config: Dictionary) -> void:
		profile = source_profile.duplicate(true)
		config = source_config.duplicate(true)
	func replace_profile(next_profile: Dictionary) -> void:
		profile = next_profile.duplicate(true)
		generation += 1
	func replace_config(next_config: Dictionary) -> void:
		config = next_config.duplicate(true)
		config_generation += 1
var fixture_mode := "compact_medium"
var requested_equipment := "laser"
var requested_start_level := 1
var requested_row: Dictionary = {}
var requested_evolution: Dictionary = {}
var requested_material_balance := 9007199254740991
var level_key := "laser_level"
var resource_key := "1"
var mutate_before_commit := false
var mutation_mode := "replacement"
var tamper_before_commit := false
var cancel_during_work := false
var host: HostState
var bound_host: HostState
var bound_profile: Dictionary
var bound_config: Dictionary
var starting_profile_json := ""
var starting_config_json := ""
var start_level := 1
var starting_wallet: CurrencyValue
var starting_material := 0
var prefix_cost: CurrencyValue
var prefix_material := 0
var quoted: Dictionary = {}
var quote_json := ""
var externally_mutated_json := ""
var externally_mutated_config_json := ""
var state := "pending"
var reason := ""
var evaluated := 0
var bounds_worker_us := 0
var boundary_next: Dictionary = {}
var heartbeat_last := 0
var heartbeat_max_gap_us := 0
var heartbeat_frames := 0
var cancel_requested := false
var cancel_requested_us := 0
var stopped_us := 0
var started_us := 0

func _initialize() -> void:
	Engine.max_fps = 60
	started_us = Time.get_ticks_usec()
	process_frame.connect(Callable(self,"_heartbeat"))
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTUAL_CONFIG_PATH))
	var row: Dictionary = actual.rows.get(requested_equipment,{}).duplicate(true)
	var evolution: Dictionary = actual.evolution.duplicate(true)
	if not requested_row.is_empty():
		row = requested_row.duplicate(true)
	if not requested_evolution.is_empty():
		evolution = requested_evolution.duplicate(true)
	start_level = requested_start_level
	level_key = requested_equipment + "_level"
	var wallet_encoded: Dictionary
	if fixture_mode == "compact_billion":
		wallet_encoded = {"v":4,"blocks":[["250000000",1]]}
	elif fixture_mode == "exact_256" or fixture_mode == "approx_256":
		var total: Variant = 0
		var price_engine = Price.new()
		for i in 256 if fixture_mode == "exact_256" else 257:
			var price = price_engine.quote(50.0,0.2,start_level+i+1)
			if price == null:
				print(JSON.stringify({"kind":"exploratory_max_approx_query","state":"unsupported","reason":"fixture_price","success":true}))
				quit(0)
				return
			total = I.add(total,price)
		wallet_encoded = encode(currency_from_integer(total))
	else:
		wallet_encoded = {"v":4,"blocks":[["950",1]]}
	host = HostState.new({level_key:start_level,"resources":{resource_key:wallet_encoded},"hyperspace":{"materials":{"degenerate_matter":requested_material_balance}}},{"row":row,"evolution":evolution})
	bound_host = host
	bound_profile = host.profile
	bound_config = host.config
	starting_profile_json = JSON.stringify(host.profile)
	starting_config_json = JSON.stringify(host.config)
	starting_wallet = decode(host.profile.resources[resource_key])
	starting_material = int(host.profile.hyperspace.materials.degenerate_matter)
	if starting_wallet == null:
		state = "error"
		reason = "invalid_fixture_wallet"
		_finish()
		return
	call_deferred("_run")

func _supported() -> bool:
	var row: Dictionary = host.config.row
	var evolution: Dictionary = host.config.evolution
	if requested_equipment not in ["armour","shield","laser","missile","cannon","longLaser"] or start_level < 1 or requested_material_balance < 0:
		return false
	if row.size() != 7 or evolution.size() != 3 or row.get("name") != requested_equipment:
		return false
	if not (row.get("cost_1") is int or row.get("cost_1") is float) or not (row.get("costMulti_1") is int or row.get("costMulti_1") is float):
		return false
	return float(row.cost_1) == 50.0 and float(row.costMulti_1) == 0.2 and row.get("res_1") == 1 and row.get("res_2") == null and row.get("cost_2") == null and row.get("costMulti_2") == null and evolution.get("interval") == 20 and evolution.get("material_id") == "degenerate_matter" and evolution.get("material_cost_per_tier") == 10

func _heartbeat() -> void:
	var now := Time.get_ticks_usec()
	if heartbeat_last > 0:
		heartbeat_max_gap_us = maxi(heartbeat_max_gap_us,now-heartbeat_last)
	heartbeat_last = now
	heartbeat_frames += 1

func _request_cancel() -> void:
	if not cancel_requested:
		cancel_requested = true
		cancel_requested_us = Time.get_ticks_usec()

func _same_host() -> bool:
	return host == bound_host and is_same(host.profile,bound_profile) and is_same(host.config,bound_config) and host.generation == 0 and host.config_generation == 0 and JSON.stringify(host.profile) == starting_profile_json and JSON.stringify(host.config) == starting_config_json

func _material_due(count: int) -> Variant:
	var interval: int = int(host.config.evolution.interval)
	var per_tier: int = int(host.config.evolution.material_cost_per_tier)
	var last_tier: int = (start_level+count)/interval
	var first_tier: int = start_level/interval
	var last_sum: Variant = I.div_small(I.multiply(last_tier,last_tier+1),2)[0]
	var first_sum: Variant = I.div_small(I.multiply(first_tier,first_tier+1),2)[0]
	return I.multiply(I.subtract(last_sum,first_sum),per_tier)

func _material_fits(amount: Variant) -> bool:
	return I.compare(amount,I.make(str(starting_material))) <= 0

func _mul_small(value: CurrencyValue, times: int) -> CurrencyValue:
	var result: CurrencyValue = currency_from_integer(0)
	for i in times:
		result = add(result,value)
	return result

func _fee(count: int) -> Dictionary:
	var material_amount: Variant = _material_due(count)
	if not _material_fits(material_amount):
		return {"state":"unaffordable_material","material":material_amount}
	if count == 256:
		return {"state":"ready","lower":prefix_cost,"upper":prefix_cost,"material":material_amount}
	var engine = Bound.new()
	var worker := Thread.new()
	var begun := Time.get_ticks_usec()
	if cancel_during_work and count >= 32768 and cancel_requested_us == 0:
		create_timer(0.005).timeout.connect(Callable(self,"_request_cancel"))
	var err: Error = worker.start(Callable(engine,"rounded_fee_envelope").bind(start_level+256,count-256))
	if err != OK:
		return {"state":"unsupported","reason":"thread_start"}
	while worker.is_alive():
		await process_frame
	var interval: Array = worker.wait_to_finish()
	bounds_worker_us += Time.get_ticks_usec() - begun
	if cancel_requested:
		return {"state":"cancelled"}
	if not _same_host():
		return {"state":"stale"}
	var lower: CurrencyValue = decode(engine.encoded_integer(interval[0],false))
	var upper: CurrencyValue = decode(engine.encoded_integer(interval[1],true))
	if lower == null or upper == null:
		return {"state":"unsupported","reason":"bound_encoding"}
	lower = add(prefix_cost,lower)
	upper = add(prefix_cost,upper)
	if lower == null or upper == null or compare(lower,upper)>0:
		return {"state":"unsupported","reason":"bound_arithmetic"}
	# U <= ceil(28*L/25) iff 25*U <= 28*L+24.
	var right: CurrencyValue = add(_mul_small(lower,28),currency_from_integer(24))
	if right == null or compare(_mul_small(upper,25),right)>0:
		return {"state":"unsupported","reason":"fee_certificate_over_12_percent"}
	evaluated += 1
	return {"state":"ready","lower":lower,"upper":upper,"material":material_amount}

func _affordable(candidate: Dictionary) -> bool:
	return candidate.state == "ready" and compare(starting_wallet,candidate.upper)>=0 and _material_fits(candidate.material)

func _run() -> void:
	if not _supported():
		state = "unsupported"
		reason = "outside_fixed_main_equipment_family"
		_finish()
		return
	var price_engine = Price.new()
	var shadow: CurrencyValue = starting_wallet
	var exact_cost: CurrencyValue = currency_from_integer(0)
	var exact_material := 0
	var exact_count := 0
	for index in 257:
		if index % 4 == 0:
			await process_frame
		if cancel_requested:
			state = "cancelled"
			_finish()
			return
		if not _same_host():
			state = "stale"
			_finish()
			return
		var target: int = start_level+index+1
		var exact = price_engine.quote(float(host.config.row.cost_1),float(host.config.row.costMulti_1),target)
		if exact == null:
			state = "unsupported"
			reason = "prefix_quote"
			_finish()
			return
		var cost: CurrencyValue = currency_from_integer(exact)
		var material_cost: int = int(host.config.evolution.material_cost_per_tier) * (target / int(host.config.evolution.interval)) if target % int(host.config.evolution.interval) == 0 else 0
		if compare(shadow,cost)<0 or exact_material+material_cost>starting_material:
			_emit_quote("exact",exact_count,exact_cost,exact_cost,exact_material)
			return
		shadow = subtract(shadow,cost)
		exact_cost = add(exact_cost,cost)
		exact_material += material_cost
		exact_count += 1
		if exact_count == 256:
			prefix_cost = exact_cost
			prefix_material = exact_material
	var first: Dictionary = await _fee(257)
	if first.state != "ready":
		state = first.state
		reason = str(first.get("reason",""))
		_finish()
		return
	if not _affordable(first):
		_emit_quote("approx_fallback_exact_fee",256,prefix_cost,prefix_cost,prefix_material)
		return
	var low := 257
	var low_fee: Dictionary = first
	var high := 514
	while true:
		if high > 4611686018427387903:
			state = "unsupported"
			reason = "search_int64_range"
			_finish()
			return
		var candidate: Dictionary = await _fee(high)
		if candidate.state == "cancelled" or candidate.state == "stale" or candidate.state == "unsupported":
			state = candidate.state
			reason = str(candidate.get("reason",""))
			_finish()
			return
		if not _affordable(candidate):
			boundary_next = _boundary_record(high,candidate)
			break
		low = high
		low_fee = candidate
		high *= 2
	while high-low > 1:
		var middle: int = low+(high-low)/2
		var candidate: Dictionary = await _fee(middle)
		if candidate.state == "cancelled" or candidate.state == "stale" or candidate.state == "unsupported":
			state = candidate.state
			reason = str(candidate.get("reason",""))
			_finish()
			return
		if _affordable(candidate):
			low = middle
			low_fee = candidate
		else:
			high = middle
			boundary_next = _boundary_record(high,candidate)
	_emit_quote("approx",low,low_fee.lower,low_fee.upper,int(I.digits(low_fee.material)))

func _boundary_record(count: int, candidate: Dictionary) -> Dictionary:
	return {"count":count,"state":candidate.state,"resource_upper":encode(candidate.upper) if candidate.state == "ready" else null,"material_due":I.digits(candidate.material) if candidate.has("material") else ""}

func _emit_quote(mode: String, count: int, lower: CurrencyValue, upper: CurrencyValue, material_amount: int) -> void:
	if not _same_host() or cancel_requested:
		state = "stale" if not _same_host() else "cancelled"
		_finish()
		return
	if count == 0:
		state = "not_affordable"
		reason = "first_purchase_unaffordable"
		_finish()
		return
	quoted = {"rule_version":RULE,"mode":mode,"equipment_id":requested_equipment,"resource_id":resource_key,"start_level":start_level,"count":count,"resource_debit":encode(upper),"material_debit":material_amount,"bound_certificate":{"lower":encode(lower),"upper":encode(upper),"precision":Bound.PRECISION,"finite_oracle_sha256":FINITE_ORACLE_SHA},"dependency_snapshot":{"host_instance_id":host.get_instance_id(),"profile_generation":host.generation,"config_generation":host.config_generation,"profile_sha256":_digest(starting_profile_json),"config_sha256":_digest(starting_config_json)}}
	quote_json = JSON.stringify(quoted)
	state = "quoted"
	if mutate_before_commit:
		if mutation_mode == "config":
			var next_config: Dictionary = host.config.duplicate(true)
			next_config.row.costMulti_1 = 0.21
			host.replace_config(next_config)
		elif mutation_mode == "wallet":
			host.profile.resources[resource_key] = {"v":4,"blocks":[["0",1]]}
		elif mutation_mode == "silent_profile_replace":
			host.profile = host.profile.duplicate(true)
		else:
			host = HostState.new(host.profile,host.config)
		externally_mutated_json = JSON.stringify(host.profile)
		externally_mutated_config_json = JSON.stringify(host.config)
	if tamper_before_commit:
		quoted.resource_debit = {"v":4,"blocks":[["0",1]]}
	var committed: bool = _commit(quoted,host)
	state = "committed" if committed else "stale_rejected"
	_finish()

func _digest(value: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(value.to_utf8_buffer())
	return hash.finish().hex_encode()

func _commit(presented: Dictionary, current_owner: HostState) -> bool:
	if state != "quoted" or current_owner != bound_host or current_owner != host or JSON.stringify(presented) != quote_json or not _same_host():
		return false
	if presented.rule_version != RULE or presented.equipment_id != requested_equipment or presented.resource_id != resource_key or int(presented.start_level) != int(host.profile[level_key]) or not _supported():
		return false
	var fee: CurrencyValue = decode(presented.resource_debit)
	if fee == null or compare(starting_wallet,fee)<0:
		return false
	var material_cost: int = int(presented.material_debit)
	if material_cost < 0 or material_cost > int(host.profile.hyperspace.materials.degenerate_matter):
		return false
	var remaining: CurrencyValue = subtract(starting_wallet,fee)
	if remaining == null:
		return false
	var next_profile: Dictionary = host.profile.duplicate(true)
	next_profile.resources[resource_key] = encode(remaining)
	next_profile.hyperspace.materials.degenerate_matter -= material_cost
	next_profile[level_key] += int(presented.count)
	# One synchronous publication, after every check and calculation.
	host.replace_profile(next_profile)
	return true

func _finish() -> void:
	stopped_us = Time.get_ticks_usec()
	var fee: CurrencyValue = decode(quoted.resource_debit) if not quoted.is_empty() else null
	var remaining_matches := false
	var material_matches := false
	var level_matches := false
	if state == "committed":
		remaining_matches = compare(decode(host.profile.resources[resource_key]),subtract(starting_wallet,fee))==0
		material_matches = int(host.profile.hyperspace.materials.degenerate_matter)==starting_material-int(quoted.material_debit)
		level_matches = int(host.profile[level_key])==start_level+int(quoted.count)
	var live_unchanged: bool = (JSON.stringify(host.profile)==(externally_mutated_json if mutate_before_commit else starting_profile_json) and JSON.stringify(host.config)==(externally_mutated_config_json if mutate_before_commit else starting_config_json)) if state != "committed" else true
	var success: bool = (state == "committed" and remaining_matches and material_matches and level_matches) or (state == "stale_rejected" and (mutate_before_commit or tamper_before_commit) and quoted.size()>0 and live_unchanged) or (state == "cancelled" and live_unchanged) or (state == "unsupported" and reason == "outside_fixed_main_equipment_family" and live_unchanged) or (state == "not_affordable" and reason == "first_purchase_unaffordable" and live_unchanged)
	print(JSON.stringify({"kind":"exploratory_max_approx_query","success":success,"state":state,"reason":reason,"fixture":fixture_mode,"equipment_id":requested_equipment,"start_level":start_level,"mutation_mode":mutation_mode,"count":quoted.get("count",-1),"mode":quoted.get("mode",""),"quoted":quoted,"boundary_next":boundary_next,"evaluated_candidates":evaluated,"bound_worker_wall_us":bounds_worker_us,"total_wall_us":stopped_us-started_us,"heartbeat_frames":heartbeat_frames,"max_heartbeat_gap_us":heartbeat_max_gap_us,"cancel_requested_us":cancel_requested_us,"cancel_stop_latency_us":stopped_us-cancel_requested_us if cancel_requested_us>0 else 0,"live_unchanged_on_failure":live_unchanged,"remaining_matches":remaining_matches,"material_matches":material_matches,"level_matches":level_matches,"pre_profile_bytes":starting_profile_json.to_utf8_buffer().size(),"post_profile_bytes":JSON.stringify(host.profile).to_utf8_buffer().size(),"post_wallet":host.profile.resources[resource_key] if state=="committed" else null,"post_material":host.profile.hyperspace.materials.degenerate_matter,"post_level":host.profile[level_key],"remaining_blocks":decode(host.profile.resources[resource_key]).positions.size()}))
	quit(0 if success else 1)
