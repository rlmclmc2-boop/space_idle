extends Node2D
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")

var _economy
var _context: Callable
var _after_income: Callable

func _init(economy, context: Callable, after_income: Callable) -> void:
	_economy = economy
	_context = context
	_after_income = after_income
	# Native contact flashes use z=2; the pickup identity must remain legible above them.
	z_index = 3
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
			var color: Color = ResourceVisuals.color(resource_id)
			draw_circle(center, 15.0, Color("092536"))
			draw_arc(center, 15.0, 0.0, TAU, 24, color, 1.3)
			draw_texture_rect(icon, Rect2(center - Vector2(14, 14), Vector2(28, 28)), false, color)
		else:
			draw_circle(center, 5.0, ResourceVisuals.color(resource_id))

static func describe_error(reason: String) -> String:
	return str({"InsufficientResources": "资源不足"}.get(reason, ""))
