extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture() -> BattleGame:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks()
 g.profile.enhancementLevel=50
 g.profile.loadout={"weapons":[{"key":"missile","level":150}],"defence":[{"key":"armour","level":150}]}
 g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 return g
func reference(g,entry: Dictionary) -> Array:
 var result: Array=[]
 if not g.enhancement_unlocked() or str(entry.get("key","")) not in g.EQUIPMENT:return result
 var count:=0;var level: int=g.enhancement_effective_level()
 for i in 3:
  if level>=g.enhancement_effect_threshold(i):count+=1
 var category: String="weapons" if str(entry.key) in g.WEAPON_KEYS else "defence"
 for i in count:result.append(g._enhancement_effect(str(g.profile.enhancementOrder[category][i]),i,level))
 return result
func matches(g) -> bool:
 for category in ["weapons","defence"]:
  for entry in g.loadout_entries(category):
   if g.enhancement_effects(entry)!=reference(g,entry):return false
 return true
func _initialize() -> void:
 var g:=fixture();check(matches(g),"recipes equal uncached authored formula")
 var initial: int=g.enhancement_plan.builds
 for i in 120:
  g.enhancement_effects(g.slot_entry("weapons",0));g.memory_effect(g.slot_entry("defence",0))
  g.enhancement_branches.reconcile(g)
 check(g.enhancement_plan.builds==initial and g.enhancement_branches.reconciliations==1,"steady qualification and reconcile compile once")
 var recipe: Array=g.enhancement_recipe(g.slot_entry("weapons",0))
 check(recipe.is_read_only() and recipe[0].is_read_only(),"shared templates immutable")
 var mutable: Array=g.enhancement_effects(g.slot_entry("weapons",0));mutable[0].source=123;mutable.append({})
 check(not recipe[0].has("source") and recipe.size()==3,"public attack payload is deep independent copy")
 g.profile.jewelFragments=1e300
 check(g.upgrade_enhancement(1)==1 and matches(g) and g.enhancement_plan.level==51,"upgrade updates before buffer reads")
 check(g.set_enhancement_branch("weapons","critical",1,"B") and g.enhancement_branch_active(g.slot_entry("weapons",0),"critical",1,"B"),"branch selection immediate")
 var data: Dictionary=g.enhancement_branches.weapon(g,0);data.next=2
 g.set_enhancement_branch("weapons","critical",1,"A")
 check(data.next==0,"removed branch clears only its transient next state")
 g.set_enhancement_order("weapons",["critical","repeat","proficiency"])
 check(matches(g) and g._enhancement_effect_index(g.slot_entry("weapons",0),"critical")==0,"order changes ownership before dependent reads")
 var previous: int=g.enhancement_plan.builds
 g.record_enhancement_attack();g.record_enhancement_hit();g.enhancement_effects(g.slot_entry("weapons",0))
 check(g.enhancement_plan.builds==previous,"counter changes do not rebuild static recipe")
 var entry: Dictionary=g.slot_entry("defence",0);var before=g.jewel_equipment_stat(entry)
 for i in 50:g.record_enhancement_hit()
 check(N.compare(g.jewel_equipment_stat(entry),before)>0,"adaptation value still follows live hit counter")
 g.db.data.enhance_config.adaptation_growth.value=.123
 g.notify_configuration_changed()
 check(matches(g) and is_equal_approx(float(g.memory_effect(entry).p2),g.enhancement_parameter("memory_heal_fraction")),"explicit in-place config invalidation uses new recipe")
 var configuration: Dictionary=g.db.data.enhance_config.duplicate(true);configuration.memory_heal_fraction.value=.042;g.db.data.enhance_config=configuration
 check(matches(g) and is_equal_approx(float(g.memory_effect(entry).p2),.042),"table replacement invalidates without notification")
 var old_builds: int=g.enhancement_plan.builds
 g.invalidate_stat_cache();g.enhancement_recipe(entry)
 check(g.enhancement_plan.builds==old_builds,"unrelated stat invalidation retains identical qualification")
 g.profile.grantedUnlocks=[];g.profile.cleared=[];g.profile.highestLevel=1
 check(g.enhancement_effects(entry).is_empty(),"unlock removal immediate")
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 check(matches(g) and not g.enhancement_effects(entry).is_empty(),"unlock restoration immediate")
 var old_revision: int=g.enhancement_plan.revision
 g.profile.loadout.defence[0]={"key":"shield","level":150};g.invalidate_stat_cache();g.enhancement_branches.reconcile(g)
 check(g.enhancement_plan.revision==old_revision and is_same(g.enhancement_branches.defense(g,0).entry,g.slot_entry("defence",0)),"refit identity reconciles without recompile")
 var saved:=g.profile.duplicate(true);saved.enhancementLevel=1;saved.enhancementOrder.defence=["delayed_damage","adaptation","memory_material"]
 g.load_progress_data(saved)
 check(matches(g) and g.enhancement_plan.level==g.enhancement_effective_level(),"load returns final canonical qualification")
 g=fixture();g.set_enhancement_branch("weapons","proficiency",1,"B")
 g.begin_enhancement_attack(0,g.enemies[0]);g.finish_enhancement_attack(0)
 g.enhancement_branches.advance_weapons(g,.4);var dwell: float=g.enhancement_branches.weapon(g,0).dwell
 g.enhancement_branches.reconcile(g)
 check(is_equal_approx(g.enhancement_branches.weapon(g,0).dwell,dwell),"steady reconcile retains live dwell")
 g.set_enhancement_branch("defence","adaptation",2,"B");g.enhancement_branches.advance_defense(g,.3)
 var elapsed: float=g.enhancement_branches.defense(g,0).cover_elapsed
 g.enhancement_branches.reconcile(g)
 check(is_equal_approx(g.enhancement_branches.defense(g,0).cover_elapsed,elapsed),"steady reconcile retains live cover timer")
 g=fixture();g.profile.cleared=range(1,101);g.rebuild_unlocks()
 g.profile.planets["1"].degree=300;g.planet_buildings.sync(g,"1")
 g.profile.planets["1"].buildings.shipyard.status="built"
 check(g.reforge_planet("1"),"actual authorized reforge succeeds")
 check(matches(g) and g.enhancement_plan.level==g.enhancement_effective_level() and g.enhancement_level_bonus()==2,"reforge reset and permanent conquest level bonus compile canonically")
 print("ENHANCEMENT PLAN: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
