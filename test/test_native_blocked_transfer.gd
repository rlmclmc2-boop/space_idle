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
	var shield_before_hit:=0.0
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
	var db:=ShipDatabase.new();db.ships.Heavy_Battleship.defenseSlots=2
	var g=SharedObservedGame.new(db,false);g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var equipment:Dictionary=g.equipment.save_data();equipment.selectedShip="Heavy_Battleship"
	equipment.loadout=preload("res://scripts/equipment_state.gd").empty_loadout(db,equipment.selectedShip)
	for entry in equipment.loadout.weapons:entry.key="laser"
	equipment.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
	check(g.equipment.install_snapshot(equipment,db),"current blocked transfer equipment installs")
	g.stat_cache_enabled=true;g.configuration_committed();g.save_enabled=false;g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	if galaxy_boundary:
		g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy_runtime.refresh_unlocks(g)
		check(g.assign_crew("navigator","galaxy_explore","galaxy_1"),"crew before native boundary fixture")
		var galaxy:Dictionary=g.galaxy.save_data();var saved:Dictionary=galaxy.galaxies.galaxy_1
		var chosen=""
		for row in g.galaxy.regions.galaxy_1.builds.values():
			if row.effect_type=="equipment_value":chosen=row.key;break
		saved.slots[0].type=chosen;saved.slots[0].planned_type=chosen;saved.slots[0].status="constructing";saved.slots[0].level=1
		saved.slots[0].work=g.galaxy.regions.galaxy_1.work_cost();saved.slots[0].construction=0.01
		saved.blueprint.nodes[0].type=chosen;saved.blueprint.nodes[0].planned_type=chosen
		saved.explore_work=g.galaxy.regions.galaxy_1.work_cost();saved.pending_crew_count=1;saved.pending_online_time=0.99
		check(g.galaxy.install_snapshot(galaxy,g.db),"current galaxy refit boundary installs")
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
	g.consume_external_time(3.0/60.0,scene)
	check(g.shared_calls==1 and g.paused and is_equal_approx(g.game_time_remainder,3.0/60.0) and g.native_step_remaining==1.0/60.0,"normal frame scheduler keeps blocked and unvisited time budget")
	g.begin_retreat();scene.free()
	g=fixture();scene=BudgetMain.new();scene.game=g
	var runtime=CancelBudgetRuntime.new();runtime.scene=scene;runtime.game=g;runtime.geometry=GeometryProbe.new()
	scene.battle_slice_runtime=runtime;g.consume_external_time(3.0/60.0,scene)
	check(g.shared_calls==1 and g.paused and runtime.logical_steps==0 and is_equal_approx(g.game_time_remainder,3.0/60.0),"native frame scheduler does not acknowledge blocked logical step")
	g.begin_retreat();scene.free()
	for slice in [false,true]:
		g=fixture(true);scene=BudgetMain.new();scene.game=g
		var state=g.galaxy.save_data().duplicate(true);var clock=g.production_time();before=g.native_execution.kernel.export_handoff().duplicate(true)
		var economic_state:Dictionary={"wallet":g.economy.save_data(),"crew":g.crew.save_data(),"research":g.research.save_data()}
		var probe=GeometryProbe.new()
		if slice:
			runtime=CancelBudgetRuntime.new();runtime.scene=scene;runtime.game=g;runtime.geometry=probe
			scene.battle_slice_runtime=runtime;g.consume_external_time(3.0/60.0,scene)
			check(runtime.logical_steps==0 and is_equal_approx(g.game_time_remainder,3.0/60.0),"galaxy failure keeps slice step and remainder")
		else:g.consume_external_time(3.0/60.0,scene)
		check(g.paused and g.native_step_phase=="blocked" and g.shared_calls==0 and g.production_time()==clock,"galaxy failure precedes shared clock and economy")
		check(scene.demo_time==0 and probe.demo_time==0 and probe.fx_time==0 and is_equal_approx(g.game_time_remainder,3.0/60.0),"galaxy failure preserves presentation clocks and complete budget")
		check(g.galaxy.save_data()==state and g.native_execution.kernel.export_handoff()==before and economic_state=={"wallet":g.economy.save_data(),"crew":g.crew.save_data(),"research":g.research.save_data()},"Galaxy refusal preserves real wallet, growth, region and combat")
		g.begin_retreat();scene.free()
	for slice in [false,true]:
		g=fixture();scene=BudgetMain.new();scene.game=g
		g.native_cancelled_step=1.0/60.0
		if slice:
			runtime=CancelBudgetRuntime.new();runtime.scene=scene;runtime.game=g;g.game_time_remainder=1.5/60.0
			scene.battle_slice_runtime=runtime;g.consume_external_time(0.0,scene)
			check(is_equal_approx(g.game_time_remainder,0.5/60.0),"cancel consumes only the partial shared step from slice budget")
		else:
			g.game_time_remainder=1.5/60.0;g.consume_external_time(0.0,scene)
			check(is_equal_approx(g.game_time_remainder,0.5/60.0),"cancel consumes only the partial shared step from Main budget")
		check(g.native_cancelled_step==0 and g.shared_calls==0,"cancel never replays shared work")
		g.begin_retreat();scene.free()
	print("EXPECTED_BLOCKED_TRANSFER_PROOF ",JSON.stringify({"checks":checks,"failures":failures,"remaining_preserved":true}))
	quit(0 if failures==0 else 1)
