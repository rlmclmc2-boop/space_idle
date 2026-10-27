extends Node2D
var _statistics

func _init(statistics) -> void:
	_statistics = statistics
	_statistics.changed.connect(queue_redraw)

func _draw() -> void:
	var text: String = _statistics.display_text()
	if not text.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(20, 898), text, HORIZONTAL_ALIGNMENT_LEFT, 532, 14, Color("c1d5f0"))
