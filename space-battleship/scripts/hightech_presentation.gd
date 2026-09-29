extends RefCounted
## View formatting only. Values come from the existing formula contract, never description prose.
const TYPES := {BattleGame.FURNACE:"iron",BattleGame.JEWEL_FURNACE:"jewel",BattleGame.ENERGY_FOCUS:"damage",BattleGame.DENSE_ARMOUR:"health"}

static func effect(game, key: String) -> Dictionary:
	var kind: String=TYPES.get(key,"generic")
	var formulas: Array=UIText.formulas(UIText.data_key("hightech",key,"description"))
	var values: Array[String]=[]
	var income: float=game.furnace_income_peak(-1,key==BattleGame.JEWEL_FURNACE) if key in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE] else 0.0
	for formula in formulas:
		values.append(game.format_description(game.db.data.hightech[key],str(formula),game.effective_hightech_level(key),income,income))
	return {"effect_type":kind,"value":values[1] if kind in ["iron","jewel"] and values.size()>1 else values[0] if not values.is_empty() else "—","time":values[0] if not values.is_empty() else "—"}

static func effect_text(game, key: String) -> String:
	if not game.hightech_unlocked(key):return ""
	var data := effect(game,key)
	var params := {"value":data.value}
	if data.effect_type in ["iron","jewel"]:params.time=data.time
	return UIText.t("research.effect."+str(data.effect_type),params)

static func title(game, key: String) -> String:
	if not game.hightech_unlocked(key):return UIText.t("research.unrevealed")
	return UIText.t("gem.name_level",{"item_name":UIText.data_text("hightech",key),"level":game.permanent_level_text(game.hightech_level(key),"hightech")})

static func surface(kind: String="control-surface") -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	var painted := kind in ["global-surface","detail-surface"]
	if painted:
		skin.texture=preload("res://assets/hightech/console-global-v2.tres") if kind=="global-surface" else preload("res://assets/hightech/console-detail-v2.tres")
	else:
		skin.texture=load("res://assets/hightech/"+kind+".svg")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(side,0 if painted else 16)
		skin.set_content_margin(side,4)
	return skin

static func button_skin(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var skin := StyleBoxTexture.new()
		skin.texture=preload("res://assets/hightech/button-reference-v2.tres")
		skin.modulate_color=Color(0.45,0.55,0.6,0.7) if state=="disabled" else Color(0.65,0.8,0.85) if state=="pressed" else Color(1.2,1.3,1.35) if state=="hover" else Color(1,1,1,0.35) if state=="focus" else Color.WHITE
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:skin.set_content_margin(side,4)
		button.add_theme_stylebox_override(state,skin)
