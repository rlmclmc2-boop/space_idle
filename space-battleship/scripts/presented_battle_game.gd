extends "res://scripts/game.gd"
## Authorized player weapon presentation mechanics. Shared attack/hit paths remain authoritative.
var EJECTION_GAP := 0.28
var RAIL_SPEED_FACTOR := 12.0
var MISSILE_LAUNCH_SPEED := 120.0
var MISSILE_CRUISE_SPEED := 420.0
var MISSILE_TURN_RATE := 4.0
# Normal coasting exits the arena first, even at the minimum guided speed.
# This is only a backstop for malformed/stalled projectiles, not a visual fade.
var ORPHAN_LIFETIME := 30.0
var MISSILE_REACQUIRE_INTERVAL := 0.12
var MISSILE_DEPARTURE_ANGLE := 12.0
var MISSILE_IGNITION := 0.22
var MISSILE_SEEK_START := 0.40
var MISSILE_CRUISE_AT := 0.65
var MISSILE_LIFETIME := 4.5
var MISSILE_BRAKE_RANGE := 120.0
var MISSILE_BRAKE_ANGLE := 0.30
var MISSILE_MIN_GUIDED_SPEED := 60.0
var MISSILE_BRAKE_FACTOR := 0.70
var MISSILE_HIT_RADIUS := 5.0
var MISSILE_LAUNCH_EDGE_MARGIN := 55.0
var MISSILE_LAUNCH_FORWARD_Y := -0.12
var drone_launch_provider:=Callable()
var launch_provider:Callable
var target_provider:Callable
var target_spatial_source:RefCounted
# Complete read-only publication for one actual projectile substep. Live death
# checks and every straight projectile's launch anchors remain authoritative.
var projectile_target_points:Dictionary={}
var projectile_target_points_active:=false
var projectile_target_points_version:=0
var projectile_target_points_state:=0
var projectile_target_points_player:Dictionary={}
var projectile_target_points_roster_size:=0
var projectile_target_points_shape_version:=0
var projectile_target_points_geometry_version:=0
var missile_queue:Array[Dictionary]=[]
var motion_clock:=0.0
var release_context:Dictionary={}
var launch_records:Array[Dictionary]=[]
var hit_records:Array[Dictionary]=[]
var lifetime_expirations:=0
var maximum_turn_step_error:=0.0
var orphan_expirations:=0
var cancelled_ejections:=0
var missile_retirements:Array[Dictionary]=[]
# Encounter-owned identity registry; sorting candidates is only done when a
# target is lost, with a short per-type cache. Live locks never switch target.
var missile_target_registry:Dictionary={}
var missile_target_candidates:Dictionary={}
var missile_retarget_count:=0
var missile_target_scans:=0
var invalid_target_cancellations:=0

