extends SceneTree
const Region = preload("res://scripts/galaxy_region.gd")
func _initialize() -> void:call_deferred("run")
func simulate(count:int, dt:float) -> Dictionary:
	var db:=ShipDatabase.new()
	var row:Dictionary=db.data.galaxy["galaxy_1"]
	var defs:Dictionary={}
	for build in db.data.galaxy_build.values():
		if build.galaxy_key=="galaxy_1":defs[build.key]=build
	var r:=Region.new()
	r.setup(row,defs,32)
	r.state.status="exploring"
	var t:=0.0
	var first_all:=-1.0
	while t<360000.0 and not r.is_complete():
		r.advance(dt,count,false)
		t+=dt
		if first_all<0 and r.occupied_count==r.slots.size() and r.progress()>=1:first_all=t
	var levels:Array=[]
	for slot in r.slots:levels.append({"type":slot.type,"level":slot.level,"status":slot.status})
	return {"crew":count,"step":dt,"seconds":t,"all_constructed_at":first_all,"complete":r.is_complete(),"slots":r.slots.size(),"max_level_count":r.max_level_count,"explore_work":r.state.explore_work,"upgrade_work":r.state.upgrade_work,"levels":levels}
func run() -> void:
	var runs:Array=[]
	for count in [1,3,5,10]:
		var r:=simulate(count,60.0)
		runs.append(r)
		print("PARENT_GALAXY ",JSON.stringify(r))
	var check:=simulate(3,10.0)
	runs.append(check)
	print("PARENT_GALAXY_FINE ",JSON.stringify(check))
	FileAccess.open("res://.runtime/parent-galaxy-stage.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"04a5a307bcef9325efa9026e1ca94affa577e10d","scope":"direct formal GalaxyRegion fixed crew stage diagnostic, bypassed unlock; not new save end-to-end proof","runs":runs},"\t"))
	quit(0)
