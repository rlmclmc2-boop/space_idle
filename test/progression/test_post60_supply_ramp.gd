extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const S=preload("res://scripts/hyperspace_scheduler.gd")
const State=preload("res://scripts/hyperspace_state.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var packet:Dictionary=CP.read_one(OS.get_environment("QA_SUPPLY_CLEAR60_SOURCE"))
 check(packet.error.is_empty(),"Exact real clear60 checksum")
 if not packet.error.is_empty():quit(2);return
 var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.stat_cache_enabled=true
 check(g.load_hyperspace_routes(),"Actual route binding")
 g.load_progress_data(packet.payload.save)
 check(g.hyperspace.last_error.is_empty() and g.profile.cleared.has(60),"Real clear60 loads without counter fabrication")
 var c:Dictionary=g.hyperspace.config
 var initial:Dictionary=g.profile.hyperspace.duplicate(true)
 var online:Dictionary=g.hyperspace.online_config(g)
 check(float(online.energy_rate)==10.0 and Rewards.material_amount(online,60)==19,"Ramp starts at unchanged base; no unlock grant")
 g.hyperspace.advance(g,300.0)
 check(is_equal_approx(float(g.profile.hyperspace.energy),float(initial.energy)+24750.0),"Exact integrated first five minutes 24750 energy")
 check(float(g.profile.hyperspace.late_supply_work)==300.0,"Only actual online advance earns clock")
 online=g.hyperspace.online_config(g)
 check(float(online.energy_rate)==155.0 and Rewards.material_amount(online,60)==47,"Halfway rate155 and floor-rounded material47")
 var portable:Dictionary=g.portable_save_data()
 var exported:Dictionary=Transfer.clean(portable,Transfer.schema())
 check(float(exported.hyperspace.late_supply_work)==300.0,"Portable save schema preserves earned ramp clock")
 var restored=Game.new(ShipDatabase.new());restored.save_enabled=false;restored.stat_cache_enabled=true;restored.load_hyperspace_routes();restored.load_progress_data(exported)
 check(restored.hyperspace.last_error.is_empty() and restored.profile.hyperspace==g.profile.hyperspace,"Saved clock, resources, inventory and RNG reload exactly")
 g.paused=true;g.hyperspace.advance(g,100.0)
 check(g.profile.hyperspace==restored.profile.hyperspace,"Paused time earns no clock or supply")
 g.paused=false;g.hyperspace.advance(g,300.0)
 check(is_equal_approx(float(g.profile.hyperspace.energy),float(initial.energy)+93000.0),"Exact full ten-minute integral93000")
 online=g.hyperspace.online_config(g)
 check(float(online.energy_rate)==300.0 and Rewards.material_amount(online,60)==76,"Ten-minute cap reaches authored30/4")
 var split:Dictionary=initial.duplicate(true)
 for _i in 600:S.charge(split,online,1.0)
 check(is_equal_approx(float(split.energy),float(g.profile.hyperspace.energy)) and split.late_supply_work==g.profile.hyperspace.late_supply_work,"Split and lumped charging agree")
 var overflow:Dictionary=initial.duplicate(true);overflow.energy=217832.5
 S.charge(overflow,online,600.0)
 check(overflow.energy==217832.5 and overflow.late_supply_work==600.0,"Overcap refund retained while online clock advances")
 var wait:float=S.charge_wait(initial,online)
 var charged:Dictionary=initial.duplicate(true);S.charge(charged,online,wait)
 check(is_equal_approx(float(charged.energy),216000.0),"Exact nonlinear full-energy wait reaches cap")
 var invalid:Dictionary=g.profile.hyperspace.duplicate(true);invalid.late_supply_work=-1.0
 check(not State.valid(invalid,c,g.db.levels.size()),"Invalid saved clock rejected")
 invalid.late_supply_work=601.0
 check(not State.valid(invalid,c,g.db.levels.size()),"Saved clock above ramp cap rejected")
 check(initial.materials==g.profile.hyperspace.materials and initial.inventory==g.profile.hyperspace.inventory and initial.random_state==g.profile.hyperspace.random_state and initial.ultimate_cores==g.profile.hyperspace.ultimate_cores,"Time alone gives no materials, drones, cores or RNG draws")
 var pre:Dictionary=CP.read_one(OS.get_environment("QA_SUPPLY_PRE60_SOURCE"));check(pre.error.is_empty(),"Actual pre60 source checksum")
 var before=Game.new(ShipDatabase.new());before.save_enabled=false;before.stat_cache_enabled=true;before.load_hyperspace_routes();before.load_progress_data(pre.payload.save)
 online=before.hyperspace.online_config(before)
 check(not before.profile.cleared.has(60) and float(online.energy_rate)==10.0 and not online.has("late_supply_base_rate"),"Pre60 behavior and cache unchanged")
 FileAccess.open(OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")+"/ramp-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"full_energy_wait_seconds":wait,"source_sha256":FileAccess.get_sha256(OS.get_environment("QA_SUPPLY_CLEAR60_SOURCE")),"scope":"Actual source loads plus explicit API boundary fixtures; not native wholebody acceptance"},"\t"))
 print("POST60_RAMP ",checks," checks ",failures," failures");quit(2 if failures else 0)
