extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class BonusGame extends BattleGame:
 var bonus:=0
 func gem_drop_level_bonus() -> int:return bonus
var checks:=0
var failures:=0
var evidence: Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(unlocked:=false,level:=0):
 var db:=ShipDatabase.new()
 db.equipment.shield[0].para2=0 # Isolate Memory from ordinary shield repair.
 var g=BonusGame.new(db,false);g.speed=1;g.rng.seed=1701
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")] if unlocked else []
 g.profile.cleared=[];g.profile.highestLevel=1
 g.profile.enhancementLevel=level;g.profile.enhancementAttacks=1000;g.profile.enhancementHits=1000
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"shield","level":1},{"key":"armour","level":1}]}
 g.profile.enhancementOrder.defence=["memory_material","adaptation","delayed_damage"]
 g.reset_player();g.stat_cache_enabled=true
 return g
func _initialize():call_deferred("run")
func run():
 var g=fixture(false,50);g.bonus=50
 var w=g.slot_entry("weapons",0);var d=g.slot_entry("defence",0)
 evidence.append({"case":"locked high level","purchased":g.enhancement_level(),"effective":g.enhancement_effective_level(),"critical":g.jewel_critical(w).x,"repeat":g.enhancement_branches.repeat_probability(g,w),"memory_description":g.enhancement_effect_runtime("memory_material",d)})
 check(not g.enhancement_unlocked() and g.enhancement_effects(w).is_empty() and g.memory_effect(d).is_empty(),"Locked high level and permanent bonus do not enable effects")
 check(g.jewel_critical(w).x==float(g.db.equip("laser",1).get("cri",0)),"Locked enhancement critical probability does not enter attacks")
 check(g.enhancement_branches.repeat_probability(g,w)==0 and g.enhancement_deferred_fraction()==0,"Locked trigger and deferral consumers are neutral")
 check(g.enhancement_effect_runtime("memory_material",d).capacity_percent==0,"Locked runtime description shows no active capacity")
 for kind in ["proficiency","adaptation"]:check(g.enhancement_effect_runtime(kind,w if kind=="proficiency" else d).growth==0,"Locked history description has neutral growth")
 check(g.enhancement_effect_runtime("repeat",w).damage_percent==0 and g.enhancement_effect_runtime("repeat",w).probability_percent==0,"Locked repeat description is neutral")
 check(g.enhancement_effect_runtime("delayed_damage",d).fraction_percent==0 and g.enhancement_effect_runtime("delayed_damage",d).probability_percent==0,"Locked deferral description is neutral")
 for category in ["weapons","defence"]:
  for effect in g.default_enhancement_order()[category]:
   for node in [1,2,3]:
    g.profile.enhancementBranches[category][effect][str(node)]="B"
    check(not g.enhancement_branch_unlocked(category,effect,node),"Locked saved branch stays dormant")
 var base=fixture(false,0)
 check(g.stat("shield")==base.stat("shield") and g.stat("laser")==base.stat("laser"),"Locked stats match no-enhancement baseline")
 check(g.player_weapon_row(w).cd==g.db.equip("laser",1).cd,"Locked attack cooldown unchanged")
 g.player.shield=N.multiply(g.player.shield,.5);var hp=g.player.shield
 g.advance_jewel_repair(.2)
 check(g.enhancement_protection_current()==0 and g.player.shield==hp,"Locked memory produces no pool or healing")
 g.db.data.enhance_config.base_critical_rate.value=1
 g.db.data.enhance_config.repeat_probability.value=1
 var attack=g.jewel_attack(0)
 check(not attack.critical and attack.effects.is_empty() and attack.damage==g.jewel_equipment_stat(w),"Locked actual attack ignores forced enhancement triggers")
 check(g.plan_attack_repeats(w,[]).is_empty(),"Locked attack produces no repeats")
 g.db.equipment.laser[0].cri=.15
 check(is_equal_approx(g.jewel_critical(w).x,.15),"Equipment-authored critical probability survives enhancement gate")
 for level in [0,1,9,10,19,20]:
  g=fixture(true,level)
  var expected:=0 if level==0 else 1 if level<10 else 2 if level<20 else 3
  for key in ["laser","shield"]:
   for equip_level in [1,150]:check(g.available_effect_count({"key":key,"level":equip_level})==expected,"Shared gate independent of equipment level")
  for rank in 3:
   var effect:String=g.profile.enhancementOrder.weapons[rank]
   for node in [1,2,3]:check(g.enhancement_branch_threshold(node,"weapons",effect)==10*(rank+node),"Branch position boundaries remain 10/20/30 through 30/40/50")
 g=fixture(true,0)
 check(g.set_enhancement_order("weapons",["critical","repeat","proficiency"]),"Dormant positions can be reordered")
 check(g.jewel_critical(g.slot_entry("weapons",0)).x==0,"Unlocked purchased zero has no enhancement critical")
 g.profile.enhancementLevel=1;g.invalidate_stat_cache()
 check(g.jewel_critical(g.slot_entry("weapons",0)).x==g.enhancement_parameter("base_critical_rate"),"First purchased level enables reordered first critical effect")
 g.bonus=19
 check(g.enhancement_effective_level()==20 and g.available_effect_count(g.slot_entry("weapons",0))==3,"Permanent bonus retains effective shared level semantics")
 g.stat("shield");g.stat("laser") # Populate cache while unlocked.
 g.profile.grantedUnlocks=[];g.rebuild_unlocks();g.sync_enhancement_buffers()
 check(g.available_effect_count(g.slot_entry("weapons",0))==0 and g.enhancement_protection_current()==0,"Permanent bonus cannot bypass relocked system")
 var cached_shield=g.stat("shield");var cached_laser=g.stat("laser")
 g.stat_cache_enabled=false
 check(cached_shield==g.stat("shield") and cached_laser==g.stat("laser"),"Unlock rebuild clears previously boosted stat caches")
 g=fixture(true,50)
 for category in ["weapons","defence"]:
  for rank in 3:
   var effect:String=g.profile.enhancementOrder[category][rank]
   for node in [1,2,3]:
    var threshold:int=10*(rank+node)
    g.profile.enhancementLevel=threshold-1
    check(not g.enhancement_branch_unlocked(category,effect,node),"Branch closed before original boundary")
    g.profile.enhancementLevel=threshold
    check(g.enhancement_branch_unlocked(category,effect,node),"Branch opens exactly at original boundary")
 for raw in [{},{"enhancementVersion":1},{"enhancementVersion":1,"enhancementLevel":37,"jewelFragments":123},{"enhancementLevel":37,"jewelFragments":123}]:
  g=fixture();g.load_jewels(raw)
  check(g.enhancement_level()==int(raw.get("enhancementLevel",0)) and N.compare(g.profile.jewelFragments,raw.get("jewelFragments",0))==0,"Migration defaults only missing fields and preserves existing purchase/resources")
 check(BonusGame.new(ShipDatabase.new(),false).enhancement_level()==0,"New profile starts at zero")
 FileAccess.open("res://enhancement-gate-results.json",FileAccess.WRITE).store_string(JSON.stringify(evidence))
 print("ENHANCEMENT UNLOCK GATE: ",checks," checks, ",failures," failures; speed1")
 quit(1 if failures else 0)
