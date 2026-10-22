extends RefCounted
## Desktop portable progress, validated before any live state or file replacement.
const Writer := preload("res://scripts/progress_writer.gd")
const ReactorInt := preload("res://scripts/reactor_integer.gd")
const MAX_BYTES := 16 * 1024 * 1024
const BACKUP_ROOT := "user://save-import-backups"
const SUPPORTED_VERSIONS := [BattleGame.SAVE_VERSION]
# Complete current-format fields; legacy saves are explicitly unsupported.
const CURRENT_FIELDS := ["version","resources","materials","ultimateCores","highestLevel","cleared","bossSeen","unlocked","loop","selectedShip","loadout","moduleVersion","productionElapsed","aiTechLevels","aiTechProgress","aiTechActive","aiTechInput","aiIncomePeak","aiTechCompletionUnread","equipmentSwitchUntil","hightechSavedAt","resourceSamples","chronoSavedAt","chronoParticles","reactorLevel","reactorAllocation","enhancementVersion","enhancementLevel","enhancementOrder","enhancementBranches","enhancementAttacks","enhancementHits","lifetime_max_stage","seenUnlocks","readUnlocks","jewelFragments","jewelFurnaceElapsed","jewelFurnaceIncomePeak","hyperspace","hyperspaceReceipt","onboarding","jewels","levels","galaxies","galaxyIncomeElapsed","grantedUnlocks","saveIntervalMinutes","planets","crew","crewEquipment"]
static func structure_quality(raw: Dictionary) -> Dictionary:
 var slots = raw.get("loadout")
 if raw.get("version") == BattleGame.SAVE_VERSION and slots is Dictionary and slots.has("weapons") and slots.has("defence") and CURRENT_FIELDS.all(func(key):return raw.has(key)):
  return {"quality":"complete","quality_rank":3}
 return {"quality":"incomplete","quality_rank":0}

static func schema() -> Dictionary:
 var building := {"status":"s","build_progress":"g","crew":["s"]}
 var planet := {"degree":"g","unlocked":"b","conquered":"b","auto_explore":"b","crewId":"s","elapsed":"n","buildings":{"*":building}}
 var node := {"id":"i","parent_id":"i","depth":"i","planned_type":"s","node_id":"s","type":"s","world_pos":"p","footprint":"p","rotation_y":"n","connections":["s"],"requires":["s"],"visual_seed":"i"}
 var edge := {"from":"s","to":"s","width":"n","path":["p"]}
 var blueprint := {"layout_version":"i","core_id":"s","units":"s","core":node,"nodes":[node],"edges":[edge]}
 var slot := {"id":"n","node_id":"s","world_pos":"p","unlock_progress":"n","status":"s","type":"s","level":"i","work":"n","construction":"n","upgrade_progress":"n","visual_seed":"i","planned_type":"s","parent_id":"i"}
 var galaxy := {"version":"i","status":"s","explore_work":"n","upgrade_work":"n","slot_seed":"i","build_elapsed":"n","bag":["s"],"rounds":"i","special_due":"b","rng_state":"s","map_rng_state":"s","owned":"s","blueprint":blueprint,"slots":[slot],"pending_online_time":"n","pending_crew_count":"i"}
 var result := {"version":"i","resources":{"*":"g"},"selectedShip":"s","loadout":{"*": [{"key":"s","level":"i"}]},"unlocked":["s"],"levels":{"*":"n"},"planets":{"*":planet},"galaxies":{"*":galaxy},"crew":[{"crewId":"s","level":"i","exp":"n","assignmentType":"s","targetId":"s","upgradeMode":"s","equipmentSlots":["empty"]}],"crewEquipment":{},"jewels":[],"jewelFragments":"currency","saveIntervalMinutes":"interval","onboarding":{"version":"i","intro":"b","equipped":"b","upgraded":"b","completed":"b","dismissed":"b","retreatSeen":"b","pickupSeen":"b"},"journey":{"stage":"n","groupIndex":"n","state":"n","distance":"n","guardArrived":"b","retreatBossPending":"b","pendingUnlocks":["s"]},"enhancementOrder":{"*": ["s"]},"enhancementBranches":{"*":{"*":{"*":"s"}}}}
 for key in ["highestLevel","lifetime_max_stage","moduleVersion","hightechVersion","enhancementVersion","scientists","enhancementLevel","enhancementAttacks","enhancementHits","jewelFurnaceElapsed","jewelFurnaceIncomePeak","chronoParticles","chronoSavedAt","hightechSavedAt","furnaceElapsed","furnaceIncomePeak","guardDeath","loopLevel","guardStage","guardIndex","guardDistance","reactorLevel"]:result[key]="n"
 for key in ["cleared","bossSeen"]:result[key]=["n"]
 for key in ["grantedUnlocks","seenUnlocks","readUnlocks","hightechOrder"]:result[key]=["s"]
 for key in ["hightechLevels","scientistAssignments"]:result[key]={"*":"i"}
 result.reactorAllocation={"*":"r"}
 # The portable projection includes every live durable field used by the
 # ordinary save. Legacy versions may omit these fields during migration.
 result.aiTechLevels={"*":"i"}
 result.aiTechProgress={"*":"n"}
 result.aiTechActive="s"
 result.aiTechInput={"*":"i"}
 result.aiIncomePeak={"*":"g"}
 result.aiTechCompletionUnread="b"
 result.productionElapsed="n"
 result.galaxyIncomeElapsed="n"
 result.equipmentSwitchUntil={"*":"n"}
 result.techPoints={"*":"n"}
 for key in ["highestLevel","lifetime_max_stage","moduleVersion","hightechVersion","enhancementVersion","scientists","enhancementLevel","enhancementAttacks","enhancementHits","guardDeath","loopLevel","guardStage","guardIndex","reactorLevel"]:result[key]="i"
 result.enhancementAttacks="counter";result.enhancementHits="counter"
 result.loop="b"
 result.resourceSamples=[{"time":"n","amount":"g","production_base":"g","id":"s","origin":"s","production_time":"n"}]
 result.hightechDrops=[{"uid":"n","x":"n","y":"n","age":"n","id":"s","amount":"n","hightech":"b","jewel":"b","jewelRatio":"n"}]
 result.materials={"*":"i"}
 result.ultimateCores="i"
 result.hyperspace=preload("res://scripts/hyperspace_state.gd").schema()
 result.hyperspaceReceipt={"round":"i","run":"i","drone_id":"s","unread":"b"}
 return result

