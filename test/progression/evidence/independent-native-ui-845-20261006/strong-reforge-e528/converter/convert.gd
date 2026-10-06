extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
func fail(message):
 printerr(message);quit(2)
func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=4:fail("source whitelist target_manifest output required");return
 var w=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
 var m=JSON.parse_string(FileAccess.get_file_as_string(args[2]))
 if FileAccess.get_sha256(args[0])!=w.source_sha256 or m.fingerprint!=w.target_fingerprint or m.source_commit!=w.target_commit:fail("closed identity rejected");return
 var raw=CP.read_one(args[0])
 if not raw.error.is_empty() or raw.header.code_fingerprint!=w.source_fingerprint or raw.header.source_commit!=w.source_commit:fail("source header rejected");return
 var old:Dictionary=raw.payload
 var c=preload("res://scripts/hyperspace_config.gd").load_config()
 if not preload("res://scripts/drone_inventory.gd").valid(old.save.hyperspace.inventory,c) or not preload("res://scripts/hyperspace_state.gd").valid(old.save.hyperspace,c,220):fail("current production legality rejected");return
 var p:Dictionary=old.duplicate(true)
 p.code_fingerprint=m.fingerprint
 p.data_sha256=m.files["data/game_data.json"]
 # These fields did not exist in cf29. No previous policy field is discarded.
 if p.space_policy.has("idle_salvage_enabled") or p.space_policy.has("idle_salvage_budget"):fail("unexpected existing new policy fields");return
 p.space_policy.idle_salvage_enabled=true
 p.space_policy.idle_salvage_budget={"round":-1,"used":0,"tour_started":-1.0}
 var transition={"source_commit":w.source_commit,"target_commit":w.target_commit,"source_sha256":w.source_sha256,"source_fingerprint":w.source_fingerprint,"target_fingerprint":w.target_fingerprint,"kind":"closed_whitelist_preserve_all_old_policy_controller_rng","new_policy_defaults":{"idle_salvage_enabled":true,"idle_salvage_budget":{"round":-1,"used":0,"tour_started":-1.0}},"scope":"formal_journey_reload_not_live_combat_restore"}
 p.candidate_transition=transition
 p.lineage.append(transition)
 var proof={}
 for key in old:
  var unchanged=CP.digest(var_to_bytes(old[key]))==CP.digest(var_to_bytes(p[key]))
  proof[key]={"old_digest":CP.digest(var_to_bytes(old[key])),"new_digest":CP.digest(var_to_bytes(p[key])),"unchanged":unchanged}
  if not unchanged and not key in ["code_fingerprint","data_sha256","space_policy","lineage"]:fail("undeclared root mutation "+str(key));return
 for key in old.space_policy:
  if var_to_bytes(old.space_policy[key])!=var_to_bytes(p.space_policy[key]):fail("old policy mutation "+str(key));return
 for i in range(old.lineage.size()):
  if var_to_bytes(old.lineage[i])!=var_to_bytes(p.lineage[i]):fail("old lineage mutation");return
 if CP.write_once(args[3],p,m)!=OK:fail("write failed/existing output");return
 var audit={"source":w.source_sha256,"output_sha256":FileAccess.get_sha256(args[3]),"x1_seconds":p.x1_seconds,"root_proof":proof,"all_old_policy_fields_preserved":true,"all_old_lineage_entries_preserved":true,"inventory_valid":true,"hyperspace_valid":true,"transition":transition,"source_options":old.options,"runtime_restore_caveat":"Production formal restore regenerates battle, clears scientist_context/reactor_context, resets active_space_record and rebases current segment; conversion preserves all of these old fields exactly."}
 CP.atomic_json(args[3]+".audit.json",audit)
 print("CONVERT_OK ",JSON.stringify(audit));quit()
