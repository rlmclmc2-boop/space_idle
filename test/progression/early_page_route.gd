extends SceneTree
## QA player model: real public actions, one visible page, finite action time.
const Game=preload("res://qa/presented_balance_game.gd")
const PlayerInput=preload("res://qa/player_input.gd")
const Driver=preload("res://qa/scene_driver.gd")
const STEP:=1.0/60.0
const IDLE_CHECK:=3.0
const PAGE_TOUR:=10.0
const BUTTON_TIME:=0.3 # Explicit test assumption, not a user-specified exact value.
var game
var player_input
var pending_picker:Dictionary={}
var scientist_context:=""
var reactor_context:=""
var rejected_inputs:=0
var driver
var trace:FileAccess
var output:String
var next_check:=0.0
var next_tour:=10.0
var next_button:=0.0
var tour:Array=[]
var touring:=false
var tour_started:=0.0
var observed_weapons:Array[String]=[]
var tour_durations:Array=[]
var busy:=false
var page:=0
var checks:=0
var clicks:=0
var visits:=0
var empty_checks:=0
var burst_start:=0.0
var bursts:Array=[]
var rows:Dictionary={}
var clears:Dictionary={}
var deaths:=0
var unlock_id:=""
var unlock_since:=0.0
var unlock_confirmations:=0
var segment_start:=0.0
var segment_state:=-1
var segment_stage:=1
var segments:Array=[]
func _initialize() -> void:call_deferred("run")
func record(kind:String,extra:Dictionary={}) -> void:
	var data={"x1_seconds":game.simulated_time,"kind":kind,"stage":game.stage,"page":page}
	if extra.has("kind"):data["action_kind"]=extra.kind
	data.merge(extra);trace.store_line(JSON.stringify(data))
func row(stage:int) -> Dictionary:
	var key:=str(stage)
	if not rows.has(key):rows[key]={"travel":0.0,"combat":0.0,"retreat":0.0,"clear_notice":0.0,"other":0.0,"growth_blocked_checks":0,"checks":0,"clicks":0,"page_visits":0}
	return rows[key]
func state_change() -> void:
	if segment_state>=0:segments.append({"stage":segment_stage,"state":segment_state,"seconds":game.simulated_time-segment_start})
	segment_state=game.state;segment_stage=game.stage;segment_start=game.simulated_time
func observe(kind:String,_payload:Dictionary) -> void:
	if kind=="state":
		state_change()
		if game.state==BattleGame.State.LEVEL_CLEAR and not clears.has(str(game.stage)):
			clears[str(game.stage)]=game.simulated_time
			record("first_clear",{"loadout":game.profile.loadout.duplicate(true),"resources":game.profile.resources.duplicate(true),"rng":str(game.rng.state)})
	elif kind=="retreat":deaths+=1
func control_action(kind:String,control,details:Dictionary={}) -> Dictionary:
	if not player_input.available(control):return {}
	var container=player_input.scroll_needed(control)
	if container!=null:return {"kind":"scroll","control":control,"container":container,"for_action":kind}
	details["kind"]=kind;details["control"]=control
	return details
func picker_action(kind:String,picker:OptionButton,index:int)->Dictionary:
	if index<0 or index>=picker.item_count or picker.get_popup().is_item_disabled(index):return {}
	return control_action(kind,picker,{"index":index})
func allocation_context()->String:
	return JSON.stringify([game.profile.selectedShip,game.active_slot_count("weapons"),game.active_slot_count("defence"),driver.scene.hightech_page.rows.keys()])
func crew_action()->Dictionary:
	var panel=driver.scene.crew_panel
	for member in game.profile.crew:
		var id:=str(member.crewId)
		if not panel.rows.has(id):continue
		if not str(member.assignmentType).is_empty():
			if str(member.assignmentType) not in ["equipment_upgrade","hightech_scientists"]:continue
			var desired:="10" if member.assignmentType=="equipment_upgrade" else "max"
			if str(member.upgradeMode)==desired:continue
			if panel.selected!=id:return control_action("crew_select",panel.rows[id],{"crew":id})
			return picker_action("crew_mode_open",panel.upgrade_picker,panel.mode_ids.find(desired))
		if not game.crew_exploration(id).is_empty():continue
		if panel.selected!=id:return control_action("crew_select",panel.rows[id],{"crew":id})
		for job in ["equipment_upgrade","hightech_scientists","reactor_upgrade","jewel_auto"]:
			var job_index:int=panel.job_ids.find(job)
			if job_index<0 or panel.jobs.get_popup().is_item_disabled(job_index):continue
			if panel.jobs.selected!=job_index:return picker_action("crew_job_open",panel.jobs,job_index)
			# Target/amount options come from the actual selected inspector. Hidden
			# target pickers keep their production default; never select backend IDs.
			if panel.target_picker.is_visible_in_tree():
				for index in panel.target_ids.size():
					if panel.target_picker.get_popup().is_item_disabled(index):continue
					if panel.target_picker.selected!=index:return picker_action("crew_target_open",panel.target_picker,index)
					break
			# Assign the draft first. Changing the upgrade mode emits a member
			# refresh; the existing-assignment branch sets it on the next visit.
			if not panel.assign_button.disabled:return control_action("crew_assign",panel.assign_button,{"crew":id,"job":job})
	return {}
