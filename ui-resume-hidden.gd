extends SceneTree
const Session=preload("res://src/game_session.gd")
var session
func _initialize()->void:
	GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"));call_deferred("_run")
func host(parent:Control,title:String,action:Callable)->Button:
	var button:=Button.new();button.text=title;button.pressed.connect(action);parent.add_child(button);return button
func fail(message:String)->void:printerr(message);quit(1)
func _run()->void:
	session=Session.new()
	if not session.initialize("res://generated/config.json",871).ok:fail("initialize");return
	var research=preload("res://src/ui/research_panel.gd").new(session.research,host,func():return {"paused":false,"research_staffed":false})
	root.add_child(research)
	var reactor=preload("res://src/ui/reactor_panel.gd").new(session.reactor_system,session.reactor_inputs,session.economy.payment,session.publish_reactor,host)
	root.add_child(reactor)
	session.reactor_system.refresh_availability(func(kind:String,_id:String):return kind=="feature")
	reactor._refresh_choices();reactor._stage.set_model(session.reactor_system.presentation_model(session.reactor_inputs()),false,0)
	for row in reactor._stage.model.modules:
		if row.id=="condensation":fail("locked condensation device visible");return
	for index in reactor.module_picker.item_count:
		if reactor.module_picker.get_item_metadata(index)=="condensation":fail("locked condensation choice visible");return
	print("CONDENSATION_LOCKED_DEVICE_AND_CHOICE_HIDDEN")
	session.reactor_system.refresh_availability(func(_kind:String,_id:String):return true)
	reactor._refresh_choices()
	var model:Dictionary=session.reactor_system.presentation_model(session.reactor_inputs())
	var found:bool=false
	for row in model.modules:found=found or row.id=="condensation"
	if not found:fail("unlocked condensation missing");return
	print("CONDENSATION_UNLOCKED_DEVICE_AND_CHOICE_RESTORED")
	session.research.refresh_progress(func(_kind:String,_id:String):return true)
	research._set_drawer(true);research._refresh_choices();research._refresh_stage()
	var choices:Dictionary=session.research.choices()
	var hidden:int=0
	for row in session.research.presentation_model().rows:
		if not row.available:
			hidden+=1
			if research._machine_rows.has(row.id) and research._machine_rows[row.id].line.visible:fail("locked research card visible");return
	for index in research.research_picker.item_count:
		if not choices.get(research.research_picker.get_item_metadata(index),false):fail("locked research option visible");return
	if hidden==0:fail("research hidden fixture missing");return
	print("RESEARCH_PREREQUISITES_HIDDEN count=",hidden)
	var first:String=""
	for key in choices:
		if choices[key]:first=key;break
	if not session.research.select(first).ok:fail("research select");return
	research._refresh_stage()
	if not research._research_detail.text.begins_with("正在研究"):fail("base research incorrectly waiting for crew/investment");return
	session.galaxy_system.refresh_availability(func(_kind:String,_id:String):return true,{61:true})
	for option in session.galaxy_system.assignment_options():
		var node:Dictionary=session.galaxy_system.node_presentation(str(option.target),0)
		if node.is_empty() or node.explored:fail("unexplored node fixture" );return
	print("GALAXY_UNEXPLORED_NODE_DETAIL_OK")
	var before:Dictionary=session.save_payload()
	for i in 3:
		session.research.presentation_model();session.reactor_system.presentation_model(session.reactor_inputs());session.crew_system.status_rows()
	if not before.ok or before!=session.save_payload():fail("presentation mutated saved state");return
	print("BASE_RESEARCH_WITHOUT_STAFF_OR_INVESTMENT_RUNNING READONLY_PRESENTATION_OK")
	research.queue_free();reactor.queue_free();await process_frame;quit(0)