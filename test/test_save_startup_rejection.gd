extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	source.profile.highestLevel=6;source.profile.cleared=range(1,6);source.rebuild_unlocks()
	raw=source.portable_save_data();raw.hyperspace.version=4;raw.hyperspace.erase("idle")
	bytes=JSON.stringify(raw).to_utf8_buffer();file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	var restored:=BattleGame.new(db,true)
	check(restored.startup_error.is_empty() and restored.save_enabled and restored.profile.highestLevel==6,"actual persisted v4 startup restores nonfresh stage")
	check(restored.profile.resources==raw.resources and FileAccess.get_file_as_bytes(path)==bytes,"successful startup preserves balances and original bytes until explicit save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var fresh:=BattleGame.new(db,true)
	check(fresh.startup_error.is_empty() and fresh.save_enabled,"genuine first launch remains available")
	print("SAVE_STARTUP_REJECTION: ",checks," checks ",failures," failures; isolated invalid fixture only")
	quit(1 if failures else 0)
