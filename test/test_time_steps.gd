extends SceneTree

class IsolatedMain extends "res://scripts/main.gd":
	func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)

class ObservedGame extends BattleGame:
	var steps: Array[float] = []
	var planet_seconds := 0.0
	var research_seconds := 0.0
	var production_seconds := 0.0
	func tick(dt: float) -> void:
		steps.append(dt)
		super.tick(dt)
	func advance_planets(dt: float) -> void:
		planet_seconds += dt
		super.advance_planets(dt)
	func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
		research_seconds += dt
		super.advance_hightech(dt,real_dt,end_time)
	func advance_auto_gen(dt: float) -> void:
		production_seconds += dt
		super.advance_auto_gen(dt)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func set_chrono(g,value:float)->void:
	var wallet:Dictionary=g.economy.save_data();wallet.chronoParticles=value
	check(g.economy.install_snapshot(wallet),"Current chrono wallet installs")

func run() -> void:
	var scene = IsolatedMain.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	for speed in [1.0,2.0,5.0,10.0]:
		for delta in [0.04,0.1,0.8]:
			var game := ObservedGame.new(scene.db,false)
			game.start(1,false)
			game.group_index = scene.db.levels[0].groups.size()
			game.speed = speed
			set_chrono(game,game.chrono_capacity())
			scene.game = game
			var expected_real := maxf(delta,0.0)
			var clock_before: float = scene.clock
			scene._process(delta)
			var total := 0.0
			for step in game.steps:
				total += step
			var max_expected_step := 1.0/60.0
			check(is_equal_approx(total+game.game_time_remainder,expected_real*speed),"Processed ticks plus pending frame tail equal budget: %s/%s" % [speed,delta])
			check(game.steps.all(func(step):return is_equal_approx(step,max_expected_step)),"Simulation substep uses the selected speed mode: %s/%s" % [speed,delta])
			check(scene.accelerated_visual_mode==(speed>=3.0),"Accelerated presentation starts at 3x: %s/%s" % [speed,delta])
			check(is_equal_approx(game.distance,game.ship_movement()*total),"Travel follows simulated time: %s/%s" % [speed,delta])
			check(is_equal_approx(game.planet_seconds,total) and is_equal_approx(game.research_seconds,total) and is_equal_approx(game.production_seconds,total),"Exploration, research and production share game time: %s/%s" % [speed,delta])
			check(is_equal_approx(game.resource_prune_elapsed,expected_real),"Resource history pruning interval follows online real time: %s/%s" % [speed,delta])
			check(is_equal_approx(float(game.economy.balance("chrono")),game.chrono_capacity()-expected_real*game.chrono_cost(speed)),"Particle cost follows real time once: %s/%s" % [speed,delta])
			check(is_equal_approx(scene.clock-clock_before,expected_real),"UI clock retains complete foreground real time: %s/%s" % [speed,delta])
			game.state = BattleGame.State.LEVEL_CLEAR
			game.clear_timer = 100.0
			var tick_count_before := game.steps.size()
			scene._process(delta)
			check(is_equal_approx(100.0-game.clear_timer,(game.steps.size()-tick_count_before)/60.0),"Countdown follows the same game time: %s/%s" % [speed,delta])
			game.paused = true
			var before := {"profile":game.profile.duplicate(true),"player":game.player.duplicate(true),"cooldowns":game.cooldowns.duplicate(true),"distance":game.distance,"prune_elapsed":game.resource_prune_elapsed}
			game.steps.clear()
			scene._process(delta)
			check(game.steps.is_empty(),"Paused main invokes no simulation ticks: %s/%s" % [speed,delta])
			check(before=={"profile":game.profile,"player":game.player,"cooldowns":game.cooldowns,"distance":game.distance,"prune_elapsed":game.resource_prune_elapsed},"Pause preserves simulation state and resource pruning timer: %s/%s" % [speed,delta])
	var exact_steps := ObservedGame.new(scene.db,false)
	scene.game = exact_steps
	exact_steps.consume_external_time(10.0/60.0)
	check(exact_steps.steps.size()==10,"10x exact frame has no floating-point residue tick")
	for fps in [45,60,144]:
		for multiplier in [1.0,10.0]:
			var frame_probe := ObservedGame.new(scene.db,false)
			scene.game=frame_probe
			frame_probe.speed=multiplier;set_chrono(frame_probe,100)
			for frame in fps:frame_probe.consume_external_time(1.0/fps)
			check(frame_probe.steps.size()==int(multiplier*60),"Frame-rate-independent step count %s/%s" % [fps,multiplier])
			check(frame_probe.game_time_remainder<.000000001,"Frame tails settle at exact budget %s/%s" % [fps,multiplier])
	var cooldown_probe := BattleGame.new(scene.db,false)
	cooldown_probe.speed = 3.0
	check(is_equal_approx(cooldown_probe.weapon_cooldown_after_shot(0.1,1.0/6.0,0.5),0.5),"3x cooldown retains the same X1 attack schedule")
	cooldown_probe.speed = 2.99
	check(is_equal_approx(cooldown_probe.weapon_cooldown_after_shot(0.1,1.0/6.0,0.5),0.5),"below 3x keeps the standard cooldown")
	var background := ObservedGame.new(scene.db,false)
	background.start(1,false)
	background.group_index=scene.db.levels[0].groups.size()
	set_chrono(background,20)
	background.set_speed(5)
	scene.db.config.autoGenRes="0.25,2,5,10000"
	scene.game=background
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var resources_before := float(background.economy.balance("2"))
	scene._process(0.5)
	check(is_equal_approx(background.production_seconds,0.5) and is_equal_approx(background.planet_seconds,0.5) and is_equal_approx(background.research_seconds,0.5),"Background advances all online systems for full elapsed time")
	check(background.speed==background.default_speed() and background.economy.balance("chrono")==20,"Background runs at default speed without spending particles")
	scene._process(0.5)
	check(float(background.economy.balance("2"))>resources_before,"Background auto production reaches normal resource income")
	background.profile.chronoSavedAt=Time.get_unix_time_from_system()-20
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(background.economy.balance("chrono")==20,"Focus return does not also claim offline particles")
	# Same paid/default split is applied before the shared fixed-step sequence.
	var split:=ObservedGame.new(scene.db,false);split.speed=5;set_chrono(split,0.2)
	split.consume_external_time(0.1)
	check(split.steps.size()==18 and split.economy.balance("chrono")==0 and split.speed==split.default_speed(),"Exhaustion divides one real frame into 0.05 at x5 and 0.05 at x1")
	var tail:=ObservedGame.new(scene.db,false);tail.consume_external_time(0.01);tail.speed=10;set_chrono(tail,10);tail.consume_external_time(0.01)
	check(is_equal_approx(tail.steps.size()/60.0+tail.game_time_remainder,0.11),"Changing speed does not rescale the previously earned game-time tail")
	var unchanged:=tail.economy.save_data();var tail_before:=tail.game_time_remainder
	for invalid in [-1.0,INF,NAN]:tail.consume_external_time(invalid)
	check(tail.economy.save_data()==unchanged and tail.game_time_remainder==tail_before,"Invalid external durations neither spend nor advance")
	var valid:=tail.portable_save_data();tail.begin_return_departure()
	var invalid_save:=valid.duplicate(true);invalid_save.materials.erase(invalid_save.materials.keys()[0])
	tail.load_progress_data(invalid_save)
	check(tail.game_time_remainder==tail_before and tail.departure_remaining>0,"Rejected load retains the existing time session")
	tail.load_progress_data(valid)
	check(tail.game_time_remainder==0 and tail.departure_remaining==0,"Validated snapshot installation starts with no abandoned frame debt")
	var lab=preload("res://scripts/balance_game.gd").new(scene.db)
	lab.resource_samples.assign([{"time":-100.0,"id":"1","amount":1.0}]);lab.tick(6.0)
	check(lab.resource_samples.is_empty() and is_equal_approx(lab.resource_prune_elapsed,1.0),"Independent analysis preserves sample pruning using its simulated clock")
	tail.begin_return_departure();tail.start(1,false)
	check(tail.departure_remaining==0,"An explicit new sortie does not inherit a prior return animation wait")
	# A visible independent lab no longer freezes the live scene.
	scene.game=split;split.paused=false
	scene.balance_lab=Window.new();root.add_child(scene.balance_lab);scene.balance_lab.show()
	var before_steps:int=split.steps.size();scene._process(0.1)
	check(split.steps.size()==before_steps+6,"Showing the lab does not own live gameplay time")
	scene.balance_lab.queue_free()
	var viewed:=BattleGame.new(scene.db,false);viewed.profile.cleared=range(1,101);viewed.rebuild_unlocks();viewed.galaxy_runtime.refresh_unlocks(viewed)
	check(viewed.assign_crew("navigator","galaxy_explore","galaxy_1"),"Visible galaxy starts with real crew")
	var unseen:=BattleGame.new(scene.db,false)
	unseen.load_progress_data(viewed.portable_save_data())
	check(unseen.galaxy.save_data()==viewed.galaxy.save_data(),"Unseen galaxy installs same complete state")
	scene.game=viewed;scene.galaxy_panel.game=viewed;scene.galaxy_panel.selected="galaxy_1"
	var panel=scene.galaxy_panel
	for i in 8:
		var committed:=viewed.galaxy.save_data()
		panel.visible=i%2==0;panel.refresh()
		check(viewed.galaxy.save_data()==committed,"Showing, hiding and refreshing galaxy cannot commit pending work")
		viewed.consume_external_time(0.25);unseen.consume_external_time(0.25)
		check(viewed.galaxy.save_data()==unseen.galaxy.save_data(),"Visible and unseen galaxies commit identical work at every shared boundary")
	check(viewed.galaxy.regions.galaxy_1.state.build_elapsed>0 and viewed.galaxy.pending("galaxy_1")<viewed.galaxy.work_interval(viewed),"Hidden work uses the same live cadence")
	scene.queue_free();await process_frame
	print("Time steps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
