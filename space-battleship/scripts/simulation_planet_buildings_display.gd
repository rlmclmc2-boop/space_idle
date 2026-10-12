extends "res://scripts/planet_buildings.gd"
## Display-only helper. Mutation arguments are values; the owner supplies its Game.
func activate(g, planet_id: String, building_id: String) -> bool:
	if g.display_ready:
		return g.command("planet_buildings.activate",[planet_id,building_id])
	return super.activate(g,planet_id,building_id)

func assign(g, planet_id: String, building_id: String, crew_id: String) -> bool:
	if g.display_ready:
		return g.command("planet_buildings.assign",[planet_id,building_id,crew_id])
	return super.assign(g,planet_id,building_id,crew_id)

