extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const Manifest=preload("res://qa/upgrade_policy_checkpoint.gd")
func reject(reason:String)->void:
 printerr("CANDIDATE_TRANSITION_REJECTED ",reason);quit(2)
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_CANDIDATE_TRANSITION")))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source_manifest));var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 if Manifest.manifest_digest(old)!=r.source_fingerprint or Manifest.manifest_digest(target)!=r.target_fingerprint or FileAccess.get_sha256(r.source)!=r.source_sha256:reject("Source/manifest changed");return
 for name in target.files:
  if FileAccess.get_sha256("res://"+name)!=target.files[name]:reject("Frozen target changed");return
 var payload:Dictionary
 if r.legacy:
  var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source))
  if snapshot.code_fingerprint!=old.fingerprint:reject("Legacy identity mismatch");return
  payload=CP.legacy_payload(snapshot)
 else:
  var packet:Dictionary=CP.read_one(r.source)
  if not packet.error.is_empty() or packet.header.code_fingerprint!=old.fingerprint or packet.header.continuity_fingerprint!=CP.continuity(old):reject("Packet integrity mismatch");return
  payload=packet.payload.duplicate(true)
 var original:PackedByteArray=var_to_bytes(payload.save)
 if old.files["data/game_data.json"]!=target.files["data/game_data.json"]:reject("Data change");return
 # Leave the actual player save untouched. Reset only controller drafts that belonged to old UI.
 payload.controller.merge({"busy":false,"tour":[],"touring":false,"next_button":payload.x1_seconds,"next_check":payload.x1_seconds,"next_tour":payload.x1_seconds,"scientist_context":"","reactor_context":"","active_space_record":{}},true)
 var policy_changed:bool=old.files.get("qa/hyperspace_player_policy.gd","")!=target.files.get("qa/hyperspace_player_policy.gd","")
 if policy_changed:payload.space_policy={}
 var link:Dictionary={"kind":"explicit_production_candidate_transition","source_library_identity":r.source_library_identity,"source_sha256":r.source_sha256,"source_fingerprint":old.fingerprint,"target_fingerprint":target.fingerprint,"source_commit":old.source_commit,"target_commit":target.source_commit,"source_x1":payload.x1_seconds,"changes":r.changes,"source_save_byte_identical":true,"numeric_data_identical":true,"old_segment_used_new_fix":false,"discontinuities":{"production_changed":true,"formal_reload_regenerates_battle":true,"qa_policy_changed":policy_changed,"controller_drafts_reset":true,"legacy_missing_state":payload.get("legacy_missing_state",[])}}
 payload.lineage.append(link);payload.candidate_transition=link;payload.code_fingerprint=target.fingerprint;payload.data_sha256=target.files["data/game_data.json"]
 if original!=var_to_bytes(payload.save) or FileAccess.file_exists(r.output):reject("Save changed/output exists");return
 if CP.write(r.output,payload,target)!=OK:reject("Atomic output failure");return
 CP.atomic_json(r.output+".transition.json",link)
 print("CANDIDATE_TRANSITION ",JSON.stringify(link));quit(0)
