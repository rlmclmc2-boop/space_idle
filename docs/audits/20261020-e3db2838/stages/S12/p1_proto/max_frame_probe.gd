extends "res://max_resumable_probe.gd"

# Actual frame-boundary experiment. Unlike self-call_deferred, the coroutine
# awaits the next process_frame before starting another budgeted work group.
# Every frame's work and main-thread heartbeat is recorded. This remains a
# fixed audit probe and does not certify all legal query inputs.
const FRAME_WORK_TARGET_US := 3000
var frame_index := 0
var previous_heartbeat_us := 0
var max_heartbeat_gap_us := 0
var heartbeat_gaps_over_50ms := 0
var frame_work: Array = []
var max_frame_work_us := 0
var frame_work_over_4ms := 0
var main_cancel_frame := -1
var expected_state := "complete"

func _initialize() -> void:
	Engine.max_fps = 60
	total_started = Time.get_ticks_usec()
	process_frame.connect(Callable(self, "_heartbeat"))
	call_deferred("_frame_loop")

func _heartbeat() -> void:
	var now := Time.get_ticks_usec()
	if previous_heartbeat_us > 0:
		var gap: int = now - previous_heartbeat_us
		max_heartbeat_gap_us = maxi(max_heartbeat_gap_us, gap)
		if gap > 50000:
			heartbeat_gaps_over_50ms += 1
	previous_heartbeat_us = now
	frame_index += 1

func _frame_loop() -> void:
	while result_state == "pending":
		await process_frame
		var id := frame_index
		var frame_begun := Time.get_ticks_usec()
		var steps := 0
		var first_phase: String = phase
		while result_state == "pending":
			var elapsed: int = Time.get_ticks_usec() - frame_begun
			var phase_allowance: int = maxi(1000, int(phase_max_us.get(phase, 0)))
			if steps > 0 and (elapsed >= FRAME_WORK_TARGET_US or elapsed + phase_allowance >= 3600):
				break
			var prior_phase: String = phase
			_tick_step()
			steps += 1
			if prior_phase == "powers":
				break
		var used: int = Time.get_ticks_usec() - frame_begun
		max_frame_work_us = maxi(max_frame_work_us, used)
		if used > 4000:
			frame_work_over_4ms += 1
		frame_work.append({"frame":id,"work_us":used,"steps":steps,"quoted_prices":scan_prices_completed,"start_phase":first_phase,"end_phase":phase})
	_finish()

func _finish() -> void:
	stop_us = Time.get_ticks_usec()
	var contiguous := true
	for i in range(1, frame_work.size()):
		if int(frame_work[i].frame) != int(frame_work[i-1].frame) + 1:
			contiguous = false
			break
	var live_unchanged: bool = profile is Dictionary and JSON.stringify(profile) == original_json
	var latency_us: int = stop_us - cancel_requested_us if cancel_requested_us > 0 else 0
	var success: bool = contiguous and live_unchanged and result_state == expected_state
	if expected_state == "complete":
		success = success and level == 50000 and material_wallet == 0
	else:
		success = success and main_cancel_frame >= 0 and cancel_requested_us > 0 and latency_us <= 100000
	print(JSON.stringify({"kind":"exploratory_true_frame_query","success":success,"state":result_state,"level":level,"count":level-initial_level,"material_remaining":material_wallet,"stop_reason":stop_reason,"frame_count":frame_work.size(),"contiguous_frame_ids":contiguous,"frame_work":frame_work,"max_frame_work_us":max_frame_work_us,"frames_over_4ms":frame_work_over_4ms,"max_heartbeat_gap_us":max_heartbeat_gap_us,"heartbeat_gaps_over_50ms":heartbeat_gaps_over_50ms,"main_cancel_frame":main_cancel_frame,"cancel_requested_us":cancel_requested_us,"cancel_observed_us":cancel_observed_us,"stop_us":stop_us,"cancel_latency_us":latency_us,"total_wall_us":stop_us-total_started,"live_unchanged":live_unchanged}))
	quit(0 if success else 1)
