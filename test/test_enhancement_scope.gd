extends SceneTree
class ProbeGame extends BattleGame:
 var mode: String="plain"
 var depths: Array=[]
 var guard_delta := -1
 var updated := false
 func _tick_synchronized(dt: float) -> void:
  depths.append(_enhancement_read_scope_depth)
  var guards: int=enhancement_plan.guard_checks
  for i in 20:
   shared_enhancement_effect_count();enhancement_effects({"key":"armour","level":1})
   has_enhancement_effect({"key":"missile","level":1},"repeat")
   enhancement_branch_active({"key":"missile","level":1},"critical",1,"B")
   enhancement_branches.reconcile(self)
  guard_delta=enhancement_plan.guard_checks-guards
  if mode=="nested":
   mode="plain";tick(dt);depths.append(_enhancement_read_scope_depth)
  elif mode=="upgrade":
   upgrade_enhancement(1)
   updated=enhancement_effects({"key":"armour","level":1}).size()==2
  elif mode=="order":
   set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
   updated=enhancement_effects({"key":"armour","level":1})[0].kind=="memory_material"
  elif mode=="config":
   set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
   db.data.enhance_config.memory_heal_fraction.value=.046
   notify_configuration_changed()
   updated=is_equal_approx(float(memory_effect({"key":"armour","level":1}).p2),.046)
  elif mode=="unlock":
   profile.grantedUnlocks=[];profile.cleared=[];profile.highestLevel=1
   event.emit("unlocks_changed",{})
   updated=enhancement_effects({"key":"armour","level":1}).is_empty()
  elif mode=="branch":
   profile.enhancementLevel=50;invalidate_stat_cache()
   set_enhancement_branch("weapons","critical",1,"B")
   updated=enhancement_branch_active({"key":"missile","level":1},"critical",1,"B")
  elif mode=="reforge":
   profile.cleared=range(1,101);rebuild_unlocks()
   profile.planets["1"].degree=300;planet_buildings.sync(self,"1")
   profile.planets["1"].buildings.shipyard.status="built"
   var ok:=reforge_planet("1")
   shared_enhancement_effect_count()
   updated=ok and enhancement_plan.level==enhancement_effective_level()
  elif mode=="load":
   var raw:=profile.duplicate(true);raw.enhancementLevel=1
   load_progress_data(raw)
   updated=shared_enhancement_effect_count()==(1 if enhancement_unlocked() else 0)
  # Exercise real body early returns without adding cleanup to any branch.
  super._tick_synchronized(dt)
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture() -> ProbeGame:
 var g:=ProbeGame.new(ShipDatabase.new(),false)
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 g.profile.enhancementLevel=9;g.profile.jewelFragments=1e300
 g.reset_player()
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g:=fixture();var guards: int=g.enhancement_plan.guard_checks
 g.tick(0)
 check(g._enhancement_read_scope_depth==0 and g.guard_delta==0,"owned reads skip full guard and early return exits scope")
 check(g.enhancement_plan.guard_checks==guards+1,"one complete guard on ordinary tick entry")
 guards=g.enhancement_plan.guard_checks;g.shared_enhancement_effect_count()
 check(g.enhancement_plan.guard_checks==guards+1,"outside public query fully guarded")
 g.mode="nested";g.depths=[];g.tick(0)
 check(g.depths==[1,2,1] and g._enhancement_read_scope_depth==0,"nested ticks restore outer depth then exit")
 g.paused=true;g.tick(1)
 check(g._enhancement_read_scope_depth==0,"paused tick leaves no scope")
 for mode in ["upgrade","order","config","unlock","load","branch","reforge"]:
  g=fixture();g.mode=mode;g.tick(0)
  check(g.updated and g._enhancement_read_scope_depth==0,"same tick immediate invalidation "+mode)
 g=fixture();g.tick(0);g.profile.enhancementLevel=20
 check(g.shared_enhancement_effect_count()==3,"outside scalar edit seen before next tick")
 g.db.data.enhance_config=g.db.data.enhance_config.duplicate(true)
 g.db.data.enhance_config.threshold_3.value=999
 check(g.shared_enhancement_effect_count()==2,"outside config replacement seen before next tick")
 for state in [BattleGame.State.MAIN_MENU,BattleGame.State.LEVEL_SELECT,BattleGame.State.LEVEL_CLEAR,BattleGame.State.RETREAT,BattleGame.State.UPGRADE]:
  g=fixture();g.state=state;g.tick(0)
  check(g._enhancement_read_scope_depth==0,"state return exits scope "+str(state))
 g=fixture();g.tick(0)
 await process_frame
 check(g._enhancement_read_scope_depth==0,"later asynchronous UI frame sees no owned scope")
 print("ENHANCEMENT SCOPE: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
