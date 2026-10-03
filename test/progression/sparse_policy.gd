extends "res://scripts/balance_autoplayer.gd"
## QA assumptions only. Every change uses the public player action APIs.
const VERSION="sparse-v13-explicit-earned-farm-study"
var unlock_visit_limit := 32
var later_preparation_stages := 3
var fixed_farm_stage := 0
var fixed_weapon_from_stage := 0
var fixed_weapon_key := ""
var fixed_weapon_active := false
var fixed_weapon_stage_seen := false
var thematic := false
var allow_reforge := true
var use_bulk := false
var scientist_batch_mode := false
var scientist_max_mode := false
var recovering := false
var recovery_end_stage := 0
var farm := {}
var deaths_seen := 0
var last_progress := 0.0
var furthest := 1
var best_won := {}
var galaxy_crew_target := 6
var cap_stage := 0
var journal: Callable
func record(g, kind: String, extra: Dictionary = {}) -> void:
	if journal.is_valid():journal.call(kind,extra)
func module_sum(g) -> int:
	var total := 0
	for category in ["weapons","defence"]:
		for entry in g.loadout_entries(category):total+=int(entry.level)
	return total
func acknowledge_pending_in_visit(g:BattleGame)->int:
	var count:=0
	for notification in clampi(unlock_visit_limit,1,32):
		if g.pending_unlocks.is_empty():break
		g.acknowledge_unlocks();count+=1
	return count
func observe_progress_stage(stage:int)->void:
	if fixed_weapon_from_stage>0 and stage>=fixed_weapon_from_stage:fixed_weapon_stage_seen=true
func reforge_progress_ready(g:BattleGame,planet_id:int)->bool:
	if planet_id==1:return g.profile.highestLevel>=33
	if later_preparation_stages==2:
		var unlocked_after_clear:int=25+5*planet_id
		return g.profile.cleared.has(unlocked_after_clear+1) and g.profile.cleared.has(unlocked_after_clear+2)
	# Retain the historical three-clear/actual-stage strategy for comparison.
	return g.stage>=34+5*(planet_id-1)
func commit_fixed_weapon_in_visit(g:BattleGame)->void:
	if fixed_weapon_active or fixed_weapon_from_stage<=0 or fixed_weapon_key.is_empty():return
	if g.stage<fixed_weapon_from_stage and not fixed_weapon_stage_seen:return
	assert(g.profile.unlocked.has(fixed_weapon_key))
	fixed_weapon_active=true
	record(g,"fixed_weapon_commit",{"weapon":fixed_weapon_key,"from_stage":fixed_weapon_from_stage,"frontier":g.profile.highestLevel,"actual_visit_stage":g.stage,"assumption":"one declared whole-stage weapon choice after actual arrival, retained while farming; no per-enemy or hidden-tick choice"})
func preferred(stage: int) -> String:
	return {1:"laser",2:"missile",3:"cannon",6:"longLaser",7:"laser",8:"missile",9:"cannon"}.get(stage,"")
func manual_upgrade_sweep(g,levels:int)->bool:
	# The real toolbar selects +1/+10/MAX per card; no manual all-modules button.
	var changed:=false
	for category in ["weapons","defence"]:
		for index in g.loadout_entries(category).size():
			if g.upgrade_slot(category,index,levels):changed=true
	return changed
