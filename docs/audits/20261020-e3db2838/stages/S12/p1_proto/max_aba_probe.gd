extends "res://max_change_probe.gd"

# Equal final numeric wallet still carries three distinct invalidating
# revisions. This is separate from sustained +5 and its final oracle.
func _initialize() -> void:
	schedule = [3, -5, 2]
	super._initialize()
