extends SceneTree
const Presented := preload("res://scripts/presented_battle_game.gd")
const N := preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func fixture(count:=2,launchers:=1):
	var g=Presented.new(ShipDatabase.new(),false)
	g.stat_cache_enabled=true
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.profile.loadout={"weapons":[],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
	for i in launchers:g.profile.loadout.weapons.append({"key":"missile","level":150})
	g.invalidate_stat_cache();g.reset_player();g.start(1,false);g.spawn_group()
	var template:Dictionary=g.enemies[0].duplicate(true)
	g.enemies.clear()
	for i in count:
		var enemy:Dictionary=template.duplicate(true)
		enemy.uid=100+i;enemy.slot=i;enemy.x=180+i*70;enemy.y=110-i*3
		enemy.hp=1e30;enemy.max_hp=enemy.hp;enemy.armourType=-99
		enemy.equipment=[];enemy.cooldowns=[];enemy.drops=[]
		g.enemies.append(enemy)
	g.refresh_missile_target_registry()
	g.rng.seed=987654
	g.launch_provider=func(slot,aim,_ordinal):
		var origin:=Vector2(230+slot*40,550)
		return {"position":origin,"direction":(Vector2(aim)-origin).normalized()}
	return g
func commit(g,index:int,target:Dictionary)->Array:
	var before:int=g.missile_queue.size()
	var row:Dictionary=g.db.equip("missile",150)
	for ordinal in 5:g.jewel_fire(index,target,row,g.player_weapon_offset(index),1,0,ordinal,5)
	var payloads:Array=[]
	for i in range(before,g.missile_queue.size()):payloads.append(g.missile_queue[i].attack.duplicate(true))
	return payloads
func step(g,dt:float)->void:
	g.motion_clock+=dt;g.tick_projectiles(dt)
func run()->void:
	var g=fixture(1);var target=g.enemies[0]
	target.x=286.;target.y=-1000.
	g.launch_provider=func(_slot,_aim,_ordinal):return {"position":Vector2(286,650),"direction":Vector2.UP}
	g.begin_enhancement_attack(0,target);g.record_enhancement_attack();commit(g,0,target);g.finish_enhancement_attack(0)
	step(g,0)
	var directions={};var peak={};var exits={};var speeds_at_loss=[]
	for frame in 420:
		if frame==72:
			for shot in g.projectiles:directions[shot.serial]=shot.direction;speeds_at_loss.append(shot.speed)
			target.hp=0
		var prior=g.projectiles.duplicate()
		step(g,1./60.)
		if frame>=72:
			for shot in prior:
				var expected=lerpf(g.MISSILE_LAUNCH_SPEED,g.MISSILE_CRUISE_SPEED,smoothstep(g.MISSILE_IGNITION,g.MISSILE_CRUISE_AT,float(shot.motion_age)))
				check(is_equal_approx(float(shot.speed),expected),"each orphan follows original age-based acceleration curve")
				check(shot.target.is_empty() and shot.direction==directions[shot.serial],"no new target or steering")
				peak[shot.serial]=maxf(float(peak.get(shot.serial,0)),float(shot.speed))
				if shot.dead:exits[shot.serial]=g.motion_clock
		if frame>72 and g.projectiles.is_empty():break
	check(speeds_at_loss.size()==5 and speeds_at_loss[0]==g.MISSILE_CRUISE_SPEED and speeds_at_loss[4]==g.MISSILE_LAUNCH_SPEED,"same batch loses target with first at cruise and last at launch speed")
	check(exits.size()==5 and peak.values().all(func(value):return value==g.MISSILE_CRUISE_SPEED),"all five accelerate to cruise and exit through normal bounds")
	check(g.hit_records.is_empty() and g.orphan_expirations==0 and g.missile_retirements.is_empty(),"no ghost hits, shortened lifetime or retirement shortcut")
	check(g.profile.enhancementAttacks==1 and g.launch_records.size()==5,"five launches remain one snapshotted attack")
	print("ORPHAN ACCELERATION: ",checks," checks, ",failures," failures; loss speeds=",speeds_at_loss," exits=",exits)
	quit(1 if failures else 0)
