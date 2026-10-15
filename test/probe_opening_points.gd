extends SceneTree
# Short, save-disabled encounters using the mounted level, group, enemy and equipment data.
# Time includes travel from the previous point and automatic pickup. Each case starts full;
# this probe does not claim to reproduce continuous player decisions or retained damage.
var records:Array=[]
var failures:=0

func _initialize()->void:
	call_deferred("run")

func case_run(label:String,stage:int,point:int,weapons:Array,defence:Array,weapon_levels:Array,defence_levels:Array,allocation:Array)->void:
	var db:=ShipDatabase.new()
	var g:=BattleGame.new(db,false)
	g.rng.seed=1729
	g.profile.cleared=range(1,stage)
	g.rebuild_unlocks()
	g.profile.resources["1"]=10000.0
	for i in weapons.size():
		if not str(weapons[i]).is_empty() and not g.equip_slot("weapons",i,str(weapons[i])):
			printerr("INVALID_EQUIP ",label," weapons ",i);failures+=1;return
	for i in defence.size():
		if not str(defence[i]).is_empty() and not g.equip_slot("defence",i,str(defence[i])):
			printerr("INVALID_EQUIP ",label," defence ",i);failures+=1;return
	for i in weapon_levels.size():
		if int(weapon_levels[i])>1 and not g.upgrade_slot("weapons",i,int(weapon_levels[i])-1):
			printerr("INVALID_UPGRADE ",label," weapons ",i);failures+=1;return
	for i in defence_levels.size():
		if int(defence_levels[i])>1 and not g.upgrade_slot("defence",i,int(defence_levels[i])-1):
			printerr("INVALID_UPGRADE ",label," defence ",i);failures+=1;return
	var spent:float=10000.0-float(g.profile.resources["1"])
	g.profile.resources["1"]=0.0
	if stage>1:
		if not g.set_reactor_allocation("weapons",float(allocation[0])) or not g.set_reactor_allocation("defence",float(allocation[1])):
			printerr("INVALID_REACTOR ",label);failures+=1;return
	if not g.start(stage,false):
		printerr("INVALID_START ",label);failures+=1;return
	var level:Dictionary=db.levels[stage-1]
	g.group_index=point-1
	g.distance=0.0 if point==1 else float(level.groups[point-2].position)*float(level.length)
	var travelled:float=0.0
	var entered:float=-1.0
	var cleared:float=-1.0
	var ended:float=-1.0
	var entry_armour:float=0.0
	var entry_shield:float=0.0
	var after_armour:float=0.0
	var after_shield:float=0.0
	var previous_state:int=g.state
	for step in 18000:
		g.tick(1.0/60.0)
		travelled+=1.0/60.0
		if entered<0 and g.state==BattleGame.State.COMBAT:
			entered=travelled;entry_armour=float(g.player.armour);entry_shield=float(g.player.shield)
		if entered>=0 and cleared<0 and previous_state==BattleGame.State.COMBAT and g.state!=BattleGame.State.COMBAT:
			cleared=travelled;after_armour=float(g.player.armour);after_shield=float(g.player.shield);g.group_index=level.groups.size()
		previous_state=g.state
		if g.state==BattleGame.State.RETREAT:
			ended=travelled;break
		if cleared>=0 and (g.drops.is_empty() or travelled>=cleared+15.0):
			ended=travelled;break
		if entered<0 and travelled>45.0:
			ended=travelled;break
	var collected:float=float(g.profile.resources["1"])
	var expected:float=0.0
	for id in db.groups[str(int(level.groups[point-1].id))].slots:
		if id!=null:
			for drop in db.enemies[str(int(id))].drops:
				if int(drop.resourceId)==1:expected+=ceilf(float(drop.amount)*float(level.resRatio))*float(drop.chance)
	var status:="clear" if cleared>=0 and g.state!=BattleGame.State.RETREAT else "retreat" if g.state==BattleGame.State.RETREAT else "timeout"
	var record={"case":label,"stage":stage,"point":point,"status":status,"travel_s":entered,"combat_s":cleared-entered if cleared>=0 else -1.0,"pickup_wait_s":ended-cleared if cleared>=0 else -1.0,"total_s":ended,"authored_iron":expected,"auto_iron":collected,"upgrade_spent":spent,"armour_in":entry_armour,"armour_out":after_armour,"shield_in":entry_shield,"shield_out":after_shield,"resources_at_end":g.profile.resources["1"],"drops_remaining":g.drops.size()}
	records.append(record)
	print("OPENING_POINT ",JSON.stringify(record))
	if status=="timeout" or entered<0:
		failures+=1


func run()->void:
	var one:Array=["laser","",""]
	var full:Array=["laser","laser","laser"]
	var double_missile:Array=["laser","missile","missile"]
	var mixed:Array=["laser","missile","cannon"]
	var two_armour:Array=["armour","armour"]
	var armour_shield:Array=["armour","shield"]
	case_run("initial_1_1",1,1,one,["armour",""],[1,1,1],[1,1],[0,0])
	case_run("filled_1_1",1,1,full,two_armour,[1,1,1],[1,1],[0,0])
	case_run("initial_1_3",1,3,one,["armour",""],[1,1,1],[1,1],[0,0])
	case_run("filled_1_3",1,3,full,two_armour,[1,1,1],[1,1],[0,0])
	case_run("initial_1_4",1,4,one,["armour",""],[1,1,1],[1,1],[0,0])
	case_run("filled_1_5",1,5,full,two_armour,[1,1,1],[1,1],[0,0])
	case_run("grown_1_5",1,5,full,two_armour,[2,2,1],[2,1],[0,0])
	case_run("pulse_2_1",2,1,full,two_armour,[2,2,1],[2,1],[50,50])
	case_run("missile_2_1",2,1,double_missile,two_armour,[2,1,1],[2,1],[50,50])
	case_run("missile_2_2",2,2,double_missile,two_armour,[2,1,1],[2,1],[50,50])
	case_run("mixed_3_3",3,3,mixed,two_armour,[2,2,1],[2,2],[50,50])
	case_run("mixed_3_5",3,5,mixed,armour_shield,[2,2,1],[2,1],[50,50])
	case_run("mixed_3_6",3,6,mixed,armour_shield,[2,2,1],[2,1],[50,50])
	case_run("mixed_3_7",3,7,mixed,two_armour,[2,2,1],[2,2],[50,50])
	print("OPENING_POINT_SUMMARY ",records.size()," cases ",failures," invalid")
	quit(1 if failures else 0)