static func shape(value: Variant, spec: Variant, depth := 0) -> bool:
 if depth>48:return false
 if spec is String:
  match spec:
   "counter":return preload("res://scripts/enhancement_growth.gd").valid_counter(value)
   "filter_value":return value is String or ((value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)))
   "s":return value is String
   "b":return value is bool
   "n":return (value is int or value is float) and is_finite(float(value))
   "i":return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)) and absf(float(value))<9.22e18
   "g":return GrowthNumber.valid(value)
   "r":return ReactorInt.valid(value) or ((value is int or value is float) and is_finite(float(value)) and value>=0 and value==floorf(float(value)) and float(value)<9223372036854775808.0)
   "currency":return GrowthNumber.valid(value) or (value is Dictionary and value.values().all(func(n):return GrowthNumber.valid(n)))
   "interval":return BattleGame.parse_save_interval(str(value))>0 and (value is String or value is int or value is float)
   "p":return value is Array and value.size()==2 and value.all(func(n):return (n is float or n is int) and is_finite(float(n)))
   "empty":return value==null
  return false
 if spec is Array:
  if not value is Array:return false
  if spec.is_empty():return true # Retired jewel bag is ignored by the existing migration.
  return value.all(func(item):return shape(item,spec[0],depth+1))
 if not value is Dictionary:return false
 for key in value:
  if spec.has(key) and not shape(value[key],spec[key],depth+1):return false
  if spec.has("*") and not shape(value[key],spec["*"],depth+1):return false
 return true

static func clean(value: Variant, spec: Variant) -> Variant:
 # Strip unrelated/unknown fields rather than transporting local metadata.
 if spec is String:return value.duplicate(true) if value is Dictionary or value is Array else value
 if spec is Array:
  return value.map(func(item):return clean(item,spec[0])) if not spec.is_empty() else []
 var result := {}
 for key in value:
  if spec.has(key):result[key]=clean(value[key],spec[key])
  elif spec.has("*"):result[key]=clean(value[key],spec["*"])
 return result

