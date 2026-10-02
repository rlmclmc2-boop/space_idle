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
 var galaxy_key: String=raw.galaxies.keys()[0]
 var disk_before:=FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
 for kind in ["edge_to","edge_from","edge_core","unknown_type","unknown_planned","node_id","parent","connection"]:
  var malformed:=raw.duplicate(true)
  var region: Dictionary=malformed.galaxies[galaxy_key]
  match kind:
   "edge_to":region.blueprint.edges[0].to="node_999"
   "edge_from":region.blueprint.edges[0].from="node_999"
   "edge_core":region.blueprint.edges[0].to="core"
   "unknown_type":
    region.blueprint.nodes[0].type="unknown_construct"
    region.blueprint.nodes[0].planned_type="unknown_construct"
    region.slots[0].type="unknown_construct"
   "unknown_planned":region.blueprint.nodes[0].planned_type="unknown_construct"
   "node_id":region.blueprint.nodes[0].node_id="node_999"
   "parent":region.blueprint.nodes[1].parent_id=0 if region.blueprint.nodes[1].parent_id==-1 else -1
   "connection":region.blueprint.core.connections.append("node_999")
  write_json("user://transfer-bad-graph.json",malformed)
  check(not transfer.prepare("user://transfer-bad-graph.json",db).error.is_empty(),"Reject malformed galaxy file before confirmation: "+kind)
  check(transfer.commit_import(g,malformed).error==ERR_INVALID_DATA and g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==disk_before,"Rejected galaxy cannot replace disk/runtime: "+kind)
 for version in [1,2]:
  var legacy:=raw.duplicate(true);legacy.version=2 if version==1 else 3
  legacy.galaxies[galaxy_key].version=version
  legacy.galaxies[galaxy_key].erase("blueprint")
  check(transfer.prepare_data(legacy,db).error.is_empty(),"Legal old galaxy regenerates layout: "+str(version))
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
 # Recovery of a process interruption between old-primary move and installation.
 FileAccess.open(BattleGame.SAVE_PATH+".import-prev",FileAccess.WRITE).store_string(original)
 DirAccess.remove_absolute(BattleGame.SAVE_PATH)
 FileAccess.open(BattleGame.SAVE_PATH+".import-new",FileAccess.WRITE).store_string('{"version":4}')
 var recovered: Variant=preload("res://scripts/progress_writer.gd").read_progress(BattleGame.SAVE_PATH)
 check(recovered.resources["1"]==111 and FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original,"Interrupted installation restores the previous committed file on startup")
 check(not FileAccess.file_exists(BattleGame.SAVE_PATH+".import-prev") and not FileAccess.file_exists(BattleGame.SAVE_PATH+".import-new"),"Recovered interruption clears owned staging files for retry")
 print("SAVE TRANSFER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
