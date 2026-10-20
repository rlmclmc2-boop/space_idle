extends SceneTree
const Transfer := preload("res://scripts/save_transfer.gd")
class Interrupted extends Transfer:
 var phase: String
 func stop() -> void:
  print("INTERRUPTION: "+phase)
  OS.kill(OS.get_process_id())
  while true:OS.delay_msec(10)
 func write_file(path: String,bytes: PackedByteArray) -> Error:
  var error:=super.write_file(path,bytes)
  if error==OK and path.ends_with(".import-new") and phase in ["staged","first-save"]:stop()
  return error
 func rename(from: String,to: String) -> Error:
  var error:=super.rename(from,to)
  if error==OK and ((phase=="moved" and to.ends_with(".import-prev")) or (phase=="installed" and from.ends_with(".import-new"))):stop()
  return error
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 var mode:=args[0]
 var phase:=args[1]
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var game:=BattleGame.new(db,mode!="interrupt")
 if mode=="interrupt":
  if FileAccess.file_exists(BattleGame.SAVE_PATH):game.load_progress_data(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)))
  var raw:=game.portable_save_data();raw.resources["1"]=333;raw.resources["2"]=444
  var service:=Interrupted.new();service.phase=phase
  var result:=service.commit_import(game,raw)
  printerr("Expected interruption, got "+str(result));quit(1);return
 var primary:=ProjectSettings.globalize_path(BattleGame.SAVE_PATH)
 check(OS.get_user_data_dir().contains("test/work"),"Isolated fresh-process user directory")
 var expected=BattleGame.new(db,false).profile.resources["1"] if phase=="first-save" else 333 if phase=="installed" else 111
 check(game.profile.resources["1"]==expected,"Fresh startup loads committed progress at "+phase)
 var before:=FileAccess.get_file_as_bytes(primary) if FileAccess.file_exists(primary) else PackedByteArray()
 var recovery:=FileAccess.get_file_as_bytes(primary+".bak") if FileAccess.file_exists(primary+".bak") else PackedByteArray()
 var previous:=FileAccess.get_file_as_bytes(primary+".import-prev") if FileAccess.file_exists(primary+".import-prev") else PackedByteArray()
 var incoming:=FileAccess.get_file_as_bytes(primary+".import-new") if FileAccess.file_exists(primary+".import-new") else PackedByteArray()
 if mode=="active":
  check(FileAccess.file_exists(primary+".import-active") and not incoming.is_empty(),"Startup retains live-owner staging")
  var blocked:=Transfer.new().commit_import(game,game.portable_save_data())
  check(blocked.error==ERR_ALREADY_IN_USE,"Another import cannot take live transaction ownership")
  check((FileAccess.get_file_as_bytes(primary) if FileAccess.file_exists(primary) else PackedByteArray())==before and FileAccess.get_file_as_bytes(primary+".import-new")==incoming and (FileAccess.get_file_as_bytes(primary+".import-prev") if FileAccess.file_exists(primary+".import-prev") else PackedByteArray())==previous,"Live transaction files stay byte-identical")
 else:
  check(not FileAccess.file_exists(primary+".import-active") and not FileAccess.file_exists(primary+".import-new") and not FileAccess.file_exists(primary+".import-prev"),"Fresh startup removes abandoned staging and ownership")
  var raw:=game.portable_save_data();raw.resources["1"]=555
  var service:=Transfer.new();var transaction:=service.commit_import(game,raw)
  check(transaction.error==OK,"Subsequent import succeeds after "+phase)
  if transaction.error==OK:
   check((FileAccess.get_file_as_bytes(transaction.backup+"/original-progress.json") if FileAccess.file_exists(transaction.backup+"/original-progress.json") else PackedByteArray())==before,"Subsequent import backs up exact recovered primary")
   check(service.rollback(transaction)==OK and (FileAccess.get_file_as_bytes(primary) if FileAccess.file_exists(primary) else PackedByteArray())==before,"Subsequent import rollback preserves recovered primary")
 check((FileAccess.get_file_as_bytes(primary+".bak") if FileAccess.file_exists(primary+".bak") else PackedByteArray())==recovery,"Startup/import preserve committed recovery copy")
 print("IMPORT RECOVERY "+mode+" "+phase+": %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
