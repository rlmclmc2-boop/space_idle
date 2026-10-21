extends "res://max_approx_probe.gd"

func _initialize() -> void:
	fixture_mode = "compact_medium"
	cancel_during_work = true
	super._initialize()
