extends SceneTree

class ReferenceGame extends BattleGame:
	func research_rate(key: String, _crew_effects: Dictionary = {}) -> float:
		var count := assigned_scientists(key)+dedicated_scientists(key)
		if count<=0 or not hightech_unlocked(key):return 0.0
		var base := float(db.config.techPointGet)*count
		return (roundf(pow(base,float(db.config.hightechLimit))) if count>1 else base)*crew.system_effect(self,"tech_speed")
	func active_research(rates: Dictionary = {}) -> Array:
		var active: Array=db.data.hightech.keys().filter(func(key):return research_rate(key)>0)
		for key in active:rates[key]=research_rate(key)
		return active

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)
func state(g: BattleGame) -> Dictionary:
	return {"levels":g.profile.hightechLevels,"points":g.profile.techPoints,"furnace":g.profile.furnaceElapsed,"jewels":g.profile.jewelFurnaceElapsed,"drops":g.drops,"resources":g.profile.resources,"rng":g.rng.state}
func configure(g: BattleGame, mode: String) -> void:
	g.rng.seed=19091
	if mode=="locked":return
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.profile.scientists=40
	g.profile.furnaceIncomePeak=100.0
	g.profile.jewelFurnaceIncomePeak=10.0
	for key in g.db.data.hightech:
		g.profile.scientistAssignments[key]=5
		g.profile.hightechLevels[key]=1
		g.profile.techPoints[key]=g.hightech_required(key)-0.001
	if mode=="crew":
		for member in g.profile.crew:member.level=4
		check(g.assign_crew("researcher","hightech_scientists","hightech"),"Crew fixture assigns an active researcher")
		check(g.dedicated_scientists(BattleGame.FURNACE)>0,"Crew fixture supplies dedicated scientists")
	if mode=="bulk":
		for key in g.db.data.hightech:g.profile.techPoints[key]=1e21
func _initialize() -> void:
	var db := ShipDatabase.new()
	for mode in ["locked","active","crew","bulk"]:
		var original := ReferenceGame.new(db,false)
		var updated := BattleGame.new(db,false)
		var lab = preload("res://scripts/balance_game.gd").new(db)
		var games := [original,updated,lab]
		for g in games:configure(g,mode)
		var elapsed := 0.0
		for dt in [0.001,1.0/60,0.1,0.7,3.0,31.0]:
			elapsed+=dt
			for g in games:g.advance_hightech(dt,dt,1000.0+elapsed)
			check(state(original)==state(updated),"Research points/levels/furnace/RNG match original: "+mode+"/"+str(dt))
			check(state(original)==state(lab),"Lab shares the same research result: "+mode+"/"+str(dt))
		# Rates must not survive a change between calls, even without UI events.
		for g in games:
			for key in db.data.hightech:g.profile.scientistAssignments[key]=0
			for member in g.profile.crew:member.level=0
		for key in db.data.hightech:check(original.research_rate(key)==updated.research_rate(key) and original.research_rate(key)==lab.research_rate(key),"Assignment/crew change has fresh rate: "+mode+"/"+str(key))
	print("Research rate snapshot: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
