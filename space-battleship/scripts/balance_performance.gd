extends RefCounted
## Debug-only, real-time sampled diagnostics. Stream records; retain no history.
var enabled := false
var interval_usec := 5000000
var started := 0
var previous_time := 0
var previous_steps := 0
var next_time := 0
var records := 0
var peaks := {}
var first_rate := 0.0
var last_rate := 0.0
var path := ""
var stream: FileAccess

func configure(directory: String, active := true, interval_seconds := 5.0) -> void:
	enabled = active and OS.has_feature("debug")
	interval_usec = int(maxf(1.0,interval_seconds)*1000000)
	started = Time.get_ticks_usec()
	previous_time = started
	next_time = started+interval_usec
	if not enabled:return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:return
	path = directory.path_join("performance_%d_%d.jsonl" % [OS.get_process_id(),started])
	stream = FileAccess.open(path,FileAccess.WRITE)

func sample(runner, force := false) -> void:
	if not enabled or runner.game == null:return
	var now := Time.get_ticks_usec()
	if not force and now < next_time:return
	var elapsed := float(now-previous_time)/1000000.0
	var rate := float(runner.logic_steps_total-previous_steps)/maxf(elapsed,0.000001)
	var game = runner.game
	var metrics = runner.metrics
	var timeline = metrics.timeline
	var sizes := {"enemies":game.enemies.size(),"projectiles":game.projectiles.size(),"drops":game.drops.size(),
		"pending_hits":game.pending_hits.size(),
		"resource_samples":game.resource_samples.size(),"jewel_repeats":game.jewel_repeats.size(),"jewels":game.profile.jewels.size(),
		"cooldowns":game.cooldowns.size(),"defence_damage":game.jewel_defence_damage.size(),"defence_times":game.jewel_defence_times.size(),"charged":game.jewel_charged.size(),
		"timeline":timeline.samples.size(),"events":timeline.events.size(),"decision_bins":timeline.decision_bins.size(),"born":metrics.born.size(),
		"damage_keys":metrics.damage.size(),"income_keys":metrics.income.size(),"spending_keys":metrics.spending.size(),"systems":metrics.uses.size(),
		"spending_systems":metrics.spending_by_system.size(),"usage_keys":metrics.usage_seconds.size(),"last_used":metrics.last_used.size(),
		"overflow_keys":metrics.overflow_seconds.size(),"choices":timeline.choices.size(),"marks":timeline.marks.size(),
		"cleared":game.profile.cleared.size(),"unlocks":game.profile.get("grantedUnlocks",[]).size(),
		"effect_entries":game.tick_effect_entries.size(),"repair_entries":game.repair_entries.size(),
		"research_rates":game.research_rates.size(),"research_active":game.research_active.size(),
		"unlock_cache":game.db.unlock_ids.size() if game.db.get("unlock_ids") != null else 0,
		"enemy_rows":game.db.enemy_rows.size() if game.db.get("enemy_rows") != null else 0,
		"reports":runner.reports.size(),"warnings":runner.warning_count,"equipment_rows":game.db.equipment_rows.size() if game.db.get("equipment_rows") != null else 0,
		"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphan_nodes":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"memory_bytes":OS.get_static_memory_usage(),
		"signal_connections":game.event.get_connections().size()}
	for key in sizes:peaks[key] = maxi(int(peaks.get(key,0)),int(sizes[key]))
	# Tiny forced final windows are not representative throughput measurements.
	if elapsed >= 1.0:
		if first_rate == 0:first_rate = rate
		last_rate = rate
	records += 1
	var job: Dictionary = runner.jobs[mini(runner.job_index,runner.jobs.size()-1)]
	var record := {"real_seconds":float(now-started)/1000000.0,"window_seconds":elapsed,"final":force,"sim_seconds":metrics.time,"total_game_seconds":runner.total_game_seconds,
		"simulation_mode":runner.config.get("simulation_mode","exact"),
		"run":mini(runner.job_index+1,runner.jobs.size()),"status":runner.status,"seed":job.seed,"strategy":job.strategy,
		"parameter_id":job.parameter_id,"parameter_value":job.value,"duration_seconds":runner.config.duration,"data_sha256":runner.config.data_sha256,
		"steps":runner.logic_steps_total,"steps_per_second":rate,"stage":game.stage,"containers":sizes}
	if stream != null:
		stream.store_line(JSON.stringify(record))
		stream.flush()
	previous_steps = runner.logic_steps_total
	previous_time = now
	next_time = now+interval_usec

func resume(steps: int) -> void:
	previous_time = Time.get_ticks_usec()
	previous_steps = steps
	next_time = previous_time+interval_usec

func summary() -> Dictionary:
	return {"path":path,"records":records,"sampled_peaks":peaks.duplicate(),"start_steps_per_second":first_rate,"end_steps_per_second":last_rate}

func close() -> void:
	if stream != null:stream.close()
	stream = null