func _init(database:ShipDatabase,persist:=true)->void:
	# Keep player equipment/UI projection separate from every hostile fallback.
	var player_database=preload("res://scripts/player_weapon_database.gd").new(database)
	# Only legacy data without the migration table retains the old presentation
	# projection. Authored equipment values always win for migrated data.
	if not player_database.data.has("weapon_motion"):
		for row in player_database.equipment.get("missile",[]):
			row.para1=5;row.cd=2.4;row.dmg=float(row.dmg)*2.0
			row.para2=420.0/player_database.projectile_pixels_per_unit()
	super(player_database,persist)
	EJECTION_GAP=db.weapon_motion_value("missile_ejection_gap",EJECTION_GAP)
	RAIL_SPEED_FACTOR=db.weapon_motion_value("player_cannon_speed_multiplier",RAIL_SPEED_FACTOR)
	MISSILE_LAUNCH_SPEED=db.weapon_motion_value("missile_launch_speed",MISSILE_LAUNCH_SPEED)
	MISSILE_TURN_RATE=db.weapon_motion_value("missile_turn_rate",MISSILE_TURN_RATE)
	ORPHAN_LIFETIME=db.weapon_motion_value("missile_orphan_lifetime",ORPHAN_LIFETIME)
	MISSILE_REACQUIRE_INTERVAL=db.weapon_motion_value("missile_reacquire_interval",MISSILE_REACQUIRE_INTERVAL)
	MISSILE_DEPARTURE_ANGLE=db.weapon_motion_value("missile_departure_angle",MISSILE_DEPARTURE_ANGLE)
	MISSILE_IGNITION=db.weapon_motion_value("missile_ignition_at",MISSILE_IGNITION)
	MISSILE_SEEK_START=db.weapon_motion_value("missile_seek_start",MISSILE_SEEK_START)
	MISSILE_CRUISE_AT=db.weapon_motion_value("missile_cruise_at",MISSILE_CRUISE_AT)
	MISSILE_LIFETIME=db.weapon_motion_value("missile_lifetime",MISSILE_LIFETIME)
	MISSILE_BRAKE_RANGE=db.weapon_motion_value("missile_brake_range",MISSILE_BRAKE_RANGE)
	MISSILE_BRAKE_ANGLE=db.weapon_motion_value("missile_brake_angle",MISSILE_BRAKE_ANGLE)
	MISSILE_MIN_GUIDED_SPEED=db.weapon_motion_value("missile_min_guided_speed",MISSILE_MIN_GUIDED_SPEED)
	MISSILE_BRAKE_FACTOR=db.weapon_motion_value("missile_brake_factor",MISSILE_BRAKE_FACTOR)
	MISSILE_HIT_RADIUS=db.weapon_motion_value("missile_hit_radius",MISSILE_HIT_RADIUS)
	MISSILE_LAUNCH_EDGE_MARGIN=db.weapon_motion_value("missile_launch_edge_margin",MISSILE_LAUNCH_EDGE_MARGIN)
	MISSILE_LAUNCH_FORWARD_Y=db.weapon_motion_value("missile_launch_forward_y",MISSILE_LAUNCH_FORWARD_Y)
	MISSILE_CRUISE_SPEED=float(db.equip("missile",1).para2)*db.projectile_pixels_per_unit()
	if ClassDB.class_exists("SpaceNativePipeline"):native_pipeline=ClassDB.instantiate("SpaceNativePipeline")
	event.connect(_projectile_target_points_event)

func _projectile_target_points_event(kind:String,info:Dictionary)->void:
	match kind:
		"state","encounter","explode","retreat","wave_clear","ship_changed","module_changed","upgrade","prototype_missile_reset":invalidate_projectile_target_points()
		"equipment_stats":
			if not bool(info.get("counter_only",false)):invalidate_projectile_target_points()

func invalidate_projectile_target_points()->void:
	projectile_target_points_version+=1
	projectile_target_points_active=false

func begin_projectile_target_points()->void:
	invalidate_projectile_target_points()
	projectile_target_points.clear()
	projectile_target_points_player={}
	if not target_provider.is_valid() or state!=State.COMBAT:return
	var version:=projectile_target_points_version
	var publication:Dictionary={}
	var spatial_version_captured:=false
	# Provider callbacks only see the source path while this table is built.
	for index in enemies.size():
		var enemy:Dictionary=enemies[index]
		if enemy.hp<=0:continue
		var point:Vector2=_source_target_point(enemy)
		if target_spatial_source!=null:
			if not spatial_version_captured:
				projectile_target_points_shape_version=int(target_spatial_source.shape_revision)
				projectile_target_points_geometry_version=int(target_spatial_source.geometry_revision)
				spatial_version_captured=true
			elif int(target_spatial_source.shape_revision)!=projectile_target_points_shape_version or int(target_spatial_source.geometry_revision)!=projectile_target_points_geometry_version:return
		publication[int(enemy.uid)]={"entity":enemy,"point":point,"x":enemy.x,"y":enemy.y,"index":index,"available":true,"version":version}
	if version!=projectile_target_points_version:return
	projectile_target_points=publication
	projectile_target_points_state=int(state)
	projectile_target_points_player=player
	projectile_target_points_roster_size=enemies.size()
	projectile_target_points_active=true

func end_projectile_target_points()->void:
	projectile_target_points_active=false
	projectile_target_points.clear()
	projectile_target_points_player={}

