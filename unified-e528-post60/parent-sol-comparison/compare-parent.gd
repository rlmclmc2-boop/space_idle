extends SceneTree
var differences:Array=[]
func packet(path:String)->Dictionary:
 var f=FileAccess.open(path,FileAccess.READ);var h:Dictionary=JSON.parse_string(f.get_line());var b=f.get_buffer(f.get_length()-f.get_position());var c=HashingContext.new();c.start(HashingContext.HASH_SHA256);c.update(b)
 assert(c.finish().hex_encode()==h.sha256 and b.size()==int(h.bytes));assert(h.code_fingerprint=="13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d")
 return bytes_to_var(b)
func compare(a,b,path:String)->void:
 if a==b:return
 if a is Dictionary and b is Dictionary:
  var names:Array=a.keys()
  for key in b:
   if not names.has(key):names.append(key)
  for key in names:
   if not a.has(key) or not b.has(key):differences.append({"path":path+"/"+str(key),"kind":"missing_key"})
   else:compare(a[key],b[key],path+"/"+str(key))
 elif a is Array and b is Array:
  if a.size()!=b.size():differences.append({"path":path,"kind":"array_size","sol":a.size(),"parent":b.size()})
  for i in mini(a.size(),b.size()):compare(a[i],b[i],path+"/"+str(i))
 else:differences.append({"path":path,"kind":"value","sol":a,"parent":b})
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_COMPARE_POST60")));var results:Array=[]
 for pair in r.pairs:
  var sol:Dictionary=packet(pair.sol);var parent:Dictionary=packet(pair.parent);differences=[];compare(sol,parent,"")
  results.append({"label":pair.label,"sol_sha256":FileAccess.get_sha256(pair.sol),"parent_sha256":FileAccess.get_sha256(pair.parent),"sol_x1":sol.x1_seconds,"parent_x1":parent.x1_seconds,"delta_x1_parent_minus_sol":float(parent.x1_seconds)-float(sol.x1_seconds),"differences":differences.duplicate(true),"differences_count":differences.size(),"save_resources_equal":sol.save.resources==parent.save.resources,"save_loadout_equal":sol.save.loadout==parent.save.loadout,"save_hyperspace_equal":sol.save.hyperspace==parent.save.hyperspace,"main_rng_equal":sol.rng_state==parent.rng_state,"safe_farm_equal":sol.safe_farm==parent.safe_farm,"space_policy_equal":sol.space_policy==parent.space_policy,"controller_equal":sol.controller==parent.controller})
 FileAccess.open(r.output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "));print("PARENT_POST60_RAW_COMPARE_OK");quit()
