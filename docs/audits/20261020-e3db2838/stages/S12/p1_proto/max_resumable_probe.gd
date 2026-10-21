extends "res://max_stream_probe.gd"

# Audit-only schedulable query experiment. Each deferred invocation advances
# bounded setup or scan state. The live parsed profile is never debited.
# This is not a full public API: huge-wallet decode and arbitrary-precision
# multiplication still need a worst-case sub-4-ms proof.
const Fallback = preload("res://fallback_job.gd")
const WORK_PER_TICK := 8
const POWERS_PER_TICK := 128

var source_path := "res://generated_wallets/MAX-50000-GODOT-EXPLORATORY.json"
var expected_path := "res://generated_wallets/MAX-50000-GODOT-EXPLORATORY.manifest.json"
var inject_cancel_at_tick := -1
var inject_mutation_at_tick := -1
var phase := "load"
var profile: Dictionary
var expected: Dictionary
var original_json := ""
var wallet: CurrencyValue
var material_wallet := 0
var level := 0
var initial_level := 0
var lower: Array
var upper: Array
var lower_factor: Array
var upper_factor: Array
var price_engine
var overflow_domain := false
var pending: Dictionary = {}
var prices: Array = []
var material_due := 0
var replay_index := 0
var fallback_job
var warmup_job
var revision := 0
var starting_revision := 0
var cancel_requested := false
var cancel_requested_us := 0
var cancel_observed_us := 0
var stop_us := 0
var request_in_work_phase := ""
var scan_prices_completed := 0
var prices_at_request := 0
var in_work := false
var in_work_phase := ""
var state_mutex := Mutex.new()
var first_unaffordable: CurrencyValue
var stop_reason := ""
var tick_count := 0
var max_tick_us := 0
var over_budget_ticks := 0
var total_started := 0
var result_state := "pending"
var windows := 0
var fallback_count := 0
var expected_delta := 0
var last_quoted_target := 0
var repeated_price_targets := 0
var phase_max_us: Dictionary = {}

func _initialize() -> void:
	total_started = Time.get_ticks_usec()
	call_deferred("_tick")

func request_cancel() -> void:
	state_mutex.lock()
	if not cancel_requested:
		cancel_requested_us = Time.get_ticks_usec()
		request_in_work_phase = in_work_phase if in_work else ""
		prices_at_request = scan_prices_completed
	cancel_requested = true
	state_mutex.unlock()

func _cancel_now() -> bool:
	state_mutex.lock()
	var requested: bool = cancel_requested
	state_mutex.unlock()
	if requested:
		cancel_observed_us = Time.get_ticks_usec()
		result_state = "cancelled"
	return requested

func _tick() -> void:
	_before_tick()
	if inject_cancel_at_tick == tick_count:
		request_cancel()
	if inject_mutation_at_tick == tick_count:
		revision += 1
	var begun := Time.get_ticks_usec()
	var phase_before: String = phase
	state_mutex.lock()
	var must_cancel: bool = cancel_requested
	in_work = true
	in_work_phase = phase
	state_mutex.unlock()
	if must_cancel:
		cancel_observed_us = begun
		result_state = "cancelled"
	elif revision != starting_revision:
		result_state = "stale"
	else:
		_advance()
	state_mutex.lock()
	in_work = false
	in_work_phase = ""
	state_mutex.unlock()
	var elapsed := Time.get_ticks_usec() - begun
	phase_max_us[phase_before] = maxi(int(phase_max_us.get(phase_before, 0)), elapsed)
	max_tick_us = maxi(max_tick_us, elapsed)
	if elapsed > 4000:
		over_budget_ticks += 1
	tick_count += 1
	if result_state == "pending":
		call_deferred("_tick")
	else:
		_finish()

func _before_tick() -> void:
	pass

