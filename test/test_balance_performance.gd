extends SceneTree
## Actual growth runner, without a replacement game or obsolete profile fixtures.
## Compare work output before timings; identity differences are separately disclosed.
const Runner = preload("res://scripts/balance_runner.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var runner=Runner.new()
	var duration:=float(OS.get_environment("BALANCE_PERF_SECONDS")) if OS.has_environment("BALANCE_PERF_SECONDS") else 300.0
	var wall_limit:=int(OS.get_environment("BALANCE_PERF_WALL_SECONDS")) if OS.has_environment("BALANCE_PERF_WALL_SECONDS") else 120
	var began:=Time.get_ticks_usec()
	var error:String=runner.start({"speed":1000,"duration":duration,"seed":12345,"performance_diagnostics":false})
	var setup_us:=Time.get_ticks_usec()-began
	if not error.is_empty():printerr(error);quit(1);return
	began=Time.get_ticks_usec()
	while runner.status=="running":
		runner.step_once()
		if Time.get_ticks_usec()-began>wall_limit*1000000:print("PERFORMANCE_TIME_LIMIT");quit(2);return
	var elapsed:=Time.get_ticks_usec()-began
	var g=runner.game
	var work={"steps":runner.steps,"seconds":g.simulated_time,"stage":g.stage,"rng":str(g.rng.state),"equipment":g.equipment.save_data(),"economy":g.economy.save_data(),"research":g.research.save_data(),"metrics":runner.metrics.report(g)}
	print("GROWTH_PERF ",JSON.stringify({"status":runner.status,"setup_us":setup_us,"run_and_report_us":elapsed,"work":work}))
	print("Growth performance: 1 checks, ",0 if runner.status=="completed" else 1," failures")
	quit(0 if runner.status=="completed" else 1)
