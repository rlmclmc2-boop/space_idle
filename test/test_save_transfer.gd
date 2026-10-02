extends SceneTree
const Transfer := preload("res://scripts/save_transfer.gd")
class FailInstall extends Transfer:
 func rename(from: String,to: String) -> Error:
  return ERR_FILE_CANT_WRITE if from.ends_with(".import-new") else super.rename(from,to)
class FailBackup extends Transfer:
 func write_file(path: String,bytes: PackedByteArray) -> Error:
  return ERR_FILE_CANT_WRITE if path.ends_with("current-progress.json") else super.write_file(path,bytes)
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func write_json(path: String,value: Variant) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g:=BattleGame.new(db,false);g.profile.cleared=range(1,40);g.rebuild_unlocks();g.resume_progress();g.paused=true
 g.profile.resources={"1":{"m":9.7,"e":400.0},"2":321.0};g.profile.enhancementLevel=31;g.profile.planets["1"].conquered=true;g.profile.planets["1"].degree={"m":1.2,"e":350.0}
 g.profile.external_credentials="never-export";g.profile.planets["1"].absolute_path="/private/not-portable"
 var transfer:=Transfer.new();var before:=g.profile.duplicate(true);var rng:=g.rng.state
 var exported:="user://transfer-export.json"
 check(transfer.export_progress(g,exported)==OK,"Export portable current progress")
 check(g.profile==before and g.rng.state==rng,"Export does not mutate runtime profile or RNG")
 var text:=FileAccess.get_file_as_string(exported);var raw: Dictionary=JSON.parse_string(text)
 check(not text.contains("never-export") and not text.contains("/private") and not raw.has("config"),"Export strips metadata and keeps configuration separate")
 var preview:=transfer.prepare(exported,db)
 if not preview.error.is_empty():printerr("Export preview rejected: "+preview.error);quit(1);return
 check(preview.error.is_empty() and preview.data.resources["1"]==raw.resources["1"],"Export prepares with huge GrowthNumber intact")
 check(g.profile==before,"Preparing import is read-only")
 for version in [2,3,4]:
  var legacy:=raw.duplicate(true);legacy.version=version
  check(transfer.prepare_data(legacy,db).error.is_empty(),"Existing version migration accepts "+str(version))
 for bad in [{}, {"version":5,"resources":{"1":0,"2":0},"highestLevel":1}, {"version":4,"resources":[],"highestLevel":1}, {"version":4,"resources":{"1":{},"2":0},"highestLevel":1}]:
  check(not transfer.prepare_data(bad,db).error.is_empty(),"Reject invalid type/structure/future version")
 for value in ["", "{", "[]", "{\"version\":4}", "not a save"]:
  var file:=FileAccess.open("user://transfer-bad.json",FileAccess.WRITE);file.store_string(value);file.close()
  check(not transfer.prepare("user://transfer-bad.json",db).error.is_empty(),"Reject damaged/truncated/wrong JSON")
 var damaged:=raw.duplicate(true);damaged.galaxies[damaged.galaxies.keys()[0]].blueprint={"layout_version":1}
 check(not transfer.prepare_data(damaged,db).error.is_empty(),"Reject incomplete galaxy layout before loader")
 check(g.profile==before,"All rejected imports preserve live state")
 var original:="{\"version\":4,\"resources\":{\"1\":111,\"2\":222},\"highestLevel\":1}"
 var original_file:=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE);original_file.store_string(original);original_file.close()
 var recovery:=FileAccess.open(BattleGame.SAVE_PATH+".bak",FileAccess.WRITE);recovery.store_string(original+"\n");recovery.close()
 for service in [FailBackup.new(),FailInstall.new()]:
  var failed: Dictionary=service.commit_import(g,preview.data)
  check(failed.error!=OK and g.profile==before,"Failed backup/install preserves runtime")
  check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original and FileAccess.get_file_as_string(BattleGame.SAVE_PATH+".bak")==original+"\n","Failed backup/install preserves exact primary and recovery bytes")
 var transaction:=transfer.commit_import(g,preview.data)
 check(transaction.error==OK,"Confirmed import installs canonical progress")
 check(FileAccess.get_file_as_string(transaction.backup+"/original-progress.json")==original,"Persistent backup retains exact previous on-disk bytes")
 var live_backup:=transfer.prepare(transaction.backup+"/current-progress.json",db)
 check(live_backup.error.is_empty() and live_backup.data.resources["1"]==raw.resources["1"],"Current unsaved progress has a reimportable persistent backup")
 var restored:=BattleGame.new(db,true)
 check(restored.profile.resources==g.profile.resources and restored.profile.enhancementLevel==31 and restored.profile.planets["1"].conquered and GrowthNumber.compare(restored.profile.planets["1"].degree,g.profile.planets["1"].degree)==0,"Existing load restores big numbers, permanent planet state and enhancement")
 check(transfer.rollback(transaction)==OK and FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original,"Reload failure rollback restores exact original primary")
 var first:=transfer.commit_import(g,preview.data);transfer.finish(first)
 var second:=transfer.commit_import(g,preview.data);transfer.finish(second)
 check(first.error==OK and second.error==OK and first.backup!=second.backup,"Repeated import creates separate durable backups")
 var repeat:=BattleGame.new(db,true)
 check(repeat.profile.resources==restored.profile.resources,"Repeated import replaces rather than duplicates progress")
 check(transfer.export_progress(g,BattleGame.SAVE_PATH)==ERR_INVALID_PARAMETER,"Export cannot overwrite active progress path")
 print("SAVE TRANSFER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
