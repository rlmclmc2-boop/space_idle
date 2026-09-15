extends SceneTree

class ObservedGame extends BattleGame:
	var steps: Array[float] = []
	func tick(dt: float) -> void:
		steps.append(dt)
		super.tick(dt)

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
	for speed in [1.0,2.0,5.0]:
		for delta in [0.04,0.1,0.8]:
			var game := ObservedGame.new(scene.db,false)
			game.start(1,false)
			game.group_index = scene.db.levels[0].groups.size()
			game.speed = speed
			scene.game = game
			var expected_real := minf(delta,0.1)
			var clock_before: float = scene.clock
			scene._process(delta)
			var total := 0.0
			for step in game.steps:
				total += step
			check(is_equal_approx(total,expected_real*speed),"Simulation delta clamp and speed: %s/%s" % [speed,delta])
			check(game.steps.all(func(step):return step>0 and step<=1.0/60.0),"Every simulation substep bounded: %s/%s" % [speed,delta])
			check(is_equal_approx(game.distance,game.ship_movement()*expected_real*speed),"Travel follows simulated time: %s/%s" % [speed,delta])
			check(is_equal_approx(game.hightech_save_elapsed,expected_real),"Online save interval follows real time: %s/%s" % [speed,delta])
			check(is_equal_approx(scene.clock-clock_before,expected_real),"UI clock uses clamped real time: %s/%s" % [speed,delta])
			game.paused = true
			var before := {"profile":game.profile.duplicate(true),"player":game.player.duplicate(true),"cooldowns":game.cooldowns.duplicate(true),"distance":game.distance,"save_elapsed":game.hightech_save_elapsed}
			game.steps.clear()
			scene._process(delta)
			check(game.steps.is_empty(),"Paused main invokes no simulation ticks: %s/%s" % [speed,delta])
			check(before=={"profile":game.profile,"player":game.player,"cooldowns":game.cooldowns,"distance":game.distance,"save_elapsed":game.hightech_save_elapsed},"Pause preserves state and online save timer: %s/%s" % [speed,delta])
	print("Time steps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
