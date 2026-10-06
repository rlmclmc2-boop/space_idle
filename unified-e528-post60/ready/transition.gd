extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const SOURCE_SHA="f51b1178c17173a103184d7d39e7d0f24040ad82e8f79d6bd4128bb7a22f11ef"
const SOURCE_FP="4e07f51458d778fa152222ab0d39042cc07f4d7f83d2e1c563479de5e4123983"
const TARGET_FP="13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d"
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_UNIFIED_POST60_TRANSITION")))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source_manifest))
 var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var whitelist:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.whitelist))
 assert(old.fingerprint==SOURCE_FP and target.fingerprint==TARGET_FP)
 assert(FileAccess.get_sha256(r.source)==SOURCE_SHA)
 var changed:Array=[]
 for name in target.files:
  assert(FileAccess.get_sha256("res://"+name)==target.files[name],name)
  if old.files.get(name)!=target.files[name]:
   assert(whitelist.has(name) and whitelist[name].before==old.files.get(name) and whitelist[name].after==target.files[name],name)
   changed.append(name)
 for name in old.files:assert(target.files.has(name),name)
 assert(changed.size()==whitelist.size() and changed.size()==12 and target.files.size()==888)
 assert(target.files["data/game_data.json"]==old.files["data/game_data.json"])
 assert(target.files["data/hyperspace_config.json"]==old.files["data/hyperspace_config.json"])
 var packet:Dictionary=CP.read_one(r.source)
 assert(packet.error.is_empty() and packet.header.code_fingerprint==SOURCE_FP)
 var original:Dictionary=packet.payload
 assert(absf(float(original.x1_seconds)-181472.19997929)<0.000001)
 assert(original.controller.clears.has("60"))
 assert(not original.space_policy.has("idle_salvage_enabled") and not original.space_policy.has("idle_salvage_budget"))
 var p:Dictionary=original.duplicate(true)
 var link:Dictionary={"kind":"authorized_parent_actual845_clear60_to_unified_e528","source_sha256":SOURCE_SHA,"source_fingerprint":SOURCE_FP,"target_fingerprint":TARGET_FP,"changed_files":changed,"whitelist":whitelist,"source_x1":p.x1_seconds,"production_scope":"845 income/enemies unchanged; modernization baseline coefficient+1 and agreed UI/refund edits","policy_scope":"v16 to v18, at most three earned idle-white transactions per actual sparse tour; protected fleet/backup and independent safe full-storage recovery","new_policy_fields":{"idle_salvage_enabled":true,"idle_salvage_budget":{"round":-1,"used":0,"tour_started":-1.0}},"reload_boundary":"Formal production reload regenerates battle/GUI and suppresses offline compensation; not live battle restoration. Original saved active receipts/manual flags preserved; production reload rules still apply."}
 p.code_fingerprint=TARGET_FP
 p.space_policy.idle_salvage_enabled=true
 p.space_policy.idle_salvage_budget={"round":-1,"used":0,"tour_started":-1.0}
 p.lineage.append(link);p.candidate_transition=link
 var field_digests:Dictionary={};var policy_digests:Dictionary={}
 for key in original:
  field_digests[key]=CP.digest(var_to_bytes(original[key]))
  if key not in ["code_fingerprint","lineage","candidate_transition","space_policy"]:assert(CP.digest(var_to_bytes(p[key]))==field_digests[key],key)
 for key in original.space_policy:
  policy_digests[key]=CP.digest(var_to_bytes(original.space_policy[key]))
  assert(CP.digest(var_to_bytes(p.space_policy[key]))==policy_digests[key],key)
 assert(p.space_policy.size()==original.space_policy.size()+2)
 assert(not FileAccess.file_exists(r.output))
 assert(CP.write(r.output,p,target)==OK)
 var written:Dictionary=CP.read_one(r.output);assert(written.error.is_empty())
 for key in original:
  if key not in ["code_fingerprint","lineage","candidate_transition","space_policy"]:assert(CP.digest(var_to_bytes(written.payload[key]))==field_digests[key],key)
 for key in original.space_policy:assert(CP.digest(var_to_bytes(written.payload.space_policy[key]))==policy_digests[key],key)
 var audit=link.duplicate(true);audit.source_field_digests=field_digests;audit.source_policy_field_digests=policy_digests;audit.written_sha256=FileAccess.get_sha256(r.output)
 audit.original_equipped_ids=original.save.hyperspace.inventory.equipped.duplicate();audit.original_inventory=original.save.hyperspace.inventory.duplicate(true);audit.source_journey=original.save.journey.duplicate(true);audit.source_options=original.options.duplicate(true)
 CP.atomic_json(r.output+".transition.json",audit)
 print("UNIFIED_POST60_TRANSITION_OK ",audit.written_sha256);quit()
