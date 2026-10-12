extends "res://scripts/hyperspace_system.gd"
## Display-only helper. Mutation arguments are values; the owner supplies its Game.
func exchange_materials(g,request:Dictionary) -> Dictionary:
	if g.display_ready:
		return g.command("hyperspace.exchange_materials",[request])
	return super.exchange_materials(g,request)

func equip_drone(g,id: String,replace_id: String="") -> Dictionary:
	if g.display_ready:
		return g.command("hyperspace.equip_drone",[id,replace_id])
	return super.equip_drone(g,id,replace_id)

func unequip_drone(g,id: String) -> Dictionary:
	if g.display_ready:
		return g.command("hyperspace.unequip_drone",[id])
	return super.unequip_drone(g,id)

func set_equipped(g,ids: Array,hull_capacity: int=-1) -> bool:
	if g.display_ready:
		return g.command("hyperspace.set_equipped",[ids,hull_capacity])
	return super.set_equipped(g,ids,hull_capacity)

func set_favorites(g,ids: Array) -> bool:
	if g.display_ready:
		return g.command("hyperspace.set_favorites",[ids])
	return super.set_favorites(g,ids)

func set_preset(g,index: int,name: String,ids: Array,hanging_loadouts: Dictionary={}) -> bool:
	if g.display_ready:
		return g.command("hyperspace.set_preset",[index,name,ids,hanging_loadouts])
	return super.set_preset(g,index,name,ids,hanging_loadouts)

func clear_preset(g,index: int) -> bool:
	if g.display_ready:
		return g.command("hyperspace.clear_preset",[index])
	return super.clear_preset(g,index)

func remove_unprotected(g,id: String) -> bool:
	if g.display_ready:
		return g.command("hyperspace.remove_unprotected",[id])
	return super.remove_unprotected(g,id)

func claim_sealed(g,id: String) -> bool:
	if g.display_ready:
		return g.command("hyperspace.claim_sealed",[id])
	return super.claim_sealed(g,id)

func forge(g,request: Dictionary) -> Dictionary:
	if g.display_ready:
		return g.command("hyperspace.forge",[request])
	return super.forge(g,request)

func attach_hangings(g,id: String,keys: Array) -> bool:
	if g.display_ready:
		return g.command("hyperspace.attach_hangings",[id,keys])
	return super.attach_hangings(g,id,keys)

func set_filter(g,filter: Dictionary) -> bool:
	if g.display_ready:
		return g.command("hyperspace.set_filter",[filter])
	return super.set_filter(g,filter)

func import_filter(g,value: String) -> bool:
	if g.display_ready:
		return g.command("hyperspace.import_filter",[value])
	return super.import_filter(g,value)

func set_legendary_collection(g,ids: Array) -> bool:
	if g.display_ready:
		return g.command("hyperspace.set_legendary_collection",[ids])
	return super.set_legendary_collection(g,ids)

func apply_preset(g,index: int) -> bool:
	if g.display_ready:
		return g.command("hyperspace.apply_preset",[index])
	return super.apply_preset(g,index)
