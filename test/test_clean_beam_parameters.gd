extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func fixture()->BattleGame:
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.start(1,false);g.spawn_group()
	g.profile.loadout=g.empty_loadout(g.profile.selectedShip)
	g.profile.loadout.defence[0]={"key":"armour","level":1}
	g.profile.unlocked=["longLaser","armour"]
	g.equip_slot("weapons",0,"longLaser")
	for e in g.enemies:
		e.hp=100000;e.max_hp=100000;e.armourType=2;e.equipment=[]
	if g.enemies.size()<2:
		var second:Dictionary=g.enemies[0].duplicate(true);second.uid=int(second.uid)+100;second.x+=100;g.enemies.append(second)
	return g
func _initialize()->void:
	var g:=fixture();var row:Dictionary=g.db.equip("longLaser",1)
	check(row.cd==0.5 and row.dmg==62.5 and row.para1==2 and row.para2==3 and row.para3==1,"Authoritative clean beam parameters are loaded")
	var projection:Dictionary=preload("res://scripts/equipment_display.gd").snapshot(g,g.weapon_entries()[0])
	check(projection.rate.start==125 and projection.rate.end==375 and projection.rate.stage_time==3,"Read-only throughput and full-ramp time agree with clean parameters")
	var victim:Dictionary=g.targets(1)[0]
	g.tick(0.99)
	check(victim.hp==100000 and g.projectiles[0].ticks==0,"One-second charge suppresses early damage")
	g.tick(0.01)
	check(victim.hp==99937 and g.projectiles[0].ticks==1,"First actual hit rounds 62.5 to63")
	for damage in [94,125,157,188]:
		var before:float=victim.hp;g.tick(0.5)
		check(victim.hp==before-damage,"Half-second cadence advances the independently calculated ramp hit")
	check(g.projectiles[0].ticks==5 and is_equal_approx(float(g.projectiles[0].elapsed),3),"Fifth hit reaches full multiplier at three seconds")
	var before:float=victim.hp;g.tick(0.5)
	check(victim.hp==before-188,"Full multiplier persists on the next hit")
	var batched:=fixture();batched.tick(3.5)
	check(batched.targets(1)[0].hp==victim.hp,"Damage is independent of tick partition")
	var previous:=fixture();previous.db.equipment.longLaser[0].dmg=35.0;previous.db.equipment.longLaser[0].cd=0.28;previous.invalidate_stat_cache()
	previous.tick(3.0)
	check(previous.projectiles[0].ticks==8 and previous.long_laser_multiplier(previous.projectiles[0].attack_snapshot.weapon,7*0.28)<3,"Old interval has not reached full multiplier by three seconds")
	previous.tick(0.24)
	check(previous.projectiles[0].ticks==9 and previous.long_laser_multiplier(previous.projectiles[0].attack_snapshot.weapon,8*0.28)==3,"Old full-ramp boundary was3.24 seconds")
	var charged:=fixture();charged.jewel_charged[charged.slot_id("weapons",0)]=2.0
	var charged_target:Dictionary=charged.targets(1)[0];charged.tick(1)
	check(charged_target.hp==99875 and charged.projectiles[0].charged_multiplier==2,"Stored charge applies once to the new first-hit damage")
	var twin:=fixture();twin.profile.cleared=range(1,11);twin.rebuild_unlocks()
	twin.profile.enhancementOrder.weapons=["repeat","proficiency","critical"]
	twin.profile.enhancementLevel=twin.enhancement_effect_threshold(0)
	twin.db.data.enhance_config.repeat_probability.value=1.0
	twin.db.data.enhance_config.repeat_growth.value=0.2/float(twin.profile.enhancementLevel)
	twin.db.data.enhance_config.repeat_delay.value=0.5
	twin.db.data.enhance_config.base_critical_rate.value=0.0
	twin.jewel_charged[twin.slot_id("weapons",0)]=2.0;twin.invalidate_stat_cache()
	twin.tick(1)
	check(twin.jewel_repeats.size()==1,"Primary first emission queues one shared repeat")
	twin.advance_jewel_repeats(0.49)
	check(twin.projectiles.size()==1,"Repeated beam waits the configured half-second delay")
	twin.advance_jewel_repeats(0.01)
	check(twin.projectiles.size()==2,"Repeat launches one independent persistent beam")
	var secondary:Dictionary=twin.projectiles[1];var secondary_target:Dictionary=secondary.target
	check(not is_same(secondary_target,twin.projectiles[0].target),"Repeated beam selects another living target")
	before=secondary_target.hp;twin.tick_projectiles(0.99)
	check(secondary.ticks==0 and secondary_target.hp==before,"Repeated beam independently charges for one second")
	twin.tick_projectiles(0.01)
	check(secondary.ticks==1 and secondary_target.hp==before-150,"Repeated first hit combines original charge2 and repeat1.2 without inherited ramp")
	before=secondary_target.hp;twin.tick_projectiles(0.5)
	check(secondary_target.hp==before-225,"Repeated beam grows its own half-second ramp")
	for i in 5:twin.tick(0.5)
	check(twin.projectiles.size()==2 and twin.jewel_repeats.is_empty(),"Later half-second hits never accumulate recursive repeats")
	check(twin.db.enemy_weapon("longLaser-mon").cd==0.2 and twin.db.enemy_weapon("longLaser-mon").dmg==5,"Enemy beam row remains independent")
	print("Clean beam parameters: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
