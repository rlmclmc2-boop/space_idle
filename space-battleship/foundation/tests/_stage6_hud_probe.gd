extends SceneTree
const Session = preload("res://src/game_session.gd")
const Hud = preload("res://src/ui/battle_hud.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		quit(1)
		return
	call_deferred("_run")
func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)
func _run() -> void:
	var session = Session.new()
	if not session.initialize("res://generated/config.json", 79).ok:
		_fail("HUD session initialization")
		return
	var battle = session.battle
	var native_before: Dictionary = battle.persistent_state().duplicate(true)
	var logical: PackedVector2Array = battle._player_hull.duplicate()
	var muzzles: Dictionary = battle._player_muzzles.duplicate(true)
	var visual: PackedVector2Array = logical
	var expected_height: float = float(battle._player_art.static_height) * float(battle._geometry.player_display_multiplier) * float(battle._parameters["playerVisualScale" + battle._ship_key])
	if absf(battle._hull_bounds(visual).size.y - expected_height) > 0.001 or battle._player_hull != logical or battle._player_muzzles != muzzles or battle.persistent_state() != native_before:
		_fail("shared configured geometry did not match authored hull height")
		return
	for key in battle._weapon_art:
		var texture: Texture2D = battle._weapon_art[key]
		if texture.get_width() <= 0 or texture.get_height() <= 0 or not "fleet_20261019" in texture.resource_path and key != "ranked":
			_fail("approved turret texture missing " + key)
			return
	var hud = Hud.new(battle, session.economy)
	var model: Dictionary = hud.display_model()
	if model.armour != "装甲  1,000 / 1,000" or model.shield != "护盾  0 / 0" or model.armour_fraction != 1.0 or model.shield_fraction != 0.0:
		_fail("current/maximum defence labels or fractions " + str(model))
		return
	if absf(battle._hud_fraction("5e999", "1e1000") - 0.5) > 0.000001 or battle._hud_fraction("3", "0") != 0.0 or battle._hud_fraction("3", "2") != 1.0:
		_fail("extreme/zero/clamped defence bars")
		return
	for count in 20: hud.display_model()
	if battle.persistent_state() != native_before or battle._player_hull != logical or battle._player_muzzles != muzzles:
		_fail("HUD queries mutated battle")
		return
	var stats = battle.statistics()
	stats.record([{"source": "module:0", "shield": "1e3", "health": "3"}])
	if "module:" in stats.display_text() or not "武器1" in stats.display_text() or not "1,003" in stats.display_text():
		_fail("statistics name/number " + stats.display_text())
		return
	if PlayerText.number("1e3") != "1,000" or PlayerText.number("3e0") != "3" or "6.5e1" in session.equipment.price_text("weapon:0"):
		_fail("small-number display")
		return
	for resource in ["1", "2", "jewel", "chrono"]:
		var quantity: Dictionary = session.amount_api.apply("from_decimal", ["8.8e300"]).value
		if not session.economy.credit_yield(resource, quantity, 0.0, 0.0, false).ok:
			_fail("multi-currency HUD fixture")
			return
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {"wght": 450}
	font.variation_embolden = 0.8
	var cells: Array = hud.resource_layout()
	if cells.size() != 4:
		_fail("all four balances must be visible")
		return
	for index in cells.size():
		var cell: Rect2 = cells[index].rect
		if not Hud.RESOURCES_RECT.encloses(cell) or cell.intersects(Hud.DEFENCE_RECT) or cell.intersects(Hud.STATISTICS_RECT) or font.get_string_size(cells[index].text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > cell.size.x:
			_fail("resource text overlaps, clips or leaves its fixed region: " + str(cells[index]))
			return
		for previous in range(index):
			if cell.intersects(cells[previous].rect):
				_fail("resource cells overlap")
				return
	if Hud.DEFENCE_RECT.intersects(Hud.RESOURCES_RECT) or Hud.RESOURCES_RECT.intersects(Hud.STATISTICS_RECT):
		_fail("HUD regions overlap")
		return
	print("STAGE6_HUD_FOUR_BALANCES_VISIBLE_NONOVERLAPPING_FONT_BOUNDS_OK")
	print("STAGE6_HUD_READABLE_NAMES_BARS_GEOMETRY_PURITY_OK logical_height=", battle._hull_bounds(logical).size.y, " visual_height=", battle._hull_bounds(visual).size.y)
	hud.free()
	quit(0)
