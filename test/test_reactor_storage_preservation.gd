extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Growth=preload("res://scripts/reactor_allocation_growth.gd")
const Preview=preload("res://scripts/reactor_upgrade_preview.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func fixture(db,level:int,idle:bool)->BattleGame:
 var g=BattleGame.new(db,false);g.save_enabled=false;g.profile.highestLevel=40;g.profile.cleared=range(1,40);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.reactorLevel=30
 var rng:=RandomNumberGenerator.new();rng.seed=815
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"storage-preservation","blue","laser",6,"1")
 d.affixes=[];d.hanging_slots=1;d.hangings=["extra_storage"]
 assert(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config))
 g.profile.hyperspace.inventory.equipped=[d.id];g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.hanging_modules.extra_storage.unlocked=true;g.profile.hyperspace.hanging_modules.extra_storage.level=level;g.invalidate_stat_cache()
 var c:int=g.reactor_capacity();var share:int=c/4 if idle else c/2
 g.profile.reactorAllocation={"weapons":share,"defence":share,"smelting":share if idle else c-2*share,"condensation":0};g.invalidate_stat_cache()
 return g
func run()->void:
 var db=ShipDatabase.new()
 for level in [0,1,2]:
  for idle in [false,true]:
   var g=fixture(db,level,idle);var saved:Dictionary=g.profile.duplicate(true);var c:int=g.reactor_capacity()
   var parsed:Dictionary=JSON.parse_string(JSON.stringify(saved))
   var restored=BattleGame.new(db,false);restored.load_progress_data(parsed)
   check(restored.reactor_capacity()==c and restored.profile.reactorAllocation==saved.reactorAllocation,"Full JSON load restores storageLv%d before allocation, idle%s"%[level,idle])
   restored.stat("laser");restored.load_progress_data(parsed)
   check(restored.reactor_capacity()==c and restored.profile.reactorAllocation==saved.reactorAllocation,"Warm-cache repeated load preserves storageLv%d distribution, idle%s"%[level,idle])
   var transfer=Transfer.new();var prepared:Dictionary=transfer.prepare_data(parsed,db)
   check(prepared.error.is_empty(),"SaveTransfer accepts complete storageLv%d save, idle%s"%[level,idle])
   if prepared.error.is_empty():
    var imported=BattleGame.new(db,false);imported.load_progress_data(prepared.data)
    check(imported.reactor_capacity()==c and imported.profile.reactorAllocation==saved.reactorAllocation,"SaveTransfer load retains storageLv%d and idle share%s"%[level,idle])
 var g=fixture(db,2,false);var preset:Dictionary=g.profile.reactorAllocation.duplicate();var original_capacity:int=g.reactor_capacity();var id:String=g.profile.hyperspace.inventory.equipped[0]
 g.stat("laser");g.drone_combat.disabled.append(id);g.invalidate_stat_cache()
 var active:Dictionary=g.reactor_active_allocation();var current_capacity:int=g.reactor_capacity();var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 check(current_capacity<original_capacity and g.reactor_allocated()==current_capacity,"Actual disabled storage reduces supply while effective total stays within capacity")
 check(g.profile.reactorAllocation==preset and int(active.weapons)<int(preset.weapons),"Read-only integer projection preserves the original overallocated plan")
 var error:=absf(float(active.weapons)-float(preset.weapons)*current_capacity/original_capacity)
 check(error<1.0 and is_equal_approx(g.reactor_effective_ratio("weapons"),float(active.weapons)/current_capacity+g.charge_free_ratio()),"Actual integer share and effective ratio follow proportional supply")
 var expected_multiplier:=1+pow(float(active.weapons)+current_capacity*g.charge_free_ratio(),float(db.config.reactorBoostExponent))/float(db.config.reactorPercentScale)
 check(is_equal_approx(g.reactor_multiplier("weapons"),expected_multiplier),"Actual multiplier uses effective allocation instead of overpowered stored energy")
 var quote:Dictionary=Preview.quote(g,1)
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Core reads and upgrade quote do not change saved plan or RNG")
 g.hyperspace.publish(g,g.profile.hyperspace.duplicate(true),"claimed")
 check(g.profile.reactorAllocation==preset,"Claim publication during temporary disable does not truncate the preserved plan")
 g.drone_combat.restore_disabled(g,"fixture")
 check(g.reactor_capacity()==original_capacity and g.reactor_active_allocation()==preset and g.profile.reactorAllocation==preset,"Actual restoration recovers full supply and original allocation without intervention")
 g.drone_combat.disabled.append(id);g.invalidate_stat_cache();active=g.reactor_active_allocation();g.profile.resources["2"]=0
 check(not g.upgrade_reactor(1) and g.profile.reactorAllocation==preset,"Rejected purchase cannot overwrite the saved plan")
 g.profile.resources["2"]=quote.cost
 check(g.upgrade_reactor(1) and g.profile.reactorAllocation==quote.allocation and g.reactor_capacity()==quote.next_capacity,"Successful purchase commits the effective baseline exactly as previewed")
 check(is_equal_approx(g.reactor_multiplier("weapons"),quote.effects.weapons.next) and GrowthNumber.compare(g.profile.resources["2"],0)==0,"Purchase effects and payment match the same quote")
 g=fixture(db,2,false);id=g.profile.hyperspace.inventory.equipped[0];g.drone_combat.disabled.append(id);g.invalidate_stat_cache();active=g.reactor_active_allocation()
 var target:int=maxi(0,int(active.weapons)-50);active.weapons=target
 check(g.set_reactor_allocation("weapons",target) and g.profile.reactorAllocation==active,"Explicit edit adopts effective shares and changes only the chosen module")
 g.drone_combat.restore_disabled(g,"fixture")
 check(g.profile.reactorAllocation==active,"Restoration preserves the explicitly replaced plan")
 g=fixture(db,2,false);id=g.profile.hyperspace.inventory.equipped[0];g.drone_combat.disabled.append(id);g.invalidate_stat_cache()
 check(g.equalize_reactor_allocation() and g.reactor_allocated()==g.reactor_capacity(),"Explicit equalize adopts a valid current-capacity plan")
 var limit:int=9223372036854774784;var large:Dictionary={"weapons":limit/2,"defence":limit-limit/2,"smelting":0,"condensation":0}
 var scaled:Dictionary=Growth.available(["weapons","defence","smelting","condensation"],large,limit-1000)
 check(int(scaled.weapons)+int(scaled.defence)==limit-1000 and int(scaled.smelting)==0 and large.weapons==limit/2,"Large integer projection preserves total and input without float multiplication")
 print("REACTOR STORAGE PRESERVATION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
