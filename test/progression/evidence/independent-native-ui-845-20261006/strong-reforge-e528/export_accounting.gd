extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
func _initialize():
 var args=OS.get_cmdline_user_args()
 var raw=CP.read_one(args[0])
 if not raw.error.is_empty():printerr(raw.error);quit(2);return
 var p=raw.payload
 CP.atomic_json(args[1],{"header":raw.header,"source_cp_sha256":FileAccess.get_sha256(args[0]),"x1_seconds":p.x1_seconds,"wall_seconds":p.wall_seconds,"trace_bytes":p.trace_bytes,"controller":p.controller,"safe_farm":p.safe_farm,"space_policy":p.space_policy,"rng_state":p.rng_state,"save":p.save,"options":p.options})
 if args.size()>2:
  var f=FileAccess.open(args[2],FileAccess.READ);CP.atomic_bytes(args[1]+".actions.jsonl",f.get_buffer(int(p.trace_bytes)))
 print("ACCOUNTING_EXPORT ",p.x1_seconds);quit()
