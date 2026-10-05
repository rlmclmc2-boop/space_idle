extends SceneTree
const Checkpoint=preload("res://qa/hyperspace_checkpoint.gd")
const Policy=preload("res://qa/hyperspace_player_policy.gd")
static func manifest_digest(manifest:Dictionary)->String:
 var keys:Array=manifest.files.keys();keys.sort();var rows:PackedStringArray=[]
 for key in keys:
  # Frozen package paths/hashes are ASCII; match build_qa.py's canonical Python JSON.
  for ch in str(key):
   if ch.unicode_at(0)>127:return ""
  rows.append(JSON.stringify(str(key))+": "+JSON.stringify(str(manifest.files[key])))
 return Checkpoint.digest(("{"+", ".join(rows)+"}").to_utf8_buffer())
static func approved_manifests(old:Dictionary,target:Dictionary)->bool:
 if manifest_digest(old)!=old.get("fingerprint","") or manifest_digest(target)!=target.get("fingerprint",""):return false
 var known:Dictionary={"qa/hyperspace_player_policy.gd":"4ca02554319aa5c16a18bd417287da0a20fa84c46139745a16252935c5f67edf","qa/hyperspace_longrun.gd":"ccc4abf619dcd7c045bbdabe73d30c276777c391ac2466473825d0ed388db394","qa/hyperspace_checkpoint.gd":"20404138c8618c6e5ee6d76f2c335f2eb88a3b12305c77a2bb6bb2d896735ed2"}
 var added:Array=["qa/upgrade_policy_checkpoint.gd","qa/test_manual_policy.gd"]
 for name in known:
  if old.files.get(name,"")!=known[name]:return false
 for name in added:
  if old.files.has(name):return false
 for name in old.files:
  if not known.has(name) and old.files[name]!=target.files.get(name,""):return false
 for name in target.files:
  if not old.files.has(name) and not added.has(name):return false
  if FileAccess.get_sha256("res://"+str(name))!=target.files[name]:return false
 return old.files.get("data/game_data.json","")=="95ed3347bc031c9f55468ad3536f71dc58dbb83874ef40882d3d9bcc8a14556e"
func _initialize()->void:
 var request:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_POLICY_UPGRADE_REQUEST")))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(request.source_manifest))
 var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 if not approved_manifests(old,target):
  printerr("Unapproved package/production/data change");quit(2);return
 var source:Dictionary=Checkpoint.read_one(str(request.source_checkpoint))
 if not source.error.is_empty() or source.header.code_fingerprint!=old.fingerprint or source.header.get("continuity_fingerprint","")!=Checkpoint.continuity(old):
  printerr("Source integrity/version rejected");quit(2);return
 var payload:Dictionary=source.payload.duplicate(true)
 if payload.get("code_fingerprint","")!=old.fingerprint or payload.get("data_sha256","")!=FileAccess.get_sha256("res://data/game_data.json"):
  printerr("Payload identity/data rejected");quit(2);return
 var production_bytes:PackedByteArray=var_to_bytes(payload.save)
 var dropped:Array=["controller.busy","controller.tour","controller.touring","controller.next_button","controller.scientist_context","controller.reactor_context","controller.active_space_record","space_policy.manual_failures (v7 unused)","space_policy.manual_pending","space_policy.manual_watch","space_policy.last_manual_boundary","space_policy.pending_encounters","space_policy.seen_encounter","space_policy.encounter_started","space_policy.wanted_weapons","space_policy.wanted_defences"]
 payload.controller.merge({"busy":false,"tour":[],"touring":false,"next_button":payload.x1_seconds,"next_check":payload.x1_seconds,"next_tour":payload.x1_seconds,"scientist_context":"","reactor_context":"","active_space_record":{}},true)
 var failures:Dictionary={};var round_start:=0.0
 for reforge in payload.controller.get("refeeds",[]):round_start=maxf(round_start,float(reforge.x1_seconds))
 for result in payload.controller.get("space_runs",[]):
  if float(result.start)<round_start:continue
  var key:String=str([int(payload.save.hyperspace.round_id),result.route,int(result.level)])
  if result.success:failures.erase(key)
  else:failures[key]={"growth":Policy.manual_growth(payload.save),"failed_at":payload.x1_seconds,"reason":"Known v7 failure; conservative current-profile baseline because original failure-time growth was not recorded"}
 var active:Dictionary=payload.save.hyperspace.active
 if not active.is_empty() and str(active.get("mode",""))=="manual" and str(active.get("status",""))=="started":
  var key:String=str([int(payload.save.hyperspace.round_id),active.route,int(active.level)])
  failures[key]={"growth":Policy.manual_growth(payload.save),"failed_at":payload.x1_seconds,"reason":"Interrupted manual receipt will be handled by the unchanged production loader"}
 payload.space_policy.merge({"manual_failures":failures,"manual_pending":{},"manual_watch":{},"last_manual_boundary":"","pending_encounters":{},"seen_encounter":"","encounter_started":0.0,"wanted_weapons":[],"wanted_defences":[]},true)
 payload.code_fingerprint=target.fingerprint
 var upgrade:Dictionary={"kind":"explicit_qa_policy_upgrade","from_policy":"hyperspace-player-v7-initial-visible-majority-stable-plan","to_policy":Policy.VERSION,"source_commit":old.source_commit,"target_commit":target.source_commit,"source_fingerprint":old.fingerprint,"target_fingerprint":target.fingerprint,"source_checkpoint":request.source_checkpoint,"source_x1":payload.x1_seconds,"changed_files":request.changed_files,"discarded_fields":dropped,"rescheduled_fields":["controller.next_check","controller.next_tour"],"seeded_failure_keys":failures.keys(),"production_and_data_identical":true,"formal_reload_regenerates_battle":true,"fallback_failures":request.fallback_failures}
 upgrade.discontinuities={"qa_policy_changed":true,"discarded_fields":dropped,"legacy_missing_state":[]}
 payload.qa_policy_upgrade=upgrade;payload.lineage.append(upgrade)
 if production_bytes!=var_to_bytes(payload.save):
  printerr("Production save changed during conversion");quit(2);return
 if FileAccess.file_exists(str(request.output)) or Checkpoint.write(str(request.output),payload,target)!=OK:
  printerr("Output write rejected");quit(2);return
 Checkpoint.atomic_json(str(request.output)+".upgrade.json",upgrade)
 print("POLICY_UPGRADE ",JSON.stringify(upgrade));quit(0)
