extends Node2D
## Reads current native defence values. Bars do not own or change combat state.
const PlayerText = preload("res://src/ui/player_text.gd")
const DEFENCE_RECT := Rect2(12, 708, 548, 122)
const RESOURCES_RECT := Rect2(12, 838, 548, 56)
const STATISTICS_RECT := Rect2(12, 902, 548, 25)
var _economy
var _battle

func _init(battle, economy = null) -> void:
	_battle = battle
	_economy = economy

func _process(_dt: float) -> void:
	queue_redraw()

func display_model() -> Dictionary:
	var values: Dictionary = _battle.hud_values()
	return {"armour": "装甲  %s / %s" % [PlayerText.number(str(values.armour)), PlayerText.number(str(values.max_armour))],
		"shield": "护盾  %s / %s" % [PlayerText.number(str(values.shield)), PlayerText.number(str(values.max_shield))],
		"armour_fraction": values.armour_fraction, "shield_fraction": values.shield_fraction}

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var model: Dictionary = display_model()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("091a29", 0.94)
	panel.border_color = Color("31546a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	draw_style_box(panel, DEFENCE_RECT)
	draw_string(font, Vector2(28, 731), "舰船防御", HORIZONTAL_ALIGNMENT_LEFT, 500, 15, Color("e9f4fa"))
	_bar(font, str(model.armour), float(model.armour_fraction), 752.0, Color("edc878"))
	_bar(font, str(model.shield), float(model.shield_fraction), 794.0, Color("69d8ec"))
	if _economy != null:
		draw_style_box(panel, RESOURCES_RECT)
		for row in resource_layout():
			draw_string(font, row.rect.position + Vector2(0, 18), row.text, HORIZONTAL_ALIGNMENT_LEFT, row.rect.size.x, 14, Color("ffe195"))
	var statistics: String = _battle.statistics().display_text()
	if not statistics.is_empty():
		draw_string(font, STATISTICS_RECT.position + Vector2(8, 18), statistics, HORIZONTAL_ALIGNMENT_LEFT, 532, 14, Color("c1d5f0"))

func _bar(font: Font, label: String, fraction: float, baseline: float, colour: Color) -> void:
	draw_string(font, Vector2(28, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, 440, 16, Color("e5f0f7"))
	draw_string(font, Vector2(28, baseline), "%d%%" % roundi(fraction * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 516, 15, colour)
	var track := Rect2(28, baseline + 8, 516, 11)
	draw_rect(track, Color("1b3547"))
	if fraction > 0.0: draw_rect(Rect2(track.position, Vector2(track.size.x * fraction, track.size.y)), colour)
	draw_rect(track, Color("426176"), false, 1.0)

func resource_layout() -> Array:
	var layout: Array = []
	if _economy == null: return layout
	var rows: Array = _economy.balance_rows()
	# The game wallet has four currencies; two columns prevent a long single
	# line from crossing the defence card or the damage summary.
	for index in rows.size():
		var cell := Rect2(24 + (index % 2) * 268, 844 + (index / 2) * 24, 256, 24)
		layout.append({"id": rows[index].id, "text": rows[index].text, "rect": cell})
	return layout
