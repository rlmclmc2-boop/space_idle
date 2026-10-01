extends SceneTree
const PANEL := preload("res://scripts/enhancement_panel.gd")
const FORMAT := preload("res://scripts/number_format.gd")
const RICH := preload("res://scripts/parameter_text.gd")
const SHELL := preload("res://scripts/shell_presentation.gd")
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check_summary(panel, label: RichTextLabel, probability: float, description: String) -> void:
	label.text=panel.effect_overview("delayed_damage")
	var plain:=label.get_parsed_text()
	var expected:=UIText.t("enhance.overview.delayed_damage",{"value":FORMAT.compact(panel.game.enhancement_deferred_fraction()*100),"chance":FORMAT.compact(probability*100)})
	var width:=label.get_theme_font("normal_font").get_string_size(plain,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("normal_font_size")).x
	checks+=1
	if plain!=expected or width>label.size.x:
		failures+=1;printerr("FAIL: ",description," / ",plain)
func run() -> void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	game.profile.cleared=range(1,61);game.profile.highestLevel=61;game.rebuild_unlocks()
	game.profile.enhancementLevel=int(db.data.enhance_config.branch_threshold_3.value)
	game.profile.loadout={"weapons":[{"key":"laser","level":int(db.data.enhance_config.threshold_3.value)}],"defence":[{"key":"armour","level":int(db.data.enhance_config.threshold_3.value)}]}
	game.reset_player()
	var panel:=PANEL.new();panel.game=game
	var label:=RICH.create_label(root,Rect2(0,0,568,48),20,SHELL.face(500),SHELL.NAVY)
	check_summary(panel,label,float(db.data.enhance_config.deferred_clear_probability.value),"Normal buffer displays configured removal probability")
	game.set_enhancement_branch("defence","delayed_damage",2,"B")
	check_summary(panel,label,0.0,"Stable buffer displays no removal chance")
	game.set_enhancement_branch("defence","delayed_damage",3,"B")
	check_summary(panel,label,float(db.data.enhance_config.deferred_b3_forced_probability.value),"Fixed removal overrides no-removal and displays actual probability")
	panel.free();label.queue_free();await process_frame
	print("Enhancement summary: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
