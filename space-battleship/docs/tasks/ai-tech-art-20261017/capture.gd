extends SceneTree

const PAGE = preload("res://scripts/ai_tech_factory_page.gd")
const IDS = ["ai_singularity", "weapon_accuracy", "equipment_reinforcement", "resource_refining", "fragment_condensation", "equipment_precision", "uranium_extraction", "joint_integration"]
const NAMES = ["AI奇点", "武器精度", "装备强化", "资源精炼", "强化碎片凝聚", "装备精制", "铀提炼", "联合一体化"]

var page: Control
var viewport: SubViewport
var events: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _snapshot(selected: String, working: bool) -> Dictionary:
	var items := []
	for i in IDS.size():
		items.append({"id": IDS[i], "tier": "independent" if i == 0 else ("final" if i == 7 else "basic"), "name": NAMES[i], "level": 0, "effect_text": "科技效果由游戏数据提供", "requirement_text": "研发条件由游戏数据提供", "state_text": "可研究", "can_research": true, "action_text": "选择研究"})
	return {"technologies": items, "active_id": "weapon_accuracy" if working else "", "display_id": selected, "researching": working, "progress": 0.42 if working else 0.0, "remaining_text": "示例时间", "status_text": "研发中" if working else "当前无研究", "ai_text": "AI 0", "speed_text": "速度由游戏提供", "iron_investment": "0", "uranium_investment": "0"}

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1344, 1160))
	var out := ProjectSettings.globalize_path("res://docs/tasks/ai-tech-art-20261017/evidence")
	DirAccess.make_dir_recursive_absolute(out)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1344, 1160)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	page = PAGE.new()
	viewport.add_child(page)
	page.setup()
	page.research_requested.connect(func(id: String): events.append("research:" + id))
	page.investment_requested.connect(func(resource: String, amount: int): events.append("invest:" + resource + ":" + str(amount)))
	page.set_snapshot(_snapshot("weapon_accuracy", false))
	await _frame()
	_capture(out + "/main-idle.png")
	for id in IDS:
		page.set_snapshot(_snapshot(id, false))
		await _frame()
		_capture(out + "/device-%s.png" % id)
	page.set_snapshot(_snapshot("weapon_accuracy", true))
	for i in 10:
		await _frame()
	_capture(out + "/main-active.png")
	for i in 12:
		for skipped in 4:
			await _frame()
		_capture(out + "/motion-%02d.png" % i)
	_click(Vector2(1185, 55))
	await _frame()
	assert(page.drawer_open)
	_capture(out + "/drawer.png")
	_click(Vector2(1067, 768))
	await _frame()
	assert(events.has("research:equipment_reinforcement"))
	_click(Vector2(1150, 104))
	await _frame()
	assert(not page.drawer_open)
	page.set_snapshot(_snapshot("fragment_condensation", false))
	await _frame()
	_capture(out + "/condenser.png")
	page.iron_edit.text = "12"
	page.iron_edit.text_submitted.emit("12")
	var file := FileAccess.open(out + "/events.txt", FileAccess.WRITE)
	file.store_string("\n".join(events) + "\n")
	file.close()
	quit()

func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(path: String) -> void:
	viewport.get_texture().get_image().save_png(path)

func _click(position: Vector2) -> void:
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		viewport.push_input(event, true)
