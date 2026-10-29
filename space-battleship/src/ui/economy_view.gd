extends Node2D
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")

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
		var resource_id: String = str(marker.resource)
		var center := Vector2(float(marker.x), float(marker.y))
		var icon: Texture2D = ResourceVisuals.icon(resource_id)
		if icon != null:
			draw_circle(center, 10.0, Color("092536", 0.85))
			draw_texture_rect(icon, Rect2(center - Vector2(9, 9), Vector2(18, 18)), false, ResourceVisuals.color(resource_id))
		else:
			draw_circle(center, 5.0, ResourceVisuals.color(resource_id))

static func describe_error(reason: String) -> String:
	return str({"InsufficientResources": "资源不足"}.get(reason, ""))
