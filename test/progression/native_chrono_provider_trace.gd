extends SceneTree
const Adapter=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
class Probe:
	extends "res://qa/presented_balance_game.gd"
	var tick_observer:Callable
	func tick(dt:float):
		if tick_observer.is_valid():tick_observer.call()
		super.tick(dt)
func _initialize():call_deferred("run")
func vec(v:Vector2)->Array:return [v.x,v.y]
func case(speed:float,force_quality:bool)->Dictionary:
	var db=ShipDatabase.new()
	db.levels[0]=db.levels[0].duplicate(true)
	db.levels[0].groups=[{"id":1002,"position":0.0},{"id":1002,"position":0.99}]
	db.levels[0].atkRatio=1.0;db.levels[0].lifeRatio=1.0;db.levels[0].resRatio=1.0
	var g=Probe.new(db);g.rng.seed=1701;g.stat_cache_enabled=true
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	for entry in g.profile.loadout.weapons:entry.key="missile";entry.level=13
	for entry in g.profile.loadout.defence:entry.key="armour";entry.level=13
	g.profile.chronoParticles=10000.0 if speed>1.0 else 0.0
	g.reset_player();g.start(1,false);g.toggle_loop();g.speed=speed
	var driver=Driver.new();driver.setup(self,g);driver.scene.automation_args=[]
	var scene=driver.scene;var ticks:Array=[];var calls:Array=[]
	g.tick_observer=func():
		if force_quality:scene.ship_view.set_accelerated_quality(false)
		var angles:Array=[]
		for slot in g.weapon_entries().size():angles.append(scene.turret_angle(slot))
		ticks.append({"x1_before":g.simulated_time,"motion":g.motion_clock,"demo":scene.demo_time,"fx":scene.fx_time,"angles":angles,"player":vec(Vector2(g.player.x,g.player.y)),"quality":scene.ship_view.accelerated_quality})
	g.launch_provider=func(slot:int,aim:Vector2,ordinal:int):
		var result:Dictionary=scene._prototype_launch_pose(slot,aim,ordinal)
		calls.append({"kind":"launch","x1":g.simulated_time,"motion":g.motion_clock,"slot":slot,"ordinal":ordinal,"aim":vec(aim),"position":vec(result.position),"direction":vec(result.direction),"demo":scene.demo_time,"fx":scene.fx_time,"quality":scene.ship_view.accelerated_quality})
		return result
	g.target_provider=func(target:Dictionary):
		var point:Vector2=scene._prototype_target_point(target)
		calls.append({"kind":"target","x1":g.simulated_time,"uid":target.get("uid",-1),"input":vec(Vector2(target.x,target.y)),"point":vec(point),"demo":scene.demo_time,"fx":scene.fx_time,"quality":scene.ship_view.accelerated_quality})
		return point
	for frame in int(6.0/speed*60):scene._process(1.0/60.0)
	var result={"speed":speed,"force_quality_x1":force_quality,"ticks":ticks,"calls":calls,"x1":g.simulated_time,"rng":str(g.rng.state)}
	driver.close();return result
func difference(a:Array,b:Array,fields:Array)->Dictionary:
	for index in mini(a.size(),b.size()):
		for field in fields:
			if a[index].get(field)!=b[index].get(field):return {"index":index,"field":field,"baseline":a[index],"boosted":b[index]}
	return {"same_prefix":mini(a.size(),b.size()),"baseline_count":a.size(),"boosted_count":b.size()}
func run():
	var baseline=case(1.0,false);await process_frame
	var boosted=case(10.0,false);await process_frame
	var controlled=case(10.0,true);await process_frame
	var output={"seed":1701,"scope":"Native scene._process; captures actual provider calls and read-only logical tick inputs. Forced X1 ship quality is diagnostic only. No extra provider sampling, actions or RNG calls.","baseline":baseline,"boosted":boosted,"quality_control":controlled,"first_tick_input_difference":difference(baseline.ticks,boosted.ticks,["demo","fx","angles","player","quality"]),"first_geometry_difference":difference(baseline.calls,boosted.calls,["kind","x1","slot","ordinal","aim","position","direction","point"]),"first_geometry_difference_quality_control":difference(baseline.calls,controlled.calls,["kind","x1","slot","ordinal","aim","position","direction","point"])}
	var file=FileAccess.open("res://.runtime/native-chrono-provider-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print("CHRONO_PROVIDER_TRACE ",JSON.stringify({"tick":output.first_tick_input_difference,"geometry":output.first_geometry_difference,"quality_control":output.first_geometry_difference_quality_control}));quit()
