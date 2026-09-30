extends SceneTree

const Writer = preload("res://scripts/progress_writer.gd")
class SlowWriter extends "res://scripts/progress_writer.gd":
	func _write_payload(bytes: PackedByteArray) -> Dictionary:
		OS.delay_msec(80)
		return super._write_payload(bytes)
class FailingWriter extends "res://scripts/progress_writer.gd":
	var fail_install := false
	var fail_restore := false
	func _rename(from: String, to: String) -> Error:
		if fail_install and from.ends_with(".tmp"):return ERR_FILE_CANT_WRITE
		if fail_restore and from.ends_with(".bak"):return ERR_FILE_CANT_WRITE
		return super._rename(from, to)
class PartialWriter extends "res://scripts/progress_writer.gd":
	func _store_buffer(file: FileAccess, bytes: PackedByteArray) -> bool:
		file.store_buffer(bytes.slice(0,bytes.size()/2))
		# Simulate a backend accepting a truncated write. Base readback must catch it.
		return true
class OnceFailedWriter extends "res://scripts/progress_writer.gd":
	var attempts := 0
	func _write_payload(data: PackedByteArray) -> Dictionary:
		attempts+=1
		if attempts==1:return {"error":ERR_FILE_CANT_WRITE}
		return super._write_payload(data)
class ReplayScene extends "res://scripts/main.gd":
	var quit_committed := false
	func show_chrono_login_report() -> void:pass
	func show_qa_tools() -> void:pass
	func _quit_after_save() -> void:quit_committed=true

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func bytes(value: int) -> PackedByteArray:
	return JSON.stringify({"version":3,"resources":{"1":value}}).to_utf8_buffer()