func action() -> Dictionary:
	if not pending_picker.is_empty():
		if is_instance_valid(pending_picker.picker) and pending_picker.picker.get_popup().visible:return {"kind":"option_select","picker":pending_picker.picker,"index":pending_picker.index,"origin":pending_picker.origin}
		pending_picker.clear()
	if not player_input.modal_windows().is_empty():return {"kind":"dismiss_modal"}
	if not game.pending_unlocks.is_empty():return {}
	# Pickups use the viewport transform and production cover clipping. The
	# production mouse-motion handler decides which drops a gesture collects.
	for drop in game.drops:
		if player_input.pickup_point(drop)!=null:return {"kind":"pickup","drop":drop,"uid":int(drop.uid)}
	if page==0:
		var panel=driver.scene.equipment_panel
		var weapon:=str(game.slot_entry("weapons",0).get("key","laser"))
		for key in observed_weapons:
			if game.content_unlocked("equipment",key):weapon=key
		for category in ["weapons","defence"]:
			for index in game.active_slot_count(category):
				var id:String=game.slot_id(category,index)
				if not panel.cards.has(id):continue
				var desired:=weapon if category=="weapons" else "shield" if index>0 and game.content_unlocked("equipment","shield") else "armour"
				var card=panel.cards[id]
				if not desired.is_empty() and str(game.slot_entry(category,index).key)!=desired:
					var option:int=card.equipment_options.find(desired)
					var choice:=picker_action("refit_open",card.name_button,option)
					if not choice.is_empty():return choice
		var choices:Array=[]
		for id in panel.cards:
			var card=panel.cards[id]
			if player_input.available(card.upgrade_button):choices.append({"id":id,"level":int(panel.items[id].level)})
		choices.sort_custom(func(a,b):return a.level<b.level if a.level!=b.level else str(a.id)<str(b.id))
		if not choices.is_empty():
			var item:Dictionary=panel.items[choices[0].id]
			if panel.upgrade_amount==1 and game.can_upgrade_slot(item.category,item.index,10):return control_action("upgrade_amount",panel.amount_buttons[1],{"amount":10})
			return control_action("upgrade_slot",panel.cards[item.id].upgrade_button,{"category":item.category,"index":item.index,"amount":panel.upgrade_amount})
		if panel.upgrade_amount!=1:return control_action("upgrade_amount",panel.amount_buttons[0],{"amount":1})
	elif page==1:
		var panel=driver.scene.hightech_page
		var choice:=control_action("scientist_max",panel.generate_actions[-1])
		if not choice.is_empty():return choice
		var context:=JSON.stringify([panel.rows.keys(),game.profile.scientists,allocation_context()])
		if game.idle_scientists()>0 or context!=scientist_context:return control_action("distribute_scientists",panel.distribute,{"context":context,"reason":"New projects/slots or idle scientists; actual distribute control"})
	elif page==2:
		var panel=driver.scene.reactor_panel
		var choice:=control_action("reactor_max",panel.upgrade_buttons["MAX"])
		if not choice.is_empty():return choice
		var context:=allocation_context()
		if game.reactor_allocated()<floori(game.reactor_capacity()) or context!=reactor_context:return control_action("reactor_balance",panel.equalize_button,{"context":context,"reason":"Reallocate after actual hull/module change"})
	elif page==3:
		var panel=driver.scene.ship_controls.page
		for key in panel.choices:
			if key==game.profile.selectedShip:continue
			if game.active_slot_count("weapons",key)+game.active_slot_count("defence",key)<=game.active_slot_count("weapons")+game.active_slot_count("defence"):continue
			if panel.candidate!=key:return control_action("ship_select",panel.choices[key],{"key":key})
			return control_action("switch_ship",panel.confirm,{"key":key})
	elif page==4:return control_action("enhancement_max",driver.scene.enhancement_panel.max_button)
	elif page==5:return crew_action()
	return {}