func tick(dt:float)->void:
	if paused:return
	if native_execution!=null:
		super.tick(dt)
		return
	var remaining:=maxf(0.0,dt)
	while remaining>0.000000001:
		var step:=minf(remaining,1.0/60.0)
		for packet in missile_queue:
			var until:=float(packet.due)-motion_clock
			if until>0.000000001:step=minf(step,until)
		motion_clock+=step
		var boss_survivors:Variant=[]
		if state==State.COMBAT and is_boss_encounter():
			boss_survivors=native_pipeline.boss_snapshot() if native_lifecycle_allowed() else projectiles.filter(func(shot):return bool(shot.get("prototype_missile",false)) and not bool(shot.dead))
		super.tick(step)
		if state==State.LEVEL_CLEAR:
			if boss_survivors is Array:
				for shot in boss_survivors:
					if not bool(shot.dead) and not projectiles.has(shot):_retire_missile(shot,"level_clear",true)
			else:native_pipeline.retire_boss_snapshot(self,boss_survivors)
		remaining-=step

func reset_player()->void:
	event.emit("prototype_missile_reset",{})
	cancelled_ejections+=missile_queue.size();missile_queue.clear()
	super.reset_player()
	refresh_missile_target_registry()

func change_state(next:State)->void:
	if next in [State.RETREAT,State.LEVEL_CLEAR]:
		cancelled_ejections+=missile_queue.size();missile_queue.clear()
	super.change_state(next)
	refresh_missile_target_registry()

func refresh_missile_target_registry()->void:
	missile_target_registry.clear()
	missile_target_candidates.clear()
	for enemy in enemies:missile_target_registry[int(enemy.uid)]=enemy

func missile_target_live(target:Dictionary)->bool:
	return not target.is_empty() and float(target.get("hp",0))>0 and is_same(missile_target_registry.get(int(target.get("uid",-1))),target)

func missile_retarget_candidate(type:int)->Dictionary:
	var cached:Dictionary=missile_target_candidates.get(type,{})
	if cached.is_empty() or motion_clock-float(cached.at)>=MISSILE_REACQUIRE_INTERVAL:
		missile_target_scans+=1
		cached={"at":motion_clock,"targets":targets(type)}
		# The shared target query is also authoritative for fixture/external
		# runtime replacement; register these exact live identities in the same pass.
		missile_target_registry.clear()
		for enemy in cached.targets:missile_target_registry[int(enemy.uid)]=enemy
		missile_target_candidates[type]=cached
	for target in cached.targets:
		if missile_target_live(target):return target
	return {}

func launch_player_attack(index:int,target:Dictionary,weapon:Dictionary,attack:Dictionary,offset:Vector2,spread:float,salvo_index:int=0,salvo_count:int=1)->void:
	if str(combat_entry(index).key)=="cannon":
		if target.is_empty() or target.hp<=0 or not enemies.has(target):return
		super.launch_player_attack(index,target,weapon,attack,offset,spread,salvo_index,salvo_count)
		var shot:Dictionary=projectiles.back()
		if shot.has("higgs"):
			# The rendered rail spans the battlefield on this launch frame.
			advance_higgs_projectile(shot,0.0)
			projectile_mark_dead(shot);projectile_erase(shot)
			return
		projectile_mark_dead(shot)
		projectile_erase(shot)
		event.emit("projectile_impact",{"shot":shot,"pos":target_point(target)})
		hit_enemy(target,shot.damage,int(shot.type),shot.get("jewelEffects",[]),bool(shot.get("critical",false)),shot.get("combat_context",{}))
		return
	if str(combat_entry(index).key)!="missile":
		super.launch_player_attack(index,target,weapon,attack,offset,spread,salvo_index,salvo_count);return
	# Payload is resolved now, exactly once. Delayed ejection does not reroll gems/crit.
	var aim:=target_point(target)
	missile_queue.append({"mount":index,"entry":combat_entry(index),"source":player,"target":target,"aim":aim,"weapon":weapon.duplicate(true),"attack":attack,"offset":offset,"spread":spread,"ordinal":salvo_index,"count":salvo_count,"due":motion_clock+float(salvo_index)*EJECTION_GAP})

