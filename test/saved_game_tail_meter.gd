
	var reasons: Array = []
	var frame_saves: Array = []
	var all_saves: Array = []
	var save_clock := 0
	var stage_clock := 0
	var save_row := {}
	var by_revision := {}
	var in_longrun := false
	var long_frame_count := {"over20":0,"over33":0,"frames":0}
	var long_frame_max := 0.0
	func save_frame_begin() -> void:
		reasons.clear()
		frame_saves.clear()
	func save_reason(reason: String) -> void:
		if not reasons.has(reason):reasons.append(reason)
	func save_start() -> void:
		save_clock=Time.get_ticks_usec()
		stage_clock=save_clock
		save_row={"reason":reasons.duplicate(),"stages_us":{},"requested_us":save_clock}
	func save_stage(stage: String) -> void:
		var now := Time.get_ticks_usec()
		save_row.stages_us[stage]=now-stage_clock
		stage_clock=Time.get_ticks_usec()
	func save_end(bytes: int, success: bool) -> void:
		var now := Time.get_ticks_usec()
		save_row.total_us=now-save_clock
		var measured := 0
		for value in save_row.stages_us.values():measured+=int(value)
		save_row.stages_us.other=save_row.total_us-measured
		save_row.bytes=bytes
		save_row.success=success
		frame_saves.append(save_row)
	func save_blocking_end(started: int = 0) -> void:
		save_row.main_thread_save_us=Time.get_ticks_usec()-(started if started>0 else int(save_row.requested_us))
	func register_revision(revision: int) -> void:
		by_revision[revision]=save_row
		save_row.revision=revision
		save_row.front_total_us=save_row.total_us
		save_row.written=false
	func io_completed(revision: int, result: Dictionary) -> void:
		if not by_revision.has(revision):return
		var row: Dictionary=by_revision[revision]
		row.written=true
		row.success=result.error==OK
		row.stages_us.merge(result.io_stages_us)
		var io_measured := 0
		for value in result.io_stages_us.values():io_measured+=int(value)
		row.stages_us.other+=result.io_total_us-io_measured
		row.total_us=row.front_total_us+result.io_total_us
		row.request_to_commit_us=result.completed_us-row.requested_us
		by_revision.erase(revision)
	func attach_frame(frame: Dictionary) -> void:
		if in_longrun:
			long_frame_count.frames+=1
			if frame.frame_ms>20:long_frame_count.over20+=1
			if frame.frame_ms>33:long_frame_count.over33+=1
			long_frame_max=maxf(long_frame_max,frame.frame_ms)
		for row in frame_saves:
			row.frame={"page":frame.page,"index":frame.index,"frame_ms":frame.frame_ms,"cpu_ms":frame.cpu_ms,"stage":frame.stage,"state":frame.state,"enemies":frame.enemies,"projectiles":frame.projectiles,"modules":frame.modules}
			all_saves.append(row)
	func census(value: Variant) -> Dictionary:
		var counts := {"dicts":0,"arrays":0,"objects":0}
		var stack: Array=[value]
		while not stack.is_empty():
			var item=stack.pop_back()
			if item is Dictionary:
				counts.dicts+=1
				stack.append_array(item.values())
			elif item is Array:
				counts.arrays+=1
				stack.append_array(item)
			elif item is Object:counts.objects+=1
		return counts
