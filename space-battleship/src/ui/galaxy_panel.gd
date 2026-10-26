extends VBoxContainer

var _galaxy
var _pending_full: bool = false
var _pending_keys: Dictionary = {}
var _labels: Dictionary = {}

func _init(galaxy) -> void:
	_galaxy = galaxy
	_galaxy.status_changed.connect(_queue_status)
	_galaxy.availability_changed.connect(_queue_status)
	_queue_status()

func _queue_status(keys: Array = []) -> void:
	if keys.is_empty(): _pending_full = true
	for key in keys: _pending_keys[key] = true

func _refresh_status(keys: Array = []) -> void:
	for row in _galaxy.status_rows(keys):
		if not _labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(label)
			_labels[row.id] = label
		_labels[row.id].text = row.text

static func describe_error(reason: String) -> String:
	return "星系尚未开放" if reason == "GalaxyUnavailable" else ""

func _ready() -> void:
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()

func _flush_pending() -> void:
	if not is_visible_in_tree(): return
	if not _pending_full and _pending_keys.is_empty(): return
	var full: bool = _pending_full
	var keys: Array = _pending_keys.keys()
	_pending_full = false
	_pending_keys = {}
	if full: _refresh_status()
	elif not keys.is_empty(): _refresh_status(keys)
