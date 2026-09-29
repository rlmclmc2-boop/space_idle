extends SceneTree
var failures := 0
var checks := 0
var scenario := ""
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(scenario+": "+message)
func _initialize() -> void:
	run_case("live configuration",{})
	run_case("changed balance",{"base_exp":37,"exp_multiplier":1.7,"equip_bonus":0.23,"tech_ai_per_level":3,"tech_speed":0.35,"gem_bonus":0.27,"charge_bonus":0.45})
	run_case("zero bonuses and flat XP",{"base_exp":10,"exp_multiplier":1.0,"equip_bonus":0.0,"tech_ai_per_level":0,"tech_speed":0.0,"gem_bonus":0.0,"charge_bonus":0.0})
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
	var ai: int=int(cfg.tech_ai_per_level.value)*2
	var speed_factor: float=1.0+float(cfg.tech_speed.value)*2
	var gem_factor: float=1.0+float(cfg.gem_bonus.value)*2
	var charge_factor: float=1.0+float(cfg.charge_bonus.value)*2
	# Text-format assertions use controlled templates, independent of editable wording.
	cfg.equip_bonus.des="Equipment {effect}"
	cfg.tech_ai_per_level.des="AI {ai}"
	cfg.tech_speed.des="Research {effect}"
	cfg.gem_bonus.des="Fragments {effect}"
	cfg.charge_bonus.des="Energy {effect}"
	cfg.name_level.des="{name} Lv{level}"
	var g:=BattleGame.new(db,false)
	var c=g.crew
	g.profile.cleared=[]
	g.rebuild_unlocks()
	check(c.entry(g,"navigator").level==0,"Fresh crew starts at zero")
	c.assign(g,"navigator","equipment_upgrade","equipment")
	var module: Dictionary=g.slot_entry("weapons",0)
	var base = g.jewel_equipment_stat(module)
	c.entry(g,"navigator").level=3
	check(not c.levels_unlocked(g) and g.jewel_equipment_stat(module)==base,"Locked ignores stored levels")
	check(not g.add_crew_exp("navigator",100),"Locked rejects XP")
	check(not c.display_name(g,c.entry(g,"navigator")).contains("Lv"),"Locked name hides levels")
	g.profile.cleared.append(1)
	g.rebuild_unlocks()
	check(c.levels_unlocked(g),"Existing clear unlocks feature")
	for effect_key in ["equip_bonus","tech_speed","gem_bonus","charge_bonus"]:
		check(c.level_effect(g,effect_key,0)==1.0,"Level zero has no multiplier bonus: "+effect_key)
	check(c.level_effect(g,"tech_ai_per_level",0)==0.0,"Level zero grants no dedicated AI")
	check(c.level_description(g,c.entry(g,"navigator")).contains("%+.2f%%" % ((equipment_factor-1.0)*100)),"Equipment compounded bonus uses two decimal places")
	check(is_equal_approx(g.jewel_equipment_stat(module),base*equipment_factor),"Equipment uses exponential level projection")
	check(is_equal_approx(g.jewel_equipment_stat(module),base*equipment_factor),"Repeated reads do not compound")
	c.assign(g,"navigator","","")
	check(g.jewel_equipment_stat(module)==base,"Removing assignment removes effect")
	c.load_state(g,[{"crewId":"navigator"}])
	check(c.entry(g,"navigator").level==0,"Missing saved level defaults zero")
	g.profile.cleared=range(1,61);g.rebuild_unlocks()
	c.assign(g,"navigator","hightech_scientists","hightech")
	var key: String=g.hightech_slots()[0]
	check(g.dedicated_scientists(key)==0,"Level zero AI is zero")
	g.profile.scientists=2;g.profile.scientistAssignments[key]=2
	var first_cost: float=maxf(1.0,roundf(float(cfg.base_exp.value)))
	var second_cost: float=maxf(1.0,roundf(float(cfg.base_exp.value)*float(cfg.exp_multiplier.value)))
	g.add_crew_exp("navigator",first_cost+second_cost)
	check(c.entry(g,"navigator").level==2,"XP from zero uses configured curve")
	check(g.dedicated_scientists(key)==ai,"Each tech gets configured dedicated AI")
	check(c.level_description(g,c.entry(g,"navigator")).contains("Research %+.2f%%" % ((speed_factor-1.0)*100)) and c.level_description(g,c.entry(g,"navigator")).contains("AI %d" % ai),"Research percent and AI count retain distinct units")
	check(g.idle_scientists()==0 and g.profile.scientists==2,"Dedicated AI outside ordinary pool")
	g.assign_scientist(key,-100)
	check(g.assigned_scientists(key)==0 and g.dedicated_scientists(key)==ai,"Dedicated AI cannot be removed")
	var expected: float=(roundf(pow(float(db.config.techPointGet)*ai,float(db.config.hightechLimit))) if ai>1 else float(db.config.techPointGet)*ai)*speed_factor
	check(is_equal_approx(g.research_rate(key),expected),"AI and speed multiply research rate")
	g.distribute_scientists()
	check(g.dedicated_scientists(key)==ai,"Distribution preserves dedicated AI")
	for tech in g.hightech_slots():
		if g.hightech_unlocked(tech):check(g.dedicated_scientists(tech)==ai,"All unlocked techs derive dedicated AI")
	var rate:=g.research_rate(key)
	db.data.crew_config.tech_ai_per_level.des="自定义 {level}/{value}/{effect}/{ai}/{unknown}"
	var description: String=c.level_description(g,c.entry(g,"navigator"))
	check(description.contains("自定义 2/") and description.contains("/{unknown}") and not description.contains("{ai}") and not description.contains("{effect}") and not description.contains("{value}"),"Descriptions substitute safe placeholders")
	check(g.research_rate(key)==rate,"Text does not affect math")
	c.assign(g,"navigator","jewel_auto","jewels")
	check(c.level_description(g,c.entry(g,"navigator")).contains("Fragments %+.2f%%" % ((gem_factor-1.0)*100)),"Jewel bonus uses two decimal percent")
	check(is_equal_approx(g.settle_jewel_fragments(10,"drop",1),snappedf(10*gem_factor,0.01)),"Direct fragments use bonus")
	check(is_equal_approx(g.settle_jewel_fragments(10,"furnace",1),10),"Furnace fragments unchanged")
	c.assign(g,"navigator","","")
	var energy:=g.reactor_energy()
	c.assign(g,"navigator","reactor_upgrade","reactor")
	check(c.level_description(g,c.entry(g,"navigator")).contains("Energy %+.2f%%" % ((charge_factor-1.0)*100)),"Reactor bonus uses two decimal percent")
	check(is_equal_approx(g.reactor_energy(),energy*charge_factor),"Energy derives current level")
	c.assign(g,"navigator","","")
	check(g.reactor_energy()==energy,"Energy returns to base")
