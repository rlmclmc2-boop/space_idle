extends "res://scripts/game.gd"
## Authorized prototype mechanics only. Shared attack/hit paths remain authoritative.
const EJECTION_GAP := 0.10
const RAIL_SPEED_FACTOR := 12.0
const MISSILE_LAUNCH_SPEED := 180.0
const MISSILE_CRUISE_SPEED := 620.0
const MISSILE_TURN_RATE := 4.5
const ORPHAN_LIFETIME := 0.55
var launch_provider:Callable
var target_provider:Callable
var missile_queue:Array[Dictionary]=[]
var motion_clock:=0.0
var release_context:Dictionary={}
var launch_records:Array[Dictionary]=[]
var hit_records:Array[Dictionary]=[]
var lifetime_expirations:=0
var maximum_turn_step_error:=0.0
var orphan_expirations:=0
var cancelled_ejections:=0

func _init(database:ShipDatabase,persist:=false)->void:super(database,persist)

func tick(dt:float)->void:
	if paused:return
	var remaining:=maxf(0.0,dt)
	while remaining>0.000000001:
		var step:=minf(remaining,1.0/60.0)
		for packet in missile_queue:
			var until:=float(packet.due)-motion_clock
			if until>0.000000001:step=minf(step,until)
		motion_clock+=step
		super.tick(step)
		remaining-=step

func reset_player()->void:
	cancelled_ejections+=missile_queue.size();missile_queue.clear()
	super.reset_player()

func change_state(next:State)->void:
	if next in [State.RETREAT,State.LEVEL_CLEAR]:
		cancelled_ejections+=missile_queue.size();missile_queue.clear()
	super.change_state(next)

func launch_player_attack(index:int,target:Dictionary,weapon:Dictionary,attack:Dictionary,offset:Vector2,spread:float,salvo_index:int=0,salvo_count:int=1)->void:
	if str(slot_entry("weapons",index).key)!="missile":
		super.launch_player_attack(index,target,weapon,attack,offset,spread,salvo_index,salvo_count);return
	# Payload is resolved now, exactly once. Delayed ejection does not reroll gems/crit.
	var aim:=target_point(target)
	missile_queue.append({"mount":index,"entry":slot_entry("weapons",index),"source":player,"target":target,"aim":aim,"weapon":weapon.duplicate(true),"attack":attack,"offset":offset,"spread":spread,"ordinal":salvo_index,"count":salvo_count,"due":motion_clock+float(salvo_index)*EJECTION_GAP})

func target_point(target:Dictionary)->Vector2:
	if target_provider.is_valid():return target_provider.call(target)
	return Vector2(target.x,target.y)

func tick_projectiles(dt:float)->void:
	for packet in missile_queue.duplicate():
		if float(packet.due)>motion_clock+0.000000001:continue
		missile_queue.erase(packet)
		if not is_same(packet.source,player) or not is_same(slot_entry("weapons",int(packet.mount)),packet.entry) or str(packet.entry.key)!="missile" or N.compare(player.armour,0)<=0:
			cancelled_ejections+=1;continue
		release_context=packet
		# A committed salvo finishes after a normal wave transition. A dead target
		# produces an orphan, never reacquisition or damage to a ghost target.
		super.launch_player_attack(int(packet.mount),packet.target,packet.weapon,packet.attack,packet.offset,float(packet.spread),int(packet.ordinal),int(packet.count))
		release_context={}
	super.tick_projectiles(dt)

