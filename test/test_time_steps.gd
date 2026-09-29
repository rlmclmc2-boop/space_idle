extends SceneTree

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

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	for speed in [1.0,2.0,5.0,10.0]:
		for delta in [0.04,0.1,0.8]:
			var game := ObservedGame.new(scene.db,false)
			game.start(1,false)
			game.group_index = scene.db.levels[0].groups.size()
			game.speed = speed
			game.profile.chronoParticles = game.chrono_capacity()
			scene.game = game
			var expected_real := minf(delta,0.1)
			var clock_before: float = scene.clock
			scene._process(delta)
			var total := 0.0
			for step in game.steps:
				total += step
			var max_expected_step := 1.0/15.0 if speed>=3.0 else 1.0/60.0
			check(is_equal_approx(total,expected_real*speed),"Simulation delta clamp and speed: %s/%s" % [speed,delta])
			check(game.steps.all(func(step):return step>0 and step<=max_expected_step),"Simulation substep uses the selected speed mode: %s/%s" % [speed,delta])
			check(scene.accelerated_visual_mode==(speed>=3.0),"Accelerated presentation starts at 3x: %s/%s" % [speed,delta])
			check(is_equal_approx(game.distance,game.ship_movement()*expected_real*speed),"Travel follows simulated time: %s/%s" % [speed,delta])
			check(is_equal_approx(game.planet_seconds,expected_real*speed) and is_equal_approx(game.research_seconds,expected_real*speed) and is_equal_approx(game.production_seconds,expected_real*speed),"Exploration, research and production share game time: %s/%s" % [speed,delta])
			check(is_equal_approx(game.hightech_save_elapsed,expected_real),"Online save interval follows real time: %s/%s" % [speed,delta])
			check(is_equal_approx(float(game.profile.chronoParticles),game.chrono_capacity()-expected_real*game.chrono_cost(speed)),"Particle cost follows real time once: %s/%s" % [speed,delta])
			check(is_equal_approx(scene.clock-clock_before,expected_real),"UI clock uses clamped real time: %s/%s" % [speed,delta])
			game.state = BattleGame.State.LEVEL_CLEAR
			game.clear_timer = 100.0
			scene._process(delta)
			check(is_equal_approx(100.0-game.clear_timer,expected_real*speed),"Countdown follows the same game time: %s/%s" % [speed,delta])
			game.paused = true
			var before := {"profile":game.profile.duplicate(true),"player":game.player.duplicate(true),"cooldowns":game.cooldowns.duplicate(true),"distance":game.distance,"save_elapsed":game.hightech_save_elapsed}
			game.steps.clear()
			scene._process(delta)
			check(game.steps.is_empty(),"Paused main invokes no simulation ticks: %s/%s" % [speed,delta])
			check(before=={"profile":game.profile,"player":game.player,"cooldowns":game.cooldowns,"distance":game.distance,"save_elapsed":game.hightech_save_elapsed},"Pause preserves state and online save timer: %s/%s" % [speed,delta])
	var exact_steps := ObservedGame.new(scene.db,false)
	scene.game = exact_steps
	scene.advance_game_time(10.0/60.0)
	check(exact_steps.steps.size()==10,"10x exact frame has no floating-point residue tick")
	var cooldown_probe := BattleGame.new(scene.db,false)
	cooldown_probe.speed = 3.0
	check(is_equal_approx(cooldown_probe.weapon_cooldown_after_shot(0.1,1.0/6.0,0.5),0.5-(1.0/6.0-0.1)),"3x cooldown preserves elapsed time after a coarse tick")
	cooldown_probe.speed = 2.99
	check(is_equal_approx(cooldown_probe.weapon_cooldown_after_shot(0.1,1.0/6.0,0.5),0.5),"below 3x keeps the standard cooldown")
	var background := ObservedGame.new(scene.db,false)
	background.start(1,false)
	background.group_index=scene.db.levels[0].groups.size()
	background.profile.chronoParticles=20.0
	background.set_speed(5)
	scene.db.config.autoGenRes="0.25,2,5,10000"
	scene.game=background
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var resources_before := float(background.profile.resources["2"])
	scene._process(0.5)
	check(is_equal_approx(background.production_seconds,0.5) and is_equal_approx(background.planet_seconds,0.5) and is_equal_approx(background.research_seconds,0.5),"Background advances all online systems for full elapsed time")
	check(background.speed==background.default_speed() and background.profile.chronoParticles==20,"Background runs at default speed without spending particles")
	scene._process(0.5)
	check(float(background.profile.resources["2"])>resources_before,"Background auto production reaches normal resource income")
	background.profile.chronoSavedAt=Time.get_unix_time_from_system()-20
	scene._notification(scene.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(background.profile.chronoParticles==20,"Focus return does not also claim offline particles")
	print("Time steps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
