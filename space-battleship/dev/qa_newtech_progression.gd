extends SceneTree
func invest(g,stage:int,weapon:String,defence:String,target:int,reactor:int)->void:
 if g.profile.unlocked.has(weapon):g.equip_slot("weapons",0,weapon)
 if g.profile.unlocked.has(defence):g.equip_slot("defence",0,defence)
 for category in ["weapons","defence"]:
  while int(g.profile.loadout[category][0].level)<target and g.can_upgrade_slot(category,0):
   if not g.upgrade_slot(category,0):break
 while int(g.profile.reactorLevel)<reactor:
  if not g.upgrade_reactor(1):break
 var cap=g.reactor_capacity()
 var wanted=int(cap/2)
 if int(g.profile.reactorAllocation.get("weapons",0))!=wanted or int(g.profile.reactorAllocation.get("defence",0))!=cap-wanted:
  g.profile.reactorAllocation={"weapons":wanted,"defence":cap-wanted}
  g.invalidate_stat_cache()
 var selected="weapon_accuracy" if g.hightech_level("weapon_accuracy")<=g.hightech_level("equipment_reinforcement") else "equipment_reinforcement"
 g.select_tech(selected)
func snapshot(g,stage:int,frames:int,attempt:int)->Dictionary:
 return {"stage":stage,"state":g.state,"frames":frames,"attempt":attempt,"point":g.group_index,"iron":float(g.profile.resources.get("1",0)),"uranium":float(g.profile.resources.get("2",0)),"weapon":g.profile.loadout.weapons[0],"defence":g.profile.loadout.defence[0],"reactor":g.profile.reactorLevel,"ai":g.profile.aiTechLevels.duplicate(true),"uranium_samples":g.resource_samples.filter(func(x):return x.id=="2").map(func(x):return [x.get("amount",0),x.get("production_base",0),x.get("origin","")]) if stage==7 else []}
func _initialize()->void:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.aiTechInput={"1":0,"2":0}
 var weapons=["laser","missile","cannon","cannon","missile","longLaser","longLaser"]
 var defences=["armour","shield","shield","shield","shield","shield","shield"]
 var targets=[3,5,7,9,11,12,17]
 var reactors=[1,1,2,3,4,5,8]
 for stage in range(1,8):
  var done:=false
  for attempt in range(1,4):
   invest(g,stage,weapons[stage-1],defences[stage-1],targets[stage-1],reactors[stage-1])
   if not g.start(stage,false):
    print("QA_STAGE_START_FAIL ",JSON.stringify(snapshot(g,stage,0,attempt)));quit();return
   var sample_start=g.resource_samples.size();var frames:=0
   while g.state!=BattleGame.State.LEVEL_CLEAR and g.state!=BattleGame.State.DEFEAT and frames<18000:
    g.tick(1.0/60.0);frames+=1
    if frames%60==0:invest(g,stage,weapons[stage-1],defences[stage-1],targets[stage-1],reactors[stage-1])
   g.settle_drops();if stage==7:print("QA_STAGE7_DROPS ",JSON.stringify(g.resource_samples.slice(sample_start).filter(func(x):return x.id=="2")))
   print("QA_STAGE ",JSON.stringify(snapshot(g,stage,frames,attempt)))
   if g.state==BattleGame.State.LEVEL_CLEAR:done=true;break
  if not done:break
 assert(g.profile.cleared.has(7),"normal fresh path clears stages 1-7")
 if g.profile.cleared.has(7):
  g.pending_unlocks.clear()
  var switched=g.equip_slot("defence",0,"armour")
  for category in ["weapons","defence"]:
   while int(g.profile.loadout[category][0].level)<19 and g.can_upgrade_slot(category,0):
    if not g.upgrade_slot(category,0):break
  print("QA_POST7 ",JSON.stringify({"switched":switched,"iron":g.profile.resources["1"],"uranium":g.profile.resources["2"],"weapon":g.profile.loadout.weapons[0],"defence":g.profile.loadout.defence[0],"reactor":g.profile.reactorLevel,"tech":g.profile.aiTechLevels.duplicate(true)}))
  var loaded=g.manual_hyperspace.load_production(g)
  var started=g.manual_hyperspace.request(g,"alpha",1) if loaded else false
  var hyper_frames:=0
  while g.manual_hyperspace.active and hyper_frames<72000:
   g.tick(1.0/60.0);hyper_frames+=1
  var result=g.manual_hyperspace.last_result.duplicate(true)
  var receipt=g.profile.hyperspace.active.duplicate(true)
  var reward=receipt.get("reward",{}).get("materials",{})
  var claimed=g.claim_hyperspace(int(receipt.get("round_id",-1)),int(receipt.get("run_id",-1))) if result.get("reason")=="success" else false
  g.settle_drops()
  var evolved=g.upgrade_slot("weapons",0) if claimed and int(g.profile.loadout.weapons[0].level)==19 and g.can_upgrade_slot("weapons",0) else false
  print("QA_FIRST_MATERIAL_LOOP ",JSON.stringify({"loaded":loaded,"started":started,"hyper_frames":hyper_frames,"result":result,"reward":reward,"claimed":claimed,"matter":g.profile.hyperspace.materials.get("degenerate_matter",0),"evolved":evolved,"weapon":g.profile.loadout.weapons[0],"iron":g.profile.resources["1"],"uranium":g.profile.resources["2"]}))
  assert(loaded and started and claimed and evolved and int(g.profile.loadout.weapons[0].level)==20,"first material and evolution loop")
 quit()