func click_button(choice:Dictionary) -> void:
	var before:Dictionary=game.profile.resources.duplicate(true)
	var before_loadout:Dictionary=game.profile.loadout.duplicate(true)
	var ok:=false
	match choice.kind:
		"pickup":ok=await player_input.pickup(choice.drop)
		"option_select":
			ok=await player_input.popup_choice(choice.picker.get_popup(),int(choice.index))
			ok=ok and choice.picker.selected==int(choice.index)
			if ok:pending_picker.clear()
		"dismiss_modal":
			for down in [true,false]:
				var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=down
				Input.parse_input_event(event);await process_frame
			ok=true
		"scroll":ok=await player_input.scroll(choice.control,choice.container)
		_:
			ok=await player_input.press(choice.control)
			if ok and choice.has("index") and choice.control is OptionButton:
				pending_picker={"picker":choice.control,"index":choice.index,"origin":choice.kind}
			if ok and choice.kind=="distribute_scientists":scientist_context=choice.context
			if ok and choice.kind=="reactor_balance":reactor_context=choice.context
	var info:Dictionary={}
	for key in choice:
		if key not in ["control","picker","drop","container"]:info[key]=choice[key]
	info["input_gate"]=player_input.last_gate.duplicate(true)
	info["resources_before"]=before;info["resources_after"]=game.profile.resources.duplicate(true)
	info["loadout_before"]=before_loadout;info["loadout_after"]=game.profile.loadout.duplicate(true)
	if not ok:
		rejected_inputs+=1;record("input_rejected",info);return
	clicks+=1;row(game.stage).clicks+=1;record("click",info)
func visit_page(index:int) -> void:
	var before:int=driver.scene.equipment_tabs.current_tab
	if index==before:page=index;return
	var ok:bool=await player_input.press(driver.scene.system_nav_buttons[index])
	page=driver.scene.equipment_tabs.current_tab
	if not ok or page!=index:
		rejected_inputs+=1;record("navigation_rejected",{"requested":index,"input_gate":player_input.last_gate});return
	visits+=1;clicks+=1;row(game.stage).page_visits+=1;row(game.stage).clicks+=1
	record("page_visit",{"tour":touring,"input_gate":player_input.last_gate})
func check_page() -> void:
	var now:float=game.simulated_time
	if not touring and now+0.000001>=next_tour:
		driver.scene.refresh_tab_visibility()
		for index in driver.scene.equipment_tabs.get_tab_count():
			if not driver.scene.equipment_tabs.is_tab_hidden(index):tour.append(index)
		touring=true;tour_started=now
		record("tour_start",{"pages":tour.duplicate(),"deferred_seconds":maxf(0,now-next_tour)})
		next_tour=now+PAGE_TOUR
	if touring:
		if tour.is_empty():
			tour_durations.append(now-tour_started);record("tour_end",{"seconds":now-tour_started})
			touring=false;await visit_page(0);next_check=now+BUTTON_TIME;return
		await visit_page(int(tour.pop_front()))
	checks+=1;row(game.stage).checks+=1
	await process_frame # Deferred container layout must be real before inspection.
	var choice:=action();record("check",{"action_available":not choice.is_empty(),"tour":touring})
	if choice.is_empty():
		empty_checks+=1;row(game.stage).growth_blocked_checks+=1
		next_check=now+(BUTTON_TIME if touring else IDLE_CHECK)
	else:
		busy=true;burst_start=now;next_button=now+BUTTON_TIME*int(choice.get("control_steps",1))
func step_controller() -> void:
	var now:float=game.simulated_time
	if not game.pending_unlocks.is_empty():
		var current:String=game.pending_unlocks[0]
		if current!=unlock_id:
			unlock_id=current;unlock_since=now;driver.scene.refresh_unlock_content()
			var definition:Dictionary=game.db.data.unlock.get(current,{})
			if definition.get("type")=="equipment" and game.WEAPON_KEYS.has(str(definition.get("target",""))):
				observed_weapons.append(str(definition.target))
			record("unlock_exposed",{"id":current,"source":"actual notice title/description"})
		if now-unlock_since+0.000001>=3.0:
			# Accelerated exact-X1 QA supplies its UI-clock coordinate to the actual
			# production countdown; never call acknowledge_unlocks directly.
			var path:="legacy visible confirmation button after3s"
			if driver.scene.has_method("advance_unlock_notice"):
				driver.scene.advance_unlock_notice(driver.scene.unlock_notice_started_ms+int(round((now-unlock_since)*1000.0)))
				path="production UI countdown with exact-X1 QA clock"
			else:await player_input.press(driver.scene.continue_button)
			if game.pending_unlocks.is_empty() or str(game.pending_unlocks[0])!=current:
				unlock_confirmations+=1;record("unlock_confirmed",{"id":current,"exposure_seconds":now-unlock_since,"path":path});unlock_id=""
	else:unlock_id=""
	if busy:
		if now+0.000001<next_button:return
		await process_frame
		var choice:=action()
		if choice.is_empty():
			bursts.append(now-burst_start);busy=false
			next_check=now+(BUTTON_TIME if touring else IDLE_CHECK);record("burst_end",{"seconds":now-burst_start})
		else:await click_button(choice);next_button=now+BUTTON_TIME*int(choice.get("control_steps",1))
	elif now+0.000001>=next_check or (not touring and now+0.000001>=next_tour):await check_page()
