extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const SOURCE_FP="3a78ea1595662c820cfe7265932129dbade62566153f72158eabea1593305ae1"
const SOURCE_BODY_SHA="100c4dc5a6ddb318144cf55a7f4dd2263d565d4bc7313a5a419062d12f08a138"
const TARGET_FP="13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d"
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_TRANSITION_SOURCE32")))
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.audit))
 assert(audit.source_full_sha256==FileAccess.get_sha256(r.source) and audit.source_body_sha256==SOURCE_BODY_SHA)
 assert(audit.current_inventory_valid and audit.all_stored_legendary_parameters_currently_generatable)
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source_manifest));var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var whitelist:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.whitelist));var changed:Array=[]
 assert(source.fingerprint==SOURCE_FP and target.fingerprint==TARGET_FP)
 for name in target.files:
  assert(FileAccess.get_sha256("res://"+name)==target.files[name],name)
  if source.files.get(name)!=target.files[name]:
   assert(whitelist.has(name) and whitelist[name].before==source.files.get(name) and whitelist[name].after==target.files[name],name);changed.append(name)
 for name in source.files:assert(target.files.has(name),name)
 assert(changed.size()==whitelist.size() and changed.size()==19 and source.files.size()==887 and target.files.size()==888)
 var read:Dictionary=CP.read_one(r.source);assert(read.error.is_empty() and read.header.code_fingerprint==SOURCE_FP and read.header.sha256==SOURCE_BODY_SHA)
 var old:Dictionary=read.payload;assert(absf(float(old.x1_seconds)-116796.449994348)<0.000001)
 assert(int(old.save.hyperspace.round_id)==1 and int(old.save.hyperspace.inventory.reforge_count)==0)
 assert(not old.space_policy.has("idle_salvage_enabled") and not old.space_policy.has("idle_salvage_budget"))
 var p:Dictionary=old.duplicate(true)
 var added_controller:Dictionary={}
 if not p.controller.has("reforge_checkpoint_pending"):
  p.controller.reforge_checkpoint_pending={};added_controller.reforge_checkpoint_pending={}
 var added_policy:Dictionary={"idle_salvage_enabled":true,"idle_salvage_budget":{"round":-1,"used":0,"tour_started":-1.0}}
 for key in added_policy:p.space_policy[key]=added_policy[key].duplicate(true) if added_policy[key] is Dictionary else added_policy[key]
 var link:Dictionary={"kind":"authorized_natural049_source32_to_unified_e528_preflight","source_sha256":FileAccess.get_sha256(r.source),"source_body_sha256":SOURCE_BODY_SHA,"source_fingerprint":SOURCE_FP,"target_fingerprint":TARGET_FP,"source_x1":p.x1_seconds,"exact_whitelist":whitelist,"added_controller_defaults":added_controller,"added_policy_defaults":added_policy,"inventory_current_generation_validated":true,"scope":"New policy/modernization/source version at unchanged earned32 state; no new-full-run claim. Levels1-34 unchanged, future35/36 and future master generation ranges differ. No affix/resource/loadout edits.","reload_boundary":"Production formal journey regeneration, GUI contexts reset and offline compensation suppressed by existing checkpoint.restore. Not lossless battle restoration; original flags and receipt dictionaries preserved."}
 p.code_fingerprint=TARGET_FP
 p.data_sha256=target.files["data/game_data.json"]
 p.lineage.append(link);p.candidate_transition=link
 var digests:Dictionary={};var nested:Dictionary={}
 for key in old:
  digests[key]=CP.digest(var_to_bytes(old[key]))
  if key not in ["code_fingerprint","data_sha256","lineage","candidate_transition","space_policy","controller"]:assert(CP.digest(var_to_bytes(p[key]))==digests[key],key)
 for container in ["controller","space_policy"]:
  nested[container]={}
  for key in old[container]:
   nested[container][key]=CP.digest(var_to_bytes(old[container][key]));assert(CP.digest(var_to_bytes(p[container][key]))==nested[container][key],container+"/"+key)
 assert(p.controller.size()==old.controller.size()+added_controller.size() and p.space_policy.size()==old.space_policy.size()+2)
 assert(not FileAccess.file_exists(r.output));assert(CP.write(r.output,p,target)==OK)
 var written:Dictionary=CP.read_one(r.output);assert(written.error.is_empty())
 for key in old:
  if key not in ["code_fingerprint","data_sha256","lineage","candidate_transition","space_policy","controller"]:assert(CP.digest(var_to_bytes(written.payload[key]))==digests[key],key)
 for container in nested:
  for key in nested[container]:assert(CP.digest(var_to_bytes(written.payload[container][key]))==nested[container][key],container+"/"+key)
 var result=link.duplicate(true);result.source_field_digests=digests;result.source_member_digests=nested;result.written_sha256=FileAccess.get_sha256(r.output);CP.atomic_json(r.output+".transition.json",result)
 print("SOURCE32_TRANSITION_OK ",result.written_sha256);quit()
