extends SceneTree
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
var checks:=0
var failures:=0
var actions:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var source:String=OS.get_environment("QA_CREW_SOURCE")
 var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source));var raw:Dictionary=snapshot.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 var g=BattleGame.new(ShipDatabase.new(),false);g.save_enabled=false;g.load_progress_data(raw);g.resume_progress()
 check(g.profile.highestLevel==raw.highestLevel,"Actual source formally accepted")
 var p=Policy.new();var visible:Array=[]
 for member in g.profile.crew:
  if g.crew.unlocked(g,str(member.crewId)):visible.append(str(member.crewId))
 var before:Dictionary=g.profile.duplicate(true);var rng_before=g.rng.state;var now:float=snapshot.x1_seconds
 var decision:Dictionary=p.crew_redeploy_action(g,5,visible,now)
 check(not p.crew_transfer.is_empty(),"Visible earned explorer produces bounded transfer plan")
 if p.crew_transfer.is_empty():quit(1);return
 var veteran:String=p.crew_transfer.veteran;var replacement:String=p.crew_transfer.replacement;var planet:String=p.crew_transfer.planet
 check(replacement!=preload("res://scripts/hyperspace_permissions.gd").reserved_crew(g.profile.hyperspace),"Actual auto worker excluded without assuming idle")
 var old_level:int=g.crew.system_level(g,"equip_bonus");var earned_level:int=g.crew.entry(g,veteran).level;var elapsed:float=g.planet_progress(planet).elapsed
 check(p.crew_transfer.visible_level==earned_level,"Uses actual visible crew level")
 check(g.profile==before and g.rng.state==rng_before,"Plan neither grants nor recalls")
 for step in 16:
  var page:int=5 if step%2==0 else 6
  var choice:Dictionary=p.crew_redeploy_action(g,page,visible if page==5 else [],now)
  if not choice.is_empty():
   check(p.execute(g,choice,now),"Serial public command: "+str(choice.kind));actions.append({"page":page,"at":now,"choice":choice});now+=0.3
  if p.crew_transfer.is_empty():break
 check(p.crew_transfer.is_empty() and p.crew_transfer_history.size()==1,"Transfer completes once")
 check(g.crew.entry(g,veteran).assignmentType=="equipment_upgrade" and str(g.planet_progress(planet).crewId)==replacement,"Higher level in equipment with actual explorer replacement")
 check(g.crew.entry(g,veteran).upgradeMode=="10","Explicit serial equipment mode preserves normal +10 strategy")
 check(g.crew.system_level(g,"equip_bonus")==earned_level,"Actual derived equipment level improves")
 var expected:float=pow(1.0+float(g.db.data.crew_config.equip_bonus.value),earned_level-old_level)
 check(is_equal_approx(g.crew.system_effect(g,"equip_bonus")/pow(1.0+float(g.db.data.crew_config.equip_bonus.value),old_level),expected),"Weapon and defence equipment factor uses official config")
 check(is_equal_approx(float(p.crew_transfer_history[0].lost_exploration_seconds),elapsed) and g.planet_progress(planet).elapsed==0,"Actual recall loss recorded and replacement starts from zero")
 check(g.profile.resources==before.resources and g.profile.hyperspace==before.hyperspace and g.profile.loadout==before.loadout,"No currency drone or equipment levels injected by strategy")
 check(p.crew_redeploy_action(g,5,visible,now).is_empty() and p.crew_transfer.is_empty(),"Stable advantage does not immediately churn")
 var restored=Policy.new();CP.apply_fields(restored,CP.fields(p,CP.POLICY),CP.POLICY)
 check(restored.crew_transfer_history==p.crew_transfer_history and restored.last_crew_transfer==p.last_crew_transfer,"Strategy transfer history persists in full QA checkpoint")
 # A second actual-source copy tests visible access and owner changes before recall.
 var busy_game=BattleGame.new(g.db,false);busy_game.save_enabled=false;busy_game.load_progress_data(raw);busy_game.resume_progress();var busy_policy=Policy.new()
 check(busy_policy.crew_redeploy_action(busy_game,5,[],now).is_empty() and busy_policy.crew_transfer.is_empty(),"Hidden crew levels cannot create a transfer")
 var first:Dictionary=busy_policy.crew_redeploy_action(busy_game,5,visible,now)
 if not first.is_empty():check(busy_policy.execute(busy_game,first,now),"Release actual replacement job before ownership test")
 var busy_replacement:String=str(busy_policy.crew_transfer.replacement)
 check(busy_game.hyperspace.set_auto(busy_game,false,"",0,""),"Explicit external fixture pauses old owner before changing auto crew")
 check(busy_game.hyperspace.set_auto(busy_game,true,"beta",5,busy_replacement),"Real auto transaction reserves the formerly available replacement")
 var busy_before:Dictionary=busy_game.profile.duplicate(true)
 check(busy_policy.crew_redeploy_action(busy_game,6,[],now).is_empty() and busy_policy.crew_transfer.is_empty() and busy_game.profile==busy_before,"Changed auto owner cancels stale transfer without recall or grants")
 # Separate explicit legal gate fixture: production eligibility below 33 is sufficient.
 g.profile.planets[planet].buildings.shipyard.status="built";g.profile.planets[planet].buildings.shipyard.crew=[];g.profile.planets[planet].conquered=false
 check(int(g.profile.highestLevel)<33 and g.can_reforge_planet(planet),"Explicit completed shipyard fixture has actual eligibility below 33")
 var choice:Dictionary={}
 for step in 8:
  choice=p.planet_action(g,now)
  if choice.get("kind","")=="planet_reforge":break
  if choice.is_empty():break
  check(p.execute(g,choice,now),"Required visible building action before reforge")
 check(choice.get("kind","")=="planet_reforge" and float(choice.get("eligibility",{}).get("first_visible_eligible_x1",-1))==now,"First visible eligibility leads to reforge without hard 33 threshold")
 FileAccess.open(OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")+"/crew-transfer-actions.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source,"earned_level":earned_level,"old_equipment_level":old_level,"equipment_factor":expected,"actions":actions,"transfer_history":p.crew_transfer_history,"reforge_fixture_only":true},"\t"))
 print("REASONABLE_CREW_REFORGE ",checks," checks ",failures," failures");quit(1 if failures else 0)
