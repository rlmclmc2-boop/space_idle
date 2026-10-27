extends SceneTree

const NotificationsPanel = preload("res://src/ui/notifications_panel.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found: Button = _find_button(child, label)
		if found != null: return found
	return null

func _find_notifications(node: Node):
	if node.get_script() == NotificationsPanel: return node
	for child in node.get_children():
		var found = _find_notifications(child)
		if found != null: return found
	return null

func _find_line(node: Node, placeholder: String) -> LineEdit:
	if node is LineEdit and node.placeholder_text == placeholder: return node
	for child in node.get_children():
		var found: LineEdit = _find_line(child, placeholder)
		if found != null: return found
	return null

func _find_picker(node: Node) -> FileDialog:
	if node is FileDialog and node.file_mode == FileDialog.FILE_MODE_OPEN_DIR: return node
	for child in node.get_children():
		var found: FileDialog = _find_picker(child)
		if found != null: return found
	return null

func _capture(prefix: String, name: String) -> bool:
	await process_frame
	await process_frame
	return root.get_viewport().get_texture().get_image().save_png(prefix + "-" + name + ".png") == OK

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("real renderer required")
		return
	var prefix: String = OS.get_environment("SPACE_IDLE_WINDOW_EVIDENCE")
	if prefix.is_empty():
		_fail("screenshot prefix required")
		return
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", prefix + "-settings.json")
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	if not main.startup_error.is_empty() or not main._guidance_panel.visible or not main.session.pause_reasons.has("unlock"):
		_fail("visible guidance or its pause reason missing")
		return
	if not await _capture(prefix, "guidance"):
		_fail("guidance screenshot failed")
		return
	main.session.set_pause("user", true)
	main._guidance_button.pressed.emit()
	if not main.session.pause_reasons.has("user"):
		_fail("guidance release cleared user pause")
		return
	for index in 15:
		if main.session.pending_guidance().is_empty(): break
		main._guidance_button.pressed.emit()
	main._sync_guidance()
	if main._guidance_panel.visible or main.session.pause_reasons.has("unlock"):
		_fail("guidance did not close")
		return
	main._pause_button.pressed.emit()
	if main.session.pause_reasons.has("user"):
		_fail("continue action failed")
		return
	main._pause_button.pressed.emit()
	if not main.session.pause_reasons.has("user"):
		_fail("pause action failed")
		return
	main._pause_button.pressed.emit()
	var open: Button = main.growth_panel.get_parent().get_child(0)
	open.pressed.emit()
	if not main.growth_panel.visible:
		_fail("growth page did not open")
		return
	main._tabs.current_tab = main._pages.settings.index
	if not await _capture(prefix, "growth"):
		_fail("growth screenshot failed")
		return
	var picker: FileDialog = _find_picker(main)
	_find_button(main, "选择存档目录").pressed.emit()
	if picker == null or not picker.visible:
		_fail("save picker did not open")
		return
	if not await _capture(prefix, "picker"):
		_fail("picker screenshot failed")
		return
	picker.get_cancel_button().pressed.emit()
	var save_path: LineEdit = _find_line(main, "存档目录（完整路径）")
	save_path.text = ""
	_find_button(main, "保存").pressed.emit()
	if main.growth_status.text != "请选择可写的存档目录。":
		_fail("save failure not visible: " + main.growth_status.text)
		return
	if not await _capture(prefix, "save-failure"):
		_fail("failure screenshot failed")
		return
	main.session.notifications.record("research", "window-ops")
	var notifications = _find_notifications(main)
	if notifications == null:
		_fail("notifications panel missing")
		return
	var unread: int = main.session.notifications.unread()
	notifications._open.pressed.emit()
	if main.session.notifications.unread() != unread:
		_fail("opening archive marked a notification read")
		return
	main._tabs.current_tab = main._pages.archive.index
	var scroll: ScrollContainer = main._pages.archive.scroll
	scroll.scroll_vertical = int(notifications.position.y)
	if not await _capture(prefix, "notifications"):
		_fail("notification screenshot failed")
		return
	var notice = notifications._archive.get_child(notifications._archive.get_child_count() - 1)
	notice.get_child(2).pressed.emit()
	if main.session.notifications.unread() != unread - 1:
		_fail("read action did not clear one notification")
		return
	_find_button(main, "返回战斗").pressed.emit()
	if main.growth_panel.visible or not await _capture(prefix, "battle"):
		_fail("return to battle failed")
		return
	print("STAGE6_WINDOW_OPS_OK guidance pause/release, pause/continue, growth/return, picker, failure, notifications; prefix=", prefix)
	quit()
