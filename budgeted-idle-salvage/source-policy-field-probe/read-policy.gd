extends SceneTree
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_POLICY_READ")))
 var rows:Array=[]
 for path in r.paths:
  if not FileAccess.file_exists(path):continue
  var f=FileAccess.open(path,FileAccess.READ);var h=JSON.parse_string(f.get_line());var b=f.get_buffer(f.get_length()-f.get_position());var p:Dictionary=bytes_to_var(b)
  var c=HashingContext.new();c.start(HashingContext.HASH_SHA256);c.update(b);assert(c.finish().hex_encode()==h.sha256 and b.size()==int(h.bytes))
  rows.append({"path":path,"sha256":FileAccess.get_sha256(path),"x1_seconds":p.x1_seconds,"has_enabled":p.space_policy.has("idle_salvage_enabled"),"enabled":p.space_policy.get("idle_salvage_enabled"),"budget":p.space_policy.get("idle_salvage_budget"),"inventory":p.save.hyperspace.inventory,"hyperspace":p.save.hyperspace,"controller":p.controller,"rng_state":p.rng_state,"save":p.save,"safe_farm":p.safe_farm,"options":p.options,"progress_guard":p.get("progress_guard",{}),"manual_interrupted_on_reload":p.get("manual_interrupted_on_reload",false),"trace_bytes":p.trace_bytes})
 FileAccess.open(r.output,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "));print("POLICY_READ_OK");quit()
