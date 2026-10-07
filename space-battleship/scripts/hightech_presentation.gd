extends RefCounted
## View formatting only. Values come from the existing formula contract, never description prose.
const PARAMETERS := preload("res://scripts/parameter_text.gd")
const CHROME := preload("res://scripts/dialog_presentation.gd")
const NAVY := CHROME.NAVY
const PAPER := CHROME.PAPER
const TEAL := CHROME.TEAL
const MUTED := CHROME.MUTED
const TYPES := {BattleGame.FURNACE:"iron",BattleGame.JEWEL_FURNACE:"jewel",BattleGame.ENERGY_FOCUS:"damage",BattleGame.DENSE_ARMOUR:"health"}

static func effect(game, key: String) -> Dictionary:
	var kind: String=TYPES.get(key,"generic")
	var formulas: Array=UIText.formulas(UIText.data_key("hightech",key,"description"))
	var values: Array[String]=[]
	var income: float=game.furnace_income_peak(-1,key==BattleGame.JEWEL_FURNACE) if key in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE] else 0.0
	for formula in formulas:
		values.append(game.format_description(game.db.data.hightech[key],str(formula),game.effective_hightech_level(key),income,income))
	return {"effect_type":kind,"value":values[1] if kind in ["iron","jewel"] and values.size()>1 else values[0] if not values.is_empty() else "—","time":values[0] if not values.is_empty() else "—"}

static func effect_template(game, key: String) -> Dictionary:
	if not game.hightech_unlocked(key):return {}
	var data := effect(game,key)
	if key==BattleGame.FURNACE and game.effective_hightech_level(key)==0:
		return {"key":"research.effect.iron_unbuilt","values":{"time":data.time},"spans":{"time":{"role":"time","unit":" 秒"}}}
	var params := {"value":data.value}
	var spans := {"value":{"role":"effect"}}
	if data.effect_type in ["iron","jewel"]:
		params.time=data.time
		spans.time={"role":"time","unit":" 秒"}
		spans.value.unit=" 铁" if data.effect_type=="iron" else " 强化碎片"
	return {"key":"research.effect."+str(data.effect_type),"values":params,"spans":spans}

static func effect_text(game, key: String) -> String:
	var template := effect_template(game,key)
	return "" if template.is_empty() else UIText.t(template.key,template.values)

static func effect_markup(game, key: String) -> String:
	var template := effect_template(game,key)
	return "" if template.is_empty() else PARAMETERS.render(template.key,template.values,template.spans)

static func title(game, key: String) -> String:
	if not game.hightech_unlocked(key):return UIText.t("research.unrevealed")
	return UIText.t("gem.name_level",{"item_name":UIText.data_text("hightech",key),"level":game.permanent_level_text(game.hightech_level(key),"hightech")})

static func surface(kind: String="control-surface") -> StyleBoxFlat:
	var skin := CHROME.surface(Color("182b3b") if kind=="control-surface" else PAPER,NAVY,12)
	if kind!="control-surface":
		skin.shadow_color=Color("162735")
		skin.shadow_size=3
		skin.shadow_offset=Vector2(0,3)
	return skin

static func station_surface() -> StyleBoxFlat:
	return CHROME.surface(Color("304c60"),NAVY,4)

static func button_skin(button: Button, primary := false) -> void:
	CHROME.button_skin(button,primary)

static func label_skin(label: Label, primary := false) -> void:
	label.add_theme_font_override("font",CHROME.SHELL.face(600 if primary else 500))
	label.add_theme_color_override("font_color",NAVY if primary else MUTED)
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

static func scroll_skin(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll",CHROME.surface(Color("b3c4c0"),NAVY,3))
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		bar.add_theme_stylebox_override(state,CHROME.surface(TEAL,NAVY,3))
