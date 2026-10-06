extends "res://qa/hyperspace_longrun.gd"
## Persistence fixture only: no ticks, new campaign, or paid business commands.
var fixture_checks:=0
var fixture_failures:=0
func verify(ok:bool,label:String)->void:
 fixture_checks+=1
 if not ok:fixture_failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var source:String=OS.get_environment("QA_ULTIMATE_PAID_SOURCE")
 var original:String=FileAccess.get_sha256(source)
 var loaded:Dictionary=Checkpoint.read_one(source)
 assert(loaded.error.is_empty())
 var payload:Dictionary=loaded.payload
 game=Game.new(ShipDatabase.new())
 var raw:Dictionary=payload.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system();game.load_progress_data(raw)
 game.simulated_time=payload.x1_seconds
 Checkpoint.apply_fields(space_policy,payload.space_policy,Checkpoint.POLICY)
 manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 output=OS.get_environment("QA_CHECKPOINT_FIXTURE_OUTPUT")
 assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
 DirAccess.make_dir_recursive_absolute(output)
 trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE);wall_started=Time.get_ticks_usec()
 options={"checkpoint_wall_seconds":30}
 var plan:Dictionary=space_policy.ultimate_upgrade_chain
 verify(plan.phase=="complete" and plan.receipts.size()==3,"Fixture source is a real complete paid chain")
 var entry:Dictionary={"round":int(game.profile.hyperspace.round_id),"drone":str(plan.drone),"command_seq":int(game.profile.hyperspace.command_seq),"operation":"ultimate"}
 var name:String=ultimate_checkpoint_name(entry,0,"")
 var next_round:Dictionary=entry.duplicate(true);next_round.round+=1
 verify(name!=ultimate_checkpoint_name(next_round,0,""),"Reset command sequence in another round cannot collide")
 var another:Dictionary=entry.duplicate(true);another.drone="different-real-id-for-name-fixture"
 verify(name!=ultimate_checkpoint_name(another,0,""),"Different drone identity cannot collide")
 var before:Dictionary=Checkpoint.capture(self,manifest)
 verify(Checkpoint.write_once(output+"/"+name,before,manifest)==OK,"Seed actual occupied write-once name")
 var archive_sha:String=FileAccess.get_sha256(output+"/"+name)
 ultimate_upgrade_checkpoint_pending.append(entry)
 checkpoint_now()
 var primary:Dictionary=Checkpoint.read_one(output+"/checkpoint.bin")
 verify(primary.error.is_empty(),"Archive collision leaves valid primary already written")
 verify(primary.payload.space_policy.ultimate_upgrade_chain==plan,"Primary retains all three actual paid receipts and complete phase")
 verify(primary.payload.save.hyperspace.materials==game.profile.hyperspace.materials and primary.payload.save.hyperspace.ultimate_cores==game.profile.hyperspace.ultimate_cores,"Primary preserves exact actual paid balances")
 verify(input_failure.kind=="ultimate_chain_checkpoint_io" and input_failure.error==ERR_ALREADY_EXISTS,"Collision is explicitly reported, never hidden")
 verify(FileAccess.get_sha256(output+"/"+name)==archive_sha,"Write-once collision does not overwrite original archive")
 verify(ultimate_upgrade_checkpoint_pending.size()==1,"Failed archive intent remains pending in memory")
 input_failure={};ultimate_upgrade_checkpoint_pending.clear()
 var bad:Dictionary=entry.duplicate(true);bad.operation="missing-parent/ultimate"
 ultimate_upgrade_checkpoint_pending.append(bad)
 checkpoint_now()
 primary=Checkpoint.read_one(output+"/checkpoint.bin")
 verify(primary.error.is_empty() and primary.payload.space_policy.ultimate_upgrade_chain.receipts.size()==3,"Missing archive directory leaves fresh paid-state primary valid")
 verify(not input_failure.is_empty() and input_failure.kind=="ultimate_chain_checkpoint_io","Archive open failure is explicit")
 verify(Checkpoint.read_one(output+"/checkpoint.bin.previous").error.is_empty(),"Primary update retains valid backup")
 input_failure={};ultimate_upgrade_checkpoint_pending.clear();ultimate_upgrade_checkpoint_pending.append(entry)
 var prior_output:String=output;output=prior_output+"/missing-primary-parent"
 checkpoint_now();output=prior_output
 verify(input_failure.kind=="checkpoint_io" and ultimate_upgrade_checkpoint_pending.size()==1,"Primary write failure preserves pending archive intent and stops first")
 verify(FileAccess.get_sha256(source)==original,"Actual source CP remains unchanged")
 trace.close()
 print("ULTIMATE_CHECKPOINT_SAFETY checks=",fixture_checks," failures=",fixture_failures," scope=Persistence fixtures only, no campaign progression")
 quit(0 if fixture_failures==0 else 1)
