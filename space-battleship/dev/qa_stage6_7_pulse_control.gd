extends SceneTree

# 同槽位、同等级、同反应炉/科技投入的定点机制对照；不是新档通关证据。
func encounter(stage:int,point:int,weapon:String,level:int,reactor:int,tech:int)->Dictionary:
	var game:=BattleGame.new(ShipDatabase.new(),false)
	game.profile.highestLevel=stage+1
	game.profile.cleared=range(1,stage)
	game.rebuild_unlocks()
	game.pending_unlocks.clear()
	game.profile.loadout.weapons[0]={"key":weapon,"level":level}
	game.profile.loadout.defence[0]={"key":"shield","level":level}
	game.profile.aiTechLevels={"weapon_accuracy":tech,"equipment_reinforcement":tech}
	game.profile.reactorLevel=reactor
	var cap=game.reactor_capacity()
	game.profile.reactorAllocation={"weapons":int(cap/2),"defence":cap-int(cap/2)}
	game.invalidate_stat_cache()
	game.reset_player()
	assert(game.start(stage,false))
	game.group_index=point-1
	game.spawn_group()
	var enemy=game.enemies[0]
	var first_shield=float(enemy.shield)
	var first_armour=float(game.player.armour)
	var first_player_shield=float(game.player.shield)
	var hit_times=[]
	var shield_samples=[]
	var last_hit=float(enemy.get("shield_hit_at",-1.0e100))
	var regen_frames:=0
	var regen_net:=0.0
	var frames:=0
	while game.state==BattleGame.State.COMBAT and frames<6000:
		var before_shield=float(enemy.shield)
		game.tick(1.0/60.0)
		frames+=1
		if float(enemy.shield)>before_shield+0.0001:
			regen_frames+=1
			regen_net+=float(enemy.shield)-before_shield
		var hit_at=float(enemy.get("shield_hit_at",last_hit))
		if hit_at>last_hit+0.00001:
			hit_times.append(snappedf(hit_at,0.001))
			last_hit=hit_at
		if frames%15==0:
			shield_samples.append([snappedf(frames/60.0,0.01),snappedf(float(enemy.shield),0.1),snappedf(float(enemy.hp),0.1)])
	var hit_gaps=[]
	for i in range(1,hit_times.size()):hit_gaps.append(snappedf(hit_times[i]-hit_times[i-1],0.001))
	return {"stage":stage,"point":point,"weapon":weapon,"slot_level":level,"defence":"shield","reactor":reactor,"tech_each":tech,"enemy_id":enemy.id,"enemy_shield_start":first_shield,"shield_delay":enemy.shieldDelay,"shield_recovery":enemy.shieldRecovery,"seconds":snappedf(frames/60.0,0.01),"state":game.state,"enemy_hp_end":float(enemy.hp),"enemy_shield_end":float(enemy.shield),"regen_frames":regen_frames,"regen_net":snappedf(regen_net,0.01),"hit_times":hit_times,"hit_gaps":hit_gaps,"shield_samples":shield_samples,"player_armour_start":first_armour,"player_armour_end":float(game.player.armour),"player_shield_start":first_player_shield,"player_shield_end":float(game.player.shield)}

func _initialize()->void:
	for row in [[6,4,12,5,1],[7,6,17,7,2],[7,9,17,7,2]]:
		for weapon in ["laser","longLaser"]:
			print("QA_PULSE_CONTROL ",JSON.stringify(encounter(row[0],row[1],weapon,row[2],row[3],row[4])))
	quit()
