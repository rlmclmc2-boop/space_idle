extends SceneTree

const Job = preload("res://fallback_job.gd")
const I = preload("res://reference_integer.gd")
const AMBIGUOUS := [13706,19504,21588,29530,32344,33146,33762,35604,37109,37234,37247,38082,40530,44957,47198]

func _initialize() -> void:
	var compact: Array = JSON.parse_string(FileAccess.get_file_as_string("res://generated_wallets/godot_prices_50000_compact.json"))
	var failures: Array = []
	var max_step_us := 0
	var max_init_us := 0
	var steps := 0
	var max_precision := 0
	for level in AMBIGUOUS:
		var t := Time.get_ticks_usec()
		var job = Job.new(50.0, 1.0 + 0.2, level)
		max_init_us = maxi(max_init_us, Time.get_ticks_usec() - t)
		var result: Dictionary
		for attempt in 256:
			t = Time.get_ticks_usec()
			result = job.step()
			max_step_us = maxi(max_step_us, Time.get_ticks_usec() - t)
			steps += 1
			if result.state != "pending":
				break
		if result.get("state") != "complete":
			failures.append({"level":level,"reason":result})
			continue
		max_precision = maxi(max_precision, job.precision)
		var representation: Array = result.price
		var observed = compact[level - 2]
		var observed_text: String = observed if observed is String else str(int(observed[0])) + "0".repeat(int(observed[1]))
		var candidate_text: String = str(representation[0]) + "0".repeat(int(representation[1]))
		if I.compare(I.make(candidate_text), I.make(observed_text)) != 0:
			failures.append({"level":level,"reason":"price_mismatch","candidate":representation,"observed":observed})
	var cancel_job = Job.new(50.0, 1.0 + 0.2, 1000000000)
	for i in 5:
		cancel_job.step()
	var before_cancel_units: int = cancel_job.work_units
	cancel_job.cancel()
	var cancel_result: Dictionary = cancel_job.step()
	var cancel_ok: bool = cancel_result.state == "cancelled" and cancel_job.work_units == before_cancel_units
	var billion = Job.new(50.0, 1.0 + 0.2, 1000000000)
	var billion_result: Dictionary
	var billion_max_step_us := 0
	var billion_started := Time.get_ticks_usec()
	for attempt in 256:
		var t := Time.get_ticks_usec()
		billion_result = billion.step()
		billion_max_step_us = maxi(billion_max_step_us, Time.get_ticks_usec() - t)
		if billion_result.state != "pending":
			break
	var billion_ok: bool = billion_result.get("state") == "complete"
	print(JSON.stringify({"kind":"exploratory_resumable_fallback","cases":AMBIGUOUS.size(),"failures":failures,"max_init_us":max_init_us,"max_step_us":max_step_us,"steps":steps,"max_precision":max_precision,"cancel_after_units":before_cancel_units,"cancel_ok":cancel_ok,"billion_price_repr":billion_result.get("price",[]),"billion_units":billion.work_units,"billion_total_us":Time.get_ticks_usec()-billion_started,"billion_max_step_us":billion_max_step_us}))
	quit(0 if failures.is_empty() and cancel_ok and billion_ok else 1)
