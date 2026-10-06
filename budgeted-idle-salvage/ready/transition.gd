extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_IDLE_SALVAGE_REQUEST")))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.source_manifest))
 var target:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 assert(FileAccess.get_sha256(r.source)=="cf5042c688e2418290afdfa8e6f646e94f041acc8cb5c86291b6af8531bb9084")
 var changed:Array=[]
 for name in target.files:
  assert(old.files.has(name) and FileAccess.get_sha256("res://"+name)==target.files[name])
  if old.files[name]!=target.files[name]:changed.append(name)
 assert(changed==["qa/hyperspace_checkpoint.gd","qa/hyperspace_player_policy.gd"] and target.files.size()==887)
 assert(target.files["data/game_data.json"]==old.files["data/game_data.json"])
 var packet:Dictionary=CP.read_one(r.source)
 assert(packet.error.is_empty() and packet.header.code_fingerprint==old.fingerprint)
 var original:Dictionary=packet.payload
 assert(absf(float(original.x1_seconds)-42767.8833349779)<0.000001)
 assert(int(original.save.journey.stage)==20 and int(original.save.journey.groupIndex)==9 and int(original.save.journey.state)==4)
 assert(not bool(original.get("manual_interrupted_on_reload",false)))
 assert(original.save.hyperspace.active.is_empty() or original.save.hyperspace.active.get("mode","")!="manual")
 var p:Dictionary=original.duplicate(true)
 var link={"kind":"authorized_budgeted_idle_salvage_same_actual2d_clear20_formal_reload","source_sha256":FileAccess.get_sha256(r.source),"source_fingerprint":old.fingerprint,"target_fingerprint":target.fingerprint,"changed_files":changed,"source_x1":p.x1_seconds,"reload_boundary":"Same source as original2d20-to30. Production regeneration, not live battle restoration; offline compensation suppressed."}
 p.code_fingerprint=target.fingerprint
 p.lineage.append(link);p.candidate_transition=link
 var digests:Dictionary={}
 for key in original:
  digests[key]=CP.digest(var_to_bytes(original[key]))
  if key not in ["code_fingerprint","lineage","candidate_transition"]:assert(CP.digest(var_to_bytes(p[key]))==digests[key])
 assert(not FileAccess.file_exists(r.output))
 assert(CP.write(r.output,p,target)==OK)
 var written:Dictionary=CP.read_one(r.output);assert(written.error.is_empty())
 for key in original:
  if key not in ["code_fingerprint","lineage","candidate_transition"]:assert(CP.digest(var_to_bytes(written.payload[key]))==digests[key])
 link["source_field_digests"]=digests
 link["written_sha256"]=FileAccess.get_sha256(r.output)
 link["source_journey"]=original.save.journey
 link["source_options"]=original.options
 CP.atomic_json(r.output+".transition.json",link)
 print("IDLE_SALVAGE_TRANSITION_OK ",link.written_sha256);quit()
