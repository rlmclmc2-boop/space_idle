extends SceneTree

class CountedGame extends BattleGame:
	var saves:=0
	func save_progress() -> void:
		saves+=1
		super.save_progress()

var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)

func make_game(budget := 1e8) -> CountedGame:
	var g:=CountedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,41)
	g.rebuild_unlocks()
	g.profile.resources={"1":budget,"2":budget}
	return g

func _initialize() -> void:
	var modes: Array=["1","10","max"]
	for mode in modes:
		var auto:=make_game()
		var manual:=make_game()
		var assignment: Dictionary=auto.db.data.crew_assignment.hightech_scientists
		check(assignment.interval==1 and assignment.upgradeModes=="1,10,max","Interval and purchase modes from Excel")
		check(auto.crew.available_targets(auto,"hightech_scientists").size()==1 and auto.crew.available_targets(auto,"hightech_scientists")[0].id=="hightech","Auto job targets the whole hightech system")
		check(not auto.db.data.crew_assignment.has("hightech_efficiency") and auto.crew.available_targets(auto,"hightech_efficiency").is_empty(),"Research-efficiency job removed from configuration")
		check(auto.assign_crew("navigator","hightech_scientists","hightech"),"Assign automated scientists "+mode)
		check(auto.crew.set_upgrade_mode(auto,"navigator",mode,"hightech_scientists"),"Select purchase mode "+mode)
		check(auto.crew.effect_text(auto,auto.crew.entry(auto,"navigator")).contains("平均分配"),"Configured effect describes auto distribution")
		var before: Dictionary=auto.profile.resources.duplicate()
		auto.crew.advance(auto,0.99)
		check(auto.profile.scientists==0 and auto.profile.resources==before,"No purchase before interval "+mode)
		auto.saves=0
		var events: Dictionary={"count":0}
		auto.event.connect(func(kind,_payload):
			if kind=="scientists_changed":events.count+=1)
		auto.crew.advance(auto,0.01)
		var amount: int=-1 if mode=="max" else int(mode)
		check(manual.generate_scientist(amount) and manual.distribute_scientists(),"Manual purchase and distribution "+mode)
		check(auto.profile.scientists==manual.profile.scientists and auto.profile.resources==manual.profile.resources,"Exact purchase count and resource cost "+mode)
		check(auto.profile.scientistAssignments==manual.profile.scientistAssignments and auto.idle_scientists()==0,"Same average distribution "+mode)
		check(auto.saves==2 and events.count==2,"Success calls both existing action interfaces "+mode)
		var saved_count: int=auto.profile.scientists
		auto.crew.advance(auto,0.5)
		check(auto.profile.scientists==saved_count,"Scheduler waits another full interval "+mode)
	var poor:=make_game()
	poor.profile.resources=poor.scientist_cost()
	poor.assign_crew("navigator","hightech_scientists","hightech")
	poor.crew.set_upgrade_mode(poor,"navigator","10","hightech_scientists")
	poor.saves=0
	poor.crew.advance(poor,1)
	check(poor.profile.scientists==0 and poor.saves==0 and poor.profile.scientistAssignments.is_empty(),"Unaffordable ten skips purchase and redistribution")
	var locked:=CountedGame.new(ShipDatabase.new(),false)
	check(not locked.assign_crew("navigator","hightech_scientists","hightech"),"Locked crew/system cannot run automation")
	var pause:=make_game()
	pause.assign_crew("navigator","hightech_scientists","hightech")
	pause.paused=true
	pause.tick(2)
	check(pause.profile.scientists==0 and pause.crew.timers.is_empty(),"Paused game does not advance scientist automation")
	var saved:=make_game()
	saved.assign_crew("navigator","hightech_scientists","hightech")
	saved.crew.set_upgrade_mode(saved,"navigator","max","hightech_scientists")
	saved.save_enabled=true
	saved.save_progress()
	var restored:=CountedGame.new(saved.db,false)
	restored.load_progress()
	check(restored.crew.entry(restored,"navigator").assignmentType=="hightech_scientists" and restored.crew.entry(restored,"navigator").targetId=="hightech" and restored.crew.entry(restored,"navigator").upgradeMode=="max","New job and purchase mode persist")
	check(not restored.crew.set_upgrade_mode(restored,"navigator","0","hightech_scientists"),"Invalid purchase mode rejected")
	var legacy:=make_game()
	var tech: String=legacy.hightech_slots()[0]
	legacy.crew.load_state(legacy,[{"crewId":"navigator","level":2,"exp":12,"assignmentType":"hightech_efficiency","targetId":tech,"upgradeMode":"10"}])
	check(legacy.crew.entry(legacy,"navigator").assignmentType.is_empty() and legacy.crew.entry(legacy,"navigator").level==2 and legacy.crew.entry(legacy,"navigator").exp==12,"Removed job clears on old save without losing growth")
	legacy.saves=0
	legacy.crew.advance(legacy,1)
	check(legacy.profile.scientists==0 and legacy.saves==0,"Old efficiency assignment never becomes auto-spending")
	print("CREW SCIENTISTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
