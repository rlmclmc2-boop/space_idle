extends "res://max_approx_probe.gd"

func _initialize() -> void:
	fixture_mode = "compact_medium"
	mutate_before_commit = true
	mutation_mode = "config"
	super._initialize()
