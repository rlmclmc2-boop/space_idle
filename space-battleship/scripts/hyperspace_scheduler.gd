extends RefCounted
## Online game time only. A blocked inventory never accrues replay debt.
const Bag=preload("res://scripts/drone_inventory.gd")


func reset() -> void:
	pass # All elapsed work belongs to the saved profile namespace.

static func charge(s: Dictionary,c: Dictionary,dt: float) -> void:
	if float(s.energy)<float(c.energy_cap):s.energy=minf(float(c.energy_cap),float(s.energy)+float(c.energy_rate)*dt)

func advance(owner,g,dt: float) -> void:
	var c: Dictionary=owner.config
	if not is_finite(dt) or dt<=0 or g.paused or int(g.profile.highestLevel)<int(c.unlock_stage):return
	c=owner.online_config(g)
	var remaining:=dt+float(g.profile.hyperspace.pending_time)
	g.profile.hyperspace.pending_time=0.0
	var completions:=0
	while remaining>0.000000001:
		var s: Dictionary=g.profile.hyperspace
		if not s.active.is_empty() and s.active.status=="completed_pending":
			if not owner.claim(g,int(s.active.round_id),int(s.active.run_id)):
				charge(s,c,remaining);return
			s=g.profile.hyperspace
		if s.active.is_empty():
			if not owner.auto_eligible(g) or not Bag.has_space(s.inventory,c):
				s.blocked=s.auto.enabled and not Bag.has_space(s.inventory,c)
				charge(s,c,remaining);return
			# The authored auto policy starts at full energy, with reduced ticket cost.
			var wait:=maxf(0.0,(float(c.energy_cap)-float(s.energy))/float(c.energy_rate))
			var step:=minf(wait,remaining);charge(s,c,step);remaining-=step
			if step+0.000000001<wait:return
			if not owner.start_auto(g):charge(s,c,remaining);return
			s=g.profile.hyperspace
		if s.active.mode!="auto":charge(s,c,remaining);return
		var a: Dictionary=s.active
		var step:=minf(remaining,maxf(0.0,float(a.duration)-float(a.work)))
		a.work=minf(float(a.duration),float(a.work)+step);charge(s,c,step);remaining-=step
		if float(a.work)+0.000000001<float(a.duration):return
		# Freeze exactly once; errors await an explicit retry, without generating debt.
		if not owner.complete_auto(g):charge(s,c,remaining);return
		completions+=1
		if not owner.claim(g,int(a.round_id),int(a.run_id)):
			charge(g.profile.hyperspace,c,remaining);return
		if not Bag.has_space(g.profile.hyperspace.inventory,c):
			g.profile.hyperspace.blocked=true;charge(g.profile.hyperspace,c,remaining);return
		if completions>=int(c.completion_budget):
			g.profile.hyperspace.pending_time=remaining;return
