extends SceneTree

class ClockGame extends BattleGame:
	var now := 1000.0
	func economy_time() -> float:
		return now

const J := BattleGame.JEWEL_FURNACE
const F := BattleGame.FURNACE
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	db.config.autoCollectReduce=0.5
	var row: Dictionary = db.data.hightech[J]
	check(db.unlock_row("hightech",J).level==12 and row.para1==20 and row.para2==0.1 and row.tpCostBase==60 and row.tpCostMutiple==0.05,"Source row is registered unchanged")
	var g := ClockGame.new(db,false)
	check(g.hightech_level(J)==0 and g.profile.jewelFurnaceElapsed==0,"New game defaults")
	check(not g.hightech_unlocked(J) and not g.hightech_slots().has(J),"Locked before gate")
	g.profile.cleared=range(1,13)
	g.rebuild_unlocks()
	check(g.hightech_unlocked(J) and g.hightech_slots().has(J),"Gate 12 adds normal research slot")
	g.profile.scientists=1
	check(g.assign_scientist(J,1),"Uses ordinary scientist assignment")
	var first_time := g.hightech_required(J)/g.research_rate(J)
	g.advance_hightech(first_time)
	check(g.hightech_level(J)==1 and g.drops.is_empty() and g.profile.jewelFurnaceElapsed==0,"First level activates exactly at research boundary")
	check(g.hightech_required(J)==63,"Next research cost uses table growth")
	g.assign_scientist(J,-1)
	# Existing fragment settlement supplies the already multiplied production amount.
	g.settle_jewel_fragments(12.5,"drop",2.0)
	g.settle_jewel_fragments(100,"other",1.0)
	g.settle_jewel_fragments(100,"offline",1.0)
	check(g.resource_minute_total("jewel",g.now,true)==25,"Only ordinary production enters base, with multiplier once")
	g.advance_hightech(19.9)
	check(g.drops.is_empty(),"No early production")
	g.advance_hightech(0.1)
	check(g.drops.size()==1 and g.drops[0].amount==3 and g.drops[0].id=="jewel","Ceil 25 * 0.1 * 1 = 3")
	var core: Dictionary = g.drops[0]
	var before := float(g.profile.jewelFragments)
	g.settle_drops()
	check(g.drops.has(core),"Leaving battle cannot auto-collect core")
	g.collect_near(Vector2(core.x,core.y))
	check(not g.drops.has(core) and g.profile.jewelFragments==before+3,"Hover awards full fragments")
	check(g.resource_samples[-1].origin=="furnace" and g.resource_minute_total("jewel",g.now,true)==25 and g.resource_minute_total("jewel",g.now)==28,"Own output counted in actual income but excluded from base")
	g.collect(core,true)
	check(g.profile.jewelFragments==before+3,"No duplicate pickup")
	g.advance_hightech(20)
	check(g.drops[0].amount==3,"No recursive amplification")
	core=g.drops[0]
	before=g.profile.jewelFragments
	g.advance_hightech(9.99)
	check(g.drops.has(core),"Core lives until ten seconds")
	g.advance_hightech(0.01)
	check(not g.drops.has(core) and g.profile.jewelFragments==before+2,"Expired core auto-credits ceil(3 * 0.5)")
	check(g.profile.jewelFurnaceIncomePeak==25 and g.resource_samples[-1].origin=="furnace","Automatic income cannot raise own production peak")
	g.collect(core,false)
	check(g.profile.jewelFragments==before+2,"Expired core cannot credit twice")
	g.profile.hightechLevels[J]=2
	check(g.hightech_description(J,g.now).contains("含有5的"),"Description matches current level and ceil output")
	g.now+=61
	check(g.hightech_description(J,g.now).contains("含有5的"),"Historical peak survives rolling income expiry")
	g.resource_samples.assign([{"time":g.now-60,"id":"jewel","amount":100.0,"origin":"drop"},{"time":g.now-59,"id":"jewel","amount":0.1,"origin":"drop"},{"time":g.now,"id":"1","amount":100.0,"origin":"drop"},{"time":g.now+1,"id":"jewel","amount":100.0,"origin":"drop"}])
	check(g.resource_minute_total("jewel",g.now,true)==0.1,"Window excludes boundary, future, and iron")
	g.drops.clear()
	g.profile.jewelFurnaceElapsed=0
	g.profile.jewelFurnaceIncomePeak=0
	g.advance_hightech(20)
	check(g.drops[0].amount==1,"Fractional base rounds final output upward")
	g.paused=true
	g.tick(5)
	check(g.profile.jewelFurnaceElapsed==0 and g.drops[0].age==0,"Pause freezes cycle and core lifetime")
	g.paused=false
	g.advance_hightech(3600)
	check(g.drops.size()<=1,"Long offline step retains only live window")
	# Both facilities share aging/production but keep independent timers and destinations.
	g.drops.clear()
	g.profile.hightechLevels[F]=1
	g.profile.furnaceIncomePeak=100
	g.profile.furnaceElapsed=0
	g.profile.jewelFurnaceElapsed=0
	g.advance_hightech(20)
	check(g.drops.size()==1 and g.drops[0].id=="jewel" and g.profile.furnaceElapsed==20,"Independent furnace timers")
	g.advance_hightech(10)
	check(g.drops.size()==1 and g.drops[0].id=="1","Iron production and core expiry coexist")
	# Old saves lack new fields; unknown sample provenance must never feed production.
	var old := BattleGame.new(db,false)
	var legacy := old.fresh_profile()
	legacy.erase("jewelFurnaceElapsed")
	legacy.erase("jewelFurnaceIncomePeak")
	legacy.resourceSamples=[{"time":legacy.hightechSavedAt,"id":"jewel","amount":500.0}]
	legacy.hightechDrops=[{"x":600,"y":350,"age":1,"amount":7}]
	old.load_hightech(legacy)
	check(old.profile.jewelFurnaceElapsed==0 and old.profile.jewelFurnaceIncomePeak==0 and old.hightech_level(J)==0,"Missing old-save fields remain default")
	check(old.resource_minute_total("jewel",legacy.hightechSavedAt,true)==0 and old.drops[0].id=="1","Legacy unknown income excluded and untyped iron restored")
	var invalid := BattleGame.new(db,false)
	invalid.load_hightech({"hightechVersion":2,"jewelFurnaceElapsed":-5,"hightechDrops":[{"x":600,"y":350,"age":1,"amount":7,"id":"bad"}]})
	check(invalid.profile.jewelFurnaceElapsed==0 and invalid.drops.is_empty(),"Invalid new state rejected")
	# Real isolated save/load preserves both types and does not reapply jewelRatio.
	var saved := BattleGame.new(db,false)
	saved.profile.cleared=range(1,13)
	saved.profile.hightechLevels[J]=2
	saved.profile.jewelFurnaceElapsed=7.5
	saved.profile.jewelFurnaceIncomePeak=123.5
	saved.profile.techPoints[J]=12
	saved.profile.scientists=2
	saved.profile.scientistAssignments[J]=1
	saved.drops.assign([{"uid":1,"id":"jewel","jewel":true,"hightech":true,"x":600,"y":350,"age":1,"amount":7,"jewelRatio":99},{"uid":2,"id":"1","hightech":true,"x":700,"y":350,"age":2,"amount":11}])
	saved.save_enabled=true
	saved.save_progress()
	var restored := BattleGame.new(db,false)
	restored.load_progress()
	check(restored.hightech_level(J)==2 and restored.profile.jewelFurnaceElapsed==7.5 and restored.profile.techPoints[J]==12 and restored.assigned_scientists(J)==1,"Real save restores level, cycle, research and assignment")
	check(restored.drops.size()==2 and restored.drops[0].id=="jewel" and restored.drops[0].jewelRatio==1 and restored.drops[1].id=="1","Real save preserves distinct drop types")
	check(restored.profile.jewelFurnaceIncomePeak==123.5,"Historical peak survives real save/load without samples")
	before=restored.profile.jewelFragments
	restored.collect(restored.drops[0],true)
	check(restored.profile.jewelFragments==before+7,"Restored core grants fixed amount without multiplier twice")
	# Shared fragment generator still creates inventory items and handles capacity.
	db.config.jewelCreat=5
	restored.profile.jewelFragments=0
	restored.profile.jewels.clear()
	core={"uid":3,"id":"jewel","jewel":true,"hightech":true,"x":600,"y":350,"age":0,"amount":7}
	restored.drops.append(core)
	restored.collect(core,true)
	check(restored.profile.jewels.size()==1 and restored.profile.jewelFragments==2,"Core uses existing automatic jewel generation")
	for loss in [0.0,0.25,1.0]:
		db.config.autoCollectReduce=loss
		var boundary := BattleGame.new(db,false)
		boundary.profile.highestLevel=13
		var expired := {"uid":1,"id":"jewel","jewel":true,"hightech":true,"x":600,"y":350,"age":9,"amount":17}
		boundary.drops.append(expired)
		var feedback: Array=[]
		boundary.event.connect(func(kind,info):
			if kind=="jewel_pickup":feedback.append(info.amount))
		boundary.advance_hightech(1)
		var expected := ceilf(17*(1.0-loss))
		check(boundary.drops.is_empty() and feedback==[expected] and boundary.resource_minute_total("jewel")==expected,"Configured automatic loss and actual feedback: %s" % loss)
		check(boundary.profile.jewelFurnaceIncomePeak==0,"Automatic credit excluded from peak: %s" % loss)
	print("Jewel furnace: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
