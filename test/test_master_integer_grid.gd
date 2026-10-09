extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const CC=preload("res://scripts/combat_context.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func request(g,id:String,maximum:bool) -> Dictionary:
 var s:Dictionary=g.profile.hyperspace
 return {"operation":"reroll_values","drone_id":id,"args":{"guaranteed_max":maximum},"round_id":s.round_id,"command_seq":s.command_seq,"expected_revision":s.inventory.drones[id].forge_revision}
func _initialize() -> void:
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear()
 var c:Dictionary=g.hyperspace.config
 check(C.valid(c) and c.value_precision==0.001 and C.parameter_precision(c,"drone_master","maximum_reduction")==0.01,"Valid source pack changes only the master's precision")
 check(C.parameter_precision(c,"higgs_cannon","damage_bonus")==0.001,"Other legendary and ordinary affix precision remains unchanged")
 var bad:Dictionary=c.duplicate(true);bad.legendary_effects.drone_master.constants.reduction_precision=0
 check(not C.valid(bad),"Zero master precision is rejected before division")
 var rng=RandomNumberGenerator.new();rng.seed=119
 var forced:Dictionary=c.duplicate(true);forced.legendary_effects={"drone_master":c.legendary_effects.drone_master}
 var seen:Dictionary={};var on_grid:=true
 for i in 256:
  var cap:float=Rewards.legendary(rng,forced,"laser").parameters.maximum_reduction
  on_grid=on_grid and cap>=0.5 and cap<=0.6 and absf(cap*100-roundf(cap*100))<0.0000001;seen[roundi(cap*100)]=true
 check(on_grid and seen.size()==11 and seen.has(50) and seen.has(60),"Real generation samples exactly the eleven integer endpoints and interior values")
 var d:Dictionary=Rewards.create_drone(rng,c,"integer-master","legendary","laser",6,"1");d.legendary_effect={"effect_id":"drone_master","parameters":{"maximum_reduction":0.55}};d.affixes=[]
 check(Bag.valid_drone(d,c) and Bag.insert(g.profile.hyperspace.inventory,d,c),"Integer master enters the real inventory")
 var invalid:Dictionary=d.duplicate(true);invalid.legendary_effect.parameters.maximum_reduction=0.553
 check(not Bag.valid_drone(invalid,c),"Hidden fractional-percentage saved master values are rejected")
 for cap in [0.49,0.61,0.89]:
  invalid.legendary_effect.parameters.maximum_reduction=cap
  check(not Bag.valid_drone(invalid,c),"Out-of-range and historical cap values cannot create additional master outcomes")
 g.profile.hyperspace.inventory.equipped=[d.id];g.invalidate_stat_cache()
 for cap in [0.5,0.55,0.6]:
  g.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction=cap;g.invalidate_stat_cache()
  var expected:=roundf(cap*0.8/0.9*100)/100
  check(is_equal_approx(g.drone_combat.master_reduction(g),expected),"Quality conversion supplies real whole-percentage reduction")
  check(is_equal_approx(float(g.drone_combat.incoming(g,100.0,CC.root(0,"enemy","laser")).damage),100*(1-expected)),"Actual incoming damage uses the integer reduction")
 g.profile.hyperspace.inventory.drones[d.id].ultimate=true;g.profile.hyperspace.inventory.drones[d.id].ultimate_affix=Rewards.affix(rng,c,"laser");g.invalidate_stat_cache()
 check(is_equal_approx(g.drone_combat.master_reduction(g),0.6),"Ultimate quality reaches the real sixty-percent maximum")
 g.profile.hyperspace.inventory.drones[d.id].ultimate=false;g.invalidate_stat_cache()
 g.drone_combat.disabled=[d.id];g.invalidate_stat_cache();check(g.drone_combat.master_reduction(g)==0,"Disabled master has no surviving reduction");g.drone_combat.disabled=[];g.invalidate_stat_cache()
 g.profile.hyperspace.materials.antiproton=1649
 var req=request(g,d.id,true);var before=JSON.stringify(g.profile);var state=g.rng.state
 var quote:Dictionary=g.hyperspace.preview_forge(g,req)
 check(quote.cost.antiproton==1650 and quote.error=="insufficient_materials" and JSON.stringify(g.profile)==before and g.rng.state==state,"Guaranteed quote uses eleven outcomes and preserves underfunded state")
 var denied:Dictionary=g.hyperspace.forge(g,req);check(denied.error=="insufficient_materials" and JSON.stringify(g.profile)==before,"Actual guarantee cannot debit1649 for a1650 fee")
 g.profile.hyperspace.materials.antiproton=1650
 quote=g.hyperspace.preview_forge(g,req);var result:Dictionary=g.hyperspace.forge(g,req)
 check(result.error.is_empty() and result.cost==quote.cost and g.profile.hyperspace.materials.antiproton==0,"Guaranteed real transaction debits exactly1650")
 check(g.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.6 and is_equal_approx(g.drone_combat.master_reduction(g),0.53),"Guarantee delivers the actual current highest reduction and maximum cap")
 g.profile.hyperspace.materials.antiproton=5000
 var ordinary_grid:=true;var ordinary_cost:=true
 for i in 30:
  req=request(g,d.id,false);result=g.hyperspace.forge(g,req)
  ordinary_cost=ordinary_cost and result.error.is_empty() and result.cost.antiproton==50
  var cap:float=g.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction
  ordinary_grid=ordinary_grid and cap>=0.5 and cap<=0.6 and absf(cap*100-roundf(cap*100))<0.0000001
 check(ordinary_grid and ordinary_cost,"Real ordinary rerolls use the identical integer grid and unchanged50 fee")
 var affix:Dictionary=Rewards.affix(rng,c,"laser");g.profile.hyperspace.inventory.drones[d.id].affixes=[affix]
 var bounds:Array=c.affixes[affix.key].ranges[str(affix.tier)];var factor:int=roundi((float(bounds[1])-float(bounds[0]))/float(c.value_precision))+1
 g.profile.hyperspace.materials.antiproton=1650*factor
 req=request(g,d.id,true);quote=g.hyperspace.preview_forge(g,req);result=g.hyperspace.forge(g,req)
 check(result.error.is_empty() and quote.cost.antiproton==1650*factor and result.cost==quote.cost and g.profile.hyperspace.materials.antiproton==0,"Other unlocked affix combinations preserve their old precision and guarantee factor")
 check(g.profile.hyperspace.inventory.drones[d.id].affixes[0].value==float(bounds[1]) and g.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.6,"Combined guarantee reaches every real maximum")
 print("Master integer grid: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
