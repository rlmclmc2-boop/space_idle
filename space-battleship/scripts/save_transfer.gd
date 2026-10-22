extends RefCounted
## Desktop portable progress, validated before any live state or file replacement.
const Writer := preload("res://scripts/progress_writer.gd")
const Layout := preload("res://scripts/galaxy_layout.gd")
const ReactorInt := preload("res://scripts/reactor_integer.gd")
const MAX_BYTES := 16 * 1024 * 1024
const BACKUP_ROOT := "user://save-import-backups"
const SUPPORTED_VERSIONS := [2,3,4,BattleGame.SAVE_VERSION]
# Unconditional top-level fields emitted by the current v5 portable/ordinary
# writer. Conditional journey/guard fields and retired fields are not required.
# Older v5 saves predate some of these fields and remain compatible at lower
# recovery priority; their format has no sub-version to distinguish them from
# a truncated current save.
const CURRENT_V5_FIELDS := ["version","resources","highestLevel","cleared","bossSeen","unlocked","loop","selectedShip","loadout","moduleVersion","productionElapsed","aiTechLevels","aiTechProgress","aiTechActive","aiTechInput","aiIncomePeak","aiTechCompletionUnread","equipmentSwitchUntil","hightechSavedAt","resourceSamples","chronoSavedAt","chronoParticles","reactorLevel","reactorAllocation","enhancementVersion","enhancementLevel","enhancementOrder","enhancementBranches","enhancementAttacks","enhancementHits","lifetime_max_stage","seenUnlocks","readUnlocks","jewelFragments","jewelFurnaceElapsed","jewelFurnaceIncomePeak","hyperspace","hyperspaceReceipt","onboarding","jewels","levels","galaxies","grantedUnlocks","saveIntervalMinutes","planets","crew","crewEquipment"]
# v3/v4 writer baseline (4cac4e16 / cc5e4b0e). Version 2 has no matching
# writer in this tree, so it remains compatible without a completeness claim.
const HISTORICAL_CORE := ["version","resources","highestLevel","cleared","bossSeen","unlocked","loop","selectedShip","loadout","moduleVersion","hightechSavedAt","furnaceElapsed","furnaceIncomePeak","grantedUnlocks","jewels","levels"]

static func structure_quality(raw: Dictionary) -> Dictionary:
 var version = raw.get("version")
 var loadout = raw.get("loadout")
 var slots_present: bool = loadout is Dictionary and loadout.has("weapons") and loadout.has("defence")
 if version==BattleGame.SAVE_VERSION and slots_present and CURRENT_V5_FIELDS.all(func(key):return raw.has(key)):
  return {"quality":"complete","quality_rank":3}
 if version in [3,4,5] and slots_present and HISTORICAL_CORE.all(func(key):return raw.has(key)):
  return {"quality":"historical_complete","quality_rank":2}
 return {"quality":"compatible_sparse","quality_rank":1}