func recall_conquered_for_preparation(g:BattleGame,planet_id:String,building_id:String="")->bool:
	# One explicit recall at a real visit; permanent conquered bonuses remain,
	# but the recalled planet loses continuing exploration and its partial trip.
	for member in g.profile.crew:
		if g.idle_planet_crew(str(member.crewId)):return false
	for source_id in g.profile.planets:
		var progress:Dictionary=g.planet_progress(str(source_id))
		var crew_id:=str(progress.get("crewId",""))
		if str(source_id)==planet_id or not progress.get("conquered",false) or crew_id.is_empty():continue
		var elapsed_before:float=float(progress.get("elapsed",0))
		if g.cancel_planet_exploration(str(source_id)):
			record(g,"recall_conquered_for_building" if not building_id.is_empty() else "recall_conquered_for_exploration",{"planet":source_id,"crew":crew_id,"target_planet":planet_id,"building":building_id,"forfeited_trip_seconds":elapsed_before,"tradeoff":"stops this planet's continuing exploration; no free replacement crew"})
			return true
	# Fixed sensitivity assumption if no conquered explorer can be recalled:
	# move one existing growth worker, preserving the real lost automation.
	for assignment in ["jewel_auto","reactor_upgrade","hightech_scientists","equipment_upgrade"]:
		for member in g.profile.crew:
			if str(member.assignmentType)!=assignment or not g.crew.unlocked(g,str(member.crewId)):continue
			var previous:Dictionary=member.duplicate(true)
			if g.assign_crew(str(member.crewId),"",""):
				record(g,"reassign_growth_for_preparation",{"crew":member.crewId,"previous":previous,"target_planet":planet_id,"building":building_id,"tradeoff":"old growth assignment stops; same existing crew, fixed jewel/reactor/science/equipment priority"})
				return true
	return false
func buy_scientist(g:BattleGame,fraction:float)->void:
	# Independent sensitivity assumption: existing MAX button, no hidden buys.
	# It may spend most uranium; measure progression AND construction blocking.
	if scientist_max_mode and g.stage>=6:
		var purchase:Dictionary=g.scientist_purchase(-1)
		if int(purchase.count)>0 and g.generate_scientist(-1):
			record(g,"scientist_max",{"amount":purchase.count,"costs":purchase.costs,"assumption":"one actual MAX click per sparse visit; no reserve cap"})
		return
	# Optional sparse-visit assumption: existing +10 button, same reserve cap.
	if scientist_batch_mode and g.stage>=6:
		var purchase:Dictionary=g.scientist_purchase(10)
		var cheap:bool=int(purchase.count)==10
		for id in purchase.costs:
			if float(purchase.costs[id])>float(g.profile.resources.get(id,0))*fraction:cheap=false
		if cheap and g.generate_scientist(10):
			record(g,"scientist_batch",{"amount":10,"reserve_fraction":fraction});return
	super.buy_scientist(g,fraction)
