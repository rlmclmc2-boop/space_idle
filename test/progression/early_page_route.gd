extends SceneTree
## QA player model: real public actions, one visible page, finite action time.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const STEP:=1.0/60.0
const IDLE_CHECK:=3.0
const PAGE_TOUR:=10.0
const BUTTON_TIME:=0.3 # Explicit test assumption, not a user-specified exact value.
var game
var driver
var trace:FileAccess
var output:String
var next_check:=0.0
var next_tour:=10.0
var next_button:=0.0
var tour:Array=[]
var touring:=false
var tour_started:=0.0
var refit:Dictionary={}
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
func action() -> Dictionary:
	# The battlefield remains visible beside the current workspace. Pickups pay
	# one finite click each; no collection while an unlock covers the battlefield.
	if game.pending_unlocks.is_empty() and not game.paused:
		for drop in game.drops:
			if Rect2(Vector2.ZERO,game.BATTLE_SIZE).has_point(driver.scene.drop_render_position(drop)):
				return {"kind":"pickup","uid":int(drop.uid)}
	if page==0:
		if not refit.is_empty():return {"kind":"refit_select","category":refit.category,"index":refit.index,"key":refit.key}
		var weapon:=str(game.slot_entry("weapons",0).get("key","laser"))
		for key in observed_weapons:
			if game.content_unlocked("equipment",key):weapon=key
		for category in ["weapons","defence"]:
			for index in game.active_slot_count(category):
				var desired:=weapon if category=="weapons" else "shield" if index>0 and game.content_unlocked("equipment","shield") else "armour"
				if not desired.is_empty() and game.content_unlocked("equipment",desired) and str(game.slot_entry(category,index).key)!=desired:
					return {"kind":"refit_open","category":category,"index":index,"key":desired,"reason":"Fill empty mounts; weapon follows latest actually exposed unlocked tutorial, never enemy stats"}
		var choices:Array=[]
		for category in ["weapons","defence"]:
			for index in game.active_slot_count(category):
				var entry:Dictionary=game.slot_entry(category,index)
				if not str(entry.key).is_empty() and game.can_upgrade_slot(category,index):
					choices.append({"category":category,"index":index,"level":int(entry.level)})
		choices.sort_custom(func(a,b):return a.level<b.level if a.level!=b.level else str(a.category)+str(a.index)<str(b.category)+str(b.index))
		if not choices.is_empty():
			var item:Dictionary=choices[0]
			var amount:=10 if game.can_upgrade_slot(item.category,item.index,10) else 1
			if driver.scene.equipment_panel.upgrade_amount!=amount:return {"kind":"upgrade_amount","amount":amount}
			return {"kind":"upgrade_slot","category":item.category,"index":item.index,"amount":amount}
	elif page==1:
		if game.can_generate_scientist(-1):return {"kind":"scientist_max"}
		if game.idle_scientists()>0:return {"kind":"distribute_scientists"}
	elif page==2:
		if game.reactor_max_upgrades()>0:return {"kind":"reactor_max"}
		if game.reactor_allocated()<floori(game.reactor_capacity()):return {"kind":"reactor_balance"}
	elif page==3:
		for key in game.db.ships:
			if game.ship_unlocked(key) and game.active_slot_count("weapons",key)+game.active_slot_count("defence",key)>game.active_slot_count("weapons")+game.active_slot_count("defence"):
				return {"kind":"switch_ship","key":key}
	elif page==4:
		if game.can_upgrade_enhancement():return {"kind":"enhancement_max"}
	elif page==5:
		for member in game.profile.crew:
			if not game.crew.unlocked(game,str(member.crewId)):continue
			if str(member.assignmentType).is_empty():
				for job in ["equipment_upgrade","hightech_scientists","reactor_upgrade","jewel_auto"]:
					for target in game.crew.available_targets(game,job):
						if game.crew.can_assign(game,str(member.crewId),job,str(target.id)):
							return {"kind":"crew_assign","crew":member.crewId,"job":job,"target":target.id,"control_steps":3}
			elif str(member.assignmentType) in ["equipment_upgrade","hightech_scientists"]:
				var desired:="10" if member.assignmentType=="equipment_upgrade" else "max"
				if str(member.upgradeMode)!=desired and game.crew.upgrade_modes(game,str(member.assignmentType)).has(desired):return {"kind":"crew_mode","crew":member.crewId,"job":member.assignmentType,"mode":desired}
	return {}
