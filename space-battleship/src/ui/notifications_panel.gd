extends VBoxContainer

var _notifications
var _archive: VBoxContainer
var _open: Button

func _init(notifications) -> void:
	_notifications = notifications
	_open = Button.new()
	add_child(_open)
	_archive = VBoxContainer.new()
	_archive.visible = false
	add_child(_archive)
	_open.pressed.connect(func(): _archive.visible = not _archive.visible)
	_notifications.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_open.text = "通知档案（未读 %s）" % _notifications.unread()
	for child in _archive.get_children():
		_archive.remove_child(child)
		child.queue_free()
	for row in _notifications.entries():
		var line := HBoxContainer.new()
		_archive.add_child(line)
		var title := Label.new()
		title.text = "%s · %s%s" % [row.topic, row.id, " · 未读" if not row.read else ""]
		line.add_child(title)
		var seen := Button.new()
		seen.text = "已见" if row.seen else "标记已见"
		seen.disabled = row.seen
		seen.pressed.connect(_notifications.mark_seen.bind(row.key))
		line.add_child(seen)
		var read := Button.new()
		read.text = "已读" if row.read else "阅读此条"
		read.disabled = row.read
		read.pressed.connect(_notifications.mark_read.bind(row.key))
		line.add_child(read)
