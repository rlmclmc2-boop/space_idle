extends SceneTree
class BlockedGame extends BattleGame:
	var reject_change := false
	func native_before_configuration_change() -> bool:
		return false if reject_change else super.native_before_configuration_change()
var failures := 0
var checks := 0
var scenario := ""
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(scenario+": "+message)
func _initialize() -> void:
	run_case("live configuration",{})
	run_case("changed balance",{"base_exp":37,"exp_multiplier":1.7,"equip_bonus":0.23,"tech_speed":0.35,"gem_bonus":0.27,"charge_bonus":0.45})
	run_case("zero bonuses and flat XP",{"base_exp":10,"exp_multiplier":1.0,"equip_bonus":0.0,"tech_speed":0.0,"gem_bonus":0.0,"charge_bonus":0.0})
	run_boundaries()
	print("crew levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func run_case(label: String, overrides: Dictionary) -> void:
	scenario=label
	var db:=ShipDatabase.new()
	for key in overrides:db.data.crew_config[key].value=overrides[key]
	# Unlock boundaries belong to unlock tests. Keep this level/effect fixture stable.
	for gate in db.data.unlock.values():gate.level=0
	db.data.unlock[db.unlock_id("feature","crew_level")].level=1
	db.data.unlock[db.unlock_id("feature","crew_level")].mode="cleared"
	var cfg: Dictionary=db.data.crew_config
	var equipment_factor: float=pow(1.0+float(cfg.equip_bonus.value),3)
	var gem_factor: float=1.0+float(cfg.gem_bonus.value)*2
	var charge_factor: float=1.0+float(cfg.charge_bonus.value)*2
	# Text-format assertions use controlled templates, independent of editable wording.
	cfg.equip_bonus.des="Equipment {effect}"
	cfg.tech_speed.des="Research {effect}"
	cfg.gem_bonus.des="Fragments {effect}"
	cfg.charge_bonus.des="Energy {effect}"
	cfg.name_level.des="{name} Lv{level}"
	var g:=BattleGame.new(db,false)
	var c=g.crew
	g.profile.cleared=[]
	g.rebuild_unlocks()
	check(c.entry(g,"navigator").level==0,"Fresh crew starts at zero")
	g.assign_crew("navigator","equipment_upgrade","equipment")
	var module: Dictionary=g.slot_entry("weapons",0)
	var base = g.jewel_equipment_stat(module)
	var stored: Dictionary=c.save_data();stored.crew[0].level=3;check(c.install_snapshot(stored,db),"Current complete crew fixture installs")
	check(not c.levels_unlocked(g) and g.jewel_equipment_stat(module)==base,"Locked ignores stored levels")
	check(not g.add_crew_exp("navigator",100),"Locked rejects XP")
	check(not c.display_name(g,c.entry(g,"navigator")).contains("Lv"),"Locked name hides levels")
	g.profile.cleared.append(1)
	g.rebuild_unlocks()
	check(c.levels_unlocked(g),"Existing clear unlocks feature")
	for effect_key in ["equip_bonus","tech_speed","gem_bonus","charge_bonus"]:
		check(c.level_effect(g,effect_key,0)==1.0,"Level zero has no multiplier bonus: "+effect_key)
	check(c.level_description(g,c.entry(g,"navigator")).contains("%+.2f%%" % ((equipment_factor-1.0)*100)),"Equipment compounded bonus uses two decimal places")
	check(is_equal_approx(g.jewel_equipment_stat(module),base*equipment_factor),"Equipment uses exponential level projection")
	check(is_equal_approx(g.jewel_equipment_stat(module),base*equipment_factor),"Repeated reads do not compound")
	g.assign_crew("navigator","","")
	check(g.jewel_equipment_stat(module)==base,"Removing assignment removes effect")
	c.reset(g)
	check(c.entry(g,"navigator").level==0,"Fresh crew reset starts at level zero")
	g.profile.cleared=range(1,61);g.rebuild_unlocks()
	var first_cost: float=maxf(1.0,roundf(float(cfg.base_exp.value)))
	var second_cost: float=maxf(1.0,roundf(float(cfg.base_exp.value)*float(cfg.exp_multiplier.value)))
	g.add_crew_exp("navigator",first_cost+second_cost)
	check(c.entry(g,"navigator").level==2,"XP from zero uses configured curve")
	var base_speed:float=g.research.research_speed(g)
	var ai_count:int=g.research.ai_count(g)
	check(g.assign_crew("navigator","hightech_scientists","hightech"),"Factory retains its saved job identity")
	var research_factor:float=1.0+float(cfg.tech_speed.value)*2.0
	check(is_equal_approx(g.research.research_speed(g),base_speed*research_factor) and g.research.ai_count(g)==ai_count,"Crew level scales actual research speed once without adding AI")
	check(g.select_tech("weapon_accuracy"),"Start actual research while crew is assigned")
	g.advance_hightech(0.5)
	check(is_equal_approx(g.research.progress("weapon_accuracy"),base_speed*research_factor*0.5),"Configured crew bonus reaches actual progress")
	db.data.crew_config.tech_speed.des="自定义 {level}/{value}/{effect}/{unknown}"
	var description: String=c.level_description(g,c.entry(g,"navigator"))
	check(description.contains("自定义 2/") and description.contains("/{unknown}") and not description.contains("{effect}") and not description.contains("{value}"),"Descriptions substitute safe placeholders")
	g.assign_crew("navigator","","")
	check(is_equal_approx(g.research.research_speed(g),base_speed) and g.research.selected()=="weapon_accuracy","Recall removes only crew speed and preserves active research")
	g.assign_crew("navigator","jewel_auto","jewels")
	check(c.level_description(g,c.entry(g,"navigator")).contains("Fragments %+.2f%%" % ((gem_factor-1.0)*100)),"Jewel bonus uses two decimal percent")
	check(is_equal_approx(g.settle_jewel_fragments(10,"drop",1),snappedf(10*gem_factor,0.01)),"Direct fragments use bonus")
	check(is_equal_approx(g.settle_jewel_fragments(10,"furnace",1),10),"Furnace fragments unchanged")
	g.assign_crew("navigator","","")
	var energy=g.reactor_energy()
	g.assign_crew("navigator","reactor_upgrade","reactor")
	check(c.level_description(g,c.entry(g,"navigator")).contains("Energy %+.2f%%" % ((charge_factor-1.0)*100)),"Reactor bonus uses two decimal percent")
	check(is_equal_approx(g.reactor_energy(),energy*charge_factor),"Energy derives current level")
	g.assign_crew("navigator","","")
	check(g.reactor_energy()==energy,"Energy returns to base")

func run_boundaries() -> void:
	scenario="crew commit boundary"
	var db:=ShipDatabase.new()
	for gate in db.data.unlock.values():gate.level=0
	var g:=BlockedGame.new(db,false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	check(not g.profile.has("crew") and g.crew.members().is_read_only() and g.crew.entry(g,"navigator").is_read_only() and g.crew.entry(g,"navigator").equipmentSlots.is_read_only(),"Owner exposes read-only live views")
	var detached:=g.crew.save_data();detached.crew[0].level=99
	check(g.crew.entry(g,"navigator").level==0,"Save snapshot is detached")
	var invalid:=g.crew.save_data();invalid.crew[1].crewId=invalid.crew[0].crewId
	check(not g.crew.install_snapshot(invalid,db),"Duplicate crew snapshot is rejected intact")
	var stale:=g.crew.prepare_experience(g,{"navigator":100})
	g.set_crew_upgrade_mode("navigator","10")
	check(not g.crew.proposal_current(stale),"Prepared XP rejects a changed crew version")
	g.reject_change=true
	var before:=g.crew.save_data()
	check(not g.assign_crew("navigator","reactor_upgrade","reactor") and g.crew.save_data()==before,"Rejected native preparation leaves assignment intact")
	check(not g.add_crew_exp("navigator",g.crew.required_exp(g,0)) and g.crew.save_data()==before,"Rejected native preparation leaves XP and level intact")
	g.reject_change=false
	check(g.assign_crew("engineer","equipment_upgrade","equipment") and g.assign_crew("researcher","reactor_upgrade","reactor"),"Shared payout affects two live contribution consumers")
	# Use the existing configuration-driven share condition, including unchanged
	# all-crew unlock filtering and construction before/after trip semantics.
	db.data.planet_buff["payout_fixture"]={"id":9999,"planet_id":1,"source":"building","source_id":"station","condition":"always","buff_type":"crew_exp_share","target":"all","value":1,"stack":"max","order":99,"des":"fixture"}
	db.data.planet["1"].baseExp=1000
	check(g.start_planet_exploration("1","navigator"),"Start actual exploration for batch payout")
	var rewards: Dictionary={}
	for member in g.crew.members():rewards[member.crewId]=g.planet_exp_reward("1")
	var expected:=g.crew.prepare_experience(g,rewards)
	var previous_planets: Dictionary=g.planets.save_data().planets;before=g.crew.save_data()
	g.reject_change=true;g.advance_planets(g.planet_duration("1"))
	check(g.planets.all()==previous_planets and g.crew.save_data()==before,"Rejected payout preserves trip, construction and every crew member")
	g.reject_change=false
	var observed: Array=[]
	var observer:=func(kind,_payload):
		if kind in ["crew_changed","equipment_stats","reactor_changed","planet_changed"]:observed.append(g.portable_save_data())
	g.event.connect(observer);g.advance_planets(g.planet_duration("1"));g.event.disconnect(observer)
	check(not observed.is_empty() and observed.all(func(snapshot):return snapshot.crew==expected.members and snapshot.planets["1"].degree==1 and snapshot.planets["1"].crewId==""),"Every notification sees completed trip and entire XP payout")
	check(g.crew.members().all(func(member):return member.level>0),"Shared XP reaches every unlocked crew")
	var galaxy_key:=str(g.galaxy.regions.keys()[0])
	observed.clear()
	var assignment_observer:=func(kind,_payload):
		if kind in ["crew_changed","galaxy_changed"]:observed.append({"assignment":g.crew.entry(g,"navigator").assignmentType,"status":g.galaxy.regions[galaxy_key].state.status})
	g.event.connect(assignment_observer);check(g.assign_crew("navigator","galaxy_explore",galaxy_key),"Assign crew and begin region");g.event.disconnect(assignment_observer)
	check(not observed.is_empty() and observed.all(func(value):return value.assignment=="galaxy_explore" and value.status=="exploring"),"Region start and crew assignment precede both notifications")
	g.galaxy.set_pending_context(galaxy_key,1);g.galaxy.add_pending(galaxy_key,0.25)
	var region=g.galaxy.regions[galaxy_key];var prediction=region.predict_advance(0.25,1)
	check(g.assign_crew("navigator","","") and g.galaxy.pending(galaxy_key)==0,"Recall settles pending original crew time")
	check(region.state==prediction.state and region.random.state==prediction.random.state,"Recall settlement matches original one-crew algorithm")
