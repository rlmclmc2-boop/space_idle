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
func advance(g,seconds:float)->void:
	for i in roundi(seconds*60):step(g,1.0/60.0)
func verify_five(g,payloads:Array,label:String)->void:
	check(g.launch_records.size()==5,label+" keeps five configured packets")
	var ordinal:=0
	for record in g.launch_records:
		check(int(record.ordinal)==ordinal and record.target_alive,label+" releases ordered packets only onto live targets")
		check(N.compare(record.damage,payloads[ordinal].damage)==0,label+" preserves each committed damage snapshot")
		if ordinal>0:
			var gap:float=float(record.time)-float(g.launch_records[ordinal-1].time)
			check(absf(gap-g.EJECTION_GAP)<=1.0/60.0+.000001,label+" preserves staggered ejection cadence")
		ordinal+=1
	check(g.maximum_turn_step_error<.00001,label+" respects finite angular speed")
func run()->void:
	var g=fixture(1)
	var target:Dictionary=g.enemies[0]
	var payloads:Array=commit(g,0,target)
	var rng_after:int=g.rng.state
	step(g,0);advance(g,3)
	verify_five(g,payloads,"stable single target")
	check(g.hit_records.size()==5 and g.projectiles.is_empty(),"Stable single target receives all five actual hits without orbiting")
	check(g.missile_target_scans==0 and g.missile_retarget_count==0,"Live target never triggers search or target switching")
	check(g.rng.state==rng_after,"Guidance never consumes attack RNG")
	g=fixture(2);target=g.enemies[0]
	payloads=commit(g,0,target);rng_after=g.rng.state
	step(g,0);target.hp=0
	advance(g,3)
	verify_five(g,payloads,"target dies after first ejection")
	check(g.hit_records.size()==4 and g.hit_records.all(func(r):return int(r.target_uid)==101),"Only four pending packets acquire the live second enemy")
	check(g.missile_retarget_count==4 and g.rng.state==rng_after,"Four pending retargets reuse exact payloads without rerolling")
	check(g.missile_target_scans<=5,"Dead-target searches reuse bounded candidate cache")
	g=fixture(5,3)
	for mount in 3:commit(g,mount,g.enemies[0])
	step(g,0)
	var live_lock_violations:=0
	var tracked:Dictionary={}
	var lost:Dictionary={}
	for frame in 180:
		if frame in [12,30,48]:g.enemies[[12,30,48].find(frame)].hp=0
		for shot in g.projectiles:
			var previous:Dictionary=tracked.get(int(shot.serial),{})
			if not previous.is_empty() and g.missile_target_live(previous) and not is_same(previous,shot.target):live_lock_violations+=1
			if not g.missile_target_live(shot.target):lost[int(shot.serial)]=true
			tracked[int(shot.serial)]=shot.target
		step(g,1.0/60.0)
	check(g.launch_records.size()==15 and g.launch_records.all(func(r):return r.target_alive),"Rapid casualties and three launchers release fifteen valid packets")
	check(live_lock_violations==0 and not lost.is_empty() and g.hit_records.all(func(r):return not lost.has(int(r.serial))),"Rapid target deaths preserve live locks and never hit with orphaned missiles")
	check(g.missile_target_scans<=15 and g.maximum_turn_step_error<.00001,"Multiple launchers share throttled lookup and bounded turn rate")
	g=fixture(1);target=g.enemies[0]
	commit(g,0,target);step(g,0)
	var orphan:Dictionary=g.projectiles[0]
	var loss_point:=Vector2(orphan.x,orphan.y)
	var loss_velocity:=Vector2(orphan.direction)*float(orphan.speed)
	target.hp=0
	g.change_state(BattleGame.State.TRAVEL)
	advance(g,2)
	check(g.launch_records.size()==1 and g.invalid_target_cancellations==4 and g.missile_queue.is_empty(),"No enemies cancels four invalid due packets rather than banking hidden salvos")
	check(g.orphan_expirations==0 and orphan.motion_age>.24,"Empty field does not use the old short fade timeout")
	check(absf((Vector2(orphan.x,orphan.y)-loss_point).cross(loss_velocity.normalized()))<.01 and orphan.speed==g.MISSILE_CRUISE_SPEED,"Empty-field coast keeps heading and reaches cruise speed")
	advance(g,10)
	check(g.projectiles.is_empty() and g.hit_records.is_empty() and g.orphan_expirations==0,"Coasting exits the arena without timeout or ghost hits")
	g=fixture(2);target=g.enemies[0]
	commit(g,0,target);step(g,0)
	var first:Dictionary=g.projectiles[0]
	g.enemies[1].hp=0;target.hp=0
	advance(g,.10)
	g.enemies[1].hp=1e30
	g.change_state(BattleGame.State.COMBAT)
	advance(g,3)
	check(g.launch_records.size()==5 and g.hit_records.size()==4 and g.hit_records.all(func(r):return r.serial!=first.serial),"New enemy never reacquires an already orphaned packet; pending four still hit")
	g=fixture(1);commit(g,0,g.enemies[0]);step(g,0)
	var expired:Dictionary=g.projectiles[0]
	expired.motion_age=4.49;step(g,.02)
	check(expired.dead and g.lifetime_expirations==1,"Live-target missile retains its original 4.5-second lifetime")
	g.change_state(BattleGame.State.LEVEL_CLEAR)
	check(g.missile_queue.is_empty(),"Terminal clear keeps existing pending-salvo cancellation")
	g=fixture(1);g.missile_target_registry.clear()
	commit(g,0,g.enemies[0]);step(g,0)
	check(g.launch_records.size()==1 and g.launch_records[0].target_alive,"Shared candidate query refreshes externally replaced runtime identities")
	# Ordinary wave replacement invalidates runtime identity without retargeting.
	g=fixture(1);commit(g,0,g.enemies[0]);step(g,0)
	var wave_shot:Dictionary=g.projectiles[0]
	g.spawn_group();step(g,1.0/60.0)
	check(wave_shot.target.is_empty() and not wave_shot.dead,"Ordinary new wave keeps old missile coasting")
	# All cardinal/diagonal directions, minimum speed, and an age beyond 4.5s.
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
		g=fixture(2);commit(g,0,g.enemies[0]);step(g,0)
		g.missile_queue.clear() # isolate one already released missile
		var shot:Dictionary=g.projectiles[0]
		shot.x=286.;shot.y=348.;shot.direction=direction;shot.speed=60.;shot.motion_age=4.49
		g.enemies[0].hp=0
		var state:int=g.rng.state
		var straight:=true
		for frame in 1500:
			if shot.dead:break
			step(g,1.0/60.0)
			straight=straight and shot.direction==direction and shot.speed>=60.
		check(straight and shot.dead and (shot.x < -32 or shot.x > 604 or shot.y < -32 or shot.y > 776),"Orphan leaves arena along unchanged direction "+str(direction))
		check(g.hit_records.is_empty() and g.missile_retirements.is_empty() and g.orphan_expirations==0 and g.rng.state==state,"Offscreen cleanup has no ghost damage, retirement effect or RNG "+str(direction))
	g=fixture(1);commit(g,0,g.enemies[0]);step(g,0);g.missile_queue.clear()
	var stalled:Dictionary=g.projectiles[0]
	stalled.speed=0.;g.enemies[0].hp=0;step(g,30.)
	check(stalled.dead and g.orphan_expirations==1 and g.hit_records.is_empty(),"Stalled malformed missile has finite cleanup backstop")
	# Final encounter still clears every projectile and pending salvo.
	g=fixture(1);commit(g,0,g.enemies[0]);step(g,0)
	g.group_index=g.db.levels[g.stage-1].groups.size()
	g.hit_enemy(g.enemies[0],1e100,1,[],false)
	g.tick(1.0/60.0)
	check(g.projectiles.is_empty() and g.missile_queue.is_empty(),"Final group clear retains unified projectile/salvo cleanup")
	var original:=ShipDatabase.new()
	check(g.db.equipment.missile[0]==original.equipment.missile[0] and g.db.enemy_weapon("missile-mon")==original.enemy_weapon("missile-mon"),"Migrated player equipment retains authored values and independent hostile source")
	var legacy:=ShipDatabase.new();legacy.data.erase("weapon_motion");legacy.equipment.missile[0].para1=4
	var legacy_row:Dictionary=legacy.equipment.missile[0].duplicate(true)
	var legacy_hostile:Dictionary=legacy.enemy_weapon("missile-mon")
	var projected=Presented.new(legacy,false)
	check(int(projected.db.equipment.missile[0].para1)==5 and legacy.equipment.missile[0]==legacy_row and projected.db.enemy_weapon("missile-mon")==legacy_hostile,"Legacy player-only five-shot projection leaves source/enemy equipment untouched")
	var hostile:Dictionary={"x":200.0,"y":100.0,"uid":77}
	g.fire(hostile,g.player,g.db.enemy_weapon("missile-mon"),10,true,"missile-mon")
	check(not g.projectiles.back().get("prototype_missile",false) and g.projectiles.back().direction==Vector2.DOWN,"Hostile missile retains its independent simplified path")
	print("MISSILE RETARGET: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
