extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gauge = load("res://scripts/charge_circuit.gd").new()
	gauge.size=Vector2(164,180)
	root.add_child(gauge)
	var label := Label.new()
	gauge.add_child(label)
	gauge.percent_label=label
	gauge.write_value=func(control,property,value):control.set(property,value)
	gauge.set_state("charging")
	gauge.set_flow(true)
	# Drive only the display clock deterministically. No game profile is loaded.
	for upgrade in [false,true]:
		gauge.set_job_progress(0.98,0,0)
		gauge._process(0.1)
		gauge.set_job_progress(0.01,1 if upgrade else 0,0 if upgrade else 1)
		check(is_equal_approx(gauge.display_progress,0.01) and label.text=="1%","New round immediately shows actual progress, including upgrade reset")
		check(gauge.completion_remaining>0,"A separate completion accent is retained")
		var previous: float = gauge.display_progress
		var monotonic := true
		var bounded := true
		for frame in range(18):
			if frame%3==0:
				gauge.set_job_progress(0.01+frame*0.01,1 if upgrade else 0,0 if upgrade else 1)
			gauge._process(1.0/30.0)
			monotonic=monotonic and gauge.display_progress>=previous-0.00001
			bounded=bounded and gauge.display_progress<=gauge.progress+0.00001
			previous=gauge.display_progress
		check(monotonic and bounded,"Sampled progress stays forward and bounded through accent expiry, with no stale tween rebound")
		check(gauge.completion_remaining==0,"Completion accent terminates independently")
	# Immediate next-round samples at high speed cannot queue or restart a progress hold.
	for round_index in range(5):
		gauge.set_job_progress(0.02,2,round_index)
		gauge._process(0.04)
		check(is_equal_approx(gauge.display_progress,0.02),"Fast successive rounds never hold or reverse the progress ring")
	gauge.set_flow(false)
	gauge.set_frozen(true)
	check(not gauge.is_processing(),"Pause stops the display animation")
	gauge.queue_free()
	print("Charge rollover: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
