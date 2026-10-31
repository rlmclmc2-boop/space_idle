extends SceneTree

func descriptor(recovery: float) -> Dictionary:
	var enemies: Array = []
	for index in 3:
		enemies.append({"dead": false, "uid": index + 1, "hp": "1e9", "max_hp": "1e9", "shield": "1e9", "max_shield": "1e9",
			"x": 0.0, "y": float(100 - index * 100), "visual_key": "probe", "shieldDelay": 0.0, "shieldRecovery": recovery})
	var weapons: Array = []
	for index in 8:
		weapons.append({"kind": 1, "slot": index, "damage": "10", "interval": 0.01,
			"remaining": 0.0, "muzzle": Vector2(0, 200)})
	return {"player": {"x": 0.0, "y": 200.0}, "target_slot_center": 0.0,
		"enemies": enemies, "weapons": weapons, "defences": [{"base": "100", "maximum": "100", "layer": 1}]}

func execute(steps: int, recovery: float, visible: bool) -> Dictionary:
	var k = ClassDB.instantiate("SpaceCombatKernel")
	if not k.initialize(descriptor(recovery)):
		return {"error": "initialize"}
	k.set_damage_stats_enabled(true)
	k.enemy_views()
	var start: int = Time.get_ticks_usec()
	for step in steps:
		if not k.advance(0.05): return {"error": "advance", "step": step}
		k.take_results()
		if visible: k.enemy_views()
	var elapsed: int = Time.get_ticks_usec() - start
	var amounts: Array = k.take_damage_stats()
	var health: Array = []
	for actor in k.enemy_views(): health.append({"uid": actor.uid, "hp": actor.hp, "dead": actor.dead})
	return {"elapsed_usec": elapsed, "steps": steps, "dt": 0.05, "recovery": recovery, "visible": visible,
		"history": k.read_history(), "damage": amounts, "health": health,
		"clock": k.presentation_clock(), "persistent_sha256": JSON.stringify(k.persistent_state()).sha256_text()}

func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		push_error("extension load failed")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var recovery: float = float(args[0])
	var visible: bool = args[1] == "visible"
	var warm: Dictionary = execute(100, recovery, visible)
	var result: Dictionary = execute(2000, recovery, visible)
	if warm.has("error") or result.has("error"):
		push_error(JSON.stringify({"warm": warm, "result": result}))
		quit(1)
		return
	print("COST_JSON=", JSON.stringify(result))
	quit(0)