func chain_target_point(target:Dictionary)->Vector2:
	return target_point(target)

func projectile_target_point(shot:Dictionary)->Vector2:
	if bool(shot.hostile):return super.projectile_target_point(shot)
	if shot.has("ballistic_target_origin"):
		# Cosmetic entry/hover is not target movement. Preserve genuine movement
		# relative to the logical position sampled by this straight shot at launch.
		return Vector2(shot.ballistic_target_origin)+Vector2(shot.target.x,shot.target.y)-Vector2(shot.ballistic_target_logical)
	return target_point(shot.target)

func target_point(target:Dictionary)->Vector2:
	if projectile_target_points_active:
		var geometry_current:=target_spatial_source==null or (int(target_spatial_source.shape_revision)==projectile_target_points_shape_version and int(target_spatial_source.geometry_revision)==projectile_target_points_geometry_version)
		if not geometry_current or int(state)!=projectile_target_points_state or not is_same(player,projectile_target_points_player) or enemies.size()!=projectile_target_points_roster_size:
			invalidate_projectile_target_points()
		elif target.has("uid") and not is_same(target,player):
			var row:Dictionary=projectile_target_points.get(int(target.uid),{})
			if not row.is_empty() and is_same(row.entity,target) and target.hp>0 and row.version==projectile_target_points_version and target.x==row.x and target.y==row.y:
				var index:=int(row.index)
				# Same-uid replacement/removal/reordering rejects the whole table.
				if index<enemies.size() and is_same(enemies[index],target):return row.point
			invalidate_projectile_target_points()
	return _source_target_point(target)

func _source_target_point(target:Dictionary)->Vector2:
	if target_provider.is_valid():return target_provider.call(target)
	return Vector2(target.x,target.y)

func tick_projectiles(dt:float)->void:
	begin_projectile_target_points()
	for packet in missile_queue.duplicate():
		if float(packet.due)>motion_clock+0.000000001:continue
		missile_queue.erase(packet)
		if not is_same(packet.source,player) or not is_same(combat_entry(int(packet.mount)),packet.entry) or str(packet.entry.key)!="missile" or N.compare(player.armour,0)<=0:
			cancelled_ejections+=1;continue
		if not missile_target_live(packet.target):
			packet.target=missile_retarget_candidate(int(packet.weapon.dmgtype))
			if packet.target.is_empty():
				# There is no damageable enemy. Drop this already-invalid packet at
				# its original due time, rather than stockpiling across empty waves.
				cancelled_ejections+=1;invalid_target_cancellations+=1;continue
			missile_retarget_count+=1
		packet.aim=target_point(packet.target)
		release_context=packet
		# Reuse the committed payload/effects/crit exactly once. Acquiring another
		# live enemy does not constitute a new attack or a second damage roll.
		super.launch_player_attack(int(packet.mount),packet.target,packet.weapon,packet.attack,packet.offset,float(packet.spread),int(packet.ordinal),int(packet.count))
		release_context={}
	super.tick_projectiles(dt)
	end_projectile_target_points()

