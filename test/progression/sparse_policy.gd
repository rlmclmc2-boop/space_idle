extends "res://scripts/balance_autoplayer.gd"
## QA assumptions only. Every change uses the public player action APIs.
var thematic := false
var allow_reforge := true
var farm := {}
var deaths_seen := 0
var last_progress := 0.0
var furthest := 1
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
func act(g: BattleGame, elapsed: float) -> bool:
	var changed: bool = super.act(g,elapsed)
	if thematic:
		var weapon := preferred(g.stage)
		if not weapon.is_empty() and g.profile.unlocked.has(weapon):
			for index in g.weapon_entries().size():
				if str(g.weapon_entries()[index].key)!=weapon:g.equip_slot("weapons",index,weapon)
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
		if allow_reforge and g.stage>=34+5*(int(id)-1) and g.can_reforge_planet(str(id)):
			if g.reforge_planet(str(id)):record(g,"reforge",{"planet":id})
	# Assign actual idle crews, once systems are unlocked. Keep two available for future planets.
	var idle: Array=g.profile.crew.filter(func(member):return g.idle_planet_crew(str(member.crewId)))
	for member in idle.slice(2):
		var crew_id := str(member.crewId)
		if g.galaxy.available():
			for key in g.galaxy.regions:
				if g.assign_crew(crew_id,"galaxy_explore",str(key)):record(g,"assign_galaxy",{"crew":crew_id,"galaxy":key});break
		else:
			for pair in [["equipment_upgrade","equipment"],["hightech_scientists","hightech"],["reactor_upgrade","reactor"],["jewel_auto","jewels"]]:
				if g.assign_crew(crew_id,pair[0],pair[1]):record(g,"assign_crew",{"crew":crew_id,"assignment":pair[0]});break
	# Two deaths between visits trigger farming an already cleared level's first battle point.
	# Resume on five real module levels (meaningful batch), or reconsider after 15min.
	if not farm.is_empty():
		if module_sum(g)>=int(farm.modules)+5 or elapsed-float(farm.since)>=900:
			var target: int=int(farm.target)
			g.start(target,false);record(g,"resume_push",{"target":target});farm={}
	elif g.stage>=6 and g.metrics.deaths-deaths_seen>=2 and g.profile.cleared.has(g.stage-1):
		farm={"target":g.stage,"since":elapsed,"modules":module_sum(g)}
		g.start(g.stage-1,false);g.toggle_loop();record(g,"farm_battle_point",{"stage":g.stage,"node":g.profile.guardIndex,"target":farm.target})
	deaths_seen=int(g.metrics.deaths)
	return changed
