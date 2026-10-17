extends SceneTree
func invest(g,weapon:String,defence:String,target:int,reactor:int,sing_target:int)->void:
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
 var selected="singularity" if g.hightech_level("singularity")<sing_target else "weapon_accuracy" if g.hightech_level("weapon_accuracy")<=g.hightech_level("equipment_reinforcement") else "equipment_reinforcement"
 g.select_tech(selected)
func run(label:String,sing_target:int,route_b:bool)->void:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.aiTechInput={"1":0,"2":0}
 var weapons=["laser","missile","cannon","cannon","missile","longLaser","longLaser"]
 var defences=["armour","shield","shield","shield","shield","shield","armour" if route_b else "shield"]
 var targets=[3,5,7,9,11,13,16] if route_b else [3,5,7,9,11,12,17]
 var reactors=[1,1,2,3,4,6,7] if route_b else [1,1,2,3,4,5,8]
 var elapsed_frames:=0
 var milestones={}
 for stage in range(1,8):
  var done:=false
  for attempt in range(1,4):
   invest(g,weapons[stage-1],defences[stage-1],targets[stage-1],reactors[stage-1],sing_target)
   if not g.start(stage,false):
    print("QA_SING_START_FAIL ",JSON.stringify({"route":label,"stage":stage}));return
   var frames:=0
   while g.state!=BattleGame.State.LEVEL_CLEAR and g.state!=BattleGame.State.DEFEAT and frames<18000:
    g.tick(1.0/60.0);frames+=1;elapsed_frames+=1
    if frames%60==0:invest(g,weapons[stage-1],defences[stage-1],targets[stage-1],reactors[stage-1],sing_target)
    for level in [1,2,3]:
     if g.hightech_level("singularity")>=level and not milestones.has("sing%d"%level):milestones["sing%d"%level]=snappedf(elapsed_frames/60.0,.01)
     if g.hightech_level("weapon_accuracy")>=level and g.hightech_level("equipment_reinforcement")>=level and not milestones.has("basic_both_%d"%level):milestones["basic_both_%d"%level]=snappedf(elapsed_frames/60.0,.01)
   g.settle_drops()
   print("QA_SING_STAGE ",JSON.stringify({"route":label,"stage":stage,"attempt":attempt,"state":g.state,"frames":frames,"elapsed":snappedf(elapsed_frames/60.0,.01),"weapon":g.profile.loadout.weapons[0],"defence":g.profile.loadout.defence[0],"reactor":g.profile.reactorLevel,"tech":g.profile.aiTechLevels.duplicate(true),"iron":float(g.profile.resources.get("1",0)),"uranium":float(g.profile.resources.get("2",0))}))
   if g.state==BattleGame.State.LEVEL_CLEAR:done=true;break
  if not done:break
 print("QA_SING_RESULT ",JSON.stringify({"route":label,"target":sing_target,"cleared7":g.profile.cleared.has(7),"elapsed":snappedf(elapsed_frames/60.0,.01),"milestones":milestones,"weapon":g.profile.loadout.weapons[0],"defence":g.profile.loadout.defence[0],"reactor":g.profile.reactorLevel,"tech":g.profile.aiTechLevels.duplicate(true),"iron":float(g.profile.resources.get("1",0)),"uranium":float(g.profile.resources.get("2",0)),"input":g.profile.aiTechInput.duplicate(true)}))
 assert(g.profile.cleared.has(7),"route must clear stage 7")
func _initialize()->void:
 run("A_direct",0,false)
 run("A_sing1",1,false)
 run("A_sing2",2,false)
 run("B_direct",0,true)
 run("B_sing1",1,true)
 quit()