func prepare_projectile(shot:Dictionary,_source:Dictionary,_weapon:Dictionary,_spread:float)->void:
	if bool(shot.hostile):return
	if str(shot.key)!="missile":
		var aim:Vector2=target_point(shot.target)
		if str(shot.key)=="laser":
			shot.ballistic_target_origin=aim
			shot.ballistic_target_logical=Vector2(shot.target.x,shot.target.y)
		var entry:Dictionary=shot.get("entry",{})
		var pose:Dictionary={}
		if entry.has("drone_id"):
			if drone_launch_provider.is_valid():pose=drone_launch_provider.call(str(entry.drone_id),aim,int(shot.get("salvo_ordinal",0)))
		elif launch_provider.is_valid() and shot.has("mount"):pose=launch_provider.call(int(shot.mount),aim,int(shot.get("salvo_ordinal",0)))
		if not pose.is_empty():
			shot.x=pose.position.x;shot.y=pose.position.y
			shot.launch_point=pose.position
			shot.direction=(aim-Vector2(shot.x,shot.y)).normalized()
		if shot.has("ballistic_target_origin"):
			shot.launch_point=Vector2(shot.x,shot.y)
			shot.direction=(aim-Vector2(shot.x,shot.y)).normalized()
		if str(shot.key)=="cannon":shot.speed=float(shot.speed)*RAIL_SPEED_FACTOR
		return
	if release_context.is_empty():return
	var packet:=release_context
	var target_alive:bool=missile_target_live(shot.target)
	var aim:Vector2=target_point(shot.target) if target_alive else Vector2(packet.aim)
	var pose:Dictionary={"position":Vector2(shot.x,shot.y),"direction":(aim-Vector2(shot.x,shot.y)).normalized()}
	if packet.entry.has("drone_id"):
		if drone_launch_provider.is_valid():pose=drone_launch_provider.call(str(packet.entry.drone_id),aim,int(packet.ordinal))
	elif launch_provider.is_valid():pose=launch_provider.call(int(packet.mount),aim,int(packet.ordinal))
	var origin:Vector2=pose.position
	var direction:Vector2=pose.direction
	var side:float=-1.0 if int(packet.ordinal)%2==0 else 1.0
	# The sampled visible tube is the launch point; departure changes direction only.
	var departure_angle:=MISSILE_DEPARTURE_ANGLE
	var trial:=direction.rotated(side*deg_to_rad(departure_angle))
	# Launch remains toward the battle line even at an outer drone's tube.
	if trial.y>=MISSILE_LAUNCH_FORWARD_Y or (origin.x<MISSILE_LAUNCH_EDGE_MARGIN and trial.x<0.0) or (origin.x>BATTLE_SIZE.x-MISSILE_LAUNCH_EDGE_MARGIN and trial.x>0.0):departure_angle=0.0
	direction=direction.rotated(side*deg_to_rad(departure_angle))
	shot.x=origin.x;shot.y=origin.y;shot.direction=direction.normalized()
	shot.cruise_speed=float(shot.speed)
	shot.speed=MISSILE_LAUNCH_SPEED
	shot.mount=int(packet.mount);shot.prototype_missile=true
	shot.launch_point=origin;shot.motion_age=0.0;shot.orphan_age=0.0
	shot.last_target_point=aim;shot.closest_range=INF
	shot.ignition_at=MISSILE_IGNITION;shot.seek_at=MISSILE_SEEK_START;shot.cruise_at=MISSILE_CRUISE_AT
	if not target_alive:projectile_set_target(shot,{})
	if launch_records.size()>=2048:launch_records.pop_front()
	launch_records.append({"time":motion_clock,"serial":int(shot.serial),"mount":int(shot.mount),"ordinal":int(packet.ordinal),"position":origin,"target_alive":target_alive,"target_uid":int(shot.target.get("uid",-1)),"damage":shot.damage})

