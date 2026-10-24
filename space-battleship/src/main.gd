extends Node2D
const Session = preload("res://src/game_session.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
var session
var kernel
var startup_error: String = ""

func _ready() -> void:
	if not ClassDB.class_exists("SpaceCombatKernel"):
		var extension: String = OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION")
		if extension.is_empty():
			startup_error = "请先编译原生模块，再通过 run_game.ps1 启动。"
			return
		var loaded = GDExtensionManager.load_extension(extension)
		if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			startup_error = "原生模块加载失败：" + extension
			return
	session = Session.new()
	var result = session.initialize("res://generated/config.json", Time.get_ticks_usec())
	if not result.ok:
		startup_error = str(result.reason)
		return
	get_window().content_scale_size = Vector2i(int(session.geometry.view_width), int(session.geometry.view_height))
	kernel = session.kernel
	# Mode is chosen by the entry once. Display code only reads kernel data.
	if kernel.set_compact_laser_births(true) < 0:
		startup_error = "原生显示初始化失败"
		return
	result = session.start_sortie(1)
	if not result.ok:
		startup_error = str(result.reason)

func _process(dt: float) -> void:
	if session != null and startup_error.is_empty():
		session.frame(dt, DisplayServer.window_is_focused())
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		session.set_guard(not session.guard.enabled, int(session.guard.death_option))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in session.drops.keys():
			var row: Dictionary = session.drops[id]
			if event.position.distance_to(Vector2(float(row.x), float(row.y))) <= 18.0:
				session.collect_drop(int(id))
				break

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("071423"))
	var font: Font = ThemeDB.fallback_font
	if not startup_error.is_empty():
		draw_string(font, Vector2(18, 45), startup_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))
		return
	if session == null or kernel == null:
		return
	var player_point := Vector2(float(session.geometry.player_x), float(session.geometry.player_y))
	var player_hull: PackedVector2Array = Geometry.transform_hull(session.models[session.selected_ship].hull, player_point, session.player_dimensions, 0.0)
	if player_hull.size() >= 3:
		draw_colored_polygon(player_hull, Color("66d9dc"))
	var enemies: Array = kernel.enemy_views()
	for index in enemies.size():
		var actor: Dictionary = enemies[index]
		if actor.get("dead", false) or index >= session.enemy_hulls.size():
			continue
		var hull: PackedVector2Array = session.enemy_hulls[index]
		if hull.size() >= 3:
			draw_colored_polygon(hull, Color("ce6978"))
		draw_string(font, Vector2(float(actor.x) - 24, float(actor.y) + 35), str(actor.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f1d9dc"))
	for row in session.drops.values():
		draw_circle(Vector2(float(row.x), float(row.y)), 5.0, Color("ffe195") if str(row.id) != "jewel" else Color("a2afff"))
	var state: Dictionary = session.campaign
	draw_string(font, Vector2(18, 28), "关卡 %s · %s · %.0f" % [state.stage, state.state, state.distance], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ecf5ff"))
	var history: Dictionary = kernel.read_history()
	draw_string(font, Vector2(18, 53), "攻击 %s   来袭 %s" % [history.attacks, history.incoming], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9c6db"))
	var player: Dictionary = kernel.player_view()
	draw_string(font, Vector2(18, 765), "装甲 %s   护盾 %s" % [player.armour, player.shield], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b8ede6"))
	var balances: PackedStringArray = []
	for resource in session.wallet:
		var text = session.amount_api.apply("to_display", [session.wallet[resource]])
		balances.append(str(resource) + ": " + str(text.text))
	draw_string(font, Vector2(18, 795), "   ".join(balances), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffe195"))
	draw_string(font, Vector2(18, 920), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))
	if not session.last_error.is_empty():
		draw_string(font, Vector2(18, 850), session.last_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))
