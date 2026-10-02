extends SceneTree
class Reference extends BattleGame:
 func begin_enhancement_rule_context() -> void:pass
 func end_enhancement_rule_context() -> void:pass
class Presented extends "res://scripts/presented_battle_game.gd":
 func economy_time() -> float:return 1701.0
class PresentedReference extends Presented:
 func begin_enhancement_rule_context() -> void:pass
 func end_enhancement_rule_context() -> void:pass
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func fixture(reference: bool,level: int,position: int) -> BattleGame:
 var g: BattleGame=Reference.new(ShipDatabase.new(),false) if reference else BattleGame.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,101);g.rebuild_unlocks();g.profile.enhancementLevel=level
 var order: Array=["adaptation","delayed_damage"];order.insert(position,"memory_material");g.profile.enhancementOrder.defence=order
 for category in g.profile.enhancementBranches:
  for effect in g.profile.enhancementBranches[category]:
   for node in [1,2,3]:g.profile.enhancementBranches[category][effect][str(node)]="A" if node%2==1 else "B"
 g.stat_cache_enabled=true;g.invalidate_stat_cache();g.reset_player();g.rng.seed=1701
 return g
func projection(g: BattleGame) -> Array:
 var result: Array=[g.shared_enhancement_effect_count()]
 for category in ["weapons","defence"]:
  for effect in g.default_enhancement_order()[category]:
   for node in [1,2,3]:
    result.append([g.enhancement_branch_threshold(node,category,effect),g.enhancement_branch_unlocked(category,effect,node),g.enhancement_branch_choice(category,effect,node)])
  for key in (g.WEAPON_KEYS if category=="weapons" else g.DEFENSE_KEYS):
   var entry={"key":key,"level":1}
   for effect in g.default_enhancement_order()[category]:
    result.append(g._enhancement_effect_index(entry,effect))
    for node in [1,2,3]:
     for choice in ["A","B"]:result.append(g.enhancement_branches.active(g,entry,effect,node,choice))
 return result
func _initialize() -> void:
 for level in [0,9,10,19,20,29,30,39,40,49,50,59,60]:
  for position in 3:
   var a=fixture(true,level,position);var b=fixture(false,level,position)
   b.begin_enhancement_rule_context()
   var rng_before=b.rng.state
   check(projection(a)==projection(b),"boundaries level%d order%d" % [level,position])
   check(rng_before==b.rng.state,"rules never draw RNG")
   b.end_enhancement_rule_context()
   check(b._enhancement_rule_context.is_empty() and b._enhancement_rule_scope_depth==0,"scope ends")
 var a=fixture(true,60,0);var b=fixture(false,60,0)
 b.begin_enhancement_rule_context()
 for g in [a,b]:g.profile.jewelFragments=1e40;g.upgrade_enhancement(1)
 check(projection(a)==projection(b) and b._enhancement_rule_context.is_empty(),"purchase invalidates")
 b.end_enhancement_rule_context();b.begin_enhancement_rule_context()
 for g in [a,b]:g.set_enhancement_order("defence",["adaptation","delayed_damage","memory_material"])
 check(projection(a)==projection(b) and b._enhancement_rule_context.is_empty(),"reorder invalidates")
 b.end_enhancement_rule_context();b.begin_enhancement_rule_context()
 for g in [a,b]:g.set_enhancement_branch("defence","memory_material",3,"B")
 check(projection(a)==projection(b) and b._enhancement_rule_context.is_empty(),"branch invalidates")
 b.end_enhancement_rule_context();b.begin_enhancement_rule_context()
 b.event.connect(func(kind,_payload):
  if kind!="test_mutation":return
  check(b._enhancement_rule_context.is_empty(),"first observer runs before callback")
  for g in [a,b]:
   g.profile.enhancementLevel=9
   g.db.data.enhance_config.threshold_2.value=12
  check(projection(a)==projection(b),"direct profile/config callback uses original reads")
  b.begin_enhancement_rule_context()
  check(b._enhancement_rule_context.is_empty(),"reentrant scope falls back")
  b.end_enhancement_rule_context())
 b.event.emit("test_mutation",{})
 check(projection(a)==projection(b),"outer scope remains invalid after callback")
 b.end_enhancement_rule_context()
 # Reforge replaces the authoritative profile before resetting crew schedules.
 a=fixture(true,60,0);b=fixture(false,60,0)
 for g in [a,b]:
  g.planet_buildings.sync(g,"1")
  g.profile.planets["1"].buildings.shipyard.status="built"
 b.begin_enhancement_rule_context()
 for g in [a,b]:check(g.reforge_planet("1"),"reforge allowed")
 check(projection(a)==projection(b) and b._enhancement_rule_context.is_empty(),"reforge replacement invalidates")
 b.end_enhancement_rule_context()
 test_presented_callback()
 print("TICK ENHANCEMENT RULES: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
func presented_fixture(reference: bool) -> BattleGame:
 var g: BattleGame=PresentedReference.new(ShipDatabase.new(),false) if reference else Presented.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,101);g.rebuild_unlocks();g.profile.selectedShip="Heavy_Battleship";g.profile.enhancementLevel=60
 g.profile.loadout={"weapons":[{"key":"missile","level":150},{"key":"longLaser","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 g.stat_cache_enabled=true;g.invalidate_stat_cache();g.reset_player();g.rng.seed=1701;g.start(1,false);g.spawn_group()
 g.profile.hightechSavedAt=1701.0;g.cooldowns.weapons_0=0.0
 for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100
 return g
func state(g: BattleGame) -> Dictionary:
 return {"profile":g.profile,"player":g.player,"enemies":g.enemies,"shots":g.projectiles,"repeats":g.jewel_repeats,"buffers":g.enhancement_buffers,"debts":g.enhancement_deferred,"times":g.jewel_defence_times,"rng":g.rng.state,"motion_clock":g.motion_clock,"state":g.state}
func test_presented_callback() -> void:
 var a=presented_fixture(true);var b=presented_fixture(false)
 var called := [0,0]
 for side in 2:
  var g: BattleGame=a if side==0 else b
  g.event.connect(func(kind,payload):
   if kind!="equipment_stats" or payload.category!="weapons" or called[side]>0:return
   called[side]+=1
   if side==1:check(b._enhancement_rule_context.is_empty(),"real tick callback invalidated")
   g.profile.enhancementLevel=10
   g.profile.enhancementBranches.weapons.critical["1"]="B"
   g.db.data.enhance_config.branch_threshold_1.value=11)
 for frame in 12:
  a.tick(1.0/15.0);b.tick(1.0/15.0)
  check(state(a)==state(b),"actual outer tick callback state/RNG frame%d" % frame)
 check(called==[1,1],"actual callback fired on both")
 check(b._enhancement_rule_context.is_empty() and b._enhancement_rule_scope_depth==0,"actual outer tick ends scope")
