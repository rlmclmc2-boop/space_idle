extends SceneTree

var checks := 0
var failures := 0
const F := BattleGame.FURNACE

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	db.data.hightech[F].para2=0.5
	db.config.autoCollectReduce=0.5
	var g := BattleGame.new(db,false)
	g.profile.hightechLevels[F]=1
	for manual in [true,false]:
		var drop := {"uid":1,"id":"1","amount":100.0,"x":600.0,"y":350.0,"age":0.0}
		g.drops.append(drop)
		g.collect(drop,manual)
	check(g.resource_minute_total("1",-1,true)==150, "Normal input uses manual and post-loss automatic credit")
	g.advance_hightech(30)
	check(g.drops.size()==1 and g.drops[0].amount==75, "First furnace block uses ordinary income")
	g.collect(g.drops[0],true)
	check(g.resource_minute_total("1")==225 and g.resource_minute_total("1",-1,true)==150, "Total income includes furnace while its base excludes it")
	check(g.resource_samples[-1].origin=="furnace", "Pickup records furnace provenance")
	for i in range(3):
		g.advance_hightech(30)
		check(g.drops.size()==1 and g.drops[0].amount==75, "Repeated pickup cannot amplify production %d" % i)
		g.collect(g.drops[0],true)
	check(g.hightech_description(F)=="每30秒在屏幕中生成一个含有75的铁块", "New not-self description matches generated amount")
	g.save_enabled=true
	g.save_progress()
	var loaded := BattleGame.new(db)
	loaded.save_enabled=false
	check(loaded.resource_minute_total("1")==450 and loaded.resource_minute_total("1",-1,true)==150, "Save/load retains origins and independent total/base")
	var now := Time.get_unix_time_from_system()
	loaded.resource_samples.assign([{"time":now-60,"id":"1","amount":900.0,"origin":"drop"},{"time":now-59,"id":"1","amount":10.0,"origin":"drop"},{"time":now-1,"id":"1","amount":9000.0,"origin":"furnace"},{"time":now-1,"id":"2","amount":50.0,"origin":"drop"}])
	check(loaded.resource_minute_total("1",now,true)==10, "Exact sixty-second boundary and other resource excluded")
	check(loaded.resource_minute_total("1",now+61,true)==0 and loaded.hightech_description(F,now+61).contains("含有75的铁块"), "Expired income retains saved furnace peak")
	check(loaded.profile.furnaceIncomePeak==150, "Peak survives real save/load")
	loaded.resource_samples.clear()
	loaded.profile.furnaceElapsed=0
	loaded.drops.clear()
	loaded.advance_hightech(30)
	check(loaded.drops.size()==1 and loaded.drops[0].amount==75, "Production retains peak after samples expire")
	loaded.profile.hightechLevels[F]=2
	check(loaded.hightech_description(F).contains("含有150的铁块"), "Level growth applies to retained peak")
	var larger := {"uid":999,"id":"1","amount":200.0,"x":600.0,"y":350.0,"age":0.0}
	loaded.drops.append(larger)
	loaded.collect(larger,true)
	check(loaded.profile.furnaceIncomePeak==200, "Ordinary pickup records new peak without opening UI")
	loaded.resource_samples.clear()
	check(loaded.hightech_description(F).contains("含有200的铁块"), "New peak does not fall with income")
	var legacy := g.fresh_profile()
	legacy.resourceSamples=[{"time":legacy.hightechSavedAt,"id":"1","amount":500.0}]
	var old := BattleGame.new(db,false)
	old.load_hightech(legacy)
	check(old.resource_minute_total("1")==500 and old.resource_minute_total("1",-1,true)==0, "Legacy unknown origins retain displayed totals without entering furnace input")
	print("Furnace income: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
