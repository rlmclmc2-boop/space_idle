extends VBoxContainer
const ERRORS := {"ShipLocked": "舰体尚未解锁"}
var _campaign
var _host: Callable
var ship_picker: OptionButton

var _pending_choices: bool = false

func _init(campaign, refit: Callable, command: Callable) -> void:
	_campaign = campaign
	_host = command
	ship_picker = OptionButton.new()
	add_child(ship_picker)
	_host.call(self, "切换舰船", func():
		var id: String = "" if ship_picker.selected < 0 else str(ship_picker.get_item_metadata(ship_picker.selected))
		var result: Dictionary = _campaign.change_ship(id, refit)
		var reason: String = str(result.get("reason", ""))
		if not result.get("ok", false) and ERRORS.has(reason): result.message = ERRORS[reason]
		return result)
	_campaign.ship_changed.connect(_queue_choices)
	_campaign.progress_changed.connect(_queue_choices)
	_queue_choices()

func _queue_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
	ship_picker.clear()
	for option in _campaign.ship_options():
		var index: int = ship_picker.item_count
		ship_picker.add_item(option.name)
		ship_picker.set_item_metadata(index, option.id)
		ship_picker.set_item_disabled(index, not option.enabled)
		if option.selected: ship_picker.select(index)

func _ready() -> void:
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()