func prepare(path: String, db: ShipDatabase) -> Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"error":"read"}
 if file.get_length()<=0 or file.get_length()>MAX_BYTES:return {"error":"size"}
 var bytes:=file.get_buffer(file.get_length())
 if file.get_error()!=OK:return {"error":"read"}
 file.close()
 var parser:=JSON.new()
 var source:=bytes.get_string_from_utf8()
 if parser.parse(source)!=OK or not parser.data is Dictionary:return {"error":"format"}
 return prepare_data(parser.data,db)

func prepare_data(raw: Dictionary, db: ShipDatabase) -> Dictionary:
 if not (raw.get("version") is float or raw.get("version") is int) or raw.version!=floorf(float(raw.version)) or int(raw.version) not in SUPPORTED_VERSIONS:return {"error":"version"}
 if not raw.get("resources") is Dictionary or not raw.resources.has("1") or not raw.resources.has("2") or not raw.has("highestLevel"):return {"error":"format"}
 if not shape(raw,schema()):return {"error":"format"}
 if structure_quality(raw).quality_rank != 3:return {"error":"incomplete"}
 if not preload("res://scripts/economy_state.gd").valid_snapshot(raw):return {"error":"economy"}
 var material_keys: Array=preload("res://scripts/hyperspace_config.gd").load_config().routes.values().map(func(route):return str(route.material))
 if not preload("res://scripts/economy_state.gd").valid_material_wallet({"materials":raw.materials,"ultimate_cores":raw.ultimateCores},material_keys):return {"error":"materials"}
 if not preload("res://scripts/enhancement_growth.gd").valid_snapshot(raw):return {"error":"enhancement"}
 if not preload("res://scripts/equipment_state.gd").valid_snapshot(raw,db):return {"error":"equipment"}
 if not preload("res://scripts/ai_tech_tree.gd").valid_snapshot(raw,db.data.ai_tech_tree):return {"error":"research"}
 if not preload("res://scripts/crew_system.gd").valid_snapshot(raw,db):return {"error":"crew"}
 if not preload("res://scripts/planet_state.gd").valid_snapshot(raw,db):return {"error":"planets"}
 if not preload("res://scripts/reactor_state.gd").valid_snapshot(raw,db.config):return {"error":"reactor"}
 if not db.ships.has(str(raw.selectedShip)) or int(raw.highestLevel)<1 or int(raw.highestLevel)>db.levels.size():return {"error":"progress"}
 if raw.get("reactorAllocation") is Dictionary:
  var allowed:=String(db.config.reactorModules).split(",")
  for key in raw.reactorAllocation:
   if key not in allowed:return {"error":"format"}
 if raw.has("hyperspace") and not preload("res://scripts/hyperspace_state.gd").valid(raw.hyperspace,preload("res://scripts/hyperspace_config.gd").load_config(),db.levels.size()):return {"error":"format"}
 if raw.has("hyperspace") and not preload("res://scripts/hyperspace_permissions.gd").bindings_valid(raw,db.data,preload("res://scripts/hyperspace_config.gd").load_config()):return {"error":"format"}
 if not preload("res://scripts/galaxy_system.gd").valid_snapshot(raw,db):return {"error":"galaxies"}
 var quality:=structure_quality(raw)
 return {"error":"","data":clean(raw,schema()),"stage":int(raw.highestLevel),"ship":str(raw.selectedShip),"quality":quality.quality,"quality_rank":quality.quality_rank}

func prepare_disk_data(raw: Dictionary, db: ShipDatabase) -> Dictionary:
 return prepare_data(raw, db)

func export_progress(game: BattleGame, path: String) -> Error:
 var target:=ProjectSettings.globalize_path(path).simplify_path()
 if Writer.is_protected_target(target,game.progress_writer.path):return ERR_INVALID_PARAMETER
 return write_file(target,JSON.stringify(clean(game.portable_save_data(),schema()),"\t").to_utf8_buffer())

func write_file(path: String, bytes: PackedByteArray) -> Error:
 var writer:=Writer.new();writer.path=path
 return writer.write_progress(bytes)

func rename(from: String,to: String) -> Error:
 return DirAccess.rename_absolute(from,to)

