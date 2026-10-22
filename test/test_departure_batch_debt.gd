extends SceneTree
class Host extends "res://scripts/main.gd":
 var shield_before_hit=0.0
 var demo_time=0.0
class GeometryProbe extends RefCounted:
 var fx_time=0.0
 var demo_time=0.0
 var turret_visuals={}
 var turret_ship=""
 var preparations=0
 func before_tick(dt:float)->void:preparations+=1;fx_time+=dt
 func after_tick()->void:pass
class GameProbe extends BattleGame:
 var ticks=0
 var depart_on_first=true
 func prepare_logical_step(_dt:float)->bool:return true
 func tick(_dt:float)->void:
  ticks+=1
  if ticks==1 and depart_on_first:begin_return_departure()
class PresentedProbe extends "res://scripts/presented_battle_game.gd":
 var return_request=-1
 var observe_segments=false
 var segments:Array=[]
 func advance_shared_clock_and_economy(dt:float)->void:
  if observe_segments:segments.append({"dt":dt,"manual":manual_hyperspace.active})
  super.advance_shared_clock_and_economy(dt)
 func tick_projectiles(dt:float)->void:
  super.tick_projectiles(dt)
  if return_request>=0:
   var success=bool(return_request);return_request=-1
   if success:clear_level()
   else:exit_hyperspace_challenge()
class Runtime extends "res://scripts/battle_slice_runtime.gd":
 var deny_close=false
 func close()->bool:return not deny_close
 func snapshot()->void:pass
var checks=0
var failures=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var host=Host.new();var game=GameProbe.new(ShipDatabase.new(),false);host.game=game
 var runtime=Runtime.new();runtime.scene=host;runtime.game=game;runtime.geometry=GeometryProbe.new();host.battle_slice_runtime=runtime
 game.consume_external_time(3.0/60.0+0.004,host)
 check(game.ticks==1 and runtime.logical_steps==1,"mid-batch departure stops before the next logical substep")
 check(runtime.geometry.preparations==1,"no later geometry preparation after departure")
 check(absf(game.game_time_remainder-(2.0/60.0+0.004))<1e-10,"Game retains the only unconsumed debt")
 var debt=game.game_time_remainder;game.consume_external_time(0.8,host)
 check(game.game_time_remainder==debt and game.ticks==1,"departure wall time never enters game debt")
 game.consume_external_time(0.8,host)
 check(game.departure_remaining==0 and game.game_time_remainder==debt,"Game ends the departure without a rendered animation")
 game.consume_external_time(0.0,host)
 check(game.ticks==3 and runtime.logical_steps==3 and absf(game.game_time_remainder-0.004)<1e-10,"resume consumes retained debt exactly once")
 check(not runtime.advancing,"step ownership released on every return")
 game.depart_on_first=false;game.game_time_remainder=0;runtime.detach_requested=true;runtime.deny_close=true
 var before=game.ticks;game.consume_external_time(3.0/60.0,host)
 check(game.paused and game.ticks==before+1 and is_equal_approx(game.game_time_remainder,2.0/60.0),"Failed display materialization acknowledges only the completed step and stops")
 game.consume_external_time(1.0,host)
 check(game.ticks==before+1 and is_equal_approx(game.game_time_remainder,2.0/60.0),"Blocked presentation cannot accumulate more live budget")
 runtime.deny_close=false;game.paused=false;game.consume_external_time(0.0,host)
 check(game.ticks==before+3 and is_zero_approx(game.game_time_remainder) and host.battle_slice_runtime==null,"Successful detach resumes the same Game tail without another scheduler")
 runtime.scene=null;runtime.game=null;host.battle_slice_runtime=null;host.free()
 for success in [false,true]:check_presented_return(success)
 print("DEPARTURE_BATCH_DEBT ",checks," checks ",failures," failures");quit(1 if failures else 0)

func check_presented_return(success:bool)->void:
 var db=ShipDatabase.new();db.ships.Frigate.defenseSlots=2
 var g=PresentedProbe.new(db,false);g.native_execution_auto=false;g.stat_cache_enabled=true
 g.profile.cleared=range(1,41);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 var equipment:Dictionary=g.equipment.save_data();equipment.loadout.weapons[0].key="missile"
 equipment.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 check(g.equipment.install_snapshot(equipment,g.db),"Presented return equipment installs")
 g.configuration_committed();g.enable_compiled_combat_rules()
 check(g.start(1,false) and g.load_hyperspace_routes(),"Presented return uses production routes")
 check(g.start_hyperspace("alpha",g.hyperspace.current_layer(g,"alpha")+1),"Presented return starts real manual challenge")
 g.spawn_group()
 check(g.state==g.State.COMBAT and not g.enemies.is_empty(),"Presented return has an actual challenge encounter")
 if g.enemies.is_empty():return
 var entry:Dictionary=g.combat_entry(0)
 g.jewel_fire(0,g.enemies[0],g.player_weapon_row(entry),g.player_weapon_offset(0))
 check(g.missile_queue.size()==1,"Actual missile attack creates the event subdivision packet")
 if g.missile_queue.is_empty():return
 # Move the real packet deadline inside the fixed step, then request the real
 # completion/exit command during its first projectile phase.
 g.missile_queue[0].due=g.motion_clock+g.LOGICAL_STEP/4.0
 var clock=g.production_time();g.return_request=int(success);g.observe_segments=true
 g.consume_external_time(3.0*g.LOGICAL_STEP+0.004)
 g.observe_segments=false
 check(g.segments.size()==2 and is_equal_approx(g.segments[0].dt,g.LOGICAL_STEP/4.0),"Presented subdivides at the real ejection deadline")
 check(g.segments.all(func(segment):return segment.manual),"Every subdivision finishes inside the original manual session")
 var settled=0.0
 for segment in g.segments:settled+=float(segment.dt)
 check(is_equal_approx(settled,g.LOGICAL_STEP) and is_equal_approx(g.production_time()-clock,g.LOGICAL_STEP),"Complete outer step is settled exactly once")
 check(not g.manual_hyperspace.active and is_equal_approx(g.manual_hyperspace.last_result.elapsed,g.LOGICAL_STEP),"Challenge receipt includes the entire logical step before return")
 check(g.distance==0 and g.group_index==0 and g.enemies.is_empty() and g.projectiles.is_empty() and g.missile_queue.is_empty(),"No remainder segment advances the fresh mainline or revives old actors")
 check(g.departure_remaining==g.RETURN_DEPARTURE_SECONDS and is_equal_approx(g.game_time_remainder,2.0*g.LOGICAL_STEP+0.004),"Only the completed outer step is debited; later fixed steps remain pending")
 check(g.manual_hyperspace.last_result.reason==("success" if success else "user_exit"),"Requested success or exit result is committed")
 var stopped_clock=g.production_time();g.consume_external_time(g.RETURN_DEPARTURE_SECONDS)
 check(g.production_time()==stopped_clock and g.distance==0,"Real departure hold does not settle pending time")
 g.consume_external_time(0.0)
 check(is_equal_approx(g.production_time()-stopped_clock,2.0*g.LOGICAL_STEP) and is_equal_approx(g.game_time_remainder,0.004),"Pending outer steps resume exactly once after departure")