func run() -> void:
	output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
	if output.is_empty():printerr("Isolated diagnostic output required");quit(2);return
	trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
	game=Game.new(ShipDatabase.new());game.rng.seed=20261004;game.stat_cache_enabled=true
	driver=Driver.new();driver.ui_refresh_seconds=0.0;driver.production_ui_ticks=true;driver.setup(self,game)
	player_input=PlayerInput.new();player_input.setup(driver.scene,self)
	root.size=Vector2i(1373,883)
	root.grab_focus()
	await process_frame;await process_frame
	game.event.connect(observe);game.start(1,false)
	FileAccess.open(output+"/save_0.json",FileAccess.WRITE).store_string(JSON.stringify(game.portable_save_data()))
	var limit:=float(OS.get_environment("EARLY_ROUTE_SECONDS"))
	if limit<=0:limit=10800.0
	var started:=Time.get_ticks_usec();var heartbeat:=0
	while game.simulated_time<limit and not clears.has("10"):
		await step_controller()
		var before:int=game.stage;var state:int=game.state
		driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP)
		var key:String="travel" if state==BattleGame.State.TRAVEL else "combat" if state==BattleGame.State.COMBAT else "retreat" if state==BattleGame.State.RETREAT else "clear_notice" if state==BattleGame.State.LEVEL_CLEAR else "other"
		row(before)[key]+=STEP
		if int(game.simulated_time)/300>heartbeat:
			heartbeat=int(game.simulated_time)/300;print("EARLY_ROUTE t=",game.simulated_time," stage=",game.stage," clicks=",clicks)
	state_change();trace.close()
	var maximum_travel:=0.0;var maximum_retreat:=0.0
	for segment in segments:
		if segment.state==BattleGame.State.TRAVEL:maximum_travel=maxf(maximum_travel,segment.seconds)
		if segment.state==BattleGame.State.RETREAT:maximum_retreat=maxf(maximum_retreat,segment.seconds)
	var result={"scope":"Genuine new profile, formal scene providers, exact X1 1/60 ticks; only stages 1-10. No resource injection, no stat changes, no cross-page oracle, Actual native mouse/keyboard input; visible/enabled controls and GUI hit tests; modal blocking and viewport-clipped pickup gestures. Refits only to actually exposed unlocked weapon tutorials; no hidden enemy inspection.","assumptions":{"idle_check_seconds":IDLE_CHECK,"tour_start_seconds":PAGE_TOUR,"button_seconds":BUTTON_TIME,"button_mode":"lowest module first; select x10 when affordable otherwise x1; native popup open/select, scrolling, crew selection and confirmation are each separate0.3s actual input gestures; scientist/reactor/enhancement use actual MAX buttons; disabled controls never dispatched","navigation":"Current page checks every3s; tour starts about every10s, empty pages cost0.3s, same-page affordable buttons drain before next page; return to equipment; delays recorded","unlock":"actual production UI countdown called with exact-X1 QA UI clock; each queued ID exposed3s independently; real wall/X10 verified by test_unlock_tutorial, not this accelerated study","ui_refresh":"Production refresh_visible_cards/refresh_navigation every logical1/60 step; no one-second artificial throttle. Hightech production _process uses the same logical UI dt.","later":"This entry stops at clear10; existing later sparse policy remains untouched"},"status":"complete" if clears.has("10") else "bounded_partial","x1_seconds":game.simulated_time,"clears":clears,"stage":game.stage,"deaths":deaths,"checks":checks,"empty_checks":empty_checks,"clicks":clicks,"rejected_inputs":rejected_inputs,"page_visits":visits,"unlock_confirmations":unlock_confirmations,"burst_seconds":bursts,"tour_seconds":tour_durations,"observed_weapon_tutorials":observed_weapons,"rows":rows,"segments":segments,"maximum_travel_seconds":maximum_travel,"maximum_retreat_seconds":maximum_retreat,"loadout":game.profile.loadout,"resources":game.profile.resources,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"wall_seconds":float(Time.get_ticks_usec()-started)/1e6}
	FileAccess.open(output+"/early-page-route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EARLY_ROUTE_DONE ",result.status," t=",game.simulated_time," checks=",checks," clicks=",clicks," visits=",visits)
	driver.close();await process_frame;quit()
