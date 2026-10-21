extends "res://max_resumable_probe.gd"

var requester := Thread.new()

func _initialize() -> void:
	requester.start(Callable(self, "_request_during_scan"))
	super._initialize()

func _request_during_scan() -> void:
	while true:
		state_mutex.lock()
		var active: bool = in_work and (in_work_phase == "scan" or in_work_phase == "fallback")
		state_mutex.unlock()
		if active:
			request_cancel()
			return
		OS.delay_usec(50)

func _finish() -> void:
	stop_us = Time.get_ticks_usec()
	requester.wait_to_finish()
	var latency_us: int = stop_us - cancel_requested_us
	var success: bool = result_state == "cancelled" and request_in_work_phase in ["scan", "fallback"] and cancel_requested_us > 0 and cancel_observed_us >= cancel_requested_us and latency_us <= 100000 and scan_prices_completed - prices_at_request <= 1 and JSON.stringify(profile) == original_json
	print(JSON.stringify({"kind":"exploratory_default_work_cancel","success":success,"state":result_state,"request_in_work_phase":request_in_work_phase,"requested_us":cancel_requested_us,"observed_us":cancel_observed_us,"stopped_us":stop_us,"latency_us_including_request_wait":latency_us,"ticks":tick_count,"max_tick_us":max_tick_us,"prices_at_request":prices_at_request,"prices_at_stop":scan_prices_completed,"live_unchanged":JSON.stringify(profile)==original_json}))
	quit(0 if success else 1)