static func restore_legacy_reactor_integers(source: String,raw: Dictionary) -> bool:
 # v5 wrote integer allocations as bare JSON numbers; JSON.parse converts them
 # to binary64. Recover the original digits before semantic validation.
 if not raw.get("reactorAllocation") is Dictionary:return true
 var bodies: Array=[]
 var depth:=0;var quoted:=false;var escaped:=false;var start:=0
 for index in source.length():
  var c:=source[index]
  if quoted:
   if escaped:escaped=false
   elif c=="\\":escaped=true
   elif c=='"':
    quoted=false
    if depth==1 and JSON.parse_string(source.substr(start,index-start+1))=="reactorAllocation":
     var at:=index+1
     while at<source.length() and source[at] in [" ","\t","\r","\n"]:at+=1
     if at<source.length() and source[at]==":":
      at+=1
      while at<source.length() and source[at] in [" ","\t","\r","\n"]:at+=1
      if at>=source.length() or source[at]!="{":return false
      var opening:=at;var nesting:=0;var inside:=false;var slash:=false
      while at<source.length():
       var item:=source[at]
       if inside:
        if slash:slash=false
        elif item=="\\":slash=true
        elif item=='"':inside=false
       elif item=='"':inside=true
       elif item=="{":nesting+=1
       elif item=="}":
        nesting-=1
        if nesting==0:break
       at+=1
      if nesting!=0:return false
      bodies.append(source.substr(opening+1,at-opening-1))
  elif c=='"':quoted=true;start=index
  elif c=="{":depth+=1
  elif c=="}":depth-=1
 if bodies.size()!=1:return false # Missing or duplicate top-level keys are unsafe.
 var body: String=bodies[0]
 var seen: Dictionary={}
 var at:=0
 while at<body.length():
  while at<body.length() and body[at] in [" ","\t","\r","\n"]:at+=1
  if at>=body.length():break
  if body[at]!='"':return false
  var key_start:=at;at+=1
  var slash:=false
  while at<body.length():
   if slash:slash=false
   elif body[at]=="\\":slash=true
   elif body[at]=='"':break
   at+=1
  if at>=body.length():return false
  var key=JSON.parse_string(body.substr(key_start,at-key_start+1))
  if not key is String or seen.has(key) or not raw.reactorAllocation.has(key):return false
  seen[key]=true;at+=1
  while at<body.length() and body[at] in [" ","\t","\r","\n"]:at+=1
  if at>=body.length() or body[at] != ":":return false
  at+=1
  while at<body.length() and body[at] in [" ","\t","\r","\n"]:at+=1
  if at>=body.length():return false
  if body[at]=="{":
   var nested:=0;var quoted_value:=false;slash=false
   while at<body.length():
    var c:=body[at]
    if quoted_value:
     if slash:slash=false
     elif c=="\\":slash=true
     elif c=='"':quoted_value=false
    elif c=='"':quoted_value=true
    elif c=="{":nested+=1
    elif c=="}":
     nested-=1
     if nested==0:
      at+=1
      break
    at+=1
   if nested!=0 or not ReactorInt.valid(raw.reactorAllocation[key]):return false
  else:
   var value_start:=at
   while at<body.length() and body[at]!=",":at+=1
   if not (raw.reactorAllocation[key] is int or raw.reactorAllocation[key] is float) or not is_finite(float(raw.reactorAllocation[key])):return false
   var recovered=legacy_reactor_integer_lexeme(body.substr(value_start,at-value_start).strip_edges())
   if recovered==null:return false
   raw.reactorAllocation[key]=recovered
  while at<body.length() and body[at] in [" ","\t","\r","\n"]:at+=1
  if at<body.length():
   if body[at]!=",":return false
   at+=1
 return true

static func legacy_reactor_integer_lexeme(lexeme: String) -> Variant:
 if lexeme.begins_with("-"):
  var absolute=legacy_reactor_integer_lexeme(lexeme.substr(1))
  return 0 if absolute!=null and ReactorInt.compare(absolute,0)==0 else null
 var number:=RegEx.new()
 number.compile('^(0|[1-9][0-9]*)(?:\\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$')
 var match_result=number.search(lexeme)
 if match_result==null:return null
 var whole=match_result.get_string(1)
 var fractional=match_result.get_string(2)
 var exponent_text=match_result.get_string(3)
 var digits=(whole+fractional).lstrip("0")
 if digits.is_empty():return 0
 var exponent:=0
 if not exponent_text.is_empty():
  var sign:=-1 if exponent_text[0]=="-" else 1
  var clean=exponent_text.trim_prefix("+").trim_prefix("-").lstrip("0")
  if clean.length()>4:return null # Such values were never finite legacy JSON numbers.
  exponent=sign*int(clean) if not clean.is_empty() else 0
 var places=exponent-fractional.length()
 if places>=0:return ReactorInt.make(digits+"0".repeat(places))
 if -places>digits.length() or digits.substr(digits.length()+places).lstrip("0")!="":return null
 return ReactorInt.make(digits.substr(0,digits.length()+places))