func advance_custom_projectile(shot:Dictionary,dt:float)->bool:
	if bool(shot.hostile) or not bool(shot.get("prototype_missile",false)):return false
	# Existing direct-call fixtures use the same native ordered kernel. Production
	# enters once per complete substep through BattleGame.tick_projectiles.
	if native_pipeline!=null and shot.has("motion_lease"):
		native_pipeline.advance(self,dt,false,[shot])
		return true
	shot.motion_age=float(shot.motion_age)+dt
	if not missile_target_live(shot.target):
		# An ejected missile never acquires another target. Pending packets still
		# use the existing due-time target validation in tick_projectiles.
		projectile_set_target(shot,{})
	if not shot.target.is_empty() and float(shot.motion_age)>MISSILE_LIFETIME:
		_retire_missile(shot,"lifetime",false);lifetime_expirations+=1;return true
	var position:=Vector2(shot.x,shot.y)
	var old_angle:float=Vector2(shot.direction).angle()
	var cruise_speed:=lerpf(MISSILE_LAUNCH_SPEED,float(shot.get("cruise_speed",MISSILE_CRUISE_SPEED)),smoothstep(MISSILE_IGNITION,MISSILE_CRUISE_AT,float(shot.motion_age)))
	if not shot.target.is_empty():
		shot.orphan_age=0.0
		var aim:=target_point(shot.target)
		shot.last_target_point=aim
		var wanted:=(aim-position).angle()
		var range_now:=position.distance_to(aim)
		# Keep the live lock on a near miss; brake enough for a bounded turn rather
		# than deliberately turning it into a long, wandering orphan.
		if range_now<MISSILE_BRAKE_RANGE and absf(angle_difference(old_angle,wanted))>MISSILE_BRAKE_ANGLE:
			cruise_speed=minf(cruise_speed,maxf(MISSILE_MIN_GUIDED_SPEED,range_now*MISSILE_TURN_RATE*MISSILE_BRAKE_FACTOR))
		shot.speed=cruise_speed
		if float(shot.motion_age)>=MISSILE_SEEK_START:
			var angle:=rotate_toward(old_angle,wanted,MISSILE_TURN_RATE*dt)
			maximum_turn_step_error=maxf(maximum_turn_step_error,absf(angle_difference(old_angle,angle))-MISSILE_TURN_RATE*dt)
			shot.direction=Vector2.from_angle(angle)
		var next:=position+Vector2(shot.direction)*float(shot.speed)*dt
		var closest:=Geometry2D.get_closest_point_to_segment(aim,position,next)
		if closest.distance_to(aim)<=MISSILE_HIT_RADIUS:
			projectile_mark_dead(shot)
			if hit_records.size()>=2048:hit_records.pop_front()
			hit_records.append({"time":motion_clock,"serial":int(shot.serial),"target_uid":int(shot.target.get("uid",-1)),"target_alive":float(shot.target.hp)>0,"damage":shot.damage})
			event.emit("projectile_impact",{"shot":shot,"pos":aim})
			hit_enemy(shot.target,shot.damage,int(shot.type),shot.get("jewelEffects",[]),bool(shot.get("critical",false)),shot.get("combat_context",{}))
			return true
	else:
		shot.orphan_age=float(shot.orphan_age)+dt
		if float(shot.orphan_age)>=ORPHAN_LIFETIME:
			_retire_missile(shot,"orphan_timeout",false);orphan_expirations+=1;return true
		# Losing the lock stops steering, not the launch-to-cruise acceleration.
		shot.speed=maxf(float(shot.speed),cruise_speed)
		# Keep the last heading until the ordinary off-screen cleanup.
		# An empty target also excludes collision and every hit/crit effect above.
	var movement:=Vector2(shot.direction)*float(shot.speed)*dt
	shot.x+=movement.x;shot.y+=movement.y
	if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+80:projectile_mark_dead(shot)
	return true

func _retire_missile(shot:Dictionary,reason:String,coast:bool)->void:
	if bool(shot.get("retirement_emitted",false)):return
	shot.retirement_emitted=true;projectile_mark_dead(shot)
	var record:={"serial":int(shot.serial),"reason":reason,"time":motion_clock,"position":projectile_position(shot),"direction":projectile_direction(shot),"speed":projectile_speed(shot),"coast":coast}
	missile_retirements.append(record)
	if missile_retirements.size()>128:missile_retirements.pop_front()
	# Presentation-only notification, never a projectile impact or damage event.
	event.emit("prototype_missile_retired",record)

func _native_missile_retire(shot:Dictionary,reason:String)->void:
	_retire_missile(shot,reason,false)
	if reason=="lifetime":lifetime_expirations+=1
	elif reason=="orphan_timeout":orphan_expirations+=1

func _native_projectile_contact(shot:Dictionary,aim:Vector2,kind:int)->void:
	if kind==1:
		if hit_records.size()>=2048:hit_records.pop_front()
		hit_records.append({"time":motion_clock,"serial":int(shot.serial),"target_uid":int(shot.target.get("uid",-1)),"target_alive":float(shot.target.hp)>0,"damage":shot.damage})
	super._native_projectile_contact(shot,aim,kind)
