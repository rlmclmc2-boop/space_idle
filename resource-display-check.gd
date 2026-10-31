extends SceneTree
const Text = preload("res://src/ui/player_text.gd")
func _initialize() -> void:
	var cases := {"0":"0", "12":"12", "100":"100", "999":"999", "1000":"1.0k", "1000000":"1.0m", "1000000000":"1.0b", "123×10^998":"123×10^998", "12.5":"12.5"}
	var failures := 0
	for source in cases:
		var actual: String = Text.resource_number(source)
		if actual != cases[source]:
			printerr("FAIL ", source, " => ", actual, " expected ", cases[source])
			failures += 1
	print("RESOURCE_DISPLAY checks=", cases.size(), " failures=", failures)
	quit(1 if failures else 0)
