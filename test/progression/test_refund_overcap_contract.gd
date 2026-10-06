extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Scheduler=preload("res://scripts/hyperspace_scheduler.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
var records:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func actual(path:String):
 var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.load_hyperspace_routes();g.load_progress_data(raw.save);g.resume_progress();g.rng.state=int(str(raw.rng_state))
 return g
func fail_receipt(g,a:Dictionary,label:String):
 var before:float=g.profile.hyperspace.energy;var cap:float=g.hyperspace.online_config(g).energy_cap
 var bag:Dictionary=g.profile.hyperspace.inventory.duplicate(true);var materials:Dictionary=g.profile.hyperspace.materials.duplicate(true)
 var resources:Dictionary=g.profile.resources.duplicate(true);var global_rng:String=str(g.rng.state);var reward_rng:String=str(g.profile.hyperspace.random_state)
 check(g.hyperspace.complete(g,int(a.round_id),int(a.run_id),false),label+": first failure settles")
 check(is_equal_approx(g.profile.hyperspace.energy,before+float(a.ticket)),label+": full paid ticket refund may exceed effective capacity")
 check(g.profile.hyperspace.inventory==bag and g.profile.hyperspace.materials==materials and g.profile.resources==resources and str(g.rng.state)==global_rng and str(g.profile.hyperspace.random_state)==reward_rng,label+": other paid growth, balances and RNG preserved")
 var energy:float=g.profile.hyperspace.energy
 check(not g.hyperspace.complete(g,int(a.round_id),int(a.run_id),false) and g.profile.hyperspace.energy==energy,label+": duplicate cannot credit again")
 records.append({"case":label,"before":before,"ticket":a.ticket,"cap":cap,"after":energy,"actual_credit":energy-before})
func run():
 var dir:String=OS.get_environment("QA_REFUND_SOURCE")
 var started:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"/early-real7-alpha_actual_charged_and_started-business.json"))
 var ended:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"/early-real7-alpha_natural_result_before_claim-business.json"))
 var g=actual(dir+"/early-real7-alpha_actual_charged_and_started-business.json")
 # Directed transaction replay from the real receipt and observed recharge; no rerun or invented combat result.
 g.profile.hyperspace=started.save.hyperspace.duplicate(true)
 g.profile.hyperspace.energy=float(ended.save.hyperspace.energy)-float(g.profile.hyperspace.active.ticket)
 var a:Dictionary=g.profile.hyperspace.active.duplicate(true)
 fail_receipt(g,a,"Actual stage7 failed receipt with1832.5 recharge")
 Scheduler.charge(g.profile.hyperspace,g.hyperspace.online_config(g),4.0)
 check(is_equal_approx(g.profile.hyperspace.energy,float(ended.save.hyperspace.energy)),"Over-cap actual refund remains unchanged after four furtherX1")
 # Isolated legal transaction boundaries below; never claimed as natural campaign growth.
 g.profile.hyperspace.energy=150000.0;a=g.hyperspace.start(g,"alpha",5,"manual")
 check(not a.is_empty(),"Partial energy legal start")
 Scheduler.charge(g.profile.hyperspace,g.hyperspace.online_config(g),4.0)
 fail_receipt(g,a,"Partial energy retains40 recharge plus refund")
 check(is_equal_approx(g.profile.hyperspace.energy,150040.0),"Refund preserves actual recharge when headroom exists")
 var owned=actual(OS.get_environment("QA_DRONE_SOURCE"));owned.stat_cache_enabled=true
 if not owned.profile.hyperspace.active.is_empty():
  var existing:Dictionary=owned.profile.hyperspace.active.duplicate(true)
  check(existing.mode=="auto" and existing.status=="started","Actual owned-drone source has a real in-flight auto receipt")
  check(owned.hyperspace.set_auto(owned,false,"",0,""),"Pause future recurrence through actual API, preserve current receipt")
  owned.hyperspace.advance(owned,maxf(0.0,float(existing.duration)-float(existing.work))+1.0/60.0)
  check(owned.profile.hyperspace.active.is_empty(),"Naturally settle existing earned source receipt before isolated boosted-cap fixture")
 owned.profile.hyperspace.hanging_modules.hyperspace_charge={"unlocked":true,"level":2,"exp":0.0}
 check(owned.hyperspace.attach_hangings(owned,"space:1:6",["hyperspace_charge"]),"Declared unlocked level2 fixture uses real owned hanging slot and API")
 check(owned.hyperspace.set_equipped(owned,["space:1:6"]),"Owned legal fixture equipped through API")
 var boost:float=owned.hyperspace.online_config(owned).energy_cap
 check(boost>float(owned.hyperspace.config.energy_cap),"Effective capacity comes from actual equipped hanging projection")
 owned.profile.hyperspace.energy=boost;a=owned.hyperspace.start(owned,"alpha",5,"manual")
 check(not a.is_empty(),"Boosted capacity fixture legally starts actual paid receipt")
 if a.is_empty():quit(2);return
 Scheduler.charge(owned.profile.hyperspace,owned.hyperspace.online_config(owned),183.25)
 fail_receipt(owned,a,"Actual API capacity bonus")
 check(is_equal_approx(owned.profile.hyperspace.energy,boost+float(owned.hyperspace.online_config(owned).energy_rate)*183.25),"Effective boosted-cap refund preserves all actual natural recharge")
 var new_round:Dictionary=owned.hyperspace.reforge_state(owned,["space:1:6"],{})
 check(not new_round.is_empty(),"Real reforge namespace reset accepts owned retained drone")
 owned.profile.hyperspace=new_round;owned.invalidate_stat_cache()
 check(owned.hyperspace.online_config(owned).energy_cap==owned.hyperspace.config.energy_cap,"Sealed retained layout has no unreunlocked capacity bonus")
 check(not owned.hyperspace.complete(owned,int(a.round_id),int(a.run_id),false),"Old-round failure cannot credit new reforge namespace")
 # Fill with formally generated valid drones, not fake IDs, to test failure independent of storage capacity.
 var rng=RandomNumberGenerator.new();rng.seed=41
 var capacity:int=Bag.capacity(g.profile.hyperspace.inventory,g.hyperspace.config)+int(g.hyperspace.config.overflow_capacity)
 for i in capacity:
  var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"cap:%d"%i,"white","laser",5,"1")
  Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 check(not Bag.has_space(g.profile.hyperspace.inventory,g.hyperspace.config),"Declared full warehouse/overflow fixture is genuinely full")
 g.profile.hyperspace.energy=216000.0;a=g.hyperspace.start(g,"alpha",5,"manual")
 Scheduler.charge(g.profile.hyperspace,g.hyperspace.online_config(g),183.25)
 fail_receipt(g,a,"Full warehouse failure leaves all owned drones")
 # Formal loader refunds the full ticket once; no offline time credited.
 var saved:Dictionary=started.save.duplicate(true);saved.hyperspace.energy=float(ended.save.hyperspace.energy)-108000.0
 var loaded=Game.new(ShipDatabase.new());loaded.save_enabled=false;loaded.load_hyperspace_routes();loaded.load_progress_data(saved);loaded.resume_progress()
 check(loaded.profile.hyperspace.active.is_empty() and loaded.profile.hyperspace.energy==float(ended.save.hyperspace.energy),"Formal read of actual started receipt preserves over-cap refund")
 loaded.load_progress_data(saved);loaded.resume_progress()
 check(loaded.profile.hyperspace.energy==float(ended.save.hyperspace.energy),"Repeated same formal read cannot compound energy")
 g.profile.hyperspace.energy=217832.5;Scheduler.charge(g.profile.hyperspace,g.hyperspace.online_config(g),4.0)
 check(g.profile.hyperspace.energy==217832.5,"Online charge preserves actual owned overflow and stops further natural accumulation")
 var f=FileAccess.open(OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")+"/refund-ledger.json",FileAccess.WRITE);f.store_string(JSON.stringify(records,"  "));f.close()
 print("REFUND_OVERCAP_CONTRACT ",checks," checks ",failures," failures");quit(2 if failures else 0)
