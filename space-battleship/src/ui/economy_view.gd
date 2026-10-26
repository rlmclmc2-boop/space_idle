extends Node2D

var _economy
var _context: Callable
var _after_income: Callable

func _init(economy, context: Callable, after_income: Callable) -> void:
	_economy = economy
	_context = context
	_after_income = after_income
	_economy.display_changed.connect(queue_redraw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var context: Dictionary = _context.call()
		var result: Dictionary = _economy.collect_at(event.position, float(context.wall), float(context.game), context.factors)
		if result.ok: _after_income.call()

func _draw() -> void:
	for marker in _economy.drop_markers():
		draw_circle(Vector2(float(marker.x), float(marker.y)), 5.0, Color("ffe195") if str(marker.resource) != "jewel" else Color("a2afff"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 795), _economy.balances_text(), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffe195"))

static func describe_error(reason: String) -> String:
	return str({"InsufficientResources": "资源不足"}.get(reason, ""))
