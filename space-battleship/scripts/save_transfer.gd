extends RefCounted
## Desktop portable progress, validated before any live state or file replacement.
const Writer := preload("res://scripts/progress_writer.gd")
const Layout := preload("res://scripts/galaxy_layout.gd")
const MAX_BYTES := 16 * 1024 * 1024
const BACKUP_ROOT := "user://save-import-backups"

static func schema() -> Dictionary:
 var building := {"status":"s","build_progress":"g","crew":["s"]}
 var planet := {"degree":"g","unlocked":"b","conquered":"b","auto_explore":"b","crewId":"s","elapsed":"n","buildings":{"*":building}}
 var node := {"id":"i","parent_id":"i","depth":"i","planned_type":"s","node_id":"s","type":"s","world_pos":"p","footprint":"p","rotation_y":"n","connections":["s"],"requires":["s"],"visual_seed":"i"}
 var edge := {"from":"s","to":"s","width":"n","path":["p"]}
 var blueprint := {"layout_version":"i","core_id":"s","units":"s","core":node,"nodes":[node],"edges":[edge]}
 var slot := {"id":"n","node_id":"s","world_pos":"p","unlock_progress":"n","status":"s","type":"s","level":"i","work":"n","construction":"n","upgrade_progress":"n","visual_seed":"i","planned_type":"s","parent_id":"i"}
 var galaxy := {"version":"i","status":"s","explore_work":"n","upgrade_work":"n","slot_seed":"i","build_elapsed":"n","bag":["s"],"rounds":"i","special_due":"b","rng_state":"s","map_rng_state":"s","owned":"s","blueprint":blueprint,"slots":[slot],"pending_online_time":"n","pending_crew_count":"i"}
 var result := {"version":"i","resources":{"*":"g"},"selectedShip":"s","loadout":{"*": [{"key":"s","level":"i"}]},"unlocked":["s"],"levels":{"*":"n"},"planets":{"*":planet},"galaxies":{"*":galaxy},"crew":[{"crewId":"s","level":"i","exp":"n","assignmentType":"s","targetId":"s","upgradeMode":"s","equipmentSlots":["empty"]}],"crewEquipment":{},"jewels":[],"jewelFragments":"currency","saveIntervalMinutes":"interval","onboarding":{"version":"i","intro":"b","equipped":"b","upgraded":"b","completed":"b","dismissed":"b"},"journey":{"stage":"n","groupIndex":"n","state":"n","distance":"n","guardArrived":"b","retreatBossPending":"b","pendingUnlocks":["s"]},"enhancementOrder":{"*": ["s"]},"enhancementBranches":{"*":{"*":{"*":"s"}}}}
 for key in ["highestLevel","lifetime_max_stage","moduleVersion","hightechVersion","enhancementVersion","scientists","enhancementLevel","enhancementAttacks","enhancementHits","jewelFurnaceElapsed","jewelFurnaceIncomePeak","chronoParticles","chronoSavedAt","hightechSavedAt","furnaceElapsed","furnaceIncomePeak","guardDeath","loopLevel","guardStage","guardIndex","guardDistance","reactorLevel"]:result[key]="n"
 for key in ["cleared","bossSeen"]:result[key]=["n"]
 for key in ["grantedUnlocks","seenUnlocks","hightechOrder"]:result[key]=["s"]
 for key in ["hightechLevels","scientistAssignments","reactorAllocation"]:result[key]={"*":"i"}
 result.techPoints={"*":"n"}
 for key in ["highestLevel","lifetime_max_stage","moduleVersion","hightechVersion","enhancementVersion","scientists","enhancementLevel","enhancementAttacks","enhancementHits","guardDeath","loopLevel","guardStage","guardIndex","reactorLevel"]:result[key]="i"
 result.loop="b"
 result.resourceSamples=[{"time":"n","amount":"g","production_base":"g","id":"s","origin":"s"}]
 result.hightechDrops=[{"uid":"n","x":"n","y":"n","age":"n","id":"s","amount":"n","hightech":"b","jewel":"b","jewelRatio":"n"}]
 return result

static func shape(value: Variant, spec: Variant, depth := 0) -> bool:
 if depth>48:return false
 if spec is String:
  match spec:
   "s":return value is String
   "b":return value is bool
   "n":return (value is int or value is float) and is_finite(float(value))
   "i":return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)) and absf(float(value))<9.22e18
   "g":return GrowthNumber.valid(value)
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

