extends SceneTree
const ManifestCheck=preload("res://qa/upgrade_policy_checkpoint.gd")
const Checkpoint=preload("res://qa/hyperspace_checkpoint.gd")
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_STAGE_PREPARE")))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source_manifest));var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 if ManifestCheck.manifest_digest(old)!=old.fingerprint or ManifestCheck.manifest_digest(target)!=target.fingerprint or old.files.get("qa/scene_driver.gd","")!="8a509c9d77e53c892bb1799dd62e9e7c74cdd87fd19120bd8cd72982d2d45154":
  printerr("Stage manifest/known driver identity rejected");quit(2);return
 for name in target.files:
  if FileAccess.get_sha256("res://"+str(name))!=target.files[name]:printerr("Stage frozen target changed");quit(2);return
 if FileAccess.file_exists(str(r.output)):printerr("Stage output exists; preserve it");quit(2);return
 var source:Dictionary=Checkpoint.read_one(str(r.checkpoint))
 if not source.error.is_empty() or source.header.code_fingerprint!=old.fingerprint or source.header.continuity_fingerprint!=Checkpoint.continuity(old):
  printerr("Stage source identity/checksum rejected");quit(2);return
 for name in old.files:
  if not str(name).begins_with("qa/") or (str(name).trim_prefix("qa/") in Checkpoint.QA_CONTINUITY and name!="qa/scene_driver.gd"):
   if old.files[name]!=target.files.get(name,"") or target.files[name]!=FileAccess.get_sha256("res://"+str(name)):
    printerr("Stage production/data/policy mismatch: ",name);quit(2);return
 var payload:Dictionary=source.payload.duplicate(true)
 if payload.code_fingerprint!=old.fingerprint or payload.data_sha256!=FileAccess.get_sha256("res://data/game_data.json"):
  printerr("Stage payload identity mismatch");quit(2);return
 var link:Dictionary={"kind":"explicit_same_rules_stage_branch","source_commit":old.source_commit,"target_commit":target.source_commit,"source_fingerprint":old.fingerprint,"target_fingerprint":target.fingerprint,"source_x1":payload.x1_seconds,"checkpoint":r.checkpoint,"mode":r.mode,"discontinuities":{"qa_profiler_added":true,"ui_refresh_schedule":r.mode,"legacy_missing_state":[]},"source_save_unchanged":true,"policy_fields_unchanged":true}
 payload.lineage.append(link);payload.code_fingerprint=target.fingerprint
 if Checkpoint.write(str(r.output),payload,target)!=OK:printerr("Stage branch write failed");quit(2);return
 Checkpoint.atomic_json(str(r.output)+".branch.json",link);print("STAGE_BRANCH ",JSON.stringify(link));quit()
