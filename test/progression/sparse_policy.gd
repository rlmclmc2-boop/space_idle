extends "res://scripts/balance_autoplayer.gd"
## QA assumptions only. Every change uses the public player action APIs.
const VERSION="sparse-v7-losses-across-visits"
var thematic := false
var allow_reforge := true
var use_bulk := false
var scientist_batch_mode := false
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
func preferred(stage: int) -> String:
	return {1:"laser",2:"missile",3:"cannon",6:"longLaser",7:"laser",8:"missile",9:"cannon"}.get(stage,"")
func manual_upgrade_sweep(g,levels:int)->bool:
	# The real toolbar selects +1/+10/MAX per card; no manual all-modules button.
	var changed:=false
	for category in ["weapons","defence"]:
		for index in g.loadout_entries(category).size():
			if g.upgrade_slot(category,index,levels):changed=true
	return changed
func buy_scientist(g:BattleGame,fraction:float)->void:
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
	if int(g.profile.highestLevel)>furthest:
		furthest=int(g.profile.highestLevel);deaths_seen=int(g.metrics.deaths)
	if recovering and g.profile.cleared.has(recovery_end_stage):recovering=false
	forced_weapon=preferred(g.next_stage() if g.state==BattleGame.State.LEVEL_CLEAR and g.pending_unlocks.is_empty() else g.stage) if thematic else ""
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
			for member in g.profile.crew:
				if g.idle_planet_crew(str(member.crewId)) and g.start_planet_exploration(str(id),str(member.crewId)):
					record(g,"start_exploration",{"planet":id,"crew":member.crewId});break
		for row in g.planet_buildings.rows(g,str(id)):
			var state: Dictionary=g.planet_buildings.state(g,str(id),str(row.id))
			if state.get("status","")!="building":continue
			for member in g.profile.crew:
				if state.crew.size()>=int(row.extra_crew):break
				if g.idle_planet_crew(str(member.crewId)) and g.planet_buildings.assign(g,str(id),str(row.id),str(member.crewId)):record(g,"assign_builder",{"planet":id,"building":row.id,"crew":member.crewId})
		# First preparation is evaluated after two further clears (30 -> 32).
		# This is a QA action strategy, not an added gameplay unlock condition.
		var reforge_ready_progress: bool = g.profile.highestLevel>=33 if int(id)==1 else g.stage>=34+5*(int(id)-1)
		if allow_reforge and reforge_ready_progress and g.can_reforge_planet(str(id)):
			if g.reforge_planet(str(id)):
				farm={};best_won={};deaths_seen=int(g.metrics.deaths)
				record(g,"reforge",{"planet":id});recovering=true;recovery_end_stage=35+5*(int(id)-1);furthest=int(g.profile.highestLevel)
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
		farm={"target":g.stage,"since":elapsed,"modules":module_sum(g),"node":1}
		g.start(chosen_stage,false)
		g.toggle_loop()
		record(g,"travel_to_farm_point",{"stage":chosen_stage,"node":farm.node,"target":farm.target});deaths_seen=int(g.metrics.deaths)
	if cap_stage>0 and (g.stage>cap_stage or (g.stage==cap_stage and g.profile.cleared.has(cap_stage) and not g.profile.loop)):
		g.start(cap_stage,false);g.toggle_loop();farm={}
		record(g,"farm_after_progression_cap",{"stage":cap_stage,"node":1})
	# A push/return can change stage after the initial transaction pass.
	# Fit that newly chosen stage during this same real visit, never on a hidden tick.
	if thematic:
		var chosen:=preferred(g.stage)
		if not chosen.is_empty() and g.profile.unlocked.has(chosen):
			for index in g.weapon_entries().size():
				if str(g.weapon_entries()[index].key)!=chosen:g.equip_slot("weapons",index,chosen)
	return changed
