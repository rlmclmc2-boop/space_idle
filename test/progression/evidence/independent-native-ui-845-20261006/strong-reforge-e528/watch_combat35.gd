extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
func _initialize():call_deferred("watch")
func watch():
 var start=Time.get_ticks_msec();var out="/tmp/e528-strong34-evidence/actual-combat35/";DirAccess.make_dir_recursive_absolute(out)
 while Time.get_ticks_msec()-start<3600000:
  var source="/tmp/e528-strong34-evidence/cached-run/checkpoint.bin";var packet=FileAccess.get_file_as_bytes(source)
  # Read a private atomic snapshot, never mutate or interrupt the real runner.
  CP.atomic_bytes(out+"observer-latest.bin",packet)
  var raw=CP.read_one(out+"observer-latest.bin")
  if str(raw.error).is_empty():
   var p=raw.payload;var j=p.save.journey
   if int(j.stage)==35 and int(j.state)==3 and p.save.hyperspace.active.get("mode","")!="manual":
    CP.atomic_bytes(out+"checkpoint.bin",packet)
    CP.atomic_json(out+"snapshot.json",{"save":p.save,"rng_state":p.rng_state,"x1_seconds":p.x1_seconds,"options":p.options})
    CP.atomic_json(out+"audit.json",{"source":"live runner atomic checkpoint","x1_seconds":p.x1_seconds,"sha256":CP.digest(packet),"stage":35,"state":"COMBAT","round":p.save.hyperspace.round_id,"scope":"file-only observer; no restore/tick/model changes"})
    print("CAPTURE35 ",p.x1_seconds," ",CP.digest(packet));quit();return
  await create_timer(2.0).timeout
 print("WATCH35_TIMEOUT no qualifying checkpoint");quit(3)
