extends SceneTree

# 合法新档路线：武器和防具换装沿用各自槽位等级，战点结束才允许下一次切换。
const WEAPONS := [
	["laser","laser","laser","laser","laser"],
	["missile","missile","missile","missile","missile","missile"],
	["cannon","cannon","cannon","cannon","cannon","cannon","cannon"],
	["cannon","cannon","cannon","cannon","cannon","cannon","cannon","cannon"],
	["laser","laser","missile","missile","cannon","cannon","laser","missile","cannon"],
	["longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser"],
	["longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser","longLaser"],
]
const DEFENCES := [
	["armour","armour","armour","armour","armour"],
	["armour","armour","armour","armour","armour","armour"],
	["shield","shield","shield","shield","shield","shield","armour"],
	["armour","shield","armour","shield","armour","shield","armour","armour"],
	["shield","shield","shield","shield","armour","armour","shield","shield","armour"],
	["shield","shield","shield","shield","shield","shield","shield","shield","shield"],
	["shield","shield","shield","shield","shield","shield","shield","shield","shield"],
]
const TARGET_WEAPON := [3,5,7,9,12,16,19]
const TARGET_DEFENCE := [3,5,7,9,11,14,17]
const TARGET_REACTOR := [1,1,2,3,4,5,8]

func invest(game, stage:int, point:int) -> void:
	var weapon:String = WEAPONS[stage-1][point-1]
	var defence:String = DEFENCES[stage-1][point-1]
	for desired in [["weapons",weapon],["defence",defence]]:
		var category:String = desired[0]
		var key:String = desired[1]
		if not game.profile.unlocked.has(key):
			print("QA_ROUTE_LOCKED ",JSON.stringify({"stage":stage,"point":point,"key":key}))
			continue
		if str(game.profile.loadout[category][0].key) != key:
			var changed:bool = game.equip_slot(category,0,key)
			print("QA_ROUTE_SWITCH ",JSON.stringify({"stage":stage,"point":point,"category":category,"key":key,"ok":changed}))
	for category in ["defence","weapons"]:
		var target:int = TARGET_DEFENCE[stage-1] if category=="defence" else TARGET_WEAPON[stage-1]
		while int(game.profile.loadout[category][0].level)<target and game.can_upgrade_slot(category,0):
			if not game.upgrade_slot(category,0):break
	while int(game.profile.reactorLevel)<TARGET_REACTOR[stage-1]:
		if not game.upgrade_reactor(1):break
	if game.reactor_unlocked():game.equalize_reactor_allocation()
	var tech:String = "weapon_accuracy" if game.hightech_level("weapon_accuracy")<=game.hightech_level("equipment_reinforcement") else "equipment_reinforcement"
	if game.hightech_unlocked(tech):game.select_tech(tech)

func _initialize() -> void:
	var game:=BattleGame.new(ShipDatabase.new(),false)
	for stage in range(1,8):
		if not game.start(stage,false):
			print("QA_ROUTE_FAIL start=",stage);quit(2);return
		var frames:=0
		var active_point:=0
		var battle_start:=0
		var previous_point:=0
		while game.state!=BattleGame.State.LEVEL_CLEAR and game.state!=BattleGame.State.DEFEAT and frames<24000:
			var planned_point:int = clampi(int(game.group_index)+(1 if game.state==BattleGame.State.TRAVEL else 0),1,WEAPONS[stage-1].size())
			if planned_point!=previous_point or frames%60==0:
				invest(game,stage,planned_point)
				previous_point=planned_point
			var before=game.state
			game.tick(1.0/60.0)
			frames+=1
			if before!=BattleGame.State.COMBAT and game.state==BattleGame.State.COMBAT:
				battle_start=frames
				active_point=game.group_index
			if before==BattleGame.State.COMBAT and game.state!=BattleGame.State.COMBAT:
				print("QA_ROUTE_POINT ",JSON.stringify({"stage":stage,"point":active_point,"combat_seconds":snappedf((frames-battle_start)/60.0,.01),"next_state":game.state,"armour":float(game.player.armour),"shield":float(game.player.shield),"iron":float(game.profile.resources.get("1",0)),"weapon":game.profile.loadout.weapons[0],"defence":game.profile.loadout.defence[0]}))
			if game.state==BattleGame.State.RETREAT:
				print("QA_ROUTE_FAIL retreat stage=",stage," point=",active_point);quit(3);return
		game.settle_drops()
		print("QA_ROUTE_STAGE ",JSON.stringify({"stage":stage,"seconds":snappedf(frames/60.0,.01),"state":game.state,"highest":game.profile.highestLevel,"iron":float(game.profile.resources.get("1",0)),"uranium":float(game.profile.resources.get("2",0)),"reactor":game.profile.reactorLevel,"weapon":game.profile.loadout.weapons[0],"defence":game.profile.loadout.defence[0],"hyperspace":game.hyperspace.is_unlocked(game)}))
		if game.state!=BattleGame.State.LEVEL_CLEAR:
			print("QA_ROUTE_FAIL stage=",stage);quit(4);return
	quit()
