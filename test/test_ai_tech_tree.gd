extends SceneTree
const AITech = preload("res://scripts/ai_tech_tree.gd")
const VIEW = preload("res://scripts/ai_tech_view_model.gd")

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func near(a: float, b: float) -> bool:
	return absf(a-b) <= maxf(1.0,absf(b))*0.000001

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var page_script = load("res://scripts/ai_tech_factory_page.gd")
	check(page_script != null and page_script.can_instantiate(), "AI technology page compiles")
	var db := ShipDatabase.new()
	check(db.data.unlock.values().all(func(row):return str(row.type)!="hightech"), "retired scientist tutorial unlocks are absent")
	var g := BattleGame.new(db,false)
	check(g.tech_tree_snapshot().ai_count == 1 and g.tech_tree_snapshot().status == "idle", "initial AI and idle state")
	var view: Dictionary = VIEW.snapshot(g)
	check(str(view.technologies[0].generation_text).contains("Lv.0") and str(view.technologies[0].generation_text).contains("AI"), "page header shows initial level and actual AI count")
	check(view.technologies.size() == 8 and view.status_text == "暂无研究，请选择科技", "page has eight configured technologies and idle prompt")
	check(VIEW.model_id("equipment_precision") == "equipment_finishing" and VIEW.model_id("joint_integration") == "unification", "art IDs map to configured IDs")
	check(near(AITech.required(g,"singularity"),60.0), "first level time")
	check(g.select_tech("singularity"), "select singularity")
	g.advance_hightech(60.0)
	check(g.hightech_level("singularity") == 1 and near(AITech.required(g,"singularity"),108.0), "continuous research and geometric time")
	check(near(g.tech_tree_snapshot().speed,1.1), "AI speed uses (N+9)/10")
	g.advance_hightech(10.0)
	var saved_singularity := float(g.profile.aiTechProgress.singularity)
	check(g.select_tech("weapon_accuracy") and g.select_tech("singularity") and near(float(g.profile.aiTechProgress.singularity),saved_singularity), "switch preserves independent progress")
	var paid := BattleGame.new(db,false)
	paid.profile.resources = {"1":100.0,"2":10.0}
	paid.set_tech_input("1",100)
	paid.set_tech_input("2",10)
	paid.select_tech("weapon_accuracy")
	paid.advance_hightech(1.0)
	check(near(float(paid.profile.aiTechProgress.weapon_accuracy),1.5*1.25), "iron and uranium factors multiply")
	check(near(float(paid.profile.resources["1"]),0.0) and near(float(paid.profile.resources["2"]),0.0), "both currencies paid without debt")
	paid.profile.resources["2"] = 20.0
	paid.advance_hightech(1.0)
	check(near(float(paid.profile.aiTechProgress.weapon_accuracy),1.5*1.25+1.25), "one shortage keeps the other acceleration")
	paid.profile.resources["1"] = 100.0
	paid.advance_hightech(1.0)
	check(near(float(paid.profile.aiTechProgress.weapon_accuracy),1.5*1.25+1.25+1.5*1.25), "configured input resumes after balance recovers")
	var gate := BattleGame.new(db,false)
	check(not bool(AITech.eligibility(gate,"equipment_finishing").ok), "core starts locked")
	gate.profile.aiTechLevels = {"weapon_accuracy":11,"equipment_reinforcement":11}
	check(bool(AITech.eligibility(gate,"equipment_finishing").ok), "first core threshold is 11")
	gate.profile.aiTechLevels.equipment_finishing = 1
	check(not bool(AITech.eligibility(gate,"equipment_finishing").ok), "second core threshold is 21")
	gate.profile.aiTechLevels.weapon_accuracy = 21
	gate.profile.aiTechLevels.equipment_reinforcement = 21
	check(bool(AITech.eligibility(gate,"equipment_finishing").ok), "second core threshold unlocks at 21")
	gate.profile.aiTechLevels.equipment_finishing = 0
	gate.profile.aiTechLevels.weapon_accuracy = 11
	gate.profile.aiTechLevels.equipment_reinforcement = 11
	check(gate.select_tech("equipment_finishing"), "first core level can be selected")
	gate.advance_hightech(1800.0)
	check(gate.hightech_level("equipment_finishing") == 1 and gate.profile.aiTechActive == "", "next core gate stops continuous research")
	check(not bool(AITech.eligibility(gate,"fragment_condensation").ok), "fragments require enhancement unlock")
	check(near(AITech.peak_factor(gate),1.0), "ultimate zero has no effect")
	gate.profile.aiTechLevels.unification = 2
	gate.profile.aiIncomePeak = {}
	check(near(AITech.peak_factor(gate),2.0), "unavailable income uses factor one")
	gate.profile.aiIncomePeak = {"1":0.0,"2":0.0,"jewel":0.0}
	check(near(AITech.peak_factor(gate),2.0), "zero income uses factor floor")
	gate.profile.aiIncomePeak["1"] = 1e-30
	check(near(AITech.peak_factor(gate),2.0), "tiny positive income uses factor floor")
	gate.profile.aiIncomePeak["1"] = 0.5
	check(near(AITech.peak_factor(gate),2.0), "subunit income uses factor floor")
	gate.profile.aiIncomePeak["1"] = 1.0
	check(near(AITech.peak_factor(gate),2.0), "unit income keeps factor one")
	gate.profile.aiIncomePeak["1"] = 1000.0
	check(near(AITech.peak_factor(gate),3.2), "income above one follows logarithmic factor")
	gate.profile.aiIncomePeak = {"1":1000.0,"2":100.0,"jewel":10.0}
	check(near(AITech.peak_factor(gate),5.376), "historical peak formula")
	gate.profile.aiIncomePeak = {"1":0.1,"2":0.0,"jewel":0.0}
	check(near(AITech.peak_factor(gate),2.0), "subunit income does not reduce the combined multiplier")
	var combat := BattleGame.new(db,false)
	var base_stats := {}
	for key in BattleGame.WEAPON_KEYS + BattleGame.DEFENSE_KEYS:base_stats[key] = float(combat.equipment_stat(key,1))
	combat.profile.aiTechLevels = {"weapon_accuracy":2,"equipment_finishing":1}
	combat.invalidate_stat_cache()
	for key in BattleGame.WEAPON_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.1*1.1*1.25)), "shared weapon effect: "+key)
	for key in BattleGame.DEFENSE_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.25)), "shared durability effect: "+key)
	combat.profile.hightechLevels = {BattleGame.ENERGY_FOCUS:100}
	combat.invalidate_stat_cache()
	check(near(float(combat.equipment_stat("laser",1)),ceilf(float(base_stats.laser)*1.1*1.1*1.25)), "retired technology does not stack")
	check(not combat.generate_scientist(), "retired AI purchase is disabled")
	combat.profile.aiTechLevels.weapon_accuracy = 10000
	check(is_inf(AITech.required(combat,"weapon_accuracy")), "large levels do not overflow time")
	var restored := BattleGame.new(db,false)
	paid.profile.hightechSavedAt = Time.get_unix_time_from_system()-3600.0
	restored.load_hightech(paid.profile.duplicate(true))
	check(restored.profile.aiTechActive == paid.profile.aiTechActive and near(float(restored.profile.aiTechProgress.weapon_accuracy),float(paid.profile.aiTechProgress.weapon_accuracy)), "research restores without offline settlement")
	print("AI_TECH_TREE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
