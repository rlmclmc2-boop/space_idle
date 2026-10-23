extends SceneTree
const AITech = preload("res://scripts/ai_tech_tree.gd")
const VIEW = preload("res://scripts/ai_tech_view_model.gd")

class RefusedHandoff:
	extends RefCounted
	func handoff_to_legacy(_game,_reason)->bool:return false

class ChangedWalletHandoff:
	extends RefCounted
	func handoff_to_legacy(game,_reason)->bool:
		game.economy.credit("1",1);game.native_execution=null;return true

class InputHandoff:
	extends RefCounted
	var change: Callable
	func handoff_to_legacy(game,_reason)->bool:
		change.call();game.native_execution=null;return true

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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var page_script = load("res://scripts/ai_tech_factory_page.gd")
	check(page_script != null and page_script.can_instantiate(), "AI technology page compiles")
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	check(not g.ai_tech_factory_unlocked() and not g.select_tech("singularity") and not g.set_tech_input("1",10), "new save cannot open, research, or invest in factory")
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
	for key in BattleGame.WEAPON_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.1*1.1*1.25)), "shared weapon effect: "+key)
	for key in BattleGame.DEFENSE_KEYS:
		check(near(float(combat.equipment_stat(key,1)),ceilf(float(base_stats[key])*1.25)), "shared durability effect: "+key)
	var original_factor:float=db.data.ai_tech_tree.weapon_accuracy.factor
	db.data.ai_tech_tree.weapon_accuracy.factor=1.2;combat.notify_configuration_changed()
	check(near(float(combat.research.income_factor(combat,"weapon_damage")),1.2*1.2*1.25),"Contribution follows explicit configuration revision")
	db.data.ai_tech_tree.weapon_accuracy.factor=original_factor;combat.notify_configuration_changed()
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
	atomic.native_execution=RefusedHandoff.new();atomic.progress_runtime.commit_research_advance_result(atomic,atomic.research.prepare_advance(atomic,100000.0))
	check(atomic.research.save_data()==original and atomic.economy.resources()==original_wallet,"native refusal leaves research and paid interval uncommitted")
	atomic.native_execution=ChangedWalletHandoff.new();atomic.progress_runtime.commit_research_advance_result(atomic,atomic.research.prepare_advance(atomic,100000.0))
	check(atomic.research.save_data()==original and GrowthNumber.compare(atomic.economy.balance("1"),GrowthNumber.add(original_wallet["1"],1))==0,"Handoff wallet mutation invalidates research payment without overwriting callback credit")
	fund(atomic,original_wallet)
	atomic.native_execution=null
	var seen:Array=[]
	atomic.event.connect(func(kind,_info):
		if kind=="hightech_complete":seen.append(atomic.portable_save_data())
	)
	atomic.progress_runtime.commit_research_advance_result(atomic,atomic.research.prepare_advance(atomic,100000.0))
	check(seen.size()==1 and seen[0].aiTechLevels.weapon_accuracy==1 and seen[0].aiTechActive=="" and seen[0].resources==plan.resources,"completion observer sees quoted paid interval and entire growth result")
	var bad:=atomic.portable_save_data();bad.aiTechProgress.weapon_accuracy=-1
	var before_rejection:=atomic.research.save_data()
	atomic.load_progress_data(bad)
	check(atomic.research.save_data()==before_rejection and atomic.economy.resources()==plan.resources,"invalid research save cannot partially install other domains")
	run_cross_domain_inputs()
	run_factory_crew()
	run_factory_inputs()
	run_income_history()
	print("AI_TECH_TREE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)

func run_factory_crew() -> void:
	var db:=ShipDatabase.new()
	for gate in db.data.unlock.values():gate.level=0
	var g:=BattleGame.new(db,false)
	check(g.assign_crew("navigator","hightech_scientists","hightech"),"Assign actual factory crew")
	g.advance_hightech(1.0)
	check(g.research.selected().is_empty(),"Assignment and idle ticks never cancel a manual research pause")
	var state:=g.research.save_data()
	state.aiTechProgress={"singularity":g.research.required(g,"singularity")-2.0,"weapon_accuracy":g.research.required(g,"weapon_accuracy")-5.0,"resource_refining":g.research.required(g,"resource_refining")-5.0,"equipment_finishing":g.research.required(g,"equipment_finishing")-0.1}
	check(g.research.install_snapshot(state,db.data.ai_tech_tree),"Partial research fixture installs without resetting work")
	check(g.select_tech("singularity"),"Player can choose a longer project")
	g.advance_hightech(1.0)
	check(g.research.selected()=="singularity","Assigned crew never preempts current research")
	var before:=g.research.save_data();var wallet:=g.economy.save_data()
	g.native_execution=RefusedHandoff.new();g.advance_hightech(1.0)
	check(g.research.save_data()==before and g.economy.save_data()==wallet,"Rejected completion neither switches project nor partially commits growth/payment")
	g.native_execution=null;g.paused=false;g.advance_hightech(1.0)
	check(g.research.level(g,"singularity")==1 and g.research.selected()=="weapon_accuracy","After commit choose shortest remaining eligible project; configured order resolves equal times")
	check(g.research.progress("weapon_accuracy")==float(state.aiTechProgress.weapon_accuracy) and g.research.progress("equipment_finishing")==float(state.aiTechProgress.equipment_finishing),"Continuation preserves progress and ignores a shorter locked project")
	var display:Dictionary=g.tech_tree_snapshot()
	check(near(float(display.remaining_seconds),5.0/1.1),"Chosen remaining time uses newly committed AI speed")
	check(g.select_tech(""),"Player explicitly pauses research")
	g.advance_hightech(10.0)
	var paused:=g.portable_save_data();var restored:=BattleGame.new(db,false)
	restored.load_progress_data(paused);restored.advance_hightech(1.0)
	check(restored.research.selected().is_empty() and restored.crew.entry(restored,"navigator").assignmentType=="hightech_scientists","Saved assignment does not restart manually paused research on reload")
	check(g.select_tech("weapon_accuracy") and g.assign_crew("navigator","",""),"Recall preserves current research")
	g.advance_hightech(10.0)
	check(g.research.selected().is_empty(),"Without assigned crew completion stays idle")
	# All other projects are now unavailable. Completion may wait but does not poll.
	var waiting:=BattleGame.new(db,false)
	waiting.assign_crew("navigator","hightech_scientists","hightech")
	for id in db.data.ai_tech_tree:db.data.ai_tech_tree[id].requirements={"singularity":999}
	db.data.ai_tech_tree.singularity.requirements={"singularity":"10*k+1"}
	var ready:=waiting.research.save_data();ready.aiTechLevels.singularity=11
	check(waiting.research.install_snapshot(ready,db.data.ai_tech_tree),"Research prerequisite fixture installs")
	# Use an independent project whose next-level gate closes after this completion.
	db.data.ai_tech_tree.equipment_finishing.requirements={"singularity":"10*k+1"}
	check(waiting.select_tech("equipment_finishing"),"One eligible project can start")
	waiting.advance_hightech(waiting.research.required(waiting,"equipment_finishing"))
	check(waiting.research.selected().is_empty(),"No eligible next project leaves factory idle")
	db.data.ai_tech_tree.weapon_accuracy.requirements={};waiting.notify_configuration_changed();waiting.advance_hightech(1.0)
	check(waiting.research.selected().is_empty(),"New availability does not turn a completed/manual idle state into polling research")

func run_income_history()->void:
	var history=preload("res://scripts/income_history.gd").new()
	var rows:Array=[
		{"id":"1","time":99.0,"production_time":199.0,"amount":12.0,"production_base":5.0,"origin":"drop"},
		{"id":"1","time":99.0,"production_time":199.0,"amount":30.0,"origin":"galaxy"},
		{"id":"1","time":99.0,"production_time":199.0,"amount":20.0,"origin":"furnace"},
		{"id":"1","time":40.0,"production_time":140.0,"amount":100.0,"origin":"drop"},
		{"id":"2","time":99.0,"production_time":199.0,"amount":999.0,"origin":"drop"},
		{"id":"1","time":39.0,"production_time":199.0,"amount":7.0,"origin":"drop"}]
	history.replace_records(rows)
	rows[0].amount=10000.0
	check(history.display_total("1",100.0)==62.0 and history.peak_total("1",100.0)==62.0,"display and existing peak qualification retain actual mixed-source receipts and exact wall boundary")
	check(history.research_total("1",200.0)==69.0 and history.production_total("1",200.0,100.0,200.0)==12.0,"research includes actual receipts while production uses qualified base values on its own clock")
	check(history.wall_production_total("1",100.0)==5.0,"explicit legacy wall production query remains separate from mixed-source display")
	var detached:Array=history.records();detached[0].amount=20000.0
	check(history.display_total("1",100.0)==62.0,"caller arrays and detached query records cannot rewrite income facts")
	var saved:Array=history.snapshot(100.0,200.0)
	check(saved.size()==5 and history.size()==6,"portable snapshot excludes fully expired facts without mutating owner")
	history.prune(100.0,200.0)
	check(history.size()==5 and history.research_total("1",200.0)==69.0,"pruning preserves a receipt still live on the other clock")
	var restored=preload("res://scripts/income_history.gd").new();restored.restore(saved,100.0,200.0)
	check(restored.display_total("1",100.0)==62.0 and restored.research_total("1",200.0)==69.0 and restored.production_total("1",200.0,100.0,200.0)==12.0,"current-schema export and restore preserve every existing purpose query")
	history.prune(160.0,260.0)
	check(history.size()==0,"facts expire when both rolling windows end")

func run_factory_inputs() -> void:
	var N=GrowthNumber
	var db:=ShipDatabase.new()
	for gate in db.data.unlock.values():gate.level=0
	var g:=BattleGame.new(db,false)
	g.profile.productionElapsed=100.0
	g.income_history.replace_records([
		{"id":"1","time":0.0,"production_time":41.0,"amount":3000.0,"production_base":1.0,"origin":"drop"},
		{"id":"1","time":0.0,"production_time":100.0,"amount":3000.0,"origin":"galaxy"},
		{"id":"1","time":g.economy_time(),"production_time":40.0,"amount":1e20,"origin":"drop"},
		{"id":"1","time":g.economy_time(),"production_time":101.0,"amount":1e20,"origin":"drop"},
		{"id":"2","time":0.0,"production_time":90.0,"amount":11999.0,"origin":"drop"}])
	check(g.resource_game_minute_total("1")==6000.0,"Same receipt ledger sums actual amount including galaxy receipts in the game-time window")
	fund(g,{"1":1e30,"2":1e30})
	check(g.assign_crew("navigator","hightech_scientists","hightech"),"Factory assignment immediately allocates inputs")
	var state:=g.research.save_data()
	check(state.aiTechInput=={"1":1.0,"2":1.0},"Default one percent uses actual gross income, floors, and ignores wallet/production base")
	check(g.set_tech_input_ratio("1",0.025) and g.research.save_data().aiTechInput["1"]==2.0,"Ratio edit immediately recomputes floored per-second input")
	check(g.set_tech_input_ratio("2",0.001) and not g.set_tech_input_ratio("2",0.00099),"Ratio minimum is independently 0.1 percent")
	check(not g.set_tech_input("1",999),"Assigned factory owns its automatic input rather than accepting stale manual writes")
	g.income_history.clear()
	g.advance_shared_clock_and_economy(59.9)
	check(g.research.save_data().aiTechInput["1"]==2.0,"Automatic allocation stays fixed until sixty game seconds")
	g.advance_shared_clock_and_economy(0.1)
	check(g.research.save_data().aiTechInput["1"]==1.0 and g.research.save_data().aiTechAutoElapsed==0.0,"Zero income still allocates one at the refresh boundary")
	var huge=N.parse_input("1e400")
	g.income_history.replace_records([{"id":"1","time":g.economy_time(),"production_time":160.0,"amount":N.multiply(huge,6000.0),"origin":"galaxy"}])
	check(g.set_tech_input_ratio("1",0.01),"Huge income ratio can be configured")
	check(N.compare(g.research.save_data().aiTechInput["1"],huge)==0 and near(g.research.input_factor(huge),101.0),"Shared GrowthNumber allocates above floating/integer range and computes the original logarithmic factor")
	var transfer=preload("res://scripts/save_transfer.gd").new()
	g.advance_shared_clock_and_economy(12.25)
	var raw:=g.portable_save_data();var prepared:Dictionary=transfer.prepare_data(JSON.parse_string(JSON.stringify(raw)),db)
	check(prepared.get("error")=="","Portable validator accepts huge input and auto settings")
	var loaded:=BattleGame.new(db,false);loaded.load_progress_data(prepared.data)
	check(loaded.research.save_data()==g.research.save_data(),"Current save restores large inputs, separate ratios and remaining refresh interval")
	check(g.assign_crew("navigator","",""),"Recall ends automatic allocation")
	g.income_history.clear();g.advance_shared_clock_and_economy(60.0)
	check(N.compare(g.research.save_data().aiTechInput["1"],huge)==0 and g.research.save_data().aiTechAutoElapsed==12.25,"Recall leaves current inputs and stops automatic timer/writes")
	check(g.set_tech_input("1",1e20) and near(g.research.input_factor(1e20),6.0),"Manual input above the old 2^53 limit is accepted")
	check(g.set_tech_input("1",huge) and g.set_tech_input("2",0),"Manual scientific input uses the same value type")
	fund(g,{"1":N.multiply(huge,0.4),"2":0.0})
	check(g.select_tech("weapon_accuracy"),"Large paid research starts")
	g.advance_hightech(0.25)
	check(near(g.research.progress("weapon_accuracy"),25.25) and near(N.ratio(g.economy.balance("1"),huge),0.15),"Huge actual payment and progress commit together")
	g.advance_hightech(0.5)
	check(N.compare(g.economy.balance("1"),0)==0 and near(g.research.progress("weapon_accuracy"),40.75),"Insufficient huge wallet pays only its funded interval then resumes base speed")
	check(N.compare(N.parse_input(VIEW.snapshot(g).iron_investment),huge)==0,"Displayed scientific input round trips through the shared parser")
	check(g.set_tech_input("1",N.parse_input("1e1000")),"Larger shared exponent is not capped by the research interface")
	for bad in [-1.0,0.5,NAN,INF,{"m":1.0,"e":-400.0}]:
		check(not g.set_tech_input("1",bad),"Research input rejects invalid or fractional quantities")

	var fast:=BattleGame.new(db,false)
	var rate=N.make(1.0,1e12)
	fund(fast,{"1":rate,"2":rate})
	fast.set_tech_input("1",rate);fast.set_tech_input("2",rate);fast.select_tech("weapon_accuracy")
	var quote:Dictionary=fast.research.prepare_advance(fast,0.05)
	check(quote.completed and N.compare(quote.resources["1"],0)>0,"Sub-nanosecond research pays its actual interval rather than draining the wallet or discarding work")
	fast.advance_hightech(0.05)
	check(fast.research.level(fast,"weapon_accuracy")==1 and fast.economy.resources()==quote.resources,"Very short huge-input completion commits the same prepared payment")

	var ranked:=BattleGame.new(db,false)
	var extreme=N.make(1.0,1e200)
	fund(ranked,{"1":extreme,"2":extreme})
	for id in ["1","2"]:ranked.income_history.record({"id":id,"time":ranked.economy_time(),"production_time":ranked.production_time(),"amount":extreme,"origin":"galaxy"})
	check(ranked.assign_crew("navigator","hightech_scientists","hightech") and ranked.select_tech("singularity"),"Extreme shared-speed continuation starts with actual factory assignment")
	var durations:Dictionary=ranked.tech_tree_snapshot()
	var times:Array=durations.nodes.filter(func(node):return node.id in ["singularity","equipment_reinforcement"])
	check(times.all(func(node):return N.valid(node.remaining_seconds) and N.compare(node.remaining_seconds,0)>0 and N.ratio(node.remaining_seconds,1.0)==0.0),"Shared time values remain positive even below float display range")
	check(N.compare(times[1].remaining_seconds,times[0].remaining_seconds)<0,"Shared time comparison retains the shorter project")
	ranked.advance_hightech(0.05)
	check(ranked.research.level(ranked,"singularity")==1 and ranked.research.selected()=="equipment_reinforcement","Completion compares shared large-number times rather than choosing the first zero display time")

func run_cross_domain_inputs()->void:
	for dependency in ["crew","drone"]:
		var g:=BattleGame.new(ShipDatabase.new(),false);g.profile.cleared=range(1,61);g.rebuild_unlocks()
		fund(g,{"1":100000.0,"2":100000.0})
		g.select_tech("weapon_accuracy")
		var original:=g.research.save_data();var wallet:=g.economy.resources();var speed:=g.research.research_speed(g)
		var handoff:=InputHandoff.new()
		if dependency=="crew":
			var members:=g.crew.save_data()
			for member in members.crew:
				if member.crewId=="navigator":member.level=2;member.assignmentType="hightech_scientists";member.targetId="hightech"
			handoff.change=func():check(g.crew.install_snapshot(members,g.db),"Callback installs real crew speed input")
		else:
			var rng:=RandomNumberGenerator.new();rng.seed=123
			var config:Dictionary=g.hyperspace.config
			var drone:Dictionary=preload("res://scripts/drone_rewards.gd").create_drone(rng,config,"speed-fixture","blue","laser",5,"1")
			drone.hangings=["distributed_algorithm"];drone.hanging_slots=1
			var snapshot:=g.hyperspace.save_data()
			check(preload("res://scripts/drone_inventory.gd").insert(snapshot.hyperspace.inventory,drone,config),"Speed fixture inserts drone")
			snapshot.hyperspace.inventory.equipped=[drone.id]
			snapshot.hyperspace.hanging_modules.distributed_algorithm={"unlocked":true,"level":1,"exp":0.0}
			handoff.change=func():check(g.hyperspace.install_snapshot(snapshot,g.db),"Callback installs real drone speed input")
		g.native_execution=handoff;g.advance_hightech(100000.0)
		check(g.research.research_speed(g)!=speed and g.research.save_data()==original and g.economy.resources()==wallet,"Changed "+dependency+" calculation input rejects old research and payment")