func prepare_projectile(shot:Dictionary,_source:Dictionary,_weapon:Dictionary,_spread:float)->void:
	if bool(shot.hostile):return
	if str(shot.key)=="cannon":shot.speed=float(shot.speed)*RAIL_SPEED_FACTOR;return
	if str(shot.key)!="missile" or release_context.is_empty():return
	var packet:=release_context
	var target_alive:bool=not shot.target.is_empty() and enemies.has(shot.target) and float(shot.target.hp)>0
	var aim:Vector2=target_point(shot.target) if target_alive else Vector2(packet.aim)
	var pose:Dictionary=launch_provider.call(int(packet.mount),aim,int(packet.ordinal)) if launch_provider.is_valid() else {"position":Vector2(shot.x,shot.y),"direction":(aim-Vector2(shot.x,shot.y)).normalized()}
	var origin:Vector2=pose.position
	var direction:Vector2=pose.direction
	var side:float=-1.0 if int(packet.ordinal)%2==0 else 1.0
	origin+=direction.orthogonal()*side*3.0
	direction=direction.rotated(side*deg_to_rad(14.0))
	shot.x=origin.x;shot.y=origin.y;shot.direction=direction.normalized()
	shot.speed=MISSILE_LAUNCH_SPEED
	shot.mount=int(packet.mount);shot.prototype_missile=true
	shot.launch_point=origin;shot.motion_age=0.0;shot.orphan_age=0.0
	shot.last_target_point=aim;shot.closest_range=INF
	if not target_alive:shot.target={}
	if launch_records.size()>=2048:launch_records.pop_front()
	launch_records.append({"time":motion_clock,"serial":int(shot.serial),"mount":int(shot.mount),"ordinal":int(packet.ordinal),"position":origin,"target_alive":target_alive,"damage":shot.damage})

func advance_custom_projectile(shot:Dictionary,dt:float)->bool:
	if not bool(shot.get("prototype_missile",false)):return false
	shot.motion_age=float(shot.motion_age)+dt
	if float(shot.motion_age)>3.0:shot.dead=true;lifetime_expirations+=1;return true
	if not shot.target.is_empty() and (not enemies.has(shot.target) or float(shot.target.hp)<=0):shot.target={}
	var position:=Vector2(shot.x,shot.y)
	var old_angle:float=Vector2(shot.direction).angle()
	shot.speed=lerpf(MISSILE_LAUNCH_SPEED,MISSILE_CRUISE_SPEED,smoothstep(0.04,0.28,float(shot.motion_age)))
	if not shot.target.is_empty():
		var aim:=target_point(shot.target)
		shot.last_target_point=aim
		if float(shot.motion_age)>0.06:
			var angle:=rotate_toward(old_angle,(aim-position).angle(),MISSILE_TURN_RATE*dt)
			maximum_turn_step_error=maxf(maximum_turn_step_error,absf(angle_difference(old_angle,angle))-MISSILE_TURN_RATE*dt)
			shot.direction=Vector2.from_angle(angle)
		var next:=position+Vector2(shot.direction)*float(shot.speed)*dt
		var closest:=Geometry2D.get_closest_point_to_segment(aim,position,next)
		if closest.distance_to(aim)<=5.0:
			shot.dead=true
			if hit_records.size()>=2048:hit_records.pop_front()
			hit_records.append({"time":motion_clock,"serial":int(shot.serial),"target_uid":int(shot.target.get("uid",-1)),"target_alive":float(shot.target.hp)>0,"damage":shot.damage})
			event.emit("projectile_impact",{"shot":shot,"pos":aim})
			hit_enemy(shot.target,shot.damage,int(shot.type),shot.get("jewelEffects",[]),bool(shot.get("critical",false)))
			return true
		# A near miss coasts away instead of looping around a target indefinitely.
		var range_now:=position.distance_to(aim)
		if range_now<float(shot.closest_range):shot.closest_range=range_now
		elif float(shot.closest_range)<90.0 and range_now>float(shot.closest_range)+12.0:shot.target={}
	else:
		shot.orphan_age=float(shot.orphan_age)+dt
		if float(shot.orphan_age)>=ORPHAN_LIFETIME:shot.dead=true;orphan_expirations+=1
	var movement:=Vector2(shot.direction)*float(shot.speed)*dt
	shot.x+=movement.x;shot.y+=movement.y
	if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+80:shot.dead=true
	return true
