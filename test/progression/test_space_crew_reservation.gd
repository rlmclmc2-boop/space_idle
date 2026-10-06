extends SceneTree
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const Game=preload("res://scripts/game.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var loaded:Dictionary=CP.read_one(OS.get_environment("QA_CREW_SOURCE"));assert(loaded.error.is_empty())
 var g=Game.new(ShipDatabase.new());var raw:Dictionary=loaded.payload.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system();g.load_progress_data(raw)
 var p=Policy.new();var visible:Array=g.profile.crew.map(func(m):return str(m.crewId))
 var original:String=CP.digest(var_to_bytes(g.profile))
 check(p.space_crew_reservation_action(g,visible,1).is_empty() and p.space_crew_reservation.is_empty(),"Earned reforge source5 keeps growth jobs despite inherited records")
 check(CP.digest(var_to_bytes(g.profile))==original,"Planning does not mutate production profile")
 # Explicit unit fixture conditions, never written to the campaign/source CP.
 g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)-1
 check(p.space_crew_reservation_action(g,visible,2).is_empty(),"Last locked stage cannot release space workers")
 g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)
 g.profile.hyperspace.energy=float(g.hyperspace.online_config(g).energy_cap)
 for m in g.profile.crew:g.assign_crew(str(m.crewId),"","")
 check(g.assign_crew("navigator","equipment_upgrade","equipment"),"Fixture worker lawfully assigned to actual growth job")
 var choice:Dictionary=p.space_crew_reservation_action(g,["navigator"],3)
 check(choice.get("kind")=="crew_release" and choice.get("crew")=="navigator","Exactly selected visible worker released for funded eligible record")
 check(p.space_crew_reservation.get("crew")=="navigator" and p.space_crew_reservation.get("level")==5,"Reservation binds current round/crew/real eligible route record")
 check(p.execute(g,choice,3.3),"Actual legal release command succeeds")
 check(p.space_crew_reservation_action(g,["navigator"],3.6).is_empty(),"Already idle reserved worker is not released again")
 check(p.reserved_growth_crew(g)=="navigator" and p.pick_crew(g)=="navigator","Growth skip and next space dispatch use the same candidate")
 var resumed=Policy.new();CP.apply_fields(resumed,CP.fields(p,CP.POLICY),CP.POLICY)
 check(resumed.reserved_growth_crew(g)=="navigator" and resumed.space_crew_reservation_action(g,["navigator"],4).is_empty(),"Atomic policy restoration retains selected idle worker")
 g.profile.hyperspace.energy=float(g.hyperspace.online_config(g).energy_cap)-1.0
 check(resumed.space_crew_reservation_action(g,["navigator"],5).is_empty() and resumed.space_crew_reservation.is_empty(),"Unfunded auto cannot stop a growth worker")
 g.profile.hyperspace.energy=float(g.hyperspace.online_config(g).energy_cap)
 resumed.manual_pending={"route":"alpha","level":5}
 check(resumed.space_crew_reservation_action(g,["navigator"],6).is_empty() and resumed.space_crew_reservation.is_empty(),"Manual plan needs no automatic-exploration worker")
 resumed.manual_pending={};resumed.space_crew_reservation_action(g,["navigator"],7)
 check(resumed.space_crew_reservation_action(g,[],8).is_empty() and resumed.space_crew_reservation.is_empty(),"Invisible/stale candidate is not released or kept")
 print("SPACE_CREW_RESERVATION checks=",checks," failures=",failures);quit(1 if failures else 0)
