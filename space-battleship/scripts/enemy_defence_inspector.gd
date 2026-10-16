extends Control
## Read-only, local inspection. Colour is never used to infer combat resistance.
const N := preload("res://scripts/growth_number.gd")
var host: Node
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
	panel = Panel.new()
	panel.position = Vector2(14,size.y-181)
	panel.size = Vector2(510,84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",host.style(Color("243d50"),Color("83cfcb")))
	add_child(panel)
	description = Label.new()
	description.position = Vector2(14,12)
	description.size = Vector2(482,62)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font",host.font)
	description.add_theme_font_size_override("font_size",20)
	description.add_theme_color_override("font_color",Color("ecebdc"))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(description)
	panel.hide()

func available() -> bool:
	return is_instance_valid(host) and host.game.state==BattleGame.State.COMBAT and not host.help_open and host.game.pending_unlocks.is_empty()

func defence_text(enemy: Dictionary) -> String:
	var result := UIText.t("battle.enemy_status.armour",{"current":host.number(enemy.hp),"maximum":host.number(enemy.max_hp)})
	if N.compare(enemy.get("max_shield",0),0)>0:
		result += " · "+UIText.t("battle.enemy_status.shield",{"current":host.number(enemy.shield),"maximum":host.number(enemy.max_shield)})
	if int(enemy.get("reactiveReduction",0))==1:
		result += "\n"+UIText.t("battle.enemy_defence.reactive_status",{"percent":str(roundi((1.0-float(enemy.get("reactive_multiplier",1.0)))*100.0))})
	return result

func enemy_at(point: Vector2) -> Dictionary:
	for enemy in host.game.enemies:
		if N.compare(enemy.get("hp",0),0)<=0:continue
		var centre: Vector2 = host.enemy_render_position(enemy)
		var width: float = host.enemy_render_width(enemy)
		if Rect2(centre-Vector2(width/2,width),Vector2(width,width*2)).grow(5).has_point(point):return enemy
	return {}

func refresh_at(point: Vector2) -> void:
	var enabled := available()
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