func commit_import(game: BattleGame, raw: Dictionary) -> Dictionary:
 if not game.progress_writer.owns_progress():return {"error":ERR_ALREADY_IN_USE}
 # Install ownership before staging bytes, so startup in another process cannot
 # mistake an in-flight transaction for an interrupted import.
 var marker: String=game.progress_writer.path+".import-active"
 if FileAccess.file_exists(marker) or DirAccess.dir_exists_absolute(marker):return {"error":ERR_ALREADY_IN_USE}
 var error:=game.progress_writer.write_import_stage(marker,JSON.stringify({"pid":OS.get_process_id()}).to_utf8_buffer())
 if error!=OK:return {"error":error}
 var transaction:=_commit_import(game,raw)
 DirAccess.remove_absolute(marker)
 if transaction.get("error") == OK:
  transaction.owner_lock=game.progress_writer.owner_handle()
  transaction.owner_writer=game.progress_writer
 return transaction

func _commit_import(game: BattleGame, raw: Dictionary) -> Dictionary:
 var source_db=game.manual_hyperspace.base_db if game.manual_hyperspace.active else game.db
 var prepared:=prepare_data(raw,source_db)
 if not prepared.error.is_empty():return {"error":ERR_INVALID_DATA}
 var primary: String=game.progress_writer.path
 var previous:=primary+".import-prev"
 var incoming:=primary+".import-new"
 if FileAccess.file_exists(previous) or DirAccess.dir_exists_absolute(previous) or FileAccess.file_exists(incoming) or DirAccess.dir_exists_absolute(incoming):return {"error":ERR_ALREADY_IN_USE}
 var backup:=ProjectSettings.globalize_path(BACKUP_ROOT)+"/%d-%d"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
 var error:=DirAccess.make_dir_recursive_absolute(backup)
 if error!=OK:return {"error":error}
 error=write_file(backup+"/current-progress.json",JSON.stringify(clean(game.portable_save_data(),schema()),"\t").to_utf8_buffer())
 if error!=OK:return {"error":error}
 for suffix in ["", ".bak"]:
  if FileAccess.file_exists(primary+suffix):
   var original_file:=FileAccess.open(primary+suffix,FileAccess.READ)
   if original_file==null:return {"error":FileAccess.get_open_error()}
   var bytes:=original_file.get_buffer(original_file.get_length())
   if original_file.get_error()!=OK:return {"error":ERR_FILE_CANT_READ}
   original_file.close()
   error=write_file(backup+("/original-progress.json" if suffix.is_empty() else "/original-recovery.json"),bytes)
   if error!=OK:return {"error":error}
 var installed:Dictionary=prepared.data
 error=game.progress_writer.write_import_stage(incoming,JSON.stringify(clean(installed,schema()),"\t").to_utf8_buffer())
 if error!=OK:return {"error":error}
 var had_primary:=FileAccess.file_exists(primary)
 if had_primary:
  error=rename(primary,previous)
  if error!=OK:DirAccess.remove_absolute(incoming);return {"error":error}
 error=rename(incoming,primary)
 if error!=OK:
  if had_primary:rename(previous,primary)
  DirAccess.remove_absolute(incoming)
  return {"error":error,"backup":backup}
 return {"error":OK,"backup":backup,"primary":primary,"had_primary":had_primary}

func rollback(transaction: Dictionary) -> Error:
 if not _transaction_owns_progress(transaction):return ERR_ALREADY_IN_USE
 var primary: String=transaction.primary
 if transaction.had_primary and not FileAccess.file_exists(primary+".import-prev"):
  var backup_file:=FileAccess.open(str(transaction.backup)+"/original-progress.json",FileAccess.READ)
  if backup_file==null:return FileAccess.get_open_error()
  var bytes:=backup_file.get_buffer(backup_file.get_length())
  if backup_file.get_error()!=OK:return ERR_FILE_CANT_READ
  backup_file.close()
  var restored: Error=transaction.owner_writer.write_import_stage(primary+".import-prev",bytes)
  if restored!=OK:return restored
 var error:=DirAccess.remove_absolute(primary)
 if error!=OK:return error
 return rename(primary+".import-prev",primary) if transaction.had_primary else OK

func finish(transaction: Dictionary) -> void:
 if not _transaction_owns_progress(transaction):return
 if transaction.had_primary:DirAccess.remove_absolute(str(transaction.primary)+".import-prev")

func _transaction_owns_progress(transaction: Dictionary) -> bool:
 var owner: RefCounted=transaction.get("owner_lock")
 var writer: RefCounted=transaction.get("owner_writer")
 return owner != null and owner.owns() and writer != null and writer.owns_progress() and writer.owner_handle() == owner
