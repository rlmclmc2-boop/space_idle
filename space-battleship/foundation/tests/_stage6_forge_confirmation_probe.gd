extends SceneTree
var session
var panel

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(1); return
	call_deferred("_run")

func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("FORGE_BINDING_FAILED: " + reason)
	quit(1)
	return false

func _fingerprint() -> String:
	return JSON.stringify({"wallet": session.economy.budget(), "drones": session.hyperspace_system.warehouse().main}, "", true)

func _choose_operation(index: int) -> void:
	panel._operation.select(index)
	panel._operation.item_selected.emit(index)

func _run() -> void:
	session = load("res://src/game_session.gd").new()
	if not _check(session.initialize("res://generated/config.json", 1042).ok, "session"): return
	var hs = session.hyperspace_system
	var drone: Dictionary = {}
	for sequence in 20:
		drone = hs._generate_reward({"route": "alpha", "level": 10, "run_id": sequence + 1, "luck_state": "1"}).drone
		if not drone.is_empty(): break
	if not _check(not drone.is_empty(), "generated drone"): return
	drone.origin_quality = "gold"
	drone.legendary = false
	drone.ultimate = false
	drone.omen = false
	drone.affixes = [hs._draw_affix("laser")]
	hs._warehouse.append(drone)
	var second: Dictionary = drone.duplicate(true)
	second.id = "binding-second"
	hs._warehouse.append(second)
	for material in hs.material_ids():
		session.economy.credit_yield(material, session.amount_api.apply("from_decimal", ["1e12"]).value, 0.0, 0.0, false)
	panel = load("res://src/ui/hyperspace_panel.gd").new(session, _button)
	root.add_child(panel)
	panel._warehouse.select(0)
	var baseline: String = _fingerprint()
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired", "confirmation without preview"): return
	_choose_operation(6)
	if not _check(panel._forge(true).ok, "omen preview"): return
	if not _check(_fingerprint() == baseline, "preview advanced state"): return
	_choose_operation(7)
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired" and _fingerprint() == baseline, "operation switch accepted stale preview"): return
	_choose_operation(1)
	panel._forge_target.select(1)
	if not _check(panel._forge(true).ok, "targeted affix preview"): return
	panel._forge_target.select(2)
	panel._forge_target.item_selected.emit(2)
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired" and _fingerprint() == baseline, "target switch accepted stale preview"): return
	_choose_operation(5)
	if not _check(panel._forge(true).ok, "reroll preview"): return
	panel._forge_guaranteed.button_pressed = true
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired" and _fingerprint() == baseline, "guarantee switch accepted stale preview"): return
	_choose_operation(6)
	if not _check(panel._forge(true).ok, "selection preview"): return
	panel._warehouse.deselect_all()
	panel._warehouse.select(1)
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired" and _fingerprint() == baseline, "selection switch accepted stale preview"): return
	panel._warehouse.deselect_all()
	panel._warehouse.select(0)
	if not _check(panel._forge(true).ok, "shape preview"): return
	hs._warehouse[0].forge_revision += 1
	baseline = _fingerprint()
	if not _check(panel._forge(false).get("reason") == "ForgePreviewRequired" and _fingerprint() == baseline, "shape mutation accepted stale preview"): return
	if not _check(panel._forge(true).ok, "bound preview"): return
	var operation_id: String = panel._forge_preview.operation_id
	var result: Dictionary = panel._forge(false)
	if not _check(result.ok and hs.warehouse().main[0].omen, "bound command did not execute"): return
	var completed: String = _fingerprint()
	if not _check(operation_id == hs._last_forge.operation_id, "operation id not bound"): return
	panel._refresh()
	if not _check(panel._forge(false) == result and _fingerprint() == completed and hs._last_forge.operation_id == operation_id, "duplicate confirmation charged or rolled again"): return
	_choose_operation(7)
	if not _check(panel._forge(true).ok and panel._forge_preview.operation_id != operation_id, "new preview did not create new operation"): return
	if not _check(panel._forge(false).ok and not hs.warehouse().main[0].omen, "intentional new preview failed"): return
	print("HYPERSPACE_FORGE_PREVIEW_BINDING_INVALIDATION_AND_REPEAT_OK")
	panel.queue_free()
	await process_frame
	quit(0)

func _button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