static func blueprint_valid(raw: Dictionary) -> bool:
 if not raw.has("blueprint"):return true
 var plan: Dictionary=raw.blueprint
 if plan.get("layout_version")!=Layout.VERSION or not plan.get("core") is Dictionary or not plan.get("nodes") is Array or not plan.get("edges") is Array:return false
 var nodes: Array=plan.nodes
 if nodes.is_empty() or nodes.size()>10000:return false
 for i in range(-1,nodes.size()):
  var node: Dictionary=plan.core if i<0 else nodes[i]
  for key in ["id","parent_id","depth","node_id","type","world_pos","footprint","rotation_y","connections","requires"]:
   if not node.has(key):return false
  if int(node.id)!=i or node.node_id!=("core" if i<0 else "node_%03d"%i):return false
  if i>=0 and (not node.has("visual_seed") or int(node.parent_id)<-1 or int(node.parent_id)>=i):return false
  for dep in node.requires:
   if dep!="core" and (not dep.begins_with("node_") or not dep.trim_prefix("node_").is_valid_int() or int(dep.trim_prefix("node_"))<0 or int(dep.trim_prefix("node_"))>=i):return false
 for edge in plan.edges:
  if not edge.has("path") or edge.path.size()<2 or not edge.has("from") or not edge.has("to") or not edge.has("width"):return false
 return true

func prepare(path: String, db: ShipDatabase) -> Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"error":"read"}
 if file.get_length()<=0 or file.get_length()>MAX_BYTES:return {"error":"size"}
 var bytes:=file.get_buffer(file.get_length())
 if file.get_error()!=OK:return {"error":"read"}
 file.close()
 var parser:=JSON.new()
 if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return {"error":"format"}
 return prepare_data(parser.data,db)

func prepare_data(raw: Dictionary, db: ShipDatabase) -> Dictionary:
 if not (raw.get("version") is float or raw.get("version") is int) or raw.version!=floorf(float(raw.version)) or int(raw.version) not in [2,3,BattleGame.SAVE_VERSION]:return {"error":"version"}
 if not raw.get("resources") is Dictionary or not raw.resources.has("1") or not raw.resources.has("2") or not raw.has("highestLevel"):return {"error":"format"}
 if not shape(raw,schema()):return {"error":"format"}
 for region in raw.get("galaxies",{}).values():
  if region.get("version",0)>3 or not blueprint_valid(region):return {"error":"format"}
 # Existing authority handles legacy IDs, permanent buffs, unlocks and config separation.
 var candidate:=BattleGame.new(db,false)
 candidate.load_progress_data(clean(raw,schema()))
 candidate.reset_player()
 return {"error":"","data":clean(raw,schema()),"stage":candidate.profile.highestLevel,"ship":candidate.profile.selectedShip}

func export_progress(game: BattleGame, path: String) -> Error:
 var target:=ProjectSettings.globalize_path(path).simplify_path()
 var primary:=game.progress_writer.path.simplify_path()
 if target in [primary,primary+".bak",primary+".tmp",primary+".import-prev",primary+".import-new"]:return ERR_INVALID_PARAMETER
 return write_file(target,JSON.stringify(clean(game.portable_save_data(),schema()),"\t").to_utf8_buffer())

func write_file(path: String, bytes: PackedByteArray) -> Error:
 var writer:=Writer.new();writer.path=path
 return writer.write_progress(bytes)

func rename(from: String,to: String) -> Error:
 return DirAccess.rename_absolute(from,to)

func commit_import(game: BattleGame, raw: Dictionary) -> Dictionary:
 var prepared:=prepare_data(raw,game.db)
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
   var bytes:=FileAccess.get_file_as_bytes(primary+suffix)
   error=write_file(backup+("/original-progress.json" if suffix.is_empty() else "/original-recovery.json"),bytes)
   if error!=OK:return {"error":error}
 var candidate:=BattleGame.new(game.db,false)
 candidate.load_progress_data(prepared.data);candidate.reset_player()
 error=write_file(incoming,JSON.stringify(clean(candidate.portable_save_data(),schema()),"\t").to_utf8_buffer())
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
 var primary: String=transaction.primary
 var error:=DirAccess.remove_absolute(primary)
 if error!=OK:return error
 return rename(primary+".import-prev",primary) if transaction.had_primary else OK

func finish(transaction: Dictionary) -> void:
 if transaction.had_primary:DirAccess.remove_absolute(str(transaction.primary)+".import-prev")
