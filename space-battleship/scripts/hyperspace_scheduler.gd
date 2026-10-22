extends RefCounted
## Online game time only. A blocked inventory never accrues replay debt.
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
