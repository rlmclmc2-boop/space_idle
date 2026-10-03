extends SceneTree
## Native _process consumes the retained offline reserve exactly once.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():call_deferred("run")
func case(reserve:float, speed:float, real_seconds:int)->Dictionary:
	var db=ShipDatabase.new()
	db.levels[0]=db.levels[0].duplicate(true)
	db.levels[0].groups=[{"id":1002,"position":0.0},{"id":1002,"position":0.99}]
	db.levels[0].atkRatio=1.0;db.levels[0].lifeRatio=1.0;db.levels[0].resRatio=1.0
	var g=Game.new(db);g.rng.seed=1701;g.stat_cache_enabled=true
	var metrics=Metrics.new();g.metrics=metrics;metrics.initialize(g)
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	for entry in g.profile.loadout.weapons:entry.key="missile";entry.level=13
	for entry in g.profile.loadout.defence:entry.key="armour";entry.level=13
	g.profile.chronoParticles=reserve;g.reset_player();g.start(1,false);g.toggle_loop();g.speed=speed
	var driver=Driver.new();driver.setup(self,g);driver.scene.automation_args=[]
	for frame in real_seconds*60:driver.scene._process(1.0/60.0)
	var result={"real_seconds":real_seconds,"initial_chrono":reserve,"remaining_chrono":g.profile.chronoParticles,"x1_seconds":g.simulated_time,"speed":g.speed,"resources":g.profile.resources.duplicate(true),"kills":metrics.kills,"deaths":metrics.deaths,"rng":str(g.rng.state)}
	driver.close();return result
func run():
	var boosted=case(600.0,10.0,100)
	var baseline=case(0.0,1.0,700)
	assert(absf(boosted.x1_seconds-700.0)<0.00001)
	assert(absf(baseline.x1_seconds-700.0)<0.00001)
	assert(absf(boosted.remaining_chrono)<0.00001)
	var output={"boosted":boosted,"baseline":baseline,"budget_pass":true,"combat_pass":boosted.kills==baseline.kills and boosted.deaths==baseline.deaths and boosted.rng==baseline.rng and boosted.resources==baseline.resources,"scope":"Native scene _process, controlled missile farm; no actions; stored600 plus real100 yields700 X1 seconds. Exact kills/deaths/RNG/resources comparison in this fixture, not universal equivalence."}
	var file=FileAccess.open("res://.runtime/native-chrono-budget.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print("NATIVE_CHRONO_BUDGET ",JSON.stringify(output))
	assert(output.combat_pass)
	quit()
