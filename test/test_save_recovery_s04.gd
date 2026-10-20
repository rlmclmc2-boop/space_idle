extends SceneTree

const Writer := preload("res://scripts/progress_writer.gd")
class FailedInstall extends "res://scripts/progress_writer.gd":
	func _rename(from: String, to: String) -> Error:
		if from.ends_with(".tmp"):return ERR_FILE_CANT_WRITE
		return super._rename(from,to)
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func put(path: String, data: Variant) -> PackedByteArray:
	var bytes := JSON.stringify(data).to_utf8_buffer()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return bytes

func clear(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".rejected", ".import-prev", ".import-new", ".import-active"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)

func _initialize() -> void:
	var path := BattleGame.SAVE_PATH
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		printerr("Requires isolated empty user directory")
		quit(2)
		return
	var db := ShipDatabase.new()
	var source := BattleGame.new(db,false)
	source.profile.highestLevel = 6
	source.profile.cleared = [1,2,3,4,5]
	source.profile.resources["1"] = 4321.0
	var valid := source.portable_save_data()
	var bak_bytes := put(path+".bak", valid)
	var broken_bytes := put(path, {"version":5})
	var result := Writer.read_progress_result(path,db)
	check(result.status=="loaded" and result.source==".bak" and result.rejected.size()==1 and result.rejected[0].error=="format", "semantic primary falls back to backup")
	check(FileAccess.get_file_as_bytes(path)==broken_bytes and FileAccess.get_file_as_bytes(path+".bak")==bak_bytes, "selection does not alter either file")
	var restored := BattleGame.new(db,true)
	check(restored.startup_error.is_empty() and restored.profile.highestLevel==6 and restored.profile.resources["1"]==4321.0, "startup restores backup progress")
	var failed := FailedInstall.new()
	failed.path=ProjectSettings.globalize_path(path)
	failed.validation_db=db
	check(failed.write_progress(JSON.stringify(valid).to_utf8_buffer())!=OK, "failed replacement reports error")
	check(FileAccess.get_file_as_bytes(path)==broken_bytes and FileAccess.get_file_as_bytes(path+".bak")==bak_bytes, "failed replacement retains both original files")
	var writer := Writer.new()
	writer.path=ProjectSettings.globalize_path(path)
	writer.validation_db=db
	check(writer.write_progress(JSON.stringify(valid).to_utf8_buffer())==OK, "recovered progress can be saved")
	check(FileAccess.get_file_as_bytes(path+".rejected")==broken_bytes and FileAccess.get_file_as_bytes(path+".bak")==bak_bytes, "successful replacement retains rejected primary and valid backup")
	clear(path)
	var current_bytes := put(path,valid)
	put(path+".bak",{"version":5})
	result=Writer.read_progress_result(path,db)
	check(result.status=="loaded" and result.source=="", "valid primary wins over invalid backup")
	clear(path)
	put(path,{"version":5})
	put(path+".bak",{"version":5})
	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes(path+".bak")
	result=Writer.read_progress_result(path,db)
	check(result.status=="invalid" and result.rejected.size()==2, "both invalid yield explicit failure")
	var rejected := BattleGame.new(db,true)
	check(rejected.startup_error=="invalid_progress_save" and not rejected.save_enabled and rejected.profile.highestLevel==1, "failure retains fresh live state and blocks saving")
	rejected.save_progress()
	check(FileAccess.get_file_as_bytes(path)==primary_before and FileAccess.get_file_as_bytes(path+".bak")==backup_before, "failed startup retains files")
	clear(path)
	for version in [2,3,4,5]:
		var old := valid.duplicate(true)
		old.version=version
		if version<5:
			old.erase("aiTechLevels")
			old.erase("productionElapsed")
			old.erase("highestLevel")
		put(path,old)
		result=Writer.read_progress_result(path,db)
		check(result.status=="loaded" and result.data.version==version and result.data.highestLevel==(6 if version==5 else 1), "supported historical version "+str(version))
		clear(path)
	put(path+".import-prev",valid)
	var marker := put(path+".import-active",{"pid":-1})
	var incoming := put(path+".import-new",{"version":5})
	result=Writer.read_progress_result(path,db)
	check(result.status=="loaded" and result.source==".import-prev", "interrupted import previous state remains selectable")
	check(FileAccess.get_file_as_bytes(path+".import-active")==marker and FileAccess.get_file_as_bytes(path+".import-new")==incoming, "selection preserves import evidence")
	clear(path)
	put(path+".import-prev",valid)
	put(path+".import-new",{"version":5})
	var resumed := BattleGame.new(db,true)
	check(resumed.startup_error.is_empty() and resumed.profile.resources["1"]==4321.0, "interrupted import resumes previous committed state")
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(path+".import-prev") and not FileAccess.file_exists(path+".import-new"), "successful load retires abandoned import staging")
	clear(path)
	check(Writer.read_progress_result(path,db).status=="absent", "empty directory is absent")
	print("S04_RECOVERY: ",checks," checks ",failures," failures")
	print("S01_COMPLETE:test_save_recovery_s04.gd")
	quit(1 if failures else 0)
