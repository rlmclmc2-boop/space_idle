extends SceneTree
class Host extends RefCounted:
 var blocked=false
 var game_time_remainder=0.0
 var fx_time=0.0
 var demo_time=0.0
 var turret_visuals={}
 var turret_ship=""
 func battle_transition_blocked()->bool:return blocked
class GeometryProbe extends RefCounted:
 var fx_time=0.0
 var demo_time=0.0
 var turret_visuals={}
 var turret_ship=""
 var preparations=0
 func before_tick(dt:float)->void:preparations+=1;fx_time+=dt
 func after_tick()->void:pass
class GameProbe extends BattleGame:
 var host
 var ticks=0
 func prepare_logical_step(_dt:float)->bool:return true
 func tick(_dt:float)->void:
  ticks+=1
  if ticks==1:host.blocked=true
class Runtime extends "res://scripts/battle_slice_runtime.gd":
 func snapshot()->void:pass
var checks=0
var failures=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var host=Host.new();var game=GameProbe.new(ShipDatabase.new(),false);game.host=host
 var runtime=Runtime.new();runtime.scene=host;runtime.game=game;runtime.geometry=GeometryProbe.new()
 runtime.advance(3.0/60.0+0.004)
 check(game.ticks==1 and runtime.logical_steps==1,"mid-batch departure stops before the next logical substep")
 check(runtime.geometry.preparations==1,"no later geometry preparation after departure")
 check(absf(runtime.remainder-(2.0/60.0+0.004))<1e-10 and runtime.remainder==host.game_time_remainder,"unconsumed debt is retained and published")
 var debt=runtime.remainder;runtime.advance(2.0)
 check(runtime.remainder==debt and game.ticks==1,"departure wall time never enters game debt")
 host.blocked=false;runtime.advance(0.0)
 check(game.ticks==3 and runtime.logical_steps==3 and absf(runtime.remainder-0.004)<1e-10,"resume consumes retained debt exactly once")
 check(not runtime.advancing,"batch ownership released on every return")
 game.host=null;runtime.scene=null;runtime.game=null
 print("DEPARTURE_BATCH_DEBT ",checks," checks ",failures," failures");quit(1 if failures else 0)
