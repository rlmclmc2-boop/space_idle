extends SceneTree
# Narrow reload projection check; explicit fixture, no player save or play verdict.
const EquipmentDisplay=preload("res://scripts/equipment_display.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func values(g)->Array:
 var out:Array=[]
 for category in ["weapons","defence"]:
  for entry in g.loadout_entries(category):out.append(EquipmentDisplay.snapshot(g,entry))
 return out
func _initialize()->void:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 g.stat_cache_enabled=true
 g.profile.cleared=range(1,11);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.reactorLevel=24
 for key in g.reactor_modules():g.profile.reactorAllocation[key]=2208
 g.profile.enhancementLevel=45;g.profile.enhancementAttacks=10000;g.profile.enhancementHits=10000
 for entry in g.module_entries("weapons"):entry.key="longLaser";entry.level=37
 for entry in g.module_entries("defence"):entry.key="armour";entry.level=40
 g.module_entry("defence",1).key="shield";g.module_entry("defence",1).level=43
 var rng:=RandomNumberGenerator.new();rng.seed=347
 var drone:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"projection-blue","blue","missile",5,"1")
 check(Bag.insert(g.profile.hyperspace.inventory,drone,g.hyperspace.config),"valid owned drone fixture")
 check(g.hyperspace.equip_drone(g,drone.id).ok,"equip through authority")
 g.profile.hightechLevels[BattleGame.ENERGY_FOCUS]=39;g.profile.hightechLevels[BattleGame.DENSE_ARMOUR]=38
 g.profile.scientists=2
 for key in [BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR]:g.profile.scientistAssignments[key]=1
 g.invalidate_stat_cache()
 values(g) # Warm caches before the real continuous completion path.
 for key in [BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR]:g.profile.techPoints[key]=g.hightech_required(key)-g.research_rate(key)
 g.advance_hightech(1)
 check(g.hightech_level(BattleGame.ENERGY_FOCUS)==40 and g.hightech_level(BattleGame.DENSE_ARMOUR)==39,"continuous completions reached parent-reported levels")
 var before:Array=values(g)
 g.invalidate_stat_cache()
 check(values(g)==before,"continuous completion cached and direct projections agree")
 var raw:Dictionary=JSON.parse_string(JSON.stringify(g.portable_save_data()))
 var loaded:=BattleGame.new(db,false);loaded.stat_cache_enabled=true
 loaded.load_progress_data(raw)
 check(values(loaded)==before,"load_progress_data initial projection agrees")
 loaded.reset_player() # Same final cache boundary as production constructor.
 check(values(loaded)==before,"production startup final reset agrees")
 check(loaded.hightech_level(BattleGame.ENERGY_FOCUS)==40 and loaded.hightech_level(BattleGame.DENSE_ARMOUR)==39,"research levels retained")
 check(loaded.profile.reactorAllocation==g.profile.reactorAllocation,"allocation retained")
 loaded.invalidate_stat_cache()
 check(values(loaded)==before,"reload warmed and direct projections agree")
 var page=preload("res://scripts/hightech_workshop.gd").new();page.game=g
 g.profile.scientists=23;g.profile.resources={"1":1e8,"2":1e8}
 var quote:Dictionary=page.generation_quote(10)
 var text:String=page.generation_quote_text(10)
 for id in quote.costs:
  check(text.contains(NumberFormat.compact(quote.costs[id])) and text.contains(NumberFormat.precise(quote.costs[id])),"batch tooltip includes short total and exact supplement")
 page.free()
 print("RESEARCH RELOAD: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
