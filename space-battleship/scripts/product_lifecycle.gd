extends RefCounted
## One authority for product replacement. A reload request is not installation.
static var pending: RefCounted
static var constructing_scene := false
var recovery:Dictionary = {}
var state := "ready"
var reason := ""
var source := "live"
var transaction: Dictionary = {}
var operation := "import"
var writer: RefCounted
var transfer: RefCounted
var previous: WeakRef
var installed: WeakRef

func ready() -> bool:return state == "ready"
func result() -> Dictionary:return {"state":state,"reason":reason,"source":source}
func fail(why: String, authority: String) -> Dictionary:
 state="recovery_required";reason=why;source=authority
 return result()
func begin() -> bool:
 if not ready():return false
 state="preparing";reason=""
 return true
func complete(authority: String) -> void:
 state="ready";reason="";source=authority

func import_progress(g, raw: Dictionary, service) -> Dictionary:
 if not g.snapshot_ready() or g.commit_effects.active or pending!=null:return {"error":ERR_BUSY}
 var previous_snapshot:Dictionary=g.portable_save_data()
 if not begin():return {"error":ERR_BUSY}
 operation="import"
 previous=weakref(g);writer=g.progress_writer;transfer=service
 transaction=transfer._commit_import_owned(g,raw,previous_snapshot)
 if transaction.error!=OK:
  # A failed installation can itself have failed to restore the old primary.
  if transaction.get("recovery_required",false):fail("import_install_rollback_failed",str(transaction.get("backup","disk")))
  else:complete("live")
  return transaction
 state="installing";source=str(transaction.primary);pending=self
 return transaction

func attach(g) -> void:
 installed=weakref(g)
 g.lifecycle=self;g.commit_effects.guard=self

func finish_startup(g) -> bool:
 if recovery.is_empty():return ready()
 recovery.import_active=false
 var error:Error=g.progress_writer.finish_loaded_recovery(g.progress_writer.path,recovery)
 if error!=OK:
  fail("progress_recovery_pending",str(recovery.source));return false
 recovery={};return true

func watch_scene(tree: SceneTree) -> void:
 tree.scene_changed.connect(func():
  var scene=tree.current_scene
  if scene!=null and "game" in scene and scene.game!=null:attach(scene.game)
  if scene==null or not ("product_ready" in scene) or not scene.product_ready:
   fail("scene_not_ready",source)
  elif installed==null or installed.get_ref()!=scene.game or not scene.game.startup_error.is_empty():
   fail("replacement_not_installed",source)
  elif operation=="import" and not import_target_installed(scene.game):
   fail("import_target_not_installed",str(scene.game.installed_progress.get("source","unknown")))
   scene.product_ready=false;scene.set_process(false);scene.set_process_unhandled_input(false)
  else:
   var error: Error=transfer.finish_restart(transaction) if operation=="clear" else (transfer.finish(transaction) if operation=="import" else OK)
   if error!=OK:fail("import_finalization_failed",source)
   else:
    complete("installed")
    if operation=="import":scene.save_transfer_message(UIText.t("save.import_success",{"backup":str(transaction.get("backup","disk"))+"/current-progress.json"}))
    pending=null;transaction={};writer=null;transfer=null;previous=null;installed=null
 ,CONNECT_ONE_SHOT)

func import_target_installed(g)->bool:
 var expected:String=str(transaction.get("target_identity",""))
 var actual:Dictionary=g.installed_progress
 if expected.is_empty() or actual.get("source","unknown")!="" or actual.get("identity","")!=expected:return false
 # The bytes actually installed and the retained primary must both be this target.
 var checked:Dictionary=writer._check_progress_file(str(transaction.primary),g.db)
 return checked.error.is_empty() and checked.get("identity","") == expected

func reload_failed(error: Error) -> Dictionary:
 var rollback_error: Error=transfer.rollback_restart(transaction) if operation=="clear" else (transfer.rollback(transaction) if operation=="import" else OK)
 var old=previous.get_ref() if previous!=null else null
 if rollback_error==OK and old!=null and operation=="import":
  var check:Dictionary=writer.read_progress_result(writer.path,old.db)
  if (transaction.had_primary and check.status!="loaded") or (not transaction.had_primary and FileAccess.file_exists(writer.path)):
   rollback_error=ERR_FILE_CORRUPT
 if rollback_error!=OK or old==null:fail("reload_rollback_failed",str(transaction.get("backup","disk")))
 else:complete("live")
 pending=null
 return {"error":error,"rollback":rollback_error,"backup":str(transaction.get("backup","disk")),"state":state}

func restart(g, clear:bool, service) -> Dictionary:
 if not g.snapshot_ready() or g.commit_effects.active or pending!=null or not begin():return {"error":ERR_BUSY}
 operation="clear" if clear else "restart"
 previous=weakref(g);writer=g.progress_writer;transfer=service
 transaction=transfer.stage_restart(g) if clear else {"error":OK}
 if transaction.error!=OK:
  complete("live");return transaction
 pending=self;state="installing";source="fresh" if clear else "disk"
 return transaction

static func acknowledge_process(g)->bool:
 var args:=OS.get_cmdline_user_args()
 var index:=args.find("--restart-id")
 if index<0:return true
 if index+1>=args.size():g.lifecycle.fail("restart_identity_missing","disk");return false
 var token:String=args[index+1]
 if token.length()!=32 or not token.is_valid_hex_number(false):g.lifecycle.fail("restart_identity_invalid","disk");return false
 if not g.progress_writer.owns_progress():g.lifecycle.fail("restart_owner_missing","disk");return false
 var path:="user://restart-"+token+".json"
 var file:=FileAccess.open(path,FileAccess.WRITE)
 if file==null:g.lifecycle.fail("restart_ack_write","disk");return false
 file.store_string(JSON.stringify({"id":token,"pid":OS.get_process_id(),"state":"ready","owns_progress":true}))
 file.flush()
 var error:=file.get_error();file.close()
 if error!=OK:g.lifecycle.fail("restart_ack_write","disk");return false
 return true
