extends RefCounted
## Online game time only. A blocked inventory never accrues replay debt.
const Bag=preload("res://scripts/drone_inventory.gd")


func reset() -> void:
	pass # All elapsed work belongs to the saved profile namespace.

static func charge(s: Dictionary,c: Dictionary,dt: float) -> void:
	# Failure refunds may exceed capacity; pause charge without discarding paid energy.
	var earned:float=float(c.energy_rate)*dt
	if c.has("late_supply_base_rate"):
		var start:float=float(s.get("late_supply_work",0.0))
		earned=ramp_gain(c,start,dt)
		s.late_supply_work=minf(float(c.late_supply_ramp_seconds),start+dt)
	if float(s.energy)>=float(c.energy_cap):return
	s.energy=minf(float(c.energy_cap),float(s.energy)+earned)

static func ramp_gain(c:Dictionary,start:float,dt:float)->float:
	var duration:float=float(c.late_supply_ramp_seconds)
	var base:float=float(c.late_supply_base_rate)
	var maximum:float=float(c.late_energy_rate_multiplier)
	var head:float=minf(dt,maxf(0.0,duration-start))
	var slope:float=base*(maximum-1.0)/duration
	var initial:float=base*(1.0+(maximum-1.0)*minf(start,duration)/duration)
	return initial*head+0.5*slope*head*head+base*maximum*(dt-head)

static func charge_wait(s:Dictionary,c:Dictionary)->float:
	var needed:float=maxf(0.0,float(c.energy_cap)-float(s.energy))
	if not c.has("late_supply_base_rate"):return needed/float(c.energy_rate)
	var start:float=float(s.get("late_supply_work",0.0))
	var remaining:float=maxf(0.0,float(c.late_supply_ramp_seconds)-start)
	var gain:float=ramp_gain(c,start,remaining)
	if needed>=gain:return remaining+(needed-gain)/(float(c.late_supply_base_rate)*float(c.late_energy_rate_multiplier))
	var initial:float=float(c.late_supply_base_rate)*(1.0+(float(c.late_energy_rate_multiplier)-1.0)*start/float(c.late_supply_ramp_seconds))
	var slope:float=float(c.late_supply_base_rate)*(float(c.late_energy_rate_multiplier)-1.0)/float(c.late_supply_ramp_seconds)
	return needed/initial if is_zero_approx(slope) else 2.0*needed/(sqrt(initial*initial+2.0*slope*needed)+initial)

func advance(owner,g,dt: float) -> void:
	var c: Dictionary=owner.config
	if not is_finite(dt) or dt<=0 or g.paused or int(g.profile.highestLevel)<int(c.unlock_stage):return
	c=owner.online_config(g)
	# A challenge owns the global slot; even legacy background rewards stay frozen.
	if not g.profile.hyperspace.active.is_empty() and g.profile.hyperspace.active.status=="started":
		charge(g.profile.hyperspace,c,dt);return
	var remaining:=dt+float(g.profile.hyperspace.pending_time)
	g.profile.hyperspace.pending_time=0.0
	var completions:=0
	while remaining>0.000000001:
		var s:Dictionary=g.profile.hyperspace
		# Both receipts may settle out of order; identity, not a global watermark, owns payment.
		for slot in ["active","idle"]:
			var pending:Dictionary=s[slot]
			if not pending.is_empty() and pending.status=="completed_pending":
				if not owner.claim(g,int(pending.round_id),int(pending.run_id)):charge(g.profile.hyperspace,c,remaining);return
				s=g.profile.hyperspace
		if s.idle.is_empty():
			if not owner.auto_eligible(g) or not Bag.has_space(s.inventory,c):
				s.blocked=s.auto.enabled and not Bag.has_space(s.inventory,c);charge(s,c,remaining);return
			if not owner.start_auto(g):charge(s,c,remaining);return
			s=g.profile.hyperspace
		var a:Dictionary=s.idle
		var once:bool=a.mode=="idle" or not s.auto.enabled
		var step:=minf(remaining,maxf(0.0,float(a.duration)-float(a.work)))
		a.work=minf(float(a.duration),float(a.work)+step);charge(s,c,step);remaining-=step
		if float(a.work)+0.000000001<float(a.duration):return
		if not owner.complete_auto(g):charge(s,c,remaining);return
		completions+=1
		if not owner.claim(g,int(a.round_id),int(a.run_id)):charge(g.profile.hyperspace,c,remaining);return
		if once:charge(g.profile.hyperspace,c,remaining);return
		if not Bag.has_space(g.profile.hyperspace.inventory,c):
			g.profile.hyperspace.blocked=true;charge(g.profile.hyperspace,c,remaining);return
		if completions>=int(c.completion_budget):g.profile.hyperspace.pending_time=remaining;return
