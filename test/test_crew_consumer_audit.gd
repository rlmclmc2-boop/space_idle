extends SceneTree
## Direct consumer checks for crew levels; fixtures are not natural play evidence.
const N=preload("res://scripts/growth_number.gd")
const I=preload("res://scripts/reactor_integer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func level(g,value:int)->void:
 var item:Dictionary=g.crew.entry(g,"navigator");var before:=item.duplicate(true)
 g.capture_refit_health();item.level=value;item.exp=0;g.crew.changed(g,item,before)
func job(g,id:String,target:String)->void:
 check(g.crew.assign(g,"navigator",id,target),"Assign actual job "+id)
func run()->void:
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.save_enabled=false;g.stat_cache_enabled=true
 g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 var cfg:Dictionary=db.data.crew_config;var item:Dictionary=g.crew.entry(g,"navigator")
 for id in db.data.crew_assignment:
  var row:Dictionary=db.data.crew_assignment[id]
  check(g.crew.supported(row) and float(row.levelScale)==0,"Live assignment registered and intentionally has no cadence level growth: "+id)
 check(g.crew.levels_unlocked(g),"Live level gate open in controlled fixture")
 job(g,"equipment_upgrade","equipment");level(g,0)
 var weapon:Dictionary=g.slot_entry("weapons",0)
 var defence:Dictionary=g.slot_entry("defence",0);var defence0=g.jewel_equipment_stat(defence)
 var raw=g.equipment_stat(weapon.key,int(weapon.level));var equipped=g.jewel_equipment_stat(weapon);var total=g.stat(weapon.key)
 level(g,35);var factor:=pow(1+float(cfg.equip_bonus.value),35)
 check(is_equal_approx(N.ratio(g.jewel_equipment_stat(weapon),equipped),factor) and is_equal_approx(N.ratio(g.stat(weapon.key),total),factor),"Lv35 equipment multiplier reaches both actual equipped module and ship aggregate")
 check(N.compare(defence0,0)>0 and is_equal_approx(N.ratio(g.jewel_equipment_stat(defence),defence0),factor),"Actual equipped defence receives the same single crew multiplier")
 check(g.equipment_stat(weapon.key,int(weapon.level))==raw,"Crew multiplier applied once in final equipment projection, not twice in raw table base")
 var at35=g.jewel_equipment_stat(weapon);var needed:float=g.crew.required_exp(g,35)
 check(needed==maxf(1,roundf(float(cfg.base_exp.value)*pow(float(cfg.exp_multiplier.value),35))),"XP threshold comes from both numeric XP config rows")
 check(g.add_crew_exp("navigator",needed) and item.level==36 and item.exp==0 and is_equal_approx(N.ratio(g.jewel_equipment_stat(weapon),at35),1+float(cfg.equip_bonus.value)),"Actual XP upgrade invalidates warmed equipment cache and gives one configured compounded step")
 for job_id in ["equipment_upgrade","hightech_scientists","jewel_auto","reactor_upgrade"]:
  item.assignmentType=job_id
  level(g,0);var cadence0:float=g.crew.effect_value(g,item)
  level(g,35)
  check(g.crew.effect_value(g,item)==cadence0,"Lv35 leaves automatic operation cadence unchanged: "+job_id)
 item.assignmentType="equipment_upgrade"
 job(g,"hightech_scientists","hightech");level(g,0)
 var key:String=g.hightech_slots()[0];g.profile.scientists=23;g.profile.scientistAssignments={key:23}
 var no_crew_rate:float=g.research_rate(key);level(g,35)
 var ai:int=int(35*float(cfg.tech_ai_per_level.value));var speed:=1+35*float(cfg.tech_speed.value)
 var ordinary:int=g.assigned_scientists(key);var count:=ordinary+ai;var base:=float(db.config.techPointGet)*count
 var expected:float=(roundf(pow(base,float(db.config.hightechLimit))) if count>1 else base)*speed*(1+float(g.hyperspace_totals().hangings.get("distributed_algorithm",0)))
 check(g.dedicated_scientists(key)==ai and is_equal_approx(g.research_rate(key),expected),"Actual research combines ordinary plus dedicated AI, then multiplies rate by crew speed")
 check(g.profile.scientists==23 and g.idle_scientists()==0,"Dedicated AI adds no paid AI and is outside allocation pool")
 g.distribute_scientists();var assigned:=0;var all_dedicated:=true
 for tech in g.hightech_slots():
  assigned+=g.assigned_scientists(tech)
  if g.hightech_unlocked(tech):all_dedicated=all_dedicated and g.dedicated_scientists(tech)==ai
 check(assigned==23 and all_dedicated,"Actual equal distribution retains23 paid AI and full dedicated bonus in every unlocked project")
 print("AUDIT AI: +",ai," dedicated per project; speed x",speed,"; 23-AI same-project rate vsLv0 x",expected/no_crew_rate,"; limit=",db.config.hightechLimit)
 job(g,"jewel_auto","jewels");level(g,0);var direct0=g.settle_jewel_fragments(100,"drop",1)
 level(g,35);var direct35=g.settle_jewel_fragments(100,"drop",1);var gem_factor:=1+35*float(cfg.gem_bonus.value)
 check(is_equal_approx(N.ratio(direct35,direct0),gem_factor),"Direct fragment settlement multiplies crew35 with existing condensation and production bonuses exactly once")
 check(g.settle_jewel_fragments(100,"furnace",1)==100 and g.settle_jewel_fragments(100,"refund",1)==100,"Furnace/refund are excluded from direct-drop crew bonus")
 var fragment_balance=g.profile.jewelFragments;var enhancement_cost=g.enhancement_cost()
 level(g,36)
 check(g.profile.jewelFragments==fragment_balance and g.enhancement_cost()==enhancement_cost,"Crew level does not retroactively multiply owned fragments or lower enhancement price")
 job(g,"reactor_upgrade","reactor");level(g,0);g.profile.reactorLevel=215
 var energy0=g.reactor_energy();var capacity0=g.reactor_capacity();g.equalize_reactor_allocation();var allocated_before:Dictionary=g.profile.reactorAllocation.duplicate()
 level(g,35);var energy35=g.reactor_energy();var capacity35=g.reactor_capacity();var charge:=1+35*float(cfg.charge_bonus.value)
 check(is_equal_approx(N.ratio(energy35,energy0),charge) and is_equal_approx(I.ratio(capacity35,capacity0),charge),"Lv35 applies full multiplicative energy bonus across215 legacy integer boundary")
 check(g.profile.reactorAllocation==allocated_before,"Capacity growth does not silently multiply the existing manual integer preset")
 g.profile.resources["2"]=0;g.crew.advance(g,1)
 check(g.reactor_allocated()==g.reactor_capacity(),"Actual reactor automation distributes boosted capacity even with no purchase budget")
 var weapon_energy=g.reactor_active_allocation().get("weapons",0);var effective=N.add(I.as_growth(weapon_energy),N.multiply(I.as_growth(g.reactor_capacity()),g.charge_free_ratio()))
 var multiplier=N.add(1,N.divide(N.power(effective,float(db.config.reactorBoostExponent)),float(db.config.reactorPercentScale)))
 check(N.compare(g.reactor_multiplier("weapons"),multiplier)==0,"Actual category multiplier uses allocated plus free energy through0.8/50, not the displayed energy percent")
 level(g,36)
 check(is_equal_approx(N.ratio(g.reactor_energy(),energy35),(1+36*float(cfg.charge_bonus.value))/charge),"Single35→36 energy step compares cumulative factors, not another+1050%")
 print("AUDIT REACTOR: Lv35 vs0 x",I.ratio(capacity35,capacity0),"; 35→36 x",N.ratio(g.reactor_energy(),energy35),"; old capped ratio=",float(preload("res://scripts/reactor_growth.gd").CAPACITY_LIMIT)/float(capacity0))
 job(g,"","");level(g,35)
 var route:String=g.hyperspace.config.routes.keys()[0];g.profile.hyperspace.history={route:{"1":60.0}}
 g.profile.planets["1"].conquered=true
 var k:float=float(cfg.hyperspace_duration_k.value);var eff:float=(k+35)/k
 check(is_equal_approx(g.hyperspace.idle_duration(g,60,"navigator"),60/eff) and is_equal_approx(g.hyperspace.auto_quote(60,35,g).duration,60/eff),"Actual and quoted hyperspace duration divide best time by crew efficiency without a floor")
 check(g.hyperspace.set_auto(g,true,route,1,"navigator") and g.hyperspace.start_auto(g),"Actual configured crew route starts receipt")
 var receipt:Dictionary=g.profile.hyperspace.idle.duplicate(true);var permanent:float=float(g.planet_buffs.totals(g).get("hyperspace_luck",0))
 check(is_equal_approx(receipt.duration,60/eff) and receipt.crew_luck==35*float(cfg.hyperspace_luck_per_level.value) and receipt.luck==permanent+receipt.crew_luck,"Receipt snapshots the actual duration and additive permanent+crew luck once")
 level(g,36)
 check(g.profile.hyperspace.idle==receipt,"Current crew level changes leave an already-started receipt snapshot intact")
 print("AUDIT HYPERSPACE: duration35=",receipt.duration," vs60; crew luck=",receipt.crew_luck,"; permanent=",permanent)
 g.hyperspace.stop_idle(g,route);g.profile.hyperspace.paused=[]
 g.galaxy.refresh_unlocks(g)
 job(g,"galaxy_explore","galaxy_1");level(g,0);var workers:int=g.galaxy.crew_count(g,"galaxy_1")
 var region=g.galaxy.regions.galaxy_1;var explore_power:float=float(region.row.explore_power_base)+workers*float(region.row.explore_power_per_crew);var upgrade_power:float=float(region.row.upgrade_power_base)+workers*float(region.row.upgrade_power_per_crew)
 var saved_region:Dictionary=region.save_data()
 var low_region=preload("res://scripts/galaxy_region.gd").new();low_region.setup(region.row,region.builds,region.chunk_size,saved_region);low_region.advance(12,workers)
 level(g,35)
 check(g.galaxy.crew_count(g,"galaxy_1")==workers and g.crew.level_description(g,item).is_empty(),"Galaxy consumer intentionally counts workers, with no configured level bonus or false level description")
 var high_region=preload("res://scripts/galaxy_region.gd").new();high_region.setup(region.row,region.builds,region.chunk_size,saved_region);high_region.advance(12,g.galaxy.crew_count(g,"galaxy_1"))
 check(float(low_region.state.explore_work)>0 and low_region.save_data()==high_region.save_data(),"Actual galaxy construction/exploration state matches atLv0 and35 for the same workers")
 print("AUDIT GALAXY: ",workers," worker ->explore=",explore_power," upgrade=",upgrade_power," unchanged by crew level")
 job(g,"","");level(g,0);var duration0:float=g.planet_duration("1");var reward0:float=g.planet_exp_reward("1")
 level(g,35)
 check(g.planet_duration("1")==duration0 and g.planet_exp_reward("1")==reward0,"Planet exploration duration and XP reward use planet/stage/building rules, not explorer level")
 for effect_key in ["equip_bonus","tech_speed","gem_bonus","charge_bonus"]:
  check(g.crew.system_effect(g,effect_key)==1,"Idle crew contributes baseline, not a leaked multiplier: "+effect_key)
 check(g.dedicated_scientists(key)==0,"Idle crew supplies no dedicated AI")
 # Passive crew XP must not destroy a temporarily over-capacity saved plan.
 var storage=BattleGame.new(db,false);storage.save_enabled=false;storage.profile.highestLevel=101;storage.profile.cleared=range(1,101);storage.rebuild_unlocks();storage.profile.reactorLevel=30
 storage.crew.assign(storage,"navigator","reactor_upgrade","reactor");storage.crew.entry(storage,"navigator").level=35
 var storage_rng:=RandomNumberGenerator.new();storage_rng.seed=815
 var drone:Dictionary=preload("res://scripts/drone_rewards.gd").create_drone(storage_rng,storage.hyperspace.config,"crew-storage","blue","laser",6,"1")
 drone.affixes=[];drone.hanging_slots=1;drone.hangings=["extra_storage"]
 assert(preload("res://scripts/drone_inventory.gd").insert(storage.profile.hyperspace.inventory,drone,storage.hyperspace.config))
 storage.profile.hyperspace.inventory.equipped=[drone.id];storage.profile.hyperspace.hanging_modules.extra_storage.unlocked=true;storage.profile.hyperspace.hanging_modules.extra_storage.level=2;storage.invalidate_stat_cache();storage.equalize_reactor_allocation()
 var preset:Dictionary=storage.profile.reactorAllocation.duplicate();var full=storage.reactor_capacity()
 storage.drone_combat.disabled.append(drone.id);storage.invalidate_stat_cache()
 check(I.compare(storage.reactor_capacity(),full)<0 and storage.profile.reactorAllocation==preset,"Actual disabled storage reduces supply while retaining full preset before crew XP")
 storage.add_crew_exp("navigator",storage.crew.required_exp(storage,35))
 check(storage.crew.entry(storage,"navigator").level==36 and storage.profile.reactorAllocation==preset,"Actual passive crew level-up during storage disable preserves original integer preset")
 storage.drone_combat.restore_disabled(storage,"fixture")
 check(storage.reactor_active_allocation()==preset and storage.profile.reactorAllocation==preset,"Actual storage restoration after crew level-up recovers the preserved plan")
 check(storage.crew.assign(storage,"navigator","","") and I.compare(storage.reactor_allocated(),storage.reactor_capacity())<=0 and storage.profile.reactorAllocation!=preset,"Explicit reactor reassignment keeps the existing permanent-capacity clamping behavior")
 print("CREW CONSUMER AUDIT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
