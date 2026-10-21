extends "res://max_frame_probe.gd"

# Main-thread timer stands in for a UI input event while frame work proceeds.
func _initialize() -> void:
	expected_state = "cancelled"
	super._initialize()
	create_timer(0.2).timeout.connect(Callable(self, "_main_cancel"))

func _main_cancel() -> void:
	main_cancel_frame = frame_index
	request_cancel()