func _advance() -> void:
	match phase:
		"load":
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(source_path))
			var manifest = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
			if not (parsed is Dictionary and manifest is Dictionary):
				result_state = "error"
				return
			profile = parsed
			expected = manifest
			original_json = JSON.stringify(profile)
			initial_level = int(profile.laser_level)
			level = initial_level
			material_wallet = int(profile.hyperspace.materials.degenerate_matter)
			phase = "decode"
		"decode":
			var stored = profile.resources["1"]
			if stored is int:
				wallet = currency_from_integer(stored)
			elif stored is float and is_finite(stored) and stored >= 0.0 and stored <= 9007199254740991.0 and stored == floorf(stored):
				wallet = currency_from_integer(int(stored))
			else:
				wallet = decode(stored)
			if wallet == null:
				result_state = "error"
				return
			phase = "factor"
		"factor":
			price_engine = Price.new()
			var factor: Array = I.decimal_factor(1.0 + 0.2)
			lower_factor = price_engine.trim_bound(factor[0], -int(factor[1]), 10, false)
			upper_factor = price_engine.trim_bound(factor[0], -int(factor[1]), 10, true)
			lower = [50, 0]
			upper = [50, 0]
			warmup_job = Fallback.new(50.0, 1.0 + 0.2, initial_level, true) if initial_level > 1 else null
			powers_of_two.clear()
			powers_of_two.append(PackedInt32Array([1]))
			phase = "powers"
		"powers":
			for offset in POWERS_PER_TICK:
				if _cancel_now():
					return
				if powers_of_two.size() >= 1025:
					phase = "warmup" if warmup_job != null else "scan"
					break
				var previous: PackedInt32Array = powers_of_two[-1]
				var next := PackedInt32Array()
				var carry := 0
				for digit in previous:
					var value := 2 * digit + carry
					next.append(value % 10000)
					carry = value / 10000
				if carry:
					next.append(carry)
				powers_of_two.append(next)
			if powers_of_two.size() >= 1025:
				phase = "warmup" if warmup_job != null else "scan"
		"warmup":
			if _cancel_now():
				return
			var outcome: Dictionary = warmup_job.step()
			if outcome.state == "complete":
				lower = outcome.lower
				upper = outcome.upper
				phase = "scan"
			elif outcome.state != "pending":
				result_state = "error"
		"scan":
			for offset in WORK_PER_TICK:
				if _cancel_now():
					return
				if prices.size() >= WINDOW:
					phase = "window"
					break
				var target: int = level + prices.size() + 1
				if target <= last_quoted_target:
					repeated_price_targets += 1
				last_quoted_target = target
				lower = price_engine.multiply_bound(lower, lower_factor, 10, false)
				upper = price_engine.multiply_bound(upper, upper_factor, 10, true)
				var ordinary := INF if overflow_domain else 50.0 * pow(1.0 + 0.2, target - 1)
				var cost: CurrencyValue
				if is_finite(ordinary):
					cost = fast_quote(target)
				else:
					overflow_domain = true
					var lo: Array = price_engine.rounded_bound(lower)
					var hi: Array = price_engine.rounded_bound(upper)
					if lo != hi:
						fallback_job = Fallback.new(50.0, 1.0 + 0.2, target)
						fallback_count += 1
						phase = "fallback"
						break
					cost = from_two_digit(int(lo[0]), int(lo[1]))
				if cost == null:
					result_state = "error"
					return
				_accept(cost, target)
			if prices.size() >= WINDOW and phase == "scan":
				phase = "window"
		"fallback":
			if _cancel_now():
				return
			var outcome: Dictionary = fallback_job.step()
			if outcome.state == "complete":
				var representation: Array = outcome.price
				var target: int = level + prices.size() + 1
				_accept(from_two_digit(int(representation[0]), int(representation[1])), target)
				phase = "window" if prices.size() >= WINDOW else "scan"
			elif outcome.state != "pending":
				result_state = "error"
		"window":
			var summed: CurrencyValue = normalize_pending(pending)
			if compare(wallet, summed) >= 0 and material_wallet >= material_due:
				wallet = subtract(wallet, summed)
				material_wallet -= material_due
				level += prices.size()
				windows += 1
				prices.clear()
				pending.clear()
				material_due = 0
				phase = "scan"
			else:
				replay_index = 0
				phase = "replay"
		"replay":
			for offset in WORK_PER_TICK:
				if _cancel_now():
					return
				if replay_index >= prices.size():
					result_state = "error"
					return
				var cost: CurrencyValue = prices[replay_index]
				var target: int = level + 1
				if compare(wallet, cost) < 0:
					first_unaffordable = cost
					stop_reason = "insufficient_resource"
					phase = "verify"
					break
				if material_wallet < material(target):
					first_unaffordable = cost
					stop_reason = "insufficient_material"
					phase = "verify"
					break
				wallet = subtract(wallet, cost)
				material_wallet -= material(target)
				level = target
				replay_index += 1
		"verify":
			var remaining = currency_from_integer(I.make(str(expected.remaining_after_expected_purchases)))
			if expected_delta > 0:
				remaining = add(remaining, currency_from_integer(expected_delta))
			elif expected_delta < 0:
				remaining = subtract(remaining, currency_from_integer(-expected_delta))
			var failed_price = currency_from_integer(I.make(str(expected.first_unaffordable_price)))
			if compare(wallet, remaining) != 0 or compare(first_unaffordable, failed_price) != 0 or level != int(expected.expected_count) + initial_level:
				result_state = "error"
				return
			if JSON.stringify(profile) != original_json:
				result_state = "error"
				return
			result_state = "complete"
		_:
			result_state = "error"

func _accept(cost: CurrencyValue, target: int) -> void:
	for index in cost.positions.size():
		var position: int = cost.positions[index]
		pending[position] = int(pending.get(position, 0)) + int(cost.digits[index])
	prices.append(cost)
	scan_prices_completed += 1
	material_due += material(target)

func _finish() -> void:
	stop_us = Time.get_ticks_usec()
	print(JSON.stringify({"kind":"exploratory_schedulable_max","state":result_state,"phase":phase,"count":level-initial_level,"level":level,"material_remaining":material_wallet,"stop_reason":stop_reason,"windows":windows,"fallback_count":fallback_count,"ticks":tick_count,"max_tick_us":max_tick_us,"phase_max_us":phase_max_us,"over_budget_ticks":over_budget_ticks,"total_us":stop_us-total_started,"live_unchanged":JSON.stringify(profile)==original_json if profile is Dictionary else false,"revision":revision,"request_in_work_phase":request_in_work_phase,"cancel_requested_us":cancel_requested_us,"cancel_observed_us":cancel_observed_us,"stop_us":stop_us,"prices_at_request":prices_at_request,"prices_at_stop":scan_prices_completed,"repeated_price_targets":repeated_price_targets}))
	quit(0 if result_state == "complete" and level == 50000 and material_wallet == 0 else 1)
