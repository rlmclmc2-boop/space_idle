extends RefCounted
## Runtime-only reallocation anchors. Real health/capacity changes invalidate
## each pool independently; no saved balance or healing/timer state is owned here.
const N = preload("res://scripts/growth_number.gd")
const CONSERVATIVE_SCALE = 1.0 - 1.0e-12
var anchors: Dictionary = {}

func clear() -> void:
	anchors.clear()

func copy_number(value):
	return value.duplicate(true) if value is Dictionary else value

func remap(key: String, current, old_maximum, new_maximum):
	# Never keep a positive hidden fraction through death or zero capacity.
	if N.compare(current,0)<=0 or N.compare(old_maximum,0)<=0 or N.compare(new_maximum,0)<=0:
		anchors.erase(key)
		return 0.0
	var anchor: Dictionary = anchors.get(key,{})
	if anchor.is_empty() or N.compare(current,anchor.last_health)!=0 or N.compare(old_maximum,anchor.last_maximum)!=0:
		anchor = {"health":copy_number(N.minimum(current,old_maximum)),"maximum":copy_number(old_maximum)}
	var mapped
	if N.compare(old_maximum,new_maximum)==0:
		mapped = N.minimum(current,new_maximum)
	elif N.compare(new_maximum,anchor.maximum)==0:
		# Exact return to the anchor avoids accumulating rounding on slider loops.
		mapped = anchor.health
	elif N.compare(anchor.health,anchor.maximum)==0:
		mapped = new_maximum
	else:
		# Mantissas avoid an overflowing product or an underflowing health ratio.
		var health := N.parts(anchor.health)
		var before := N.parts(anchor.maximum)
		var after := N.parts(new_maximum)
		mapped = N.make(health[0]*after[0]/before[0]*CONSERVATIVE_SCALE,health[1]+after[1]-before[1])
		mapped = N.minimum(mapped,new_maximum)
	anchor.last_health = copy_number(mapped)
	anchor.last_maximum = copy_number(new_maximum)
	anchors[key] = anchor
	return mapped