static func schema() -> Dictionary:
 var building := {"status":"s","build_progress":"g","crew":["s"]}
 var planet := {"degree":"g","unlocked":"b","conquered":"b","auto_explore":"b","crewId":"s","elapsed":"n","buildings":{"*":building}}
 var node := {"id":"i","parent_id":"i","depth":"i","planned_type":"s","node_id":"s","type":"s","world_pos":"p","footprint":"p","rotation_y":"n","connections":["s"],"requires":["s"],"visual_seed":"i"}
 var edge := {"from":"s","to":"s","width":"n","path":["p"]}
 var blueprint := {"layout_version":"i","core_id":"s","units":"s","core":node,"nodes":[node],"edges":[edge]}
 var slot := {"id":"n","node_id":"s","world_pos":"p","unlock_progress":"n","status":"s","type":"s","level":"i","work":"n","construction":"n","upgrade_progress":"n","visual_seed":"i","planned_type":"s","parent_id":"i"}
 var galaxy := {"version":"i","status":"s","explore_work":"n","upgrade_work":"n","slot_seed":"i","build_elapsed":"n","bag":["s"],"rounds":"i","special_due":"b","rng_state":"s","map_rng_state":"s","owned":"s","blueprint":blueprint,"slots":[slot],"pending_online_time":"n","pending_crew_count":"i"}
 var result := {"version":"i","resources":{"*":"wallet"},"selectedShip":"s","loadout":{"*": [{"key":"s","level":"equipment_i"}]},"unlocked":["s"],"levels":{"*":"n"},"planets":{"*":planet},"galaxies":{"*":galaxy},"crew":[{"crewId":"s","level":"i","exp":"n","assignmentType":"s","targetId":"s","upgradeMode":"s","equipmentSlots":["empty"]}],"crewEquipment":{},"jewels":[],"jewelFragments":"currency","saveIntervalMinutes":"interval","onboarding":{"version":"i","intro":"b","equipped":"b","upgraded":"b","completed":"b","dismissed":"b","retreatSeen":"b","pickupSeen":"b"},"journey":{"stage":"n","groupIndex":"n","state":"n","distance":"n","guardArrived":"b","retreatBossPending":"b","pendingUnlocks":["s"]},"enhancementOrder":{"*": ["s"]},"enhancementBranches":{"*":{"*":{"*":"s"}}}}
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
 result.equipmentSwitchUntil={"*":"n"}
 result.techPoints={"*":"n"}
 for key in ["highestLevel","lifetime_max_stage","moduleVersion","hightechVersion","enhancementVersion","scientists","enhancementLevel","enhancementAttacks","enhancementHits","guardDeath","loopLevel","guardStage","guardIndex","reactorLevel"]:result[key]="i"
 result.loop="b"
 result.resourceSamples=[{"time":"n","amount":"g","production_base":"g","id":"s","origin":"s","production_time":"n"}]
 result.hightechDrops=[{"uid":"n","x":"n","y":"n","age":"n","id":"s","amount":"n","hightech":"b","jewel":"b","jewelRatio":"n"}]
 result.hyperspace=preload("res://scripts/hyperspace_state.gd").schema()
 result.hyperspace.materials={"*":"material_i"}
 result.hyperspaceReceipt={"round":"i","run":"i","drone_id":"s","unread":"b"}
 return result

static func shape(value: Variant, spec: Variant, depth := 0) -> bool:
 if depth>48:return false
 if spec is String:
  match spec:
   "filter_value":return value is String or ((value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)))
   "s":return value is String
   "b":return value is bool
   "n":return (value is int or value is float) and is_finite(float(value))
   "i":return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)) and absf(float(value))<9.22e18
   "g":return GrowthNumber.valid(value)
   "wallet":return preload("res://scripts/currency_storage.gd").valid_resource(value)
   "material_i":return preload("res://scripts/currency_storage.gd").valid_int64(value)
   "equipment_i":return preload("res://scripts/currency_storage.gd").valid_int64(value,1)
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

