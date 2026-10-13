extends SceneTree
class RefusedTransfer extends "res://scripts/native_execution_session.gd":
	func handoff_to_legacy(_game:RefCounted,_reason:String)->bool:return false
	func prepare_galaxy_refit(_game,_values:Dictionary)->Dictionary:return {}
	func prepare_geometry(_geometry:RefCounted,_game:RefCounted)->void:pass
class SharedObservedGame extends "res://scripts/presented_battle_game.gd":
	var shared_calls:=0
	func advance_shared_clock_and_economy(dt:float)->void:
		shared_calls+=1
		super.advance_shared_clock_and_economy(dt)
class BudgetMain extends "res://scripts/main.gd":
	var demo_time:=0.0
	func attach_native_display()->bool:return false
	func before_logical_game_tick(dt:float)->void:demo_time+=dt
class GeometryProbe extends RefCounted:
	var fx_time:=0.0
	var demo_time:=0.0
	var turret_visuals:Dictionary={}
	var turret_ship:=""
	func before_tick(dt:float)->void:fx_time+=dt;demo_time+=dt
	func after_tick()->void:pass
class CancelBudgetRuntime extends "res://scripts/battle_slice_runtime.gd":
	func snapshot()->void:pass
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(galaxy_boundary:bool=false):
	var g=SharedObservedGame.new(ShipDatabase.new(),false);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
	g.stat_cache_enabled=true;g.invalidate_stat_cache();g.save_enabled=false;g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	if galaxy_boundary:
		g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
		check(g.assign_crew("navigator","galaxy_explore","galaxy_1"),"crew before native boundary fixture")
		g.galaxy.elapsed_crew.galaxy_1=1;g.galaxy.elapsed.galaxy_1=9.99
	var d=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract");d.attack_counter=9007199254740990.0
	var owner=RefusedTransfer.new();check(owner.admit(g,d),"real untouched kernel admission");g.native_execution=owner
	return g
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=fixture();var owner=g.native_execution
	var before=owner.kernel.export_handoff();var rng=g.rng.state
	g.tick(1.0/60.0)
	check(g.paused and owner.advance_blocked and g.native_step_phase=="blocked" and g.native_step_remaining==1.0/60.0,"failed transfer visibly stops and retains combat remainder")
	check(g.shared_calls==1 and owner.kernel.export_handoff()==before and g.rng.state==rng and g.native_handoff_count==0,"failed transfer executes no combat or fake commit")
	g.tick(1.0/60.0)
	check(g.shared_calls==1 and g.native_step_remaining==1.0/60.0,"paused repeat does not replay shared economy")
	g.begin_retreat()
	g=fixture();var scene=BudgetMain.new();scene.game=g
	scene.advance_game_time(3.0/60.0)
	check(g.shared_calls==1 and g.paused and is_equal_approx(scene.game_time_remainder,3.0/60.0) and g.native_step_remaining==1.0/60.0,"normal frame scheduler keeps blocked and unvisited time budget")
	g.begin_retreat();scene.free()
	g=fixture();scene=BudgetMain.new();scene.game=g
	var runtime=preload("res://scripts/battle_slice_runtime.gd").new();runtime.scene=scene;runtime.game=g;runtime.geometry=GeometryProbe.new()
	runtime.advance(3.0/60.0)
	check(g.shared_calls==1 and g.paused and runtime.logical_steps==0 and is_equal_approx(runtime.remainder,3.0/60.0) and scene.game_time_remainder==runtime.remainder,"native frame scheduler does not acknowledge blocked logical step")
	g.begin_retreat();scene.free()
	for slice in [false,true]:
		g=fixture(true);scene=BudgetMain.new();scene.game=g
		var state=g.galaxy.save_data().duplicate(true);var clock=g.production_time();before=g.native_execution.kernel.export_handoff().duplicate(true)
		var probe=GeometryProbe.new()
		if slice:
			runtime=preload("res://scripts/battle_slice_runtime.gd").new();runtime.scene=scene;runtime.game=g;runtime.geometry=probe
			runtime.advance(3.0/60.0)
			check(runtime.logical_steps==0 and is_equal_approx(runtime.remainder,3.0/60.0),"galaxy failure keeps slice step and remainder")
		else:scene.advance_game_time(3.0/60.0)
		check(g.paused and g.native_step_phase=="blocked" and g.shared_calls==0 and g.production_time()==clock,"galaxy failure precedes shared clock and economy")
		check(scene.demo_time==0 and probe.demo_time==0 and probe.fx_time==0 and is_equal_approx(scene.game_time_remainder,3.0/60.0),"galaxy failure preserves presentation clocks and complete budget")
		check(g.galaxy.save_data()==state and g.native_execution.kernel.export_handoff()==before,"galaxy failure leaves region and combat untouched")
		g.begin_retreat();scene.free()
	for slice in [false,true]:
		g=fixture();scene=BudgetMain.new();scene.game=g;scene.time_step_game_id=g.get_instance_id()
		g.native_cancelled_step=1.0/60.0
		if slice:
			runtime=CancelBudgetRuntime.new();runtime.scene=scene;runtime.game=g;runtime.remainder=1.5/60.0
			runtime.advance(0.0)
			check(is_equal_approx(runtime.remainder,0.5/60.0),"cancel consumes only the partial shared step from slice budget")
		else:
			scene.game_time_remainder=1.5/60.0;scene.advance_game_time(0.0)
			check(is_equal_approx(scene.game_time_remainder,0.5/60.0),"cancel consumes only the partial shared step from Main budget")
		check(g.native_cancelled_step==0 and g.shared_calls==0,"cancel never replays shared work")
		g.begin_retreat();scene.free()
	print("EXPECTED_BLOCKED_TRANSFER_PROOF ",JSON.stringify({"checks":checks,"failures":failures,"remaining_preserved":true}))
	quit(0 if failures==0 else 1)
