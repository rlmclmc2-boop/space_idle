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
	# Only the current visible page can produce an action; no cross-page sweep.
	if page==0:
		var choices:Array=[]
		for category in ["weapons","defence"]:
			for index in game.active_slot_count(category):
				var entry:Dictionary=game.slot_entry(category,index)
				if not str(entry.key).is_empty() and game.can_upgrade_slot(category,index):
					choices.append({"category":category,"index":index,"level":int(entry.level)})
		choices.sort_custom(func(a,b):return a.level<b.level if a.level!=b.level else str(a.category)+str(a.index)<str(b.category)+str(b.index))
		if not choices.is_empty():return {"kind":"upgrade_slot","category":choices[0].category,"index":choices[0].index}
	elif page==1:
		if game.can_generate_scientist(1):return {"kind":"scientist_one"}
		if game.idle_scientists()>0:return {"kind":"distribute_scientists"}
	elif page==2:
		if game.reactor_max_upgrades()>0:return {"kind":"reactor_one"}
		if game.reactor_allocated()<game.reactor_capacity():return {"kind":"reactor_balance"}
	elif page==3:
		for key in game.db.ships:
			if game.ship_unlocked(key) and game.active_slot_count("weapons",key)+game.active_slot_count("defence",key)>game.active_slot_count("weapons")+game.active_slot_count("defence"):
				return {"kind":"switch_ship","key":key}
	elif page==4:
		if game.can_upgrade_enhancement():return {"kind":"enhancement_one"}
	return {}
func click_button(choice:Dictionary) -> void:
	var ok:=false
	match choice.kind:
		"upgrade_slot":ok=game.upgrade_slot(choice.category,choice.index,1)
		"scientist_one":ok=game.generate_scientist(1)
		"distribute_scientists":ok=game.distribute_scientists()
		"reactor_one":ok=game.upgrade_reactor(1)
		"reactor_balance":game.equalize_reactor_allocation();ok=true
		"switch_ship":ok=game.switch_ship(choice.key)
		"enhancement_one":ok=game.upgrade_enhancement(1)>0
	if not ok:printerr("Planned visible button failed: ",choice);quit(2);return
	clicks+=1;row(game.stage).clicks+=1;record("click",choice)
func check_page() -> void:
	var now:float=game.simulated_time
	if tour.is_empty() and now+0.000001>=next_tour:
		driver.scene.refresh_tab_visibility()
		for index in driver.scene.equipment_tabs.get_tab_count():
			if not driver.scene.equipment_tabs.is_tab_hidden(index):tour.append(index)
		next_tour=now+PAGE_TOUR
		record("tour_start",{"pages":tour.duplicate()})
	if not tour.is_empty():
		page=int(tour.pop_front());driver.scene.select_system(page)
		visits+=1;row(game.stage).page_visits+=1;record("page_visit")
	checks+=1;row(game.stage).checks+=1
	var choice:=action();record("check",{"action_available":not choice.is_empty()})
	if choice.is_empty():
		empty_checks+=1;row(game.stage).growth_blocked_checks+=1;next_check=now+IDLE_CHECK
	else:
		busy=true;burst_start=now;next_button=now+BUTTON_TIME
func step_controller() -> void:
	var now:float=game.simulated_time
	# Per-notice three-second X1 exposure; never batch-confirm a queue.
	if not game.pending_unlocks.is_empty():
		var current:String=game.pending_unlocks[0]
		if current!=unlock_id:unlock_id=current;unlock_since=now;record("unlock_exposed",{"id":current})
		if now-unlock_since+0.000001>=3.0:
			game.acknowledge_unlocks();unlock_confirmations+=1;record("unlock_confirmed",{"id":current,"exposure_seconds":now-unlock_since});unlock_id=""
	else:unlock_id=""
	if busy:
		if now+0.000001<next_button:return
		var choice:=action()
		if choice.is_empty():
			bursts.append(now-burst_start);busy=false;next_check=now+IDLE_CHECK;record("burst_end",{"seconds":now-burst_start})
		else:click_button(choice);next_button=now+BUTTON_TIME
	elif now+0.000001>=next_check:check_page()
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
	var result={"scope":"Genuine new profile, formal scene providers, exact X1 1/60 ticks; only stages 1-10. No resource injection, no stat changes, no cross-page oracle, no automatic refit.","assumptions":{"idle_check_seconds":IDLE_CHECK,"tour_start_seconds":PAGE_TOUR,"button_seconds":BUTTON_TIME,"button_mode":"one existing +1 button at a time, lowest module level first on equipment page; repeat on same page until no executable button remains","navigation":"One unlocked page per 3-second check; busy bursts defer page tours; settings/save visits count, buy nothing","unlock":"each queued ID exposed 3 X1 seconds then confirmed separately; X1 study, no X10 claim","later":"This entry stops at clear10; existing later sparse policy remains untouched"},"status":"complete" if clears.has("10") else "bounded_partial","x1_seconds":game.simulated_time,"clears":clears,"stage":game.stage,"deaths":deaths,"checks":checks,"empty_checks":empty_checks,"clicks":clicks,"page_visits":visits,"unlock_confirmations":unlock_confirmations,"burst_seconds":bursts,"rows":rows,"segments":segments,"maximum_travel_seconds":maximum_travel,"maximum_retreat_seconds":maximum_retreat,"loadout":game.profile.loadout,"resources":game.profile.resources,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"wall_seconds":float(Time.get_ticks_usec()-started)/1e6}
	FileAccess.open(output+"/early-page-route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EARLY_ROUTE_DONE ",result.status," t=",game.simulated_time," checks=",checks," clicks=",clicks," visits=",visits)
	driver.close();await process_frame;quit()
