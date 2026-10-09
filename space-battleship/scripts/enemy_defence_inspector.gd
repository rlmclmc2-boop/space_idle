extends Control
## Read-only, local inspection. Colour is never used to infer combat resistance.
const N := preload("res://scripts/growth_number.gd")
var host: Node
var hint: Label
var panel: Panel
var description: Label
var elapsed := 0.0
var selected_enemy: Dictionary = {}

func setup(owner_ui: Node) -> void:
	host = owner_ui
	name = "EnemyDefenceInspector"
	position = host.BATTLE_ORIGIN
	size = host.BATTLE_VIEW_SIZE
	z_index = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.text = UIText.t("battle.enemy_defence.hint")
	hint.position = Vector2(14,size.y-32)
	hint.add_theme_font_override("font",host.font)
	hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_color_override("font_color",Color("bedbdc"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	panel = Panel.new()
	panel.position = Vector2(14,size.y-245)
	panel.size = Vector2(510,148)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",host.style(Color("243d50"),Color("83cfcb")))
	add_child(panel)
	description = Label.new()
	description.position = Vector2(14,12)
	description.size = Vector2(482,124)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font",host.font)
	description.add_theme_font_size_override("font_size",20)
	description.add_theme_color_override("font_color",Color("ecebdc"))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(description)
	panel.hide()

func available() -> bool:
	return is_instance_valid(host) and host.game.state==BattleGame.State.COMBAT and not host.help_open and host.game.pending_unlocks.is_empty()

func resistance_text(value: int) -> String:
	if value not in [1,2]:return UIText.t("battle.enemy_defence.neutral")
	return UIText.t("battle.enemy_defence.resistance",{"type":UIText.t("equipment.energy" if value==1 else "equipment.physical")})

func defence_text(enemy: Dictionary) -> String:
	var armour := UIText.t("battle.enemy_defence.armour_remaining",{"value":remaining_text(enemy.get("hp",0)),"resistance":resistance_text(int(enemy.get("armourType",0)))})
	var shield := UIText.t("battle.enemy_defence.no_shield")
	if N.compare(enemy.get("max_shield",0),0)>0:
		shield = UIText.t("battle.enemy_defence.shield_remaining" if N.compare(enemy.get("shield",0),0)>0 else "battle.enemy_defence.broken_shield_remaining",{"value":remaining_text(enemy.get("shield",0)),"resistance":resistance_text(int(enemy.get("shieldType",0)))})
	return UIText.t("battle.enemy_defence.title")+"\n"+armour+"\n"+shield

func remaining_text(value: Variant) -> String:
	# Presentation only: positive fractions still represent a surviving layer.
	return NumberFormat.compact(N.ceiling(N.maximum(value,0)))

func enemy_at(point: Vector2) -> Dictionary:
	# Input/poll queries run outside the draw callback. Scope shared entry work
	# to this synchronous hit-test and restore any caller's cache afterwards.
	var previous_active: bool = host.enemy_entry_batch_active
	var previous_time: float = host.enemy_entry_distance_time
	var previous_distance: float = host.enemy_entry_distance_value
	host.enemy_entry_batch_active = true
	host.enemy_entry_distance_time = -INF
	var found: Dictionary = {}
	for enemy in host.game.enemies:
		if N.compare(enemy.get("hp",0),0)<=0:continue
		var centre: Vector2 = host.enemy_render_position(enemy)
		var width: float = host.enemy_render_width_at_y(enemy,centre.y)
		if Rect2(centre-Vector2(width/2,width),Vector2(width,width*2)).grow(5).has_point(point):
			found=enemy
			break
	host.enemy_entry_batch_active = previous_active
	host.enemy_entry_distance_time = previous_time
	host.enemy_entry_distance_value = previous_distance
	return found

func refresh_at(point: Vector2) -> void:
	var enabled := available()
	host.set_ui_value(hint,"visible",enabled)
	selected_enemy = enemy_at(point) if enabled and Rect2(Vector2.ZERO,size).has_point(point) else {}
	host.set_ui_value(panel,"visible",not selected_enemy.is_empty())
	if not selected_enemy.is_empty():host.set_ui_value(description,"text",defence_text(selected_enemy))

func _input(event: InputEvent) -> void:
	if not is_instance_valid(panel):return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		refresh_at(get_global_transform_with_canvas().affine_inverse()*event.position)

func _process(delta: float) -> void:
	if not is_instance_valid(panel):return
	elapsed += delta
	if elapsed<0.2:return
	elapsed=0.0
	# A hovered moving ship can leave the cursor; a broken shield changes the
	# currently exposed layer. Poll only this small view, never settle shields.
	refresh_at(get_local_mouse_position())
