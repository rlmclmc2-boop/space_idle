extends SceneTree
const PANEL := preload("res://scripts/enhancement_panel.gd")
const FORMAT := preload("res://scripts/number_format.gd")
const RICH := preload("res://scripts/parameter_text.gd")
const SHELL := preload("res://scripts/shell_presentation.gd")
var checks := 0
var failures := 0
var evidence: Array=[]
func _initialize() -> void:call_deferred("run")
func check_summary(panel, label: RichTextLabel, probability: float, description: String) -> void:
	label.text=panel.effect_overview("delayed_damage")
	var plain:=label.get_parsed_text()
	var expected:=UIText.t("enhance.overview.delayed_damage",{"value":FORMAT.compact(panel.game.enhancement_deferred_fraction()*100),"chance":FORMAT.compact(probability*100)})
	var width:=label.get_theme_font("normal_font").get_string_size(plain,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("normal_font_size")).x
	checks+=1
	if plain!=expected or width>label.size.x:
		failures+=1;printerr("FAIL: ",description," / ",plain)
func check_overview(panel, label: RichTextLabel, kind: String, active: bool, title: String) -> void:
	var g: BattleGame=panel.game
	var level: int=g.enhancement_level() if active else 0
	var args: Dictionary={}
	match kind:
		"proficiency","adaptation":
			var bonus:=roundf(g.enhancement_parameter(kind+"_growth")*level*log(1000.0)/log(g.enhancement_parameter("counter_log_base"))*g.enhancement_parameter("bonus_round_scale"))/g.enhancement_parameter("bonus_round_scale")
			args={"value":FORMAT.percentage(bonus*100)}
		"repeat":args={"chance":FORMAT.percentage(g.enhancement_parameter("repeat_probability")*100 if active else 0),"multiplier":FORMAT.percentage(100+g.enhancement_parameter("repeat_growth")*level*100)}
		"critical":args={"chance":FORMAT.percentage(g.enhancement_parameter("base_critical_rate")*100 if active else 0),"multiplier":FORMAT.percentage((g.enhancement_parameter("base_critical_multiplier")+g.enhancement_parameter("critical_growth")*level)*100 if active else 100)}
		"memory_material":args={"value":FORMAT.percentage(g.enhancement_parameter("memory_heal_fraction")*level*100/g.enhancement_parameter("memory_interval"))}
		"delayed_damage":
			var scale:=g.enhancement_parameter("deferred_percent_scale")
			var fraction:=maxf(0.0,(scale-maxf(1.0,ceilf(scale/(1.0+g.enhancement_parameter("deferred_curve_coefficient")*level))))/scale)
			args={"value":FORMAT.percentage(fraction*100),"chance":FORMAT.percentage(g.enhancement_parameter("deferred_clear_probability")*100 if active else 0)}
	label.text=panel.effect_overview(kind)
	var actual:=label.get_parsed_text()
	var expected:=UIText.t("enhance.overview."+kind,args)
	checks+=1
	evidence.append({"case":title,"kind":kind,"active":active,"actual":actual,"expected":expected})
	if actual!=expected:failures+=1;printerr("FAIL: ",title," ",kind," actual=",actual," expected=",expected)
func gate_texts(panel, label: RichTextLabel) -> void:
	var g: BattleGame=panel.game
	g.profile.enhancementAttacks=1000;g.profile.enhancementHits=1000
	for variant in 2:
		if variant==1:
			g.db.data.enhance_config.threshold_1.value=2;g.db.data.enhance_config.threshold_2.value=7;g.db.data.enhance_config.threshold_3.value=13
			g.db.data.enhance_config.proficiency_growth.value=0.13;g.db.data.enhance_config.adaptation_growth.value=0.07
		for category in ["weapons","defence"]:
			for kind in g.default_enhancement_order()[category]:
				var order: Array=g.default_enhancement_order()[category].duplicate();order.erase(kind);order.append(kind)
				g.profile.enhancementOrder[category]=order
				g.profile.enhancementBranches=g.default_enhancement_branches()
				var threshold: int=g.enhancement_effect_threshold(2)
				for spec in [[false,50,false],[true,0,false],[true,1,false],[true,threshold-1,false],[true,threshold,true]]:
					g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")] if spec[0] else []
					g.profile.cleared=[];g.rebuild_unlocks();g.profile.enhancementLevel=spec[1]
					check_overview(panel,label,kind,spec[2],"config%d unlocked%s level%d last-position"%[variant,spec[0],spec[1]])
				order.erase(kind);order.push_front(kind);g.profile.enhancementOrder[category]=order
				g.profile.enhancementLevel=g.enhancement_effect_threshold(0)
				check_overview(panel,label,kind,true,"config%d reordered active first-position"%variant)
				if kind=="adaptation":
					order.erase(kind);order.insert(1,kind);g.profile.enhancementOrder[category]=order
					var middle_gate: int=g.enhancement_effect_threshold(1)
					for spec in [[1,false],[middle_gate,true]]:
						g.profile.enhancementLevel=spec[0]
						check_overview(panel,label,kind,spec[1],"config%d adaptation second-position level%d"%[variant,spec[0]])
