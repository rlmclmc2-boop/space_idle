extends SceneTree
const Bind=preload("res://scripts/hyperspace_reward_binding.gd")
const Validator=preload("res://scripts/candidate_rewards.gd")
const Loader=preload("res://scripts/hyperspace_route_loader.gd")
const CC=preload("res://scripts/combat_context.gd")
var checks:=0
var failures:=0
var base:ShipDatabase
var records:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func make_game(cleared:Array,highest:int,selected:int)->BattleGame:
 var g=BattleGame.new(base,false);g.save_enabled=false;g.rng.seed=20261005;g.profile.hyperspace.random_state="123456789";g.profile.cleared=cleared;g.profile.highestLevel=highest;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.loop=false;g.enemies.clear();g.projectiles.clear();g.state=g.State.LEVEL_SELECT
 check(g.load_hyperspace_routes() and g.start_hyperspace("alpha",selected),"Actual production start for selection "+str(selected))
 return g
func verify(cleared:Array,highest:int,selected:int,reference:int)->BattleGame:
 var g=make_game(cleared,highest,selected)
 if not g.manual_hyperspace.active:return g
 check(Bind.latest_cleared_level(g)==reference,"Reference uses latest completed, not reached or selected")
 check(g.ratio("atkRatio")==float(base.levels[selected-1].atkRatio) and g.ratio("lifeRatio")==float(base.levels[selected-1].lifeRatio),"Selected level still controls actual combat ratios")
 check(g.ratio("resRatio")==float(base.levels[reference-1].resRatio) and g.jewel_ratio()==float(base.levels[reference-1].jewelRatio),"Actual iron/uranium and ordinary enhancement-fragment ratios use latest clear")
 var errors:Array=[]
 for route in g.manual_hyperspace.route_ids:
  for id in g.manual_hyperspace.route_ids[route]:
   var binding=g.db.groups[str(int(id))].rewardBinding
   if int(binding.levelId)!=selected or int(binding.resourceReferenceLevel)!=reference:errors.append("wrong level binding")
   var error=Validator.binding_error(str(int(id)),g.db.groups,g.db.enemies,g.db.levels,selected,g.ratio("resRatio"),g.jewel_ratio())
   if not error.is_empty():errors.append(error)
 check(errors.is_empty(),"All forty bound fleets preserve ordinary-drop multiset and fragment-roll budget")
 g.spawn_group()
 check(g.enemies.all(func(e):return float(e.res_ratio)==float(base.levels[reference-1].resRatio)),"Actual spawned enemies freeze the correct ordinary resource ratio")
 records.append({"cleared":cleared,"highest":highest,"selected":selected,"reference":reference,"atkRatio":g.ratio("atkRatio"),"lifeRatio":g.ratio("lifeRatio"),"resRatio":g.ratio("resRatio"),"fragmentRatio":g.jewel_ratio(),"receipt_level":g.profile.hyperspace.active.level})
 return g
func run()->void:
 base=ShipDatabase.new();var original=JSON.stringify(base.data)
 var routes=JSON.parse_string(FileAccess.get_file_as_string(Loader.ROUTES_PATH));var candidates=JSON.parse_string(FileAccess.get_file_as_string(Loader.CANDIDATES_PATH));var old_policy=routes.duplicate(true);old_policy.selected_mainline_level_policy.resRatio="inherit_selected_mainline_level"
 var loader=Loader.new();var metadata_game=BattleGame.new(base,false)
 check(loader.prepare(metadata_game,old_policy,candidates).is_empty() and loader.last_error=="space_multiplier_policy_invalid","Outdated selected-level ordinary-resource metadata cannot silently load")
 old_policy=routes.duplicate(true);old_policy.selected_mainline_level_policy.erase("jewelRatio")
 check(loader.prepare(metadata_game,old_policy,candidates).is_empty() and loader.last_error=="space_multiplier_policy_invalid","Ordinary fragment reference must be declared explicitly")
 var frontier=verify(range(1,20),20,20,19)
 var repeat=verify(range(1,21),21,5,20)
 var sparse=verify([3,19,1,8],30,5,19)
 var seeded_fragments:=false
 # Actual normal monster deaths and pickup; no injected drops or adjusted probabilities.
 for wave in 12:
  for enemy in sparse.enemies.duplicate():sparse.hit_enemy(enemy,1e100,0,[],false,CC.root(100+wave,"fixture","laser"))
  var fragments=sparse.drops.filter(func(drop):return drop.has("jewel"))
  if not fragments.is_empty():
   check(fragments.all(func(drop):return float(drop.jewelRatio)==float(base.levels[18].jewelRatio)),"Actual ordinary fragment drops snapshot latest-cleared ratio")
   var before=sparse.profile.jewelFragments;sparse.collect(fragments[0],true)
   check(sparse.N.compare(sparse.profile.jewelFragments,before)>0,"Actual fragment pickup credits ordinary enhancement currency")
   seeded_fragments=true;break
  sparse.enemies.clear();sparse.projectiles.clear();sparse.group_index=0;sparse.spawn_group()
 check(seeded_fragments,"Fixed seeded actual loot produced fragment evidence")
 var drops=sparse.drops.filter(func(drop):return str(drop.get("id","")) in ["1","2"])
 check(not drops.is_empty(),"Actual iron/uranium monster loot exists with current formal drop probabilities")
 var a=make_game(range(1,20),20,20);var b=make_game(range(1,21),21,20)
 if not a.manual_hyperspace.active or not b.manual_hyperspace.active:printerr("Invalid special reward fixture; stop before reading receipt");quit(1);return
 a.profile.hyperspace.active.work=1.0;b.profile.hyperspace.active.work=1.0
 # Explicit unit transaction completion; this is not natural ten-wave/timing evidence.
 check(a.manual_hyperspace.finish(a,true) and b.manual_hyperspace.finish(b,true),"Actual completion settles independent special rewards")
 var ar=a.profile.hyperspace.active.reward;var br=b.profile.hyperspace.active.reward
 check(ar==br and a.profile.hyperspace.random_state==b.profile.hyperspace.random_state,"Different ordinary reference levels cannot change selected-level drone/material reward or special RNG")
 check(ar.drone.is_empty() or int(ar.drone.level)==20,"Generated special drone retains exploration selection level")
 var no_clear=BattleGame.new(base,false);no_clear.profile.cleared=[];no_clear.profile.highestLevel=30
 check(Bind.latest_cleared_level(no_clear)==1,"No completed level uses only initial pre-unlock preload fallback, never highest reached")
 var saved=repeat.portable_save_data();var loaded=BattleGame.new(base,false);loaded.load_hyperspace_routes();loaded.load_progress_data(saved);loaded.resume_progress()
 check(loaded.profile.hyperspace.active.is_empty() and loaded.profile.cleared==repeat.profile.cleared,"Current started receipt still refunds/restores through formal save/read")
 check(JSON.stringify(base.data)==original,"Disposable reference binding never mutates official mainline database")
 var folder=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 if not folder.is_empty():FileAccess.open(folder+"/reference-cases.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
 print("LATEST_CLEARED_RESOURCES ",checks," checks ",failures," failures");quit(1 if failures else 0)
