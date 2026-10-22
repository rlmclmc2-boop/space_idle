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
 print("DEPARTURE_BATCH_DEBT ",checks," checks ",failures," failures");quit(1 if failures else 0)
