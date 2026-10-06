extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
func _initialize()->void:
 var source:String="/workspace/sol-validation/gate34-source-audit/source32-e528.bin"
 assert(FileAccess.get_sha256(source)=="ec3c211d1f5f6abcf1de85cf37df5f385ef153061219d71d65e68994ac05ff32")
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/workspace/sol-validation/unified-e528-post60-qa/qa-manifest.json"))
 var current:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var allowed:Array=["qa/hyperspace_longrun.gd","qa/hyperspace_player_policy.gd","qa/hyperspace_checkpoint.gd","qa/test_sparse_tour_reactions.gd"]
 var diff:Dictionary={}
 for name in current.files:
  assert(FileAccess.get_sha256("res://"+name)==current.files[name])
  if old.files.get(name)!=current.files[name]:
   assert(name in allowed);diff[name]={"before":old.files.get(name),"after":current.files[name]}
 for name in old.files:assert(current.files.has(name))
 assert(diff.size()==4)
 var loaded:Dictionary=CP.read_one(source);assert(loaded.error.is_empty())
 var p:Dictionary=loaded.payload.duplicate(true);assert(p.code_fingerprint==old.fingerprint)
 assert(int(p.space_policy.idle_salvage_budget.used)==0 and int(p.space_policy.idle_salvage_budget.round)==-1)
 var old_fields:Dictionary={}
 for name in p.controller:old_fields["controller:"+name]=CP.digest(var_to_bytes(p.controller[name]))
 for name in p.space_policy:old_fields["policy:"+name]=CP.digest(var_to_bytes(p.space_policy[name]))
 var save_sha:String=CP.digest(var_to_bytes(p.save));var rng:String=p.rng_state
 p.controller.tour_failed_encounters={};p.controller.tour_current_encounter="";p.controller.tour_seen_unlocks={}
 p.space_policy.idle_salvage_success_times=[]
 p.code_fingerprint=current.fingerprint
 p.qa_policy_upgrade={"scope":"Authorized same-earned-source short cadence comparison; QA scheduling and budget only; formal battle regeneration on both arms","source_sha256":FileAccess.get_sha256(source),"source_fp":old.fingerprint,"target_fp":current.fingerprint,"exact_whitelist":diff,"added_controller_defaults":{"tour_failed_encounters":{},"tour_current_encounter":"","tour_seen_unlocks":{}},"added_policy_defaults":{"idle_salvage_success_times":[]}}
 var output:String="/workspace/sol-validation/sparse-repeat-failure-work/source32-sparse.bin"
 assert(not FileAccess.file_exists(output));assert(CP.write_once(output,p,current)==OK)
 var back:Dictionary=CP.read_one(output).payload
 assert(CP.digest(var_to_bytes(back.save))==save_sha and back.rng_state==rng)
 for key in old_fields:
  var member:String=str(key).split(":",true,1)[1]
  var actual:Variant=back.controller[member] if str(key).begins_with("controller:") else back.space_policy[member]
  assert(CP.digest(var_to_bytes(actual))==old_fields[key])
 var audit:Dictionary={"source_sha256":FileAccess.get_sha256(source),"output_sha256":FileAccess.get_sha256(output),"x1_seconds":back.x1_seconds,"source_fp":old.fingerprint,"target_fp":current.fingerprint,"source_save_sha256":save_sha,"rng_preserved":true,"all_old_controller_and_policy_members_preserved":true,"qa_whitelist":diff,"transition":back.qa_policy_upgrade}
 FileAccess.open(output+".audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"  "))
 print("QA_ONLY_TRANSITION_OK ",audit.output_sha256);quit()
