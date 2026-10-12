extends "res://scripts/crew_system.gd"
## Display-only helper. Mutation arguments are values; the owner supplies its Game.
func assign(g, id: String, assignment: String, target: String, upgrade_mode := "") -> bool:
	if g.display_ready:
		return g.command("crew.assign",[id,assignment,target,upgrade_mode])
	return super.assign(g,id,assignment,target,upgrade_mode)

