extends SceneTree
const Binder=preload("res://scripts/hyperspace_reward_binding.gd")
const Validator=preload("res://scripts/candidate_rewards.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 var candidates:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_enemy_candidates.json"))
 var original_groups:String=JSON.stringify(g.db.groups);var original_enemies:String=JSON.stringify(g.db.enemies)
 var binder:=Binder.new();check(binder.load_contract(),"load contract")
 for level in [1,5,7,40,60]:
  var bound:Dictionary=binder.bind(g.db,candidates,level)
  check(not bound.is_empty(),"bind level "+str(level)+" "+binder.last_error)
  if bound.is_empty():continue
  var levels:Array=g.db.levels.duplicate();levels[level-1]=levels[level-1].duplicate(true);levels[level-1].rewardReferenceGroups=bound.rewardReferenceGroups
  var total:=0
  for gid in candidates.groups:
   var row:Dictionary=bound.groups[gid]
   check(Validator.binding_error(gid,bound.groups,bound.enemies,levels,level,float(levels[level-1].resRatio),float(levels[level-1].jewelRatio)).is_empty(),"validated "+gid)
   check(row.rewardBinding.levelId==level and row.rewardBinding.resRatio==levels[level-1].resRatio and row.rewardBinding.jewelRatio==levels[level-1].jewelRatio,"exact multipliers "+gid)
   for id in row.slots:
    if id!=null:total+=int(bound.enemies[str(int(id))].jewelDropRolls)
  check(total==200,"all forty retain 200 integer trials")
 check(JSON.stringify(g.db.groups)==original_groups and JSON.stringify(g.db.enemies)==original_enemies,"mainline immutable")
 check(g.load_hyperspace_routes(),"production accepted and all-level rewards ready "+g.manual_hyperspace.last_error)
 check(g.hyperspace.snapshot(g).manual_ready,"UI readiness after binding validation")
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 g.rng.seed=444
 var expected_rng:=RandomNumberGenerator.new();expected_rng.seed=444
 var expected_success:=0
 for draw in 200:
  if expected_rng.randf()<float(g.db.config.get("jewelDrop",0)):expected_success+=1
 var before_drops:int=g.drops.size()
 for enemy in candidates.enemies.values():
  var live:Dictionary=enemy.duplicate(true);live.x=100.0;live.y=100.0
  g.jewel_kill_drop(live);g.jewel_kill_drop(live)
 check(g.rng.state==expected_rng.state,"exactly 200 integer trials, duplicate kill guarded")
 check(g.drops.size()-before_drops==expected_success and g.drops.all(func(drop):return float(drop.amount)==1.0),"separate amount-one Bernoulli successes")
 g.profile.cleared=range(1,41);g.profile.highestLevel=40;g.rebuild_unlocks()
 check(g.start_hyperspace("alpha",7),"start bound route")
 check(g.db.levels[6].groups.size()==10 and g.db.levels[6].rewardReferenceGroups.size()==40,"references are not playable waves")
 var gid:String=str(int(g.db.levels[6].groups[0].id))
 check(Validator.binding_error(gid,g.db.groups,g.db.enemies,g.db.levels,7,g.ratio("resRatio"),g.jewel_ratio()).is_empty(),"runtime view validator")
 g.manual_hyperspace.finish(g,false)
 var ticket:float=float(g.profile.hyperspace.energy)
 g.db.levels[6].resRatio=-1
 check(not g.start_hyperspace("alpha",7) and g.profile.hyperspace.energy==ticket,"bad changed ratio rejected before ticket")
 check(not g.hyperspace.snapshot(g).manual_ready,"failed rebinding clears readiness")
 print("REWARD_BINDING ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
