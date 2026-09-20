extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var builds := 0
	var writes: Array = []
	func build_ui() -> void:
		builds += 1
		super.build_ui()
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			writes.append(control)
		super.set_ui_value(control, property, value)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func scroll_in(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children(true):
		var found := scroll_in(child)
		if found != null:
			return found
	return null

func click(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func key(popup: PopupMenu, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.cleared = range(1, 31)
	scene.game.rebuild_unlocks()
	scene.game.start(31, false)
	scene.game.distance = 120
	scene.game.paused = true
	scene.refresh_navigation()
	await process_frame
	var picker := scene.loop_select
	var tabs := scene.equipment_tabs
	var builds := scene.builds
	var metadata := RefCounted.new()
	picker.set_item_metadata(1, metadata)
	check(picker.item_count == 32 and picker.get_item_index(31) >= 0, "All cleared stages plus current uncleared stage remain reachable")
	await click(picker)
	var popup := picker.get_popup()
	await process_frame
	check(popup.visible, "Real click opens warp popup")
	var scroll := scroll_in(popup)
	check(scroll != null and scroll.get_v_scroll_bar().visible, "Long warp list has visible scrollbar")
	var bar := scroll.get_v_scroll_bar()
	var row_height := bar.max_value / picker.item_count
	print("Warp geometry: popup=", popup.size, " row=", row_height, " page=", bar.page, " total=", bar.max_value)
	check(absf(bar.page / row_height - 10.0) < 0.1, "Popup viewport shows ten rows")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/warp-top.png")
	popup.get_texture().get_image().save_png("res://.runtime/warp-popup.png")
	var before := bar.value
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(60, 80)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	popup.push_input(wheel, true)
	await process_frame
	check(bar.value > before, "Real mouse wheel scrolls beyond initial options")
	var scroll_value := bar.value
	scene.writes.clear()
	scene.refresh_navigation()
	check(bar.value == scroll_value and scene.writes.is_empty() and picker.get_item_metadata(1) == metadata, "Unchanged refresh preserves scroll, entries and properties")
	for i in 31:
		await key(popup, KEY_DOWN)
	check(popup.get_focused_item() == picker.item_count - 1 and bar.value > 0, "Keyboard reaches current stage at end of scroll list")
	await RenderingServer.frame_post_draw
	popup.get_texture().get_image().save_png("res://.runtime/warp-bottom.png")
	await key(popup, KEY_ENTER)
	check(scene.game.stage == 31 and scene.game.distance == 0 and scene.game.group_index == 0, "Selecting current uncleared stage restarts from origin")
	scene.game.distance = 150
	scene.game.paused = true
	await click(picker)
	if popup.get_focused_item() != picker.item_count - 1:
		await key(popup, KEY_UP)
	await key(popup, KEY_ENTER)
	check(scene.game.distance == 0, "Reselecting identical option performs another warp")
	check(scene.builds == builds and scene.loop_select == picker and scene.equipment_tabs == tabs, "Warp keeps unrelated UI instances")
	scene.game.start(2, false)
	scene.refresh_navigation()
	check(picker.get_item_index(31) == -1 and picker.get_item_metadata(1) == metadata, "Stage change removes only obsolete uncleared destination")
	print("Warp UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
