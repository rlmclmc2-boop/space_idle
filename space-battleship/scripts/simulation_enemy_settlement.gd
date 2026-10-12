extends RefCounted
## Typed arithmetic settlement slice, not a complete battle/event authority.
## Caller resolves trigger/guidance/drone modifications before applying this slice;
## caller must still settle death, drops and chains synchronously afterward.
const N=preload("res://scripts/growth_number.gd")
const State=preload("res://scripts/simulation_battle_state.gd")
class HitResult extends RefCounted:
	var applied:bool=false
	var identity:int=0
	var generation:int=0
	var position:Vector2=Vector2.ZERO
	var amount:Variant=0.0
	var absorbed:Variant=0.0
	var health_damage:Variant=0.0
	var settled_health:Variant=0.0
	var killed:bool=false

func settle_shield(target:State.EntityState,at:float)->void:
	if N.compare(target.health.value(),0)<=0 or N.compare(target.maximum_shield.value(),0)<=0:return
	var ready_at=target.shield_hit_at+target.shield_delay
	var healing_time=maxf(0,at-ready_at)-maxf(0,target.shield_updated_at-ready_at)
	if healing_time>0:
		target.shield.assign(N.minimum(target.maximum_shield.value(),N.add(target.shield.value(),N.multiply(target.maximum_shield.value(),target.shield_recovery*healing_time))))
	target.shield_updated_at=at

func hit(target:State.EntityState,raw:Variant,damage_type:int,resistance:float,shield_clock:float,scheduled_hit_at:float,collect_statistics:bool)->HitResult:
	var result=HitResult.new()
	result.identity=target.id;result.generation=target.generation;result.position=target.position
	if N.compare(target.health.value(),0)<=0:return result
	result.applied=true
	var incoming=N.multiply(raw,1.0+target.interference)
	if N.compare(target.maximum_shield.value(),0)>0:
		incoming=N.maximum(1,incoming)
		var at=maxf(target.shield_updated_at,shield_clock if scheduled_hit_at<0 else scheduled_hit_at)
		settle_shield(target,at);target.shield_hit_at=at
		if N.compare(target.shield.value(),0)>0:
			var factor=1.0-resistance if damage_type==target.shield_type else 1.0
			result.absorbed=N.minimum(target.shield.value(),N.maximum(1,N.multiply(incoming,factor)))
			target.shield.subtract(result.absorbed)
			incoming=N.maximum(0,N.subtract(incoming,N.divide(result.absorbed,factor))) if factor>0 else 0.0
	var amount:Variant=0.0
	if N.compare(result.absorbed,0)<=0 or N.compare(incoming,0)>0:
		amount=N.maximum(1,N.ceiling(N.multiply(incoming,1.0-resistance if damage_type==target.armour_type else 1.0)))
		if collect_statistics:result.settled_health=N.minimum(target.health.value(),amount)
		target.health.subtract(amount)
	result.health_damage=amount
	result.amount=N.add(amount,result.absorbed)
	result.killed=N.compare(target.health.value(),0)<=0
	target.alive=not result.killed
	return result
