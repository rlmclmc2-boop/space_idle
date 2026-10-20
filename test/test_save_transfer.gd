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
 var writer:=preload("res://scripts/progress_writer.gd")
 for query in [[0,["123"]],[1,[]],[1,["permission denied"]],[-1,[]],[2,["invalid option"]]]:
  check(writer._import_owner_ps_result(query[0],query[1])!=(query[0]==1 and query[1].is_empty()),"Failed ownership query is retained; only confirmed absence is cleared")
 var durable_fields:=["aiTechLevels","aiTechProgress","aiTechActive","aiTechInput","aiIncomePeak","aiTechCompletionUnread","productionElapsed","equipmentSwitchUntil"]
 var missing:=durable_fields.filter(func(key):return not Transfer.schema().has(key))
 check(missing.is_empty() and Transfer.schema().resourceSamples[0].has("production_time"),"Portable contract covers durable fields and sample production time")
 if not missing.is_empty() or not Transfer.schema().resourceSamples[0].has("production_time"):
  print("S03 BASELINE REPRO: missing "+str(missing)+"; sample.production_time="+str(Transfer.schema().resourceSamples[0].has("production_time")))
  quit(1)
  return
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g:=BattleGame.new(db,false);g.profile.cleared=range(1,40);g.rebuild_unlocks();g.resume_progress();g.paused=true
 g.profile.resources={"1":{"m":9.7,"e":400.0},"2":321.0};g.profile.enhancementLevel=31;g.profile.planets["1"].conquered=true;g.profile.planets["1"].degree={"m":1.2,"e":350.0}
 g.profile.aiTechLevels.singularity=3
 g.profile.aiTechProgress.singularity=12.5
 g.profile.aiTechActive="singularity"
 g.profile.aiTechInput={"1":2,"2":3}
 g.profile.aiIncomePeak={"1":42.0,"2":21.0,"jewel":3.0}
 g.profile.aiTechCompletionUnread=true
 g.profile.productionElapsed=500.0
 var switch_id:=g.slot_id("weapons",0)
 g.profile.equipmentSwitchUntil[switch_id]=530.0
 var sample_time:=Time.get_unix_time_from_system()
 g.resource_samples=[{"time":sample_time,"production_time":495.0,"amount":7.0,"production_base":7.0,"id":"1","origin":"test"}]
 g.profile.hyperspaceReceipt={"round":int(g.profile.hyperspace.round_id),"run":int(g.profile.hyperspace.settled_run),"drone_id":"","unread":true}
 g.save_enabled=true
 check(g.progress_writer.acquire_owner(),"Synthetic ordinary game acquires the save lock")
 g.save_progress()
 check(g.last_save_error==OK,"Ordinary save writes current progress")
 var ordinary: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
 var portable_schema:=Transfer.schema()
 for key in ordinary:
  check(portable_schema.has(key),"Every ordinary durable field belongs to the portable contract: "+str(key))
 check(Transfer.clean(ordinary,portable_schema).size()==ordinary.size(),"Ordinary durable top-level fields all survive portable cleaning")
 for key in ["aiTechProgress","aiTechActive","aiIncomePeak","aiTechCompletionUnread","productionElapsed","equipmentSwitchUntil"]:
  check(ordinary.get(key)==g.profile[key],"Ordinary save retains "+key)
 check(int(ordinary.aiTechLevels.get("singularity",-1))==3 and int(ordinary.aiTechInput.get("1",-1))==2 and int(ordinary.aiTechInput.get("2",-1))==3,"Ordinary save retains AI integer maps")
 check(ordinary.resourceSamples.size()==1 and ordinary.resourceSamples[0].get("production_time")==495.0,"Ordinary save retains sample production time")
 g.save_enabled=false
 g.profile.external_credentials="never-export";g.profile.planets["1"].absolute_path="/private/not-portable"
 var transfer:=Transfer.new();var before:=g.profile.duplicate(true);var rng:=g.rng.state
 var exported:="user://transfer-export.json"
 check(transfer.export_progress(g,exported)==OK,"Export portable current progress")
 check(g.profile==before and g.rng.state==rng,"Export does not mutate runtime profile or RNG")
 var text:=FileAccess.get_file_as_string(exported);var raw: Dictionary=JSON.parse_string(text)
 for key in ["aiTechProgress","aiTechActive","aiIncomePeak","aiTechCompletionUnread","productionElapsed","equipmentSwitchUntil"]:
  check(raw.has(key) and raw[key]==g.profile[key],"Portable export retains "+key)
 check(int(raw.aiTechLevels.get("singularity",-1))==3 and int(raw.aiTechInput.get("1",-1))==2 and int(raw.aiTechInput.get("2",-1))==3,"Portable export retains AI integer maps")
 check(raw.resourceSamples.size()==1 and raw.resourceSamples[0].get("production_time")==495.0,"Portable export retains sample production time")
 check(not text.contains("never-export") and not text.contains("/private") and not raw.has("config"),"Export strips metadata and keeps configuration separate")
 var preview:=transfer.prepare(exported,db)
 if not preview.error.is_empty():printerr("Export preview rejected: "+preview.error);quit(1);return
 check(preview.error.is_empty() and preview.data.resources["1"]==raw.resources["1"],"Export prepares with huge GrowthNumber intact")
 for key in ["aiTechLevels","aiTechProgress","aiTechActive","aiTechInput","aiIncomePeak","aiTechCompletionUnread","productionElapsed","equipmentSwitchUntil"]:
  check(preview.data.get(key)==raw[key],"Import cleaner retains "+key)
 check(preview.data.resourceSamples[0].get("production_time")==495.0,"Import cleaner retains sample production time")
 for invalid in [{"aiTechLevels":{"singularity":"3"}},{"aiTechProgress":{"singularity":"bad"}},{"aiTechActive":[]},{"aiTechInput":{"1":true}},{"aiIncomePeak":{"1":"bad"}},{"aiTechCompletionUnread":1},{"productionElapsed":"500"},{"equipmentSwitchUntil":{switch_id:"later"}},{"resourceSamples":[{"production_time":"495"}]}]:
  var damaged_field:=raw.duplicate(true)
  damaged_field.merge(invalid,true)
  check(not transfer.prepare_data(damaged_field,db).error.is_empty(),"Reject malformed durable field "+str(invalid.keys()[0]))
 var receipt:Dictionary=preview.data.get("hyperspaceReceipt",{})
 check(receipt.size()==4 and Transfer.shape(receipt,Transfer.schema().hyperspaceReceipt) and int(receipt.get("round",-1))==int(g.profile.hyperspaceReceipt.round) and int(receipt.get("run",-1))==int(g.profile.hyperspaceReceipt.run) and receipt.get("drone_id")==g.profile.hyperspaceReceipt.drone_id and receipt.get("unread")==g.profile.hyperspaceReceipt.unread,"Actual export and prepare cleaner preserve unread UI receipt metadata")
 check(g.profile==before,"Preparing import is read-only")
 for version in [2,3,4]:
  var legacy:=raw.duplicate(true);legacy.version=version
  check(transfer.prepare_data(legacy,db).error.is_empty(),"Existing version migration accepts "+str(version))
 for bad in [{}, {"version":6,"resources":{"1":0,"2":0},"highestLevel":1}, {"version":4,"resources":[],"highestLevel":1}, {"version":4,"resources":{"1":{},"2":0},"highestLevel":1}]:
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
 for key in ["aiTechLevels","aiTechProgress","aiTechActive","aiTechInput","aiIncomePeak","aiTechCompletionUnread","productionElapsed","equipmentSwitchUntil"]:
  check(live_backup.data.get(key)==raw[key],"Import pre-backup retains "+key)
 check(live_backup.data.resourceSamples[0].get("production_time")==495.0,"Import pre-backup retains sample production time")
 var restored:=BattleGame.new(db,true)
 check(not restored.save_enabled and restored.last_save_error==ERR_ALREADY_IN_USE,"Parallel reload reads the committed import without gaining write ownership")
 check(restored.profile.aiTechLevels.singularity==3 and restored.profile.aiTechProgress.singularity==12.5 and restored.profile.aiTechActive=="singularity" and restored.profile.aiTechInput==g.profile.aiTechInput and restored.profile.aiIncomePeak==g.profile.aiIncomePeak and restored.profile.aiTechCompletionUnread,"Imported AI state survives startup")
 check(restored.profile.productionElapsed==500.0 and restored.profile.equipmentSwitchUntil.get(switch_id)==530.0 and restored.resource_samples.size()==1 and restored.resource_samples[0].get("production_time")==495.0,"Imported production clock, equipment deadline and sample survive startup")
 check(restored.profile.hyperspaceReceipt==g.profile.hyperspaceReceipt,"Confirmed import staging and startup reload retain the unread UI marker")
 check(restored.profile.resources==g.profile.resources and restored.profile.enhancementLevel==31 and restored.profile.planets["1"].conquered and GrowthNumber.compare(restored.profile.planets["1"].degree,g.profile.planets["1"].degree)==0,"Existing load restores big numbers, permanent planet state and enhancement")
 check(transfer.rollback(transaction)==OK and FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original,"Reload failure rollback restores exact original primary")
 var first:=transfer.commit_import(g,preview.data);transfer.finish(first)
 var second:=transfer.commit_import(g,preview.data);transfer.finish(second)
 check(first.error==OK and second.error==OK and first.backup!=second.backup,"Repeated import creates separate durable backups")
 var repeat:=BattleGame.new(db,true)
 check(repeat.profile.resources==restored.profile.resources,"Repeated import replaces rather than duplicates progress")
 check(transfer.export_progress(g,BattleGame.SAVE_PATH)==ERR_INVALID_PARAMETER,"Export cannot overwrite active progress path")
 restored=null;repeat=null;transaction.clear();first.clear();second.clear();g=null
 # Recovery of a process interruption between old-primary move and installation.
 FileAccess.open(BattleGame.SAVE_PATH+".import-prev",FileAccess.WRITE).store_string(original)
 DirAccess.remove_absolute(BattleGame.SAVE_PATH)
 FileAccess.open(BattleGame.SAVE_PATH+".import-new",FileAccess.WRITE).store_string('{"version":4}')
 var recovery_result:=preload("res://scripts/progress_writer.gd").read_progress_result(BattleGame.SAVE_PATH,db)
 check(recovery_result.status=="loaded" and recovery_result.source==".import-prev" and recovery_result.data.resources["1"]==111 and not FileAccess.file_exists(BattleGame.SAVE_PATH),"Interrupted installation selects the previous committed file without changing disk")
 var recovered_game:=BattleGame.new(db,true)
 check(recovered_game.progress_writer.owns_progress(),"Recovery startup reacquires released ownership")
 check(recovered_game.profile.resources["1"]==111 and FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==original,"Successful startup restores the selected committed file")
 check(not FileAccess.file_exists(BattleGame.SAVE_PATH+".import-prev") and not FileAccess.file_exists(BattleGame.SAVE_PATH+".import-new"),"Successful recovery clears owned staging files for retry")
 print("SAVE TRANSFER: %d checks, %d failures"%[checks,failures])
 if failures==0:print("S01_COMPLETE:test_save_transfer.gd")
 quit(1 if failures else 0)
