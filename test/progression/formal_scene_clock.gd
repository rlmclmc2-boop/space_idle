extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():call_deferred("run")
var weapon:String="missile"
var duration:float=600.0
func run_case(boost:float,fps:int)->Dictionary:
	var db=ShipDatabase.new()
	db.levels[0]=db.levels[0].duplicate(true)
	db.levels[0].groups=[{"id":1002,"position":0.0},{"id":1002,"position":0.99}]
	db.levels[0].atkRatio=1.0;db.levels[0].lifeRatio=1.0;db.levels[0].resRatio=1.0
	var g=Game.new(db);g.rng.seed=1701;g.speed=boost
	var metrics=Metrics.new();g.metrics=metrics;metrics.initialize(g)
	g.profile.selectedShip="Destroyer";g.profile.grantedUnlocks=[db.unlock_id("ship","Destroyer")]
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.loadout={"weapons":[],"defence":[]}
	for i in 4:g.profile.loadout.weapons.append({"key":weapon,"level":13})
	g.profile.loadout.defence=[{"key":"shield","level":13},{"key":"armour","level":13}]
	g.stat_cache_enabled=true;g.reset_player();g.start(1,false);g.toggle_loop()
	var driver=Driver.new();driver.setup(self,g)
	var frames:int=int(round(duration/boost*fps))
	for frame in frames:
		driver.before_tick(1.0/fps)
		driver.scene.advance_game_time(boost/fps)
		driver.after_tick(1.0/fps)
	var result={"weapon":weapon,"boost":boost,"fps":fps,"x1_seconds":g.simulated_time,"pending":driver.scene.game_time_remainder,"resources":g.profile.resources,"player":g.player,"projectiles":g.projectiles,"queue":g.missile_queue,"rng":str(g.rng.state),"kills":metrics.kills,"deaths":metrics.deaths,"state":g.state,"node":g.group_index,"furnace_peak":g.profile.furnaceIncomePeak,"motion_clock":g.motion_clock,"scope":"Controlled weapon farming; full production event hook; actual scene providers and advance_game_time; pose/turret update once per emulated render frame, no GUI side effects"}
	driver.close();return result
func run():
	if not OS.get_environment("PROGRESSION_CLOCK_WEAPON").is_empty():weapon=OS.get_environment("PROGRESSION_CLOCK_WEAPON")
	if not OS.get_environment("PROGRESSION_CLOCK_SECONDS").is_empty():duration=float(OS.get_environment("PROGRESSION_CLOCK_SECONDS"))
	var rows:Array=[]
	for fps in [60,144]:
		for boost in [1.0,10.0]:
			var row=run_case(boost,fps);rows.append(row);print("FORMAL_SCENE_CLOCK ",JSON.stringify(row))
	FileAccess.open("res://.runtime/formal-scene-clock.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