func value(path: String) -> int:
	var data = Writer.read_progress(path)
	return int(data.resources["1"]) if data is Dictionary else -1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var writer := SlowWriter.new()
	writer.path="user://order.json"
	writer.immediate(bytes(100))
	var start := Time.get_ticks_usec()
	writer.enqueue(bytes(101))
	check(Time.get_ticks_usec()-start<40000,"Ordinary enqueue returns before 80ms IO completes")
	writer.enqueue(bytes(102))
	writer.enqueue(bytes(103))
	check(writer.pending_revision==4 and writer.revision==4,"Pending ordinary snapshots coalesce to newest revision")
	writer.finish()
	check(value(writer.path)==103 and writer.committed_revision==4,"Shutdown drains newest pending snapshot")
	writer.enqueue(bytes(104))
	writer.enqueue(bytes(105))
	writer.immediate(bytes(106))
	check(value(writer.path)==106 and writer.pending.is_empty() and writer.worker==null,"Immediate transaction joins old writer and supersedes pending snapshot")
	OS.delay_msec(100)
	check(value(writer.path)==106,"Older work cannot overwrite newer synchronous commit")
	writer.enqueue(bytes(107))
	writer.enqueue(bytes(108))
	check(writer.clear_files()==OK and value(writer.path)==-1,"Delete joins active worker, cancels queued work and removes recovery files")
	OS.delay_msec(100)
	check(value(writer.path)==-1,"Deleted progress cannot be resurrected by worker completion")
	var failure := FailingWriter.new()
	failure.path="user://rollback.json"
	failure.immediate(bytes(200))
	failure.fail_install=true
	check(failure.immediate(bytes(201)).error!=OK and value(failure.path)==200,"Install failure restores byte-identical old save")
	failure.fail_restore=true
	check(failure.immediate(bytes(202)).error!=OK and value(failure.path)==200,"Failed restoration leaves previous save recoverable from backup")
	failure.fail_install=false
	failure.fail_restore=false
	check(failure.immediate(bytes(203)).error==OK and value(failure.path)==203,"Retry commits new snapshot after backup recovery")
	var original := FileAccess.get_file_as_bytes(failure.path)
	var partial := PartialWriter.new()
	partial.path=failure.path
	check(partial.immediate(bytes(204)).error!=OK and FileAccess.get_file_as_bytes(failure.path)==original,"Partial temporary write cannot damage previous committed bytes")
	# Remove the previous incomplete regular file first, then obstruct creation.
	if FileAccess.file_exists(failure.path+".tmp"):
		DirAccess.remove_absolute(failure.path+".tmp")
		DirAccess.make_dir_absolute(failure.path+".tmp")
	check(failure.immediate(bytes(205)).error!=OK and FileAccess.get_file_as_bytes(failure.path)==original,"Open failure preserves previous bytes")
	DirAccess.remove_absolute(failure.path+".tmp")
	var game := BattleGame.new(ShipDatabase.new(),false)
	game.save_enabled=true
	game.ordinary_save_async_enabled=true
	game.progress_writer=SlowWriter.new()
	game.profile.resources["1"]=301
	game.save_progress()
	game.begin_frame_save_batch()
	game.profile.resources["1"]=302
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	game.profile.resources["1"]=303
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	game.finish_pending_saves()
	check(value(BattleGame.SAVE_PATH)==303 and not game.save_dirty,"Game finish commits final frame snapshot and clears dirty revision")
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	game.save_dirty=true
	game.finish_pending_saves()
	check(game.save_dirty,"Older completion cannot clear a later module dirty marker")
	game.save_progress()
	var errors := [0]
	game.event.connect(func(kind: String,_info: Dictionary):
		if kind=="save_error":errors[0]+=1)
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	game.begin_frame_save_batch()
	game.profile.resources["1"]=304
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	game.finish_pending_saves()
	check(errors[0]==1 and game.save_dirty and value(BattleGame.SAVE_PATH)==303,"Asynchronous failure reports on main thread and leaves dirty state for retry")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	game.save_progress()
	check(value(BattleGame.SAVE_PATH)==304 and not game.save_dirty,"Immediate retry succeeds after ordinary failure")
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.profile.resources["1"]=306
	game.save_progress()
	game.end_frame_save_batch()
	check(value(BattleGame.SAVE_PATH)==306 and game.progress_writer.worker==null and not game.save_dirty,"Unknown or critical request forces the mixed frame to commit synchronously")
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.group_index=game.db.levels[game.stage-1].groups.size()
	game.clear_level()
	game.end_frame_save_batch()
	var milestone: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(int(milestone.journey.state)==BattleGame.State.LEVEL_CLEAR and game.progress_writer.worker==null,"Level-clear milestone remains synchronous even beside an ordinary request")
	game.db.config.jewelCombine=3
	game.db.data.jewel["1"].maxLevel=3
	game.profile.highestLevel=int(game.db.unlock_row("feature","jewels").level)+1
	game.profile.jewels.clear()
	for i in 3:game.profile.jewels.append(game.new_jewel("1",1))
	game.save_progress()
	game.progress_writer=SlowWriter.new()
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	var combined := game.combine_all_jewels()
	var committed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(combined.ok and committed.jewels.size()==1 and int(committed.jewels[0].level)==2 and game.progress_writer.worker==null,"Real jewel transaction waits for older ordinary work and is committed before returning")
	game.profile.jewels.clear()
	for i in 3:game.profile.jewels.append(game.new_jewel("1",1))
	var before := game.profile.duplicate(true)
	var rng_before: int=game.rng.state
	var serial_before: int=game.jewel_serial
	var disk_before := FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	var failed_writer := FailingWriter.new()
	failed_writer.fail_install=true
	game.progress_writer=failed_writer
	combined=game.combine_all_jewels()
	check(not combined.ok and game.profile==before and game.rng.state==rng_before and game.jewel_serial==serial_before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==disk_before,"Real failed jewel transaction rolls back profile, RNG, serial and committed bytes")
	game.progress_writer=OnceFailedWriter.new()
	game.begin_frame_save_batch()
	game.request_ordinary_progress_save()
	game.end_frame_save_batch()
	combined=game.combine_all_jewels()
	check(combined.ok and game.profile.jewels.size()==1 and int(game.profile.jewels[0].level)==2,"Failure of an older ordinary job does not reject a succeeding synchronous transaction")
	game.progress_writer.clear_files()
	var scene := ReplayScene.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.ordinary_save_async_enabled=true
	scene.game.progress_writer=SlowWriter.new()
	scene.game.profile.resources["1"]=401
	scene.game.begin_frame_save_batch()
	scene.game.request_ordinary_progress_save()
	scene.game.end_frame_save_batch()
	scene.game.profile.resources["1"]=402
	scene.game.begin_frame_save_batch()
	scene.game.request_ordinary_progress_save()
	scene.game.end_frame_save_batch()
	scene.free()
	check(value(BattleGame.SAVE_PATH)==402,"Real scene exit joins and flushes pending ordinary save")
	var loaded := BattleGame.new(game.db,true)
	check(int(loaded.profile.resources["1"])==402,"Reload sees flushed progress")
	var closing := ReplayScene.new()
	root.add_child(closing)
	closing.set_process(false)
	closing.game.paused=true
	closing.game.profile.resources["1"]=403
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	closing._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not closing.quit_committed and closing.game.save_dirty,"Save failure keeps close request from exiting")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	closing._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(closing.quit_committed and value(BattleGame.SAVE_PATH)==403 and not closing.game.save_dirty,"Close request commits synchronously before allowing exit")
	closing.quit_committed=false
	closing.game.save_enabled=false
	closing._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(closing.quit_committed,"Intentionally save-disabled scene can still close")
	closing.free()
	loaded.progress_writer.clear_files()
	print("Tail save: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
