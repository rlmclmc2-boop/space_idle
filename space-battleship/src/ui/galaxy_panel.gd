extends VBoxContainer

var _galaxy
var _labels: Dictionary = {}

func _init(galaxy) -> void:
	_galaxy = galaxy
	_galaxy.status_changed.connect(_refresh_status)
	_galaxy.availability_changed.connect(_refresh_status)
	_refresh_status()

func _refresh_status(keys: Array = []) -> void:
	for row in _galaxy.status_rows(keys):
		if not _labels.has(row.id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(label)
			_labels[row.id] = label
		_labels[row.id].text = row.text