func click_button(choice:Dictionary) -> void:
	var ok:=false
	var before_resources:Dictionary=game.profile.resources.duplicate(true)
	match choice.kind:
		"pickup":
			for drop in game.drops.duplicate():
				if int(drop.uid)==int(choice.uid):game.collect(drop,true);ok=true;break
		"refit_open":
			var id:String=game.slot_id(choice.category,choice.index)
			driver.scene.equipment_panel.grid_scroll.ensure_control_visible(driver.scene.equipment_panel.cards[id])
			driver.scene.equipment_panel.cards[id].name_button.show_popup()
			refit=choice.duplicate();ok=true
		"refit_select":
			var id:String=game.slot_id(choice.category,choice.index)
			var card=driver.scene.equipment_panel.cards[id]
			var index:int=card.equipment_options.find(str(choice.key))
			if index>=0:
				card.name_button.select(index);card.name_button.item_selected.emit(index);card.name_button.get_popup().hide()
				ok=str(game.slot_entry(choice.category,choice.index).key)==str(choice.key)
			refit.clear()
		"upgrade_amount":
			driver.scene.equipment_panel.amount_buttons[1 if choice.amount==10 else 0].pressed.emit();ok=true
		"upgrade_slot":
			var old_level:int=int(game.slot_entry(choice.category,choice.index).level)
			driver.scene.equipment_panel.cards[game.slot_id(choice.category,choice.index)].upgrade_button.pressed.emit()
			ok=int(game.slot_entry(choice.category,choice.index).level)>old_level
		"scientist_max":ok=game.generate_scientist(-1)
		"distribute_scientists":ok=game.distribute_scientists()
		"reactor_max":ok=game.upgrade_reactor(game.reactor_max_upgrades())
		"reactor_balance":game.equalize_reactor_allocation();ok=true
		"switch_ship":ok=game.switch_ship(choice.key)
		"enhancement_max":ok=game.upgrade_enhancement(-1)>0
		"crew_assign":ok=game.crew.assign(game,str(choice.crew),str(choice.job),str(choice.target))
		"crew_mode":ok=game.crew.set_upgrade_mode(game,str(choice.crew),str(choice.mode),str(choice.job))
	if not ok:printerr("Planned visible button failed: ",choice);quit(2);return
	var steps:int=int(choice.get("control_steps",1))
	clicks+=steps;row(game.stage).clicks+=steps
	choice["resources_before"]=before_resources;choice["resources_after"]=game.profile.resources.duplicate(true)
	choice["loadout_after"]=game.profile.loadout.duplicate(true)
	record("click",choice)
func visit_page(index:int) -> void:
	page=index;driver.scene.select_system(page)
	visits+=1;row(game.stage).page_visits+=1;record("page_visit",{"tour":touring})
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
			touring=false;visit_page(0);next_check=now+BUTTON_TIME;return
		visit_page(int(tour.pop_front()))
	checks+=1;row(game.stage).checks+=1
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
			else:driver.scene.continue_button.pressed.emit()
			if game.pending_unlocks.is_empty() or str(game.pending_unlocks[0])!=current:
				unlock_confirmations+=1;record("unlock_confirmed",{"id":current,"exposure_seconds":now-unlock_since,"path":path});unlock_id=""
	else:unlock_id=""
	if busy:
		if now+0.000001<next_button:return
		var choice:=action()
		if choice.is_empty():
			bursts.append(now-burst_start);busy=false
			next_check=now+(BUTTON_TIME if touring else IDLE_CHECK);record("burst_end",{"seconds":now-burst_start})
		else:click_button(choice);next_button=now+BUTTON_TIME*int(choice.get("control_steps",1))
	elif now+0.000001>=next_check or (not touring and now+0.000001>=next_tour):check_page()
func run() -> void:
	output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
	if output.is_empty():printerr("Isolated diagnostic output required");quit(2);return
	trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
	game=Game.new(ShipDatabase.new());game.rng.seed=20261004;game.stat_cache_enabled=true
	driver=Driver.new();driver.ui_refresh_seconds=1.0;driver.setup(self,game)
	game.event.connect(observe);game.start(1,false)
	FileAccess.open(output+"/save_0.json",FileAccess.WRITE).store_string(JSON.stringify(game.portable_save_data()))
	var limit:=float(OS.get_environment("EARLY_ROUTE_SECONDS"))
	if limit<=0:limit=10800.0
	var started:=Time.get_ticks_usec();var heartbeat:=0
	while game.simulated_time<limit and not clears.has("10"):
		step_controller()
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
	var result={"scope":"Genuine new profile, formal scene providers, exact X1 1/60 ticks; only stages 1-10. No resource injection, no stat changes, no cross-page oracle, refits only to actually exposed unlocked weapon tutorials; no hidden enemy inspection.","assumptions":{"idle_check_seconds":IDLE_CHECK,"tour_start_seconds":PAGE_TOUR,"button_seconds":BUTTON_TIME,"button_mode":"lowest module first; select x10 when affordable otherwise x1; native refit open/select are separate 0.3s actions; scientist/reactor/enhancement use existing MAX; crew picker/target/confirm costs 0.9s","navigation":"Current page checks every3s; tour starts about every10s, empty pages cost0.3s, same-page affordable buttons drain before next page; return to equipment; delays recorded","unlock":"actual production UI countdown called with exact-X1 QA UI clock; each queued ID exposed3s independently; real wall/X10 verified by test_unlock_tutorial, not this accelerated study","later":"This entry stops at clear10; existing later sparse policy remains untouched"},"status":"complete" if clears.has("10") else "bounded_partial","x1_seconds":game.simulated_time,"clears":clears,"stage":game.stage,"deaths":deaths,"checks":checks,"empty_checks":empty_checks,"clicks":clicks,"page_visits":visits,"unlock_confirmations":unlock_confirmations,"burst_seconds":bursts,"tour_seconds":tour_durations,"observed_weapon_tutorials":observed_weapons,"rows":rows,"segments":segments,"maximum_travel_seconds":maximum_travel,"maximum_retreat_seconds":maximum_retreat,"loadout":game.profile.loadout,"resources":game.profile.resources,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"wall_seconds":float(Time.get_ticks_usec()-started)/1e6}
	FileAccess.open(output+"/early-page-route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EARLY_ROUTE_DONE ",result.status," t=",game.simulated_time," checks=",checks," clicks=",clicks," visits=",visits)
	driver.close();await process_frame;quit()
