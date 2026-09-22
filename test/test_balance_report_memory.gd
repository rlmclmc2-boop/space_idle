extends SceneTree
const Runner = preload("res://scripts/balance_runner.gd")
const Report = preload("res://scripts/balance_report.gd")
func fingerprint(value: Dictionary) -> String:return JSON.stringify(value).sha256_text()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var runner = Runner.new()
	runner.start({"duration":1,"performance_diagnostics":false})
	while runner.status == "running":runner.step_once()
	var runs: Array = runner.reports
	var timeline: Dictionary = runs[0].timeline
	var sample: Dictionary = timeline.samples[0].duplicate(true)
	while timeline.samples.size() < 1200:timeline.samples.append(sample.duplicate(true))
	while timeline.events.size() < 5000:timeline.events.append({"time":0.0,"stage":1,"kind":"UPGRADE","data":{},"count":1})
	var initial := OS.get_static_memory_usage()
	var report := Report.build(runner.config,runs,"completed")
	var copied := OS.get_static_memory_usage()-initial
	var digest := fingerprint(report)
	# Prototype: finalized run dictionaries are immutable to the runner/UI.
	report.runs = runs.duplicate()
	var shared := OS.get_static_memory_usage()-initial
	assert(fingerprint(report) == digest)
	print("REPORT_RETAINED copied_bytes=",copied," shared_bytes=",shared," same_content=true")
	quit()
