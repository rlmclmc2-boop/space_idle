extends SceneTree
const Reactor=preload("res://src/systems/reactor.gd")
const RunState=preload("res://src/systems/run_state.gd")
var api
var parameters: Dictionary={}
var failures: Array=[]
func check(value: bool,label: String)->void:
	if not value: failures.append(label)
func amount(text: String)->Dictionary:
	return api.apply("from_decimal",[text]).value
func inputs(factor: String,free: float=0.0)->Dictionary:
	return {"capacity":amount(factor),"free_charge":free}
func equal(text,expected: String)->bool:
	return text is String and api.apply("compare",[amount(text),amount(expected)]).scalar==0
func by_id(model: Dictionary,id: String)->Dictionary:
	for item in model.modules:
		if item.id==id:return item
	return {}
func fixture():
	var owner=Reactor.new(parameters,api,RunState.new())
	owner.refresh_availability(func(kind,id):return kind=="feature" or id!="condensation",false)
	check(owner.prepare(inputs("1")).ok,"fixture prepare")
	owner.accept()
	var accepted: Dictionary=owner.apply_allocation_plan({"weapons":"45","defence":"35","smelting":"20"},inputs("1"),func(_f,_w,_k):
		owner.accept()
		return {"ok":true})
	check(accepted.ok,"fixture accepted plan")
	return owner
func _initialize()->void:
	var loaded=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired:",loaded);quit(1);return
	call_deferred("run")
func run()->void:
	api=ClassDB.instantiate("FoundationAmount")
	var config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	for item in config.config.config:parameters[str(item.name)]=item.para_1
	for action in ["prepare_discard","refresh_reject","allocate_reject","distribute_reject"]:
		var owner=fixture()
		var before: Dictionary=owner._state.duplicate(true)
		var current_before: Dictionary=owner.allocation_plan_preview({"kind":"equal"},inputs("1")).current
		var calls: Dictionary={"count":0}
		var decline: Callable=func(_f,_w,_k):
			calls.count+=1
			return {"ok":false,"reason":"FixturePublicationRejected"}
		var outcome: Dictionary
		match action:
			"prepare_discard":
				outcome=owner.prepare(inputs("2",0.1))
				owner.discard_prepared()
			"refresh_reject":outcome=owner.refresh(inputs("2",0.1),decline)
			"allocate_reject":outcome=owner.allocate_text("weapons","60",inputs("2",0.1),decline)
			"distribute_reject":outcome=owner.distribute(inputs("2",0.1),decline)
		check(outcome.ok== (action=="prepare_discard"),action+" expected result")
		check(calls.count==(0 if action=="prepare_discard" else 1),action+" publication count")
		check(owner._state==before and owner._prepared_state.is_empty(),action+" keeps complete true state")
		# New source inputs force a fresh projection rather than hiding pollution in a cache hit.
		check(owner.allocation_plan_preview({"kind":"equal"},inputs("2",0.1)).current==current_before,action+" keeps accepted current readings")
	var prepared_owner=fixture()
	var prepared_before: Dictionary=prepared_owner._state.duplicate(true)
	check(prepared_owner.prepare(inputs("2",0.1)).ok and prepared_owner._state==prepared_before,"prepare is detached before accept")
	check(equal(prepared_owner.allocation_plan_preview({"kind":"equal"},inputs("2",0.1)).current.capacity,"100"),"current capacity stays old before accept")
	prepared_owner.accept()
	var accepted_current: Dictionary=prepared_owner.allocation_plan_preview({"kind":"equal"},inputs("2",0.1)).current
	check(equal(accepted_current.capacity,"200") and equal(by_id(accepted_current,"weapons").free,"20"),"accept adopts candidate capacity and factors together")
	for action in ["refresh","allocate","distribute"]:
		var owner=fixture()
		var calls: Dictionary={"count":0}
		var publish: Callable=func(_f,_w,_k):
			calls.count+=1;owner.accept();return {"ok":true}
		var outcome: Dictionary
		match action:
			"refresh":outcome=owner.refresh(inputs("2",0.1),publish)
			"allocate":outcome=owner.allocate_text("weapons","1000",inputs("2",0.1),publish)
			"distribute":outcome=owner.distribute(inputs("2",0.1),publish)
		var current: Dictionary=owner.allocation_plan_preview({"kind":"equal"},inputs("2",0.1)).current
		check(outcome.ok and calls.count==1 and equal(current.capacity,"200") and equal(by_id(current,"weapons").free,"20"),action+" accepts once and current follows")
		if action=="refresh":check(equal(by_id(current,"weapons").manual,"45"),"refresh preserves manual allocation")
		elif action=="allocate":check(equal(by_id(current,"weapons").manual,"145"),"legacy allocate clipping stays unchanged")
		else:check(equal(by_id(current,"weapons").manual,"67") and equal(by_id(current,"smelting").manual,"66"),"legacy distribute integer remainder stays unchanged")
	if failures.is_empty():print("PASS: prepare/discard and rejected refresh/allocate/distribute preserve complete owner state and accepted readings; only accept adopts capacity/factors; legacy success/clipping/remainders unchanged")
	else:printerr("FAIL:",failures)
	quit(0 if failures.is_empty() else 1)
