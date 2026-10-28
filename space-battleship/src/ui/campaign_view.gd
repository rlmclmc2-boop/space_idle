extends Node2D
var _campaign
var _ui_gate: Callable

func _init(campaign, ui_gate: Callable = Callable()) -> void:
	_campaign = campaign
	_ui_gate = ui_gate
	_campaign.status_changed.connect(queue_redraw)

func _unhandled_input(event: InputEvent) -> void:
	if _ui_gate.is_valid() and _ui_gate.call(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_campaign.toggle_guard()

func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(18, 28), _campaign.status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ecf5ff"))