static func blueprint_valid(raw: Dictionary, builds: Dictionary) -> bool:
 if not raw.has("blueprint"):return true
 var plan: Dictionary=raw.blueprint
 if plan.get("layout_version")!=Layout.VERSION or plan.get("core_id")!="core" or not plan.get("core") is Dictionary or not plan.get("nodes") is Array or not plan.get("edges") is Array:return false
 var nodes: Array=plan.nodes
 if nodes.is_empty() or nodes.size()>10000 or plan.edges.size()!=nodes.size():return false
 var identities := {}
 var connections := {}
 for i in range(-1,nodes.size()):
  var node: Dictionary=plan.core if i<0 else nodes[i]
  for key in ["id","parent_id","depth","node_id","type","world_pos","footprint","rotation_y","connections","requires"]:
   if not node.has(key):return false
  if int(node.id)!=i or node.node_id!=("core" if i<0 else "node_%03d"%i):return false
  if node.footprint[0]<=0 or node.footprint[1]<=0:return false
  if i<0:
   if node.type!="core" or node.get("planned_type","core")!="core" or node.parent_id!=-1 or node.depth!=0 or not node.requires.is_empty():return false
  else:
   if not node.has("visual_seed") or int(node.parent_id)<-1 or int(node.parent_id)>=i:return false
   for type in [node.type,node.get("planned_type",node.type)]:
    if not str(type).is_empty() and not builds.has(type):return false
   if not str(node.type).is_empty() and not str(node.get("planned_type","")).is_empty() and node.type!=node.planned_type:return false
   var parent: Dictionary=plan.core if int(node.parent_id)<0 else nodes[int(node.parent_id)]
   if node.depth!=parent.depth+1 or node.requires!=[parent.node_id]:return false
  identities[node.node_id]=node
  connections[node.node_id]=[]
 var destinations := {}
 for edge in plan.edges:
  if not edge.has("path") or edge.path.size()<2 or not edge.has("from") or not edge.has("to") or not edge.has("width") or edge.width<=0:return false
  if not identities.has(edge.from) or not identities.has(edge.to) or edge.to=="core" or destinations.has(edge.to):return false
  if identities[edge.to].requires!=[edge.from]:return false
  destinations[edge.to]=true
  connections[edge.from].append(edge.to);connections[edge.to].append(edge.from)
 for id in identities:
  var expected: Array=connections[id]
  var actual: Array=identities[id].connections
  if actual.size()!=expected.size() or not expected.all(func(ref):return actual.has(ref)):return false
 for i in raw.get("slots",[]).size():
  var slot: Dictionary=raw.slots[i]
  if i>=nodes.size() or slot.get("id",i)!=i or slot.get("node_id",nodes[i].node_id)!=nodes[i].node_id:return false
  for type in [slot.get("type",""),slot.get("planned_type","")]:
   if not str(type).is_empty() and not builds.has(type):return false
  if not str(nodes[i].type).is_empty() and not str(slot.get("type","")).is_empty() and nodes[i].type!=slot.type:return false
 return true

func prepare(path: String, db: ShipDatabase) -> Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"error":"read"}
 if file.get_length()<=0 or file.get_length()>MAX_BYTES:return {"error":"size"}
 var bytes:=file.get_buffer(file.get_length())
 if file.get_error()!=OK:return {"error":"read"}
 file.close()
 var source:=bytes.get_string_from_utf8()
 var decoded=preload("res://scripts/currency_storage.gd").parse_source(source)
 if decoded.status!="ok":return {"error":"format"}
 if not restore_legacy_reactor_integers(source,decoded.data):return {"error":"format"}
 return prepare_data(decoded.data,db)

