extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path:="user://progress.json"
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		printerr("REQUIRES empty isolated user directory; refusing to overwrite existing files");quit(2);return
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var source:=BattleGame.new(db,false)
	var raw:Dictionary=source.portable_save_data();raw.hyperspace.version=4.5
	var bytes:=JSON.stringify(raw).to_utf8_buffer()
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	var rejected:=BattleGame.new(db,true)
	check(rejected.startup_error=="invalid_progress_save" and rejected.paused,"invalid existing save blocks startup")
	check(not rejected.save_enabled and rejected.last_save_error==ERR_FILE_CORRUPT,"startup disables saving and reports file error")
	rejected.save_progress();rejected.next_timed_save_at=0;rejected.check_timed_save()
	check(FileAccess.get_file_as_bytes(path)==bytes,"manual and timed save cannot overwrite rejected original")
	check(not FileAccess.file_exists(path+".bak") and not FileAccess.file_exists(path+".tmp"),"rejection creates no replacement or misleading backup")
	rejected=null
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=[];scene.music_on=false
	root.add_child(scene)
	await process_frame
	check(not scene.presentation_ready and not scene.is_processing() and not scene.is_processing_unhandled_input(),"Rejected formal scene stays inactive")
	check(scene.ship_view==null and scene.battle_clip==null,"Failed parent startup never constructs battlefield")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Formal scene rejection preserves original save")
	scene.queue_free();await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	source.profile.highestLevel=6;source.profile.cleared=range(1,6);source.rebuild_unlocks()
	raw=source.portable_save_data()
	bytes=JSON.stringify(raw).to_utf8_buffer();file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	var restored:=BattleGame.new(db,true)
	check(restored.startup_error.is_empty() and restored.save_enabled and restored.profile.highestLevel==6,"actual persisted current snapshot restores nonfresh stage")
	check(restored.economy.save_data().resources==raw.resources and FileAccess.get_file_as_bytes(path)==bytes,"successful startup preserves balances and original bytes until explicit save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	restored=null
	var fresh:=BattleGame.new(db,true)
	check(fresh.startup_error.is_empty() and fresh.save_enabled,"genuine first launch remains available")
	scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene)
	check(scene.presentation_ready and scene.is_processing() and scene.ship_view!=null,"Successful formal scene builds and enables battlefield")
	scene.queue_free();await process_frame
	print("SAVE_STARTUP_REJECTION: ",checks," checks ",failures," failures; isolated invalid fixture only")
	quit(1 if failures else 0)
