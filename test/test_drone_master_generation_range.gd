extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const CC=preload("res://scripts/combat_context.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var db:=ShipDatabase.new();var g:=BattleGame.new(db,false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks()
 var c:Dictionary=g.hyperspace.config
 check(C.valid(c),"candidate config valid")
 var old:Dictionary=c.duplicate(true);old.legendary_effects.drone_master.parameters.maximum_reduction=[0.8,0.9];old.legendary_effects.drone_master.erase("stored_parameter_ranges")
 var found:=0;var other_same:=true;var states_same:=true;var master_delta:=true
 for seed_value in 1000:
  var a:=RandomNumberGenerator.new();a.seed=seed_value
  var b:=RandomNumberGenerator.new();b.seed=seed_value
  var before:=Rewards.create_drone(a,old,"fixture","legendary","laser",30,"1")
  var after:=Rewards.create_drone(b,c,"fixture","legendary","laser",30,"1")
  states_same=states_same and a.state==b.state
  if before.legendary_effect.effect_id=="drone_master":
   found+=1
   master_delta=master_delta and is_equal_approx(float(before.legendary_effect.parameters.maximum_reduction)-float(after.legendary_effect.parameters.maximum_reduction),0.3)
   before.legendary_effect.parameters.maximum_reduction=after.legendary_effect.parameters.maximum_reduction
  other_same=other_same and before==after
 check(found>0,"paired fixed streams actually generated masters")
 check(states_same,"identical reward RNG consumption and saved forge stream")
 check(other_same,"all nonmaster values and outcomes identical")
 check(master_delta,"only generated master reduction shifts by0.3")
 var rng:=RandomNumberGenerator.new();rng.seed=123
 var d:=Rewards.create_drone(rng,c,"saved-master","legendary","laser",30,"1")
 d.legendary_effect={"effect_id":"drone_master","parameters":{"maximum_reduction":0.889}};d.affixes=[]
 d.ultimate=true;d.ultimate_affix=Rewards.affix(rng,c,"laser")
 check(Bag.valid_drone(d,c),"saved0.889 accepted without clamping")
 var invalid:=d.duplicate(true);invalid.legendary_effect.parameters.maximum_reduction=0.7
 check(not Bag.valid_drone(invalid,c),"gap between generation and historical intervals remains invalid")
 invalid.legendary_effect.parameters.maximum_reduction=0.901
 check(not Bag.valid_drone(invalid,c),"above historical interval rejected")
 Bag.insert(g.profile.hyperspace.inventory,d,c);g.hyperspace.set_equipped(g,[d.id]);g.state=g.State.COMBAT
 var damage:float=float(g.drone_combat.incoming(g,100.0,CC.root(0,"enemy","laser")).damage)
 check(is_equal_approx(damage,11.1),"savedmaster with activeultimate keeps this incoming step x0.111")
 var raw:Dictionary=g.portable_save_data();var prepared:=Transfer.new().prepare_data(raw,db)
 check(prepared.error=="" and prepared.data.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.889,"production save validation keeps old parameter")
 var loaded:=BattleGame.new(db,false);loaded.load_progress_data(prepared.data)
 check(loaded.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.889,"formal reload retains exact old value")
 print("Master generation range: %d checks, %d failures; %d paired masters"%[checks,failures,found]);quit(1 if failures else 0)
