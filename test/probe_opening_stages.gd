extends SceneTree
# One stage per save-disabled private game. Normal travel, combat, auto pickup and
# retained defence state; no new-save marathon or player save access.
var failures:=0
func _initialize()->void:call_deferred("run")
func one(label:String,stage:int,weapons:Array,defence:Array,wl:Array,dl:Array)->void:
	var db:=ShipDatabase.new()
	var g:=BattleGame.new(db,false)
	g.rng.seed=1729
	g.profile.cleared=range(1,stage)
	g.rebuild_unlocks()
	g.profile.resources["1"]=10000.0
	for i in weapons.size():
		if not g.equip_slot("weapons",i,str(weapons[i])):printerr("STAGE_INVALID_EQUIP ",label);failures+=1;return
	for i in defence.size():
		if not g.equip_slot("defence",i,str(defence[i])):printerr("STAGE_INVALID_EQUIP ",label);failures+=1;return
	for i in wl.size():
		if int(wl[i])>1 and not g.upgrade_slot("weapons",i,int(wl[i])-1):printerr("STAGE_INVALID_UPGRADE ",label);failures+=1;return
	for i in dl.size():
		if int(dl[i])>1 and not g.upgrade_slot("defence",i,int(dl[i])-1):printerr("STAGE_INVALID_UPGRADE ",label);failures+=1;return
	var spent:float=10000.0-float(g.profile.resources["1"])
	g.profile.resources["1"]=0.0
	if not g.set_reactor_allocation("weapons",50.0) or not g.set_reactor_allocation("defence",50.0):
		printerr("STAGE_INVALID_REACTOR ",label);failures+=1;return
	if not g.start(stage,false):printerr("STAGE_INVALID_START ",label);failures+=1;return
	var elapsed:=0.0
	var previous:int=g.state
	var starts:Dictionary={}
	var points:Array=[]
	var retreats:=0
	var cash_milestones:Dictionary={}
	for step in 30000:
		g.tick(1.0/60.0)
		elapsed+=1.0/60.0
		if previous!=BattleGame.State.COMBAT and g.state==BattleGame.State.COMBAT:
			starts[g.group_index]={"at":elapsed,"armour":float(g.player.armour),"shield":float(g.player.shield)}
		if previous==BattleGame.State.COMBAT and g.state!=BattleGame.State.COMBAT:
			var index:int=g.group_index
			var origin:Dictionary=starts.get(index,{})
			points.append({"point":index,"combat_s":elapsed-float(origin.get("at",elapsed)),"armour_in":origin.get("armour",0),"armour_out":g.player.armour,"shield_in":origin.get("shield",0),"shield_out":g.player.shield,"result":"retreat" if g.state==BattleGame.State.RETREAT else "clear","time_s":elapsed,"iron_at_clear":g.profile.resources["1"]})
		if previous!=BattleGame.State.RETREAT and g.state==BattleGame.State.RETREAT:retreats+=1
		previous=g.state
		for value in [65,75,85]:
			if not cash_milestones.has(str(value)) and float(g.profile.resources["1"])>=value:
				cash_milestones[str(value)]=elapsed
		if retreats>=2:break
		if g.state==BattleGame.State.LEVEL_CLEAR and g.drops.is_empty() and elapsed>5.0:break
		if g.stage>stage:break
	var record={"case":label,"stage":stage,"status":"clear" if g.state==BattleGame.State.LEVEL_CLEAR and g.drops.is_empty() else "stopped","time_s":elapsed,"points":points,"retreats":retreats,"auto_iron":g.profile.resources["1"],"spent_before_run":spent,"milestones_s":cash_milestones,"armour_end":g.player.armour,"shield_end":g.player.shield,"drops_remaining":g.drops.size()}
	print("OPENING_STAGE ",JSON.stringify(record))
	if points.is_empty():failures+=1
func run()->void:
	one("stage2_low",2,["laser","laser","laser"],["armour","armour"],[1,1,1],[1,1])
	one("stage2_target",2,["laser","missile","missile"],["armour","armour"],[2,1,1],[2,1])
	one("stage3_low",3,["laser","laser","laser"],["armour","armour"],[1,1,1],[1,1])
	one("stage3_target",3,["laser","missile","cannon"],["armour","shield"],[2,2,1],[2,1])
	print("OPENING_STAGE_SUMMARY ",4," cases ",failures," invalid")
	quit(1 if failures else 0)