func run() -> void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	game.profile.cleared=range(1,61);game.profile.highestLevel=61;game.rebuild_unlocks()
	game.profile.enhancementLevel=int(db.data.enhance_config.branch_threshold_3.value)+int(db.data.enhance_config.threshold_3.value)
	game.profile.loadout={"weapons":[{"key":"laser","level":int(db.data.enhance_config.threshold_3.value)}],"defence":[{"key":"armour","level":int(db.data.enhance_config.threshold_3.value)}]}
	game.reset_player()
	var panel:=PANEL.new();panel.game=game
	var label:=RICH.create_label(root,Rect2(0,0,568,48),20,SHELL.face(500),SHELL.NAVY)
	check_summary(panel,label,float(db.data.enhance_config.deferred_clear_probability.value),"Normal buffer displays configured removal probability")
	game.set_enhancement_branch("defence","delayed_damage",2,"B")
	check_summary(panel,label,0.0,"Stable buffer displays no removal chance")
	game.set_enhancement_branch("defence","delayed_damage",3,"B")
	check_summary(panel,label,float(db.data.enhance_config.deferred_b3_forced_probability.value),"Fixed removal overrides no-removal and displays actual probability")
	game.profile.enhancementOrder.defence=["delayed_damage","memory_material","adaptation"]
	game.profile.enhancementBranches=game.default_enhancement_branches()
	game.profile.enhancementBranches.defence.delayed_damage={"2":"B","3":"B"}
	for node in [2,3]:
		var gate: int=game.enhancement_branch_threshold(node,"defence","delayed_damage")
		for level in [gate-1,gate]:
			game.profile.enhancementLevel=level
			var chance: float=game.enhancement_parameter("deferred_clear_probability") if level<game.enhancement_branch_threshold(2,"defence","delayed_damage") else 0.0
			if level>=game.enhancement_branch_threshold(3,"defence","delayed_damage"):chance=game.enhancement_parameter("deferred_b3_forced_probability")
			check_summary(panel,label,chance,"Deferred branch boundary level"+str(level))
	game.profile.enhancementOrder.weapons=["critical","repeat","proficiency"]
	game.profile.enhancementBranches.weapons.critical={"3":"B"}
	var critical_gate: int=game.enhancement_branch_threshold(3,"weapons","critical")
	for level in [critical_gate-1,critical_gate]:
		game.profile.enhancementLevel=level
		var args: Dictionary={"chance":FORMAT.percentage(game.enhancement_parameter("critical_b3_guaranteed_rate" if level>=critical_gate else "base_critical_rate")*100),"multiplier":FORMAT.percentage((game.enhancement_parameter("base_critical_multiplier")+game.enhancement_parameter("critical_growth")*level)*100)}
		if level>=critical_gate:args.underlying=FORMAT.percentage(game.enhancement_parameter("base_critical_rate")*100)
		label.text=panel.effect_overview("critical")
		var expected:=UIText.t("enhance.overview.critical_guaranteed" if level>=critical_gate else "enhance.overview.critical",args)
		checks+=1
		evidence.append({"case":"critical branch boundary level"+str(level),"actual":label.get_parsed_text(),"expected":expected})
		if label.get_parsed_text()!=expected:failures+=1;printerr("FAIL: Critical branch boundary ",level)
	gate_texts(panel,label)
	var file=FileAccess.open("res://../overview-text-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "));file.close()
	panel.free();label.queue_free();await process_frame
	print("Enhancement summary: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
