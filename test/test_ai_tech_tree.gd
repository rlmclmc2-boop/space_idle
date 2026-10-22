extends SceneTree
const AITech = preload("res://scripts/ai_tech_tree.gd")
const VIEW = preload("res://scripts/ai_tech_view_model.gd")

class RefusedHandoff:
	extends RefCounted
	func handoff_to_legacy(_game,_reason)->bool:return false

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func near(a: float, b: float) -> bool:
	return absf(a-b) <= maxf(1.0,absf(b))*0.000001

func unlock_factory(game: BattleGame) -> void:
	game.profile.cleared = [3,4]
	game.rebuild_unlocks()


func fund(game: BattleGame, resources: Dictionary) -> void:
	var snapshot := game.economy.save_data()
	snapshot.resources = resources.duplicate(true)
	check(game.economy.install_snapshot(snapshot), "Fixture funds are valid")

func research_fixture(game: BattleGame, field: String, value: Variant, key: String="") -> void:
	var data := game.research.save_data()
	if key.is_empty():
		data[field] = value.duplicate(true) if value is Dictionary else value
		if field == "aiIncomePeak":
			for id in ["1","2","jewel"]:
				if not data[field].has(id):data[field][id]=0.0
	else:data[field][key] = value
	check(game.research.install_snapshot(data,game.db.data.ai_tech_tree),"Valid research fixture installs")
	game.invalidate_stat_cache()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var page_script = load("res://scripts/ai_tech_factory_page.gd")
	check(page_script != null and page_script.can_instantiate(), "AI technology page compiles")
	var db := ShipDatabase.new()
	check(db.data.unlock.values().filter(func(row):return str(row.type)=="hightech").size()==4, "original hightech gate rows remain")
	var g := BattleGame.new(db,false)
	check(not g.ai_tech_factory_unlocked() and not g.select_tech("singularity") and not g.set_tech_input("1",10), "new save cannot open, research, or invest in factory")
	check(not g.available_unlocks().any(func(id):return str(id).begins_with("hightech/")), "obsolete scientist notices stay hidden")
	g.profile.cleared = [3]
	g.rebuild_unlocks()
	check(g.ai_tech_factory_unlocked(), "cleared stage 3 opens replacement factory")
	check(not bool(g.research.eligibility(g,"weapon_accuracy").ok) and bool(g.research.eligibility(g,"resource_refining").ok),"original stage-four weapon gate remains")
	check(VIEW.snapshot(g).technologies.size()==2,"stage three exposes only AI and iron research")
	g.profile.cleared.append(4)
	g.rebuild_unlocks()
	check(not bool(g.research.eligibility(g,"fragment_condensation").ok),"fragment research retains original stage-twelve gate")
	check(g.tech_tree_snapshot().ai_count == 1 and g.tech_tree_snapshot().status == "idle", "initial AI and idle state")
	var view: Dictionary = VIEW.snapshot(g)
	check(str(view.technologies[0].generation_text).contains("Lv.0") and str(view.technologies[0].generation_text).contains("AI"), "page header shows initial level and actual AI count")
	check(view.technologies.size() == 4 and view.status_text == "暂无研究，请选择科技", "page has eight configured technologies and idle prompt")
	g.profile.cleared.append(12)
	g.rebuild_unlocks()
	check(bool(g.research.eligibility(g,"fragment_condensation").ok) and VIEW.snapshot(g).technologies.size()==5,"stage twelve exposes fragment research")
	check(VIEW.model_id("equipment_precision") == "equipment_finishing" and VIEW.model_id("joint_integration") == "unification", "art IDs map to configured IDs")
	var singularity_row: Dictionary = db.data.ai_tech_tree["singularity"]
	check(float(singularity_row.base_seconds)==60.0,"AI singularity first level follows the 60-second specification")
	var first_seconds := float(singularity_row.base_seconds) * pow(float(singularity_row.growth), 0.0)
	var next_seconds := float(singularity_row.base_seconds) * pow(float(singularity_row.growth), 1.0)
	check(near(g.research.required(g,"singularity"),first_seconds), "first level time follows the current table")
	check(g.select_tech("singularity"), "select singularity")
	g.advance_hightech(first_seconds)
	check(g.hightech_level("singularity") == 1 and near(g.research.required(g,"singularity"),next_seconds), "continuous research and geometric time follow the current table")
	var expected_ai_after_one_level := 1 + 1
	check(near(g.tech_tree_snapshot().speed,float(expected_ai_after_one_level+9)/10.0), "AI speed uses (N+9)/10")
	g.advance_hightech(10.0)
	var saved_singularity := float(g.research.progress("singularity"))
	check(g.select_tech("weapon_accuracy") and g.select_tech("singularity") and near(float(g.research.progress("singularity")),saved_singularity), "switch preserves independent progress")
	var paid := BattleGame.new(db,false)
	unlock_factory(paid)
	fund(paid,{"1":100.0,"2":10.0})
	paid.set_tech_input("1",100)
	paid.set_tech_input("2",10)
	paid.select_tech("weapon_accuracy")
	paid.advance_hightech(1.0)
	check(near(float(paid.research.progress("weapon_accuracy")),1.5*1.25), "iron and uranium factors multiply")
	check(near(float(paid.economy.balance("1")),0.0) and near(float(paid.economy.balance("2")),0.0), "both currencies paid without debt")
	paid.economy.credit("2",20.0)
	paid.advance_hightech(1.0)
	check(near(float(paid.research.progress("weapon_accuracy")),1.5*1.25+1.25), "one shortage keeps the other acceleration")
	paid.economy.credit("1",100.0)
	paid.advance_hightech(1.0)
	check(near(float(paid.research.progress("weapon_accuracy")),1.5*1.25+1.25+1.5*1.25), "configured input resumes after balance recovers")
	var gate := BattleGame.new(db,false)
	unlock_factory(gate)
	check(not bool(gate.research.eligibility(gate,"equipment_finishing").ok), "core starts locked")
	research_fixture(gate,"aiTechLevels",{"weapon_accuracy":11,"equipment_reinforcement":11})
	check(bool(gate.research.eligibility(gate,"equipment_finishing").ok), "first core threshold is 11")
	research_fixture(gate,"aiTechLevels",1,"equipment_finishing")
	check(not bool(gate.research.eligibility(gate,"equipment_finishing").ok), "second core threshold is 21")
	research_fixture(gate,"aiTechLevels",21,"weapon_accuracy")
	research_fixture(gate,"aiTechLevels",21,"equipment_reinforcement")
	check(bool(gate.research.eligibility(gate,"equipment_finishing").ok), "second core threshold unlocks at 21")
	research_fixture(gate,"aiTechLevels",0,"equipment_finishing")
	research_fixture(gate,"aiTechLevels",11,"weapon_accuracy")
	research_fixture(gate,"aiTechLevels",11,"equipment_reinforcement")
	check(gate.select_tech("equipment_finishing"), "first core level can be selected")
	gate.advance_hightech(1800.0)
	check(gate.hightech_level("equipment_finishing") == 1 and gate.research.selected() == "", "next core gate stops continuous research")
	check(not bool(gate.research.eligibility(gate,"fragment_condensation").ok), "fragments require enhancement unlock")
	check(near(gate.research.peak_factor(gate),1.0), "ultimate zero has no effect")
	research_fixture(gate,"aiTechLevels",2,"unification")
	research_fixture(gate,"aiIncomePeak",{})
	check(near(gate.research.peak_factor(gate),2.0), "unavailable income uses factor one")
	research_fixture(gate,"aiIncomePeak",{"1":0.0,"2":0.0,"jewel":0.0})
	check(near(gate.research.peak_factor(gate),2.0), "zero income uses factor floor")
	research_fixture(gate,"aiIncomePeak",1e-30,"1")
	check(near(gate.research.peak_factor(gate),2.0), "tiny positive income uses factor floor")
	research_fixture(gate,"aiIncomePeak",0.5,"1")
	check(near(gate.research.peak_factor(gate),2.0), "subunit income uses factor floor")
	research_fixture(gate,"aiIncomePeak",1.0,"1")
	check(near(gate.research.peak_factor(gate),2.0), "unit income keeps factor one")
	research_fixture(gate,"aiIncomePeak",1000.0,"1")
	check(near(gate.research.peak_factor(gate),3.2), "income above one follows logarithmic factor")
	research_fixture(gate,"aiIncomePeak",{"1":1000.0,"2":100.0,"jewel":10.0})
	check(near(gate.research.peak_factor(gate),5.376), "historical peak formula")
	research_fixture(gate,"aiIncomePeak",{"1":0.1,"2":0.0,"jewel":0.0})
	check(near(gate.research.peak_factor(gate),2.0), "subunit income does not reduce the combined multiplier")
	var combat := BattleGame.new(db,false)
	var base_stats := {}
	for key in BattleGame.WEAPON_KEYS + BattleGame.DEFENSE_KEYS:base_stats[key] = float(combat.equipment_stat(key,1))
	research_fixture(combat,"aiTechLevels",{"weapon_accuracy":2,"equipment_finishing":1})
	combat.invalidate_stat_cache()
	for key in BattleGame.WEAPON_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.1*1.1*1.25)), "shared weapon effect: "+key)
	for key in BattleGame.DEFENSE_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.25)), "shared durability effect: "+key)
	var original_factor:float=db.data.ai_tech_tree.weapon_accuracy.factor
	db.data.ai_tech_tree.weapon_accuracy.factor=1.2
	check(near(float(combat.research.income_factor(combat,"weapon_damage")),1.2*1.2*1.25),"contribution cache follows changed configuration without global clearing")
	db.data.ai_tech_tree.weapon_accuracy.factor=original_factor
	combat.profile.hightechLevels = {BattleGame.ENERGY_FOCUS:100}
	combat.invalidate_stat_cache()
	check(near(float(combat.equipment_stat("laser",1)),ceilf(float(base_stats.laser)*1.1*1.1*1.25)), "retired technology does not stack")
	check(not combat.generate_scientist(), "retired AI purchase is disabled")
	research_fixture(combat,"aiTechLevels",10000,"weapon_accuracy")
	check(is_inf(combat.research.required(combat,"weapon_accuracy")), "large levels do not overflow time")
	var restored := BattleGame.new(db,false)
	unlock_factory(restored)
	paid.profile.hightechSavedAt = Time.get_unix_time_from_system()-3600.0
	restored.load_hightech(paid.portable_save_data())
	check(restored.research.selected() == paid.research.selected() and near(float(restored.research.progress("weapon_accuracy")),float(paid.research.progress("weapon_accuracy"))), "research restores without offline settlement")
	check(not paid.profile.has("aiTechLevels") and not paid.profile.has("aiIncomePeak") and not paid.profile.has("aiTechActive"),"profile no longer owns research")
	var detached:=paid.research.save_data();detached.aiTechProgress.weapon_accuracy=0
	check(paid.research.progress("weapon_accuracy")>0,"research snapshots cannot mutate authority")
	var atomic:=BattleGame.new(db,false);unlock_factory(atomic)
	fund(atomic,{"1":100000.0,"2":100000.0});atomic.set_tech_input("1",100);atomic.set_tech_input("2",100)
	atomic.select_tech("weapon_accuracy")
	var plan:Dictionary=atomic.research.prepare_advance(atomic,100000.0)
	var original:Dictionary=atomic.research.save_data();var original_wallet:=atomic.economy.resources()
	check(plan.completed and atomic.research.save_data()==original and atomic.economy.resources()==original_wallet,"research preparation changes neither progress nor wallet")
	atomic.native_execution=RefusedHandoff.new();atomic.advance_hightech(100000.0)
	check(atomic.research.save_data()==original and atomic.economy.resources()==original_wallet,"native refusal leaves research and paid interval uncommitted")
	atomic.native_execution=null
	var seen:Array=[]
	atomic.event.connect(func(kind,_info):
		if kind=="hightech_complete":seen.append(atomic.portable_save_data())
	)
	atomic.advance_hightech(100000.0)
	check(seen.size()==1 and seen[0].aiTechLevels.weapon_accuracy==1 and seen[0].aiTechActive=="" and seen[0].resources==plan.resources,"completion observer sees quoted paid interval and entire growth result")
	var bad:=atomic.portable_save_data();bad.aiTechProgress.weapon_accuracy=-1
	var before_rejection:=atomic.research.save_data()
	atomic.load_progress_data(bad)
	check(atomic.research.save_data()==before_rejection and atomic.economy.resources()==plan.resources,"invalid research save cannot partially install other domains")
	print("AI_TECH_TREE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
