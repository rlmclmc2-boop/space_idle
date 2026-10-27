extends SceneTree
var session
func _initialize()->void:
	GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"));call_deferred("_run")
func check(value:bool,message:String)->bool:
	if not value:printerr("AUDIT_REGRESSION_FAILED ",message);quit(1)
	return value
func _run()->void:
	session=load("res://src/game_session.gd").new()
	if not check(session.initialize("res://generated/config.json",871).ok,"initialize"):return
	var api=session.amount_api
	var reactor=session.reactor_system
	reactor.refresh_availability(func(_kind:String,_id:String):return true)
	var one:Dictionary=api.apply("from_decimal",["1"]).value
	var base:Dictionary=reactor._capacity(reactor._state.duplicate(true),reactor._parameters,api,one).value
	var target:Dictionary=api.apply("from_decimal",["98526"]).value
	var multiplier:Dictionary=api.apply("from_decimal",[str(api.apply("to_ratio",[target,base]).scalar)]).value
	reactor._state.allocations={"weapons":target};reactor._presentation_cache={}
	var model:Dictionary=reactor.presentation_model({"capacity":multiplier,"free_charge":0.1})
	var weapon:Dictionary={}
	for row in model.modules:
		if row.id=="weapons":weapon=row
	if not check(is_equal_approx(float(weapon.load),1.0) and is_equal_approx(float(weapon.ratio),1.0),"98526 full allocation plus10% free load must saturate to1, not0.11"):return
	reactor._state.allocations={};reactor._presentation_cache={}
	model=reactor.presentation_model({"capacity":multiplier,"free_charge":0.1})
	for row in model.modules:
		if not check(is_equal_approx(float(row.load),0.1),"free10% load"):return
	print("REACTOR_98526_MANUAL_AND_FREE_RATIO_REGRESSION_OK")
	var crew=session.crew_system
	crew._features.levels=false
	for id in crew._definitions:crew._available[id]=true
	for row in crew.status_rows():
		if not check(not row.levels_enabled and row.required=="—" and not "经验" in row.text,"crew_level hidden"):return
	var id:String=str(crew._members.keys()[0])
	crew._members[id].kind="planet_build";crew._members[id].target="1:1"
	if not check(crew.assignment_count("planet_build","1:1")==1,"actual builder count"):return
	print("CREW_LEVEL_GATE_AND_ACTUAL_BUILDERS_OK")
	var research=session.research
	research.refresh_progress(func(_kind:String,_id:String):return true)
	var choice:String=""
	for key in research.choices():
		if research.choices()[key]:choice=key;break
	if not check(research.select(choice).ok,"research selection"):return
	var speed:Dictionary=api.apply("from_decimal",["2"]).value
	var shown:Dictionary=research.presentation_model(false,{"wallet":{},"speed":speed})
	var before_work:Dictionary=research.save_state().work.get(choice,api.apply("zero",[]).value)
	var advanced:Dictionary=research.advance({},1.0,speed,false)
	var difference:Dictionary=api.apply("sub_nonnegative",[research.save_state().work[choice],before_work]).value
	if not check(advanced.ok and api.apply("compare",[difference,speed]).scalar==0 and shown.speed=="2e0","display speed equals actual unstaffed baseline advancement"):return
	var before:Dictionary=session.save_payload()
	for attempt in 5:research.presentation_model(false,{"wallet":{},"speed":speed})
	if not check(before==session.save_payload(),"cached presentation query mutation"):return
	print("RESEARCH_ACTUAL_SPEED_REMAINING_EFFECT_AND_PURITY_OK")
	research.set_investment_text("1","100")
	var saved:Dictionary=research.save_state()
	var funded:Dictionary={"1":api.apply("from_decimal",["50"]).value}
	var whole:Dictionary=research.advance(funded,1.0,speed,false)
	var whole_work:Dictionary=research.save_state().work[choice]
	research.restore_state(saved)
	var first:Dictionary=research.advance(funded,0.5,speed,false)
	var second:Dictionary=research.advance(first.wallet,0.5,speed,false)
	if not check(whole.ok and first.ok and second.ok and whole.wallet==second.wallet and whole_work==research.save_state().work[choice],"partial investment exhaustion partition invariance"):return
	print("RESEARCH_PARTIAL_FUNDS_EXHAUSTION_FRAME_PARTITION_OK")
	quit(0)