func act(g: BattleGame, elapsed: float) -> bool:
	# One visit may read several already queued notifications, each via the
	# actual one-page API. Legacy limit1 keeps the old act ordering exactly.
	unlock_acknowledgements_per_visit=1
	if unlock_visit_limit>1:
		var count:=acknowledge_pending_in_visit(g)
		unlock_acknowledgements_per_visit=0
		if count>0:record(g,"notification_visit_batch",{"acknowledged":count,"limit":32,"remaining":g.pending_unlocks.size(),"assumption":"several real confirmations during the same actual visit"})
		if not g.pending_unlocks.is_empty():return count>0
	commit_fixed_weapon_in_visit(g)
	if int(g.profile.highestLevel)>furthest:
		furthest=int(g.profile.highestLevel);deaths_seen=int(g.metrics.deaths)
	if recovering and g.profile.cleared.has(recovery_end_stage):recovering=false
	forced_weapon=fixed_weapon_key if fixed_weapon_active else (preferred(g.next_stage() if g.state==BattleGame.State.LEVEL_CLEAR and g.pending_unlocks.is_empty() else g.stage) if thematic else "")
	respect_guard=true
	var changed: bool = super.act(g,elapsed)
	# Each real visit can process an affordable enhancement; resume-clock phase
	# does not define player permissions. Base policy may already have done it.
	if g.enhancement_unlocked():
		g.upgrade_enhancement(-1)
		# Explicit human-proxy assumption: choose the first displayed option once
		# when a branch opens. Never optimize or respec it between visits.
		for category in g.default_enhancement_order():
			for effect in g.default_enhancement_order()[category]:
				for node in [1,2,3]:
					if g.enhancement_branch_unlocked(category,effect,node) and g.enhancement_branch_choice(category,effect,node).is_empty():
						if g.set_enhancement_branch(category,effect,node,"A"):record(g,"choose_enhancement_branch",{"category":category,"effect":effect,"node":node,"choice":"A","assumption":"first option, no automatic respec"})
	if (use_bulk or recovering) and g.stage>=6:
		# Declared optional strategy: visit each real module card at +10/+1.
		for attempt in range(3):
			if manual_upgrade_sweep(g,10):record(g,"manual_card_sweep",{"mode":"10"})
			elif manual_upgrade_sweep(g,1):record(g,"manual_card_sweep",{"mode":"1"})
			else:break
	# Activate each explicitly ready building; reserve idle crews for exploration/building first.
	for id in g.profile.planets:
		if not g.planet_unlocked(str(id)):continue
		for row in g.planet_buildings.rows(g,str(id)):
			if g.planet_buildings.state(g,str(id),str(row.id)).get("status","")=="ready":
				if g.planet_buildings.activate(g,str(id),str(row.id)):record(g,"activate_building",{"planet":id,"building":row.id})
		if g.planet_progress(str(id)).crewId.is_empty() and not g.planet_progress(str(id)).get("conquered",false):
			recall_conquered_for_preparation(g,str(id))
			for member in g.profile.crew:
				if g.idle_planet_crew(str(member.crewId)) and g.start_planet_exploration(str(id),str(member.crewId)):
					record(g,"start_exploration",{"planet":id,"crew":member.crewId});break
		for row in g.planet_buildings.rows(g,str(id)):
			var state: Dictionary=g.planet_buildings.state(g,str(id),str(row.id))
			if state.get("status","")!="building":continue
			if state.crew.size()<int(row.extra_crew) and not g.planet_progress(str(id)).get("conquered",false):
				recall_conquered_for_preparation(g,str(id),str(row.id))
			for member in g.profile.crew:
				if state.crew.size()>=int(row.extra_crew):break
				if g.idle_planet_crew(str(member.crewId)) and g.planet_buildings.assign(g,str(id),str(row.id),str(member.crewId)):record(g,"assign_builder",{"planet":id,"building":row.id,"crew":member.crewId})
		# First preparation is evaluated after two further clears (30 -> 32).
		# This is a QA action strategy, not an added gameplay unlock condition.
		var reforge_ready_progress: bool = reforge_progress_ready(g,int(id))
		if allow_reforge and reforge_ready_progress and g.can_reforge_planet(str(id)):
			if g.reforge_planet(str(id)):
				farm={};best_won={};deaths_seen=int(g.metrics.deaths)
				record(g,"reforge",{"planet":id,"preparation_stage_assumption":2 if int(id)==1 else later_preparation_stages});recovering=true;recovery_end_stage=35+5*(int(id)-1);furthest=int(g.profile.highestLevel)
				# Major reforge visit: rebuild with existing +10 card actions.
				# Every successful card emits its own upgrade event for operation counts.
				for attempt in range(24):
					if not manual_upgrade_sweep(g,10):break
					record(g,"reforge_card_sweep",{"mode":"10"})
	# Conquered explorers can be recalled through the same manual player action.
	if g.galaxy.available():
		for id in g.profile.planets:
			var planet: Dictionary=g.planet_progress(str(id))
			if planet.get("conquered",false) and not str(planet.crewId).is_empty():
				if g.cancel_planet_exploration(str(id)):record(g,"recall_conquered_explorer",{"planet":id})
		# Declared QA allocation assumption: after the last planet is conquered,
		# move up to six unlocked, legally unoccupied crew to first-galaxy work.
		# Obey authored maxCrew and preserve other growth assignments.
		var available:Array=g.profile.crew.filter(func(member):return g.crew.unlocked(g,str(member.crewId)) and g.crew_exploration(str(member.crewId)).is_empty())
		var target:int=mini(mini(galaxy_crew_target,int(g.crew.assignments(g).galaxy_explore.maxCrew)),maxi(1,available.size()-2))
		for member in available:
			if g.galaxy.crew_count(g,"galaxy_1")>=target:break
			if str(member.assignmentType)=="galaxy_explore":continue
			if g.assign_crew(str(member.crewId),"galaxy_explore","galaxy_1"):record(g,"reallocate_galaxy",{"crew":member.crewId,"target":target})
	# Keep two idle for future planets until galaxy unlock.
	var idle: Array=g.profile.crew.filter(func(member):return g.idle_planet_crew(str(member.crewId)))
	for member in idle.slice(0 if g.galaxy.available() else 2):
		var crew_id := str(member.crewId)
		if g.galaxy.available():
			for key in g.galaxy.regions:
				if g.assign_crew(crew_id,"galaxy_explore",str(key)):record(g,"assign_galaxy",{"crew":crew_id,"galaxy":key});break
		else:
			for pair in [["equipment_upgrade","equipment"],["hightech_scientists","hightech"],["reactor_upgrade","reactor"],["jewel_auto","jewels"]]:
				if g.assign_crew(crew_id,pair[0],pair[1]):record(g,"assign_crew",{"crew":crew_id,"assignment":pair[0]});break
	# Two deaths trigger current-stage first-normal farming if already won.
	# Toggle at departure legally selects first point and preserves real travel.
	# This avoids a sparse visit overshooting node5 into an elite/Boss.
	# Resume on five real module levels (meaningful batch), or reconsider after 15min.
	if not farm.is_empty():
		if not g.profile.loop and g.stage==int(farm.target) and g.group_index>=int(farm.node) and g.state==BattleGame.State.COMBAT:
			g.toggle_loop();record(g,"begin_farm_guard",{"stage":g.stage,"node":g.group_index})
		if module_sum(g)>=int(farm.modules)+5 or elapsed-float(farm.since)>=900:
			var target: int=int(farm.target)
			g.start(target,false);record(g,"resume_push",{"target":target});farm={};deaths_seen=int(g.metrics.deaths)
	elif g.stage>=6 and g.metrics.deaths-deaths_seen>=2 and g.profile.cleared.has(g.stage-1):
		var node: int=int(best_won.get(str(g.stage),0))
		var chosen_stage: int=g.stage if node>0 else g.stage-1
		if fixed_farm_stage>0 and g.profile.cleared.has(fixed_farm_stage):chosen_stage=fixed_farm_stage
		farm={"target":g.stage,"since":elapsed,"modules":module_sum(g),"node":1}
		g.start(chosen_stage,false)
		g.toggle_loop()
		record(g,"travel_to_farm_point",{"stage":chosen_stage,"node":farm.node,"target":farm.target,"fixed_earned_stage_assumption":fixed_farm_stage});deaths_seen=int(g.metrics.deaths)
	if cap_stage>0 and (g.stage>cap_stage or (g.stage==cap_stage and g.profile.cleared.has(cap_stage) and not g.profile.loop)):
		g.start(cap_stage,false);g.toggle_loop();farm={}
		record(g,"farm_after_progression_cap",{"stage":cap_stage,"node":1})
	# A push/return can change stage after the initial transaction pass.
	# Fit that newly chosen stage during this same real visit, never on a hidden tick.
	commit_fixed_weapon_in_visit(g)
	if thematic or fixed_weapon_active:
		var chosen:=fixed_weapon_key if fixed_weapon_active else preferred(g.stage)
		if not chosen.is_empty() and g.profile.unlocked.has(chosen):
			for index in g.weapon_entries().size():
				if str(g.weapon_entries()[index].key)!=chosen:g.equip_slot("weapons",index,chosen)
	return changed