func prepare_data(raw: Dictionary, db: ShipDatabase) -> Dictionary:
 if not (raw.get("version") is float or raw.get("version") is int) or raw.version!=floorf(float(raw.version)) or int(raw.version) not in SUPPORTED_VERSIONS:return {"error":"version"}
 if not raw.get("resources") is Dictionary or not raw.resources.has("1") or not raw.resources.has("2") or not raw.has("highestLevel"):return {"error":"format"}
 if not shape(raw,schema()):return {"error":"format"}
 if raw.get("reactorAllocation") is Dictionary:
  var allowed:=String(db.config.reactorModules).split(",")
  for key in raw.reactorAllocation:
   if key not in allowed:return {"error":"format"}
 if raw.has("hyperspace") and not preload("res://scripts/hyperspace_state.gd").valid(raw.hyperspace,preload("res://scripts/hyperspace_config.gd").load_config(),db.levels.size()):return {"error":"format"}
 if raw.has("hyperspace") and not preload("res://scripts/hyperspace_permissions.gd").bindings_valid(raw,db.data,preload("res://scripts/hyperspace_config.gd").load_config()):return {"error":"format"}
 for key in raw.get("galaxies",{}):
  var region: Dictionary=raw.galaxies[key]
  if region.get("version",0)>3:return {"error":"format"}
  # Older galaxy saves regenerate their layout; preserve that migration path.
  if region.get("version",0)<3:continue
  var builds := {}
  for build in db.data.get("galaxy_build",{}).values():
   if build.galaxy_key==key:builds[build.key]=build
  if not blueprint_valid(region,builds):return {"error":"format"}
 # Existing authority handles legacy IDs, permanent buffs, unlocks and config separation.
 var candidate:=BattleGame.new(db,false)
 candidate.load_progress_data(clean(raw,schema()))
 candidate.reset_player()
 var quality:=structure_quality(raw)
 return {"error":"","data":clean(raw,schema()),"stage":candidate.profile.highestLevel,"ship":candidate.profile.selectedShip,"quality":quality.quality,"quality_rank":quality.quality_rank}

func prepare_disk_data(raw: Dictionary, db: ShipDatabase) -> Dictionary:
 # Only existing durable files receive the loader's historical defaults.
 # Portable import keeps prepare_data's strict validation unchanged.
 var quality:=structure_quality(raw)
 var migrated:=raw.duplicate(true)
 if not migrated.has("highestLevel"):migrated.highestLevel=1
 if quality.quality_rank<3 and migrated.get("resources") is Dictionary:
  for id in ["1","2"]:
   var amount = migrated.resources.get(id)
   if (amount is int or amount is float) and is_finite(float(amount)) and float(amount)<0:
    migrated.resources[id]=ceilf(float(db.defaults.startingIron if id=="1" else db.defaults.startingTitanium))
 var checked:=prepare_data(migrated,db)
 if checked.error.is_empty():
  checked.quality=quality.quality
  checked.quality_rank=quality.quality_rank
 return checked

func export_progress(game: BattleGame, path: String) -> Error:
 if game.galaxy.has_pending_income():return ERR_BUSY
 var target:=ProjectSettings.globalize_path(path).simplify_path()
 if Writer.is_protected_target(target,game.progress_writer.path):return ERR_INVALID_PARAMETER
 return write_file(target,JSON.stringify(clean(game.portable_save_data(),schema()),"\t").to_utf8_buffer())

func write_file(path: String, bytes: PackedByteArray) -> Error:
 var writer:=Writer.new();writer.path=path
 return writer.write_progress(bytes)

func rename(from: String,to: String) -> Error:
 return DirAccess.rename_absolute(from,to)

func commit_import(game: BattleGame, raw: Dictionary) -> Dictionary:
 if game.galaxy.has_pending_income():return {"error":ERR_BUSY}
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
 var active:Dictionary=installed.get("hyperspace",{}).get("active",{})
 # Current suspended receipts must survive staging: canonicalizing a refunded
 # temporary game would drop its not-yet-applied runtime return snapshot.
 if active.get("return_state",{}).is_empty():
  var candidate:=BattleGame.new(source_db,false)
  candidate.load_progress_data(prepared.data);candidate.reset_player();installed=candidate.portable_save_data()
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
