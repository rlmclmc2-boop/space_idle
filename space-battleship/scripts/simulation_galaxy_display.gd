extends "res://scripts/galaxy_system.gd"
## Display-only compiled aggregate. No authoritative region or Game references.
var display_multipliers:Dictionary={}
func multiplier(effect:String)->float:
	return float(display_multipliers.get(effect,1.